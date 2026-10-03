-- Prompt 09G-B3-UX-01-FIX-01 §E: additive enrichment of
-- rpc_get_my_member_statement's PAYMENT activity allocations.
--
-- Physical UAT of B3 found that every CONTRIBUTION_COMPONENT
-- allocation rendered as a bare, undifferentiated "Contribution" row
-- (3,000 / 3,000 / 10,000 with no way to tell them apart) because the
-- allocation JSON only ever returned bare FKs (charge_id,
-- charge_component_id) — never the human-readable period label or the
-- BASE/PENALTY/ADJUSTMENT/OPENING_BALANCE classification Flutter
-- would need to render something a member can actually understand.
--
-- Both are already deterministically resolvable from data this same
-- RPC's own CONTRIBUTION activity branch already joins for exactly
-- this purpose (contribution_charge_components.component_type,
-- contribution_periods.label via member_contribution_charges) — this
-- migration does nothing but SELECT those same two existing columns
-- into the allocation's own metadata object. It does not:
--   * touch amounts, ordering, effective dates, or any other branch;
--   * add a row, a table, or a stored balance;
--   * change payment_allocations or any other table;
--   * alter authorization (identical current_membership_id +
--     financial_report.self_view guard, byte-identical otherwise).
--
-- LOAN_* allocations are untouched here: `allocation_target_type`
-- itself already distinguishes LOAN_PRINCIPAL/LOAN_INTEREST/
-- LOAN_PENALTY/LOAN_PRINCIPAL_PREPAYMENT/LOAN_RECOVERY_* — Flutter
-- already has everything it needs for those and gets a presentation
-- fix only (no backend change required for loan allocations).
--
-- `period_label`/`component_type` are null for a LOAN_* allocation
-- (no charge/charge_component on those rows — see
-- payment_allocations_target_consistency, 20260904091000) and for any
-- allocation created before this migration's deployment is irrelevant
-- here since the join is computed fresh on every call, not backfilled
-- data — there is no historical row this doesn't resolve correctly
-- for CONTRIBUTION_COMPONENT allocations.
--
-- Migration 20260924090000 (already deployed to production) is never
-- edited — this is a new, separately-ordered CREATE OR REPLACE of the
-- same function. NOT deployed by this phase (presentation/foundation
-- work only); see 09G-B3-UX-01-FIX-01's own scope boundary.

create or replace function public.rpc_get_my_member_statement(
  p_group_id uuid,
  p_from_date date default null,
  p_to_date date default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_membership_id uuid;
  v_limit integer;
  v_offset integer;
  v_member jsonb;
  v_group jsonb;
  v_summary jsonb;
  v_activity jsonb;
  v_contrib_outstanding numeric;
  v_contrib_pending_penalty numeric;
  v_loan_outstanding numeric;
  v_loan_pending_penalty numeric;
  v_wallet_balance numeric;
  v_last_payment jsonb;
  v_opening_cutoff date;
  v_period_opening jsonb;
  v_period_closing jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_group_id is null then
    raise exception 'p_group_id is required' using errcode = '22023';
  end if;

  if p_from_date is not null and p_to_date is not null and p_from_date > p_to_date then
    raise exception 'p_from_date must not be after p_to_date' using errcode = '22023';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  if not public.has_group_permission(p_group_id, 'financial_report.self_view') then
    raise exception 'Not authorized to view a financial statement' using errcode = '42501';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  -- member / group metadata -----------------------------------------------

  select jsonb_build_object(
    'membership_id', gm.id,
    'display_name', gm.display_name,
    'member_number', gm.member_number,
    'membership_status', gm.status
  ),
  jsonb_build_object(
    'group_id', g.id,
    'group_name', g.name,
    'group_code', g.code,
    'currency', g.currency
  )
  into v_member, v_group
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = v_membership_id;

  -- summary (always CURRENT position — never implied "as of p_to_date") --

  select coalesce(sum(s.outstanding), 0)
  into v_contrib_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.membership_id = v_membership_id and c.group_id = p_group_id;

  select coalesce(sum(s.outstanding), 0)
  into v_contrib_pending_penalty
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.membership_id = v_membership_id
    and c.group_id = p_group_id
    and s.component_type = 'PENALTY';

  select coalesce(sum(pos.total_outstanding), 0),
         coalesce(sum(pos.penalty_outstanding), 0)
  into v_loan_outstanding, v_loan_pending_penalty
  from public.loan_accounts la
  cross join lateral public.loan_statement_schedule_position(la.id, current_date) pos
  where la.membership_id = v_membership_id
    and la.group_id = p_group_id
    and la.status = 'ACTIVE';

  v_wallet_balance := public.member_wallet_balance(v_membership_id);

  select jsonb_build_object(
    'amount', p.amount,
    'effective_at', p.effective_at,
    'receipt_number', p.receipt_number
  )
  into v_last_payment
  from public.payments p
  where p.membership_id = v_membership_id
    and p.group_id = p_group_id
    and p.status = 'POSTED'
  order by p.effective_at desc, p.created_at desc
  limit 1;

  v_summary := jsonb_build_object(
    'contributions', jsonb_build_object(
      'current_outstanding', v_contrib_outstanding,
      'pending_penalties', v_contrib_pending_penalty
    ),
    'loans', jsonb_build_object(
      'current_outstanding', v_loan_outstanding,
      'pending_penalties', v_loan_pending_penalty
    ),
    'wallet', jsonb_build_object(
      'current_balance', v_wallet_balance
    ),
    'last_payment', v_last_payment
  );

  -- period.opening / period.closing (09G-B3-B-FIX-01) ----------------------

  if p_from_date is not null then
    v_opening_cutoff := p_from_date - 1;
    v_period_opening := jsonb_build_object(
      'as_of_date', v_opening_cutoff,
      'contributions', jsonb_build_object(
        'outstanding', (
          select coalesce(sum(s.outstanding), 0)
          from public.member_contribution_charges c
          cross join lateral public.contribution_charge_component_states_as_of(c.id, v_opening_cutoff) s
          where c.membership_id = v_membership_id and c.group_id = p_group_id
        )
      ),
      'loans', jsonb_build_object(
        'outstanding', (
          select coalesce(sum(public.loan_account_outstanding_as_of(la.id, v_opening_cutoff)), 0)
          from public.loan_accounts la
          where la.membership_id = v_membership_id and la.group_id = p_group_id
        )
      ),
      'wallet', jsonb_build_object(
        'balance', public.member_wallet_balance_as_of_membership(v_membership_id, v_opening_cutoff)
      )
    );
  else
    v_period_opening := null;
  end if;

  if p_to_date is not null then
    v_period_closing := jsonb_build_object(
      'as_of_date', p_to_date,
      'contributions', jsonb_build_object(
        'outstanding', (
          select coalesce(sum(s.outstanding), 0)
          from public.member_contribution_charges c
          cross join lateral public.contribution_charge_component_states_as_of(c.id, p_to_date) s
          where c.membership_id = v_membership_id and c.group_id = p_group_id
        )
      ),
      'loans', jsonb_build_object(
        'outstanding', (
          select coalesce(sum(public.loan_account_outstanding_as_of(la.id, p_to_date)), 0)
          from public.loan_accounts la
          where la.membership_id = v_membership_id and la.group_id = p_group_id
        )
      ),
      'wallet', jsonb_build_object(
        'balance', public.member_wallet_balance_as_of_membership(v_membership_id, p_to_date)
      )
    );
  else
    v_period_closing := null;
  end if;

  -- activity ---------------------------------------------------------------

  with activity as (
    select
      cc.id as event_id,
      'CONTRIBUTION'::text as domain,
      cc.component_type::text as event_type,
      cc.effective_at as effective_date,
      cc.assessed_amount as amount,
      false as is_reversed,
      (case cc.component_type::text
        when 'OPENING_BALANCE' then 1
        when 'BASE' then 2
        when 'PENALTY' then 3
        when 'ADJUSTMENT' then 4
        when 'WAIVER' then 5
        else 9
      end) as source_priority,
      cc.created_at as tie_created_at,
      cc.id as tie_id,
      jsonb_build_object(
        'charge_id', c.id,
        'period_id', c.period_id,
        'period_label', p.label,
        'due_date', c.due_date,
        'reason', cc.reason
      ) as metadata
    from public.contribution_charge_components cc
    join public.member_contribution_charges c on c.id = cc.charge_id
    join public.contribution_periods p on p.id = c.period_id
    where c.membership_id = v_membership_id and c.group_id = p_group_id

    union all

    select
      pay.id,
      'PAYMENT',
      'PAYMENT',
      pay.effective_at,
      pay.amount,
      pay.status = 'REVERSED',
      6,
      pay.created_at,
      pay.id,
      jsonb_build_object(
        'status', pay.status,
        'receipt_number', pay.receipt_number,
        'payment_method', pay.payment_method,
        'external_reference', pay.external_reference,
        'reversal_reason', pay.reversal_reason,
        -- 09G-B3-UX-01-FIX-01 §E: period_label/component_type are the
        -- two additive fields — resolved via the SAME charge_id/
        -- charge_component_id FKs already returned, joined exactly
        -- like the CONTRIBUTION branch above. Both are null for a
        -- LOAN_* allocation (no charge/charge_component on those rows
        -- by the table's own target-consistency check).
        'allocations', coalesce((
          select jsonb_agg(jsonb_build_object(
            'amount', pa.amount,
            'target_type', pa.allocation_target_type,
            'charge_id', pa.charge_id,
            'charge_component_id', pa.charge_component_id,
            'loan_account_id', pa.loan_account_id,
            'loan_installment_id', pa.loan_installment_id,
            'period_label', ap.label,
            'component_type', acc.component_type
          ) order by pa.created_at, pa.id)
          from public.payment_allocations pa
          left join public.contribution_charge_components acc
            on acc.id = pa.charge_component_id
          left join public.member_contribution_charges ac
            on ac.id = pa.charge_id
          left join public.contribution_periods ap
            on ap.id = ac.period_id
          where pa.payment_id = pay.id
        ), '[]'::jsonb)
      ) as metadata
    from public.payments pay
    where pay.membership_id = v_membership_id and pay.group_id = p_group_id

    union all

    select
      ld.id,
      'LOAN',
      'DISBURSEMENT',
      ld.effective_at,
      ld.amount,
      false,
      7,
      ld.created_at,
      ld.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'reference', ld.reference
      )
    from public.loan_disbursements ld
    join public.loan_accounts la on la.id = ld.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      pc.id,
      'LOAN',
      'PENALTY_ASSESSED',
      pc.assessment_date,
      pc.penalty_amount,
      false,
      12,
      pc.created_at,
      pc.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'loan_installment_id', pc.loan_installment_id,
        'sequence_number', pc.sequence_number,
        'origin', pc.origin
      )
    from public.loan_penalty_charges pc
    join public.loan_accounts la on la.id = pc.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      wo.id,
      'LOAN',
      wo.event_type,
      wo.effective_date,
      wo.principal_amount + wo.interest_amount + wo.penalty_amount,
      wo.event_type = 'REVERSAL',
      (case wo.event_type when 'WRITE_OFF' then 8 else 9 end),
      wo.created_at,
      wo.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'reason_code', wo.reason_code,
        'note', wo.note,
        'principal_amount', wo.principal_amount,
        'interest_amount', wo.interest_amount,
        'penalty_amount', wo.penalty_amount
      )
    from public.loan_write_off_events wo
    join public.loan_accounts la on la.id = wo.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      oa.id,
      'LOAN',
      oa.adjustment_type,
      oa.effective_date,
      oa.amount,
      oa.adjustment_type = 'REVERSAL',
      10,
      oa.created_at,
      oa.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'target_type', oa.target_type,
        'reason_code', oa.reason_code,
        'note', oa.note
      )
    from public.loan_obligation_adjustments oa
    join public.loan_accounts la on la.id = oa.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      re.id,
      'LOAN',
      'RESTRUCTURED',
      re.effective_date,
      0::numeric(14, 2),
      false,
      13,
      re.created_at,
      re.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'reason', re.reason,
        'new_interest_rate', re.new_interest_rate,
        'new_term', re.new_term,
        'new_first_installment_date', re.new_first_installment_date
      )
    from public.loan_restructure_events re
    join public.loan_accounts la on la.id = re.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      we.id,
      'WALLET',
      we.entry_type::text,
      we.effective_at,
      we.amount,
      we.entry_type::text = 'REVERSAL',
      11,
      we.created_at,
      we.id,
      jsonb_build_object(
        'source_type', we.source_type,
        'source_id', we.source_id
      )
    from public.member_wallet_entries we
    where we.membership_id = v_membership_id and we.group_id = p_group_id
  ),
  filtered as (
    select *
    from activity
    where (p_from_date is null or effective_date >= p_from_date)
      and (p_to_date is null or effective_date <= p_to_date)
  ),
  total as (
    select count(*) as total_count from filtered
  ),
  paged as (
    select *
    from filtered
    order by effective_date asc, source_priority asc, tie_created_at asc, tie_id asc
    limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'event_id', paged.event_id,
          'domain', paged.domain,
          'event_type', paged.event_type,
          'effective_date', paged.effective_date,
          'amount', paged.amount,
          'is_reversed', paged.is_reversed,
          'metadata', paged.metadata
        )
        order by paged.effective_date asc, paged.source_priority asc, paged.tie_created_at asc, paged.tie_id asc
      )
      from paged
    ), '[]'::jsonb),
    'limit', v_limit,
    'offset', v_offset,
    'total_count', (select total_count from total),
    'has_more', (v_offset + v_limit) < (select total_count from total)
  )
  into v_activity;

  return jsonb_build_object(
    'member', v_member,
    'group', v_group,
    'period', jsonb_build_object(
      'from_date', p_from_date,
      'to_date', p_to_date,
      'opening', v_period_opening,
      'closing', v_period_closing
    ),
    'summary', v_summary,
    'activity', v_activity
  );
end;
$$;

comment on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) is
  'The caller''s own cross-domain financial statement (contributions,
  payments, loans, wallet) for p_group_id — resolved exclusively via
  current_membership_id(), never a client-supplied membership_id/
  user_id/phone. Requires financial_report.self_view. summary.* is
  always the CURRENT position (contribution_charge_component_states/
  loan_statement_schedule_position/member_wallet_balance — the exact
  canonical helpers every other read in this codebase already uses),
  never a synthetic cross-domain net balance. period.opening (position
  immediately before p_from_date) and period.closing (position as of
  p_to_date) are computed via dedicated as-of helper variants that
  share the exact same netting algorithms as the current-state
  helpers, never a duplicated formula — both are null when the
  corresponding bound isn''t supplied. activity is a
  deterministically-ordered union of existing immutable/append-only
  rows only — no new ledger. A payment appears once as the
  cash-receipt event with its allocations nested; only the allocations
  affect any outstanding calculation. 09G-B3-UX-01-FIX-01: each
  CONTRIBUTION_COMPONENT allocation additionally carries period_label/
  component_type (resolved via the same charge_id/charge_component_id
  FKs, null for LOAN_* allocations) so a member can tell which charge
  an allocation settled — presentation enrichment only, no change to
  amounts, ordering, or any outstanding calculation.';

revoke all on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) from public;
revoke execute on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) from anon;
grant execute on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) to authenticated;
