-- Prompt 09G-B3-B: Member Financial Statement Backend Foundation.
--
-- rpc_get_my_member_statement(p_group_id) is a self-owned, group-scoped
-- cross-domain financial READ. It introduces NO new ledger, NO new
-- stored balance, and NO second formula for anything this project
-- already calculates canonically:
--
--   contribution outstanding -> contribution_charge_component_states()
--   loan outstanding         -> loan_statement_schedule_position()
--   wallet balance           -> member_wallet_balance()
--
-- Ownership is resolved exclusively via current_membership_id(p_group_id)
-- (the same B1/B2 self-service primitive rpc_get_my_member_profile
-- already uses) — there is no p_user_id/p_membership_id/p_phone
-- parameter, and no officer-permission fallback: an ADMIN calling this
-- sees only their own statement, exactly like a plain MEMBER would.
--
-- CRITICAL (09G-B3-B §C): a payment and its allocations are never both
-- credited against the same obligation. A payment is the cash-receipt
-- event (informational, shown once with nested allocation detail);
-- only the allocation rows (already netted inside
-- contribution_charge_component_states/loan_statement_schedule_position)
-- affect any outstanding figure. There is no synthetic
-- "total_net_member_balance" anywhere in this response — contribution,
-- loan, and wallet positions are returned as three independent figures,
-- matching rpc_get_financial_position's own established separation.
--
-- 09G-B3-B-FIX-01: period.opening/period.closing. The locked,
-- current-state-only helpers above (contribution_charge_component_states/
-- loan_statement_schedule_position) are NEVER modified — every existing
-- caller (rpc_get_loan_statement, rpc_get_financial_position, etc.)
-- keeps byte-identical behavior. Instead, three NEW, separate,
-- equally-locked-down "_as_of" variant helpers below share the exact
-- same netting algorithm, parameterized by an explicit cutoff date
-- (inclusive: effective_at/effective_date <= p_as_of_date), used ONLY
-- by this statement RPC. summary.* remains the CURRENT position
-- (explicitly current_outstanding/current_balance, via the original
-- unmodified helpers); period.opening (cutoff = p_from_date - 1 day)
-- and period.closing (cutoff = p_to_date) are computed via the new
-- as-of variants whenever p_from_date/p_to_date is supplied.

-- =========================================================================
-- A. Self-service permission (09G-B3-B §E).
--
-- financial_report.self_view mirrors financial_report.view's existing
-- naming (the officer-facing group-wide financial report) with the
-- established "<domain>.self_view" suffix convention
-- (contribution.self_view). One capability for the whole cross-domain
-- statement rather than per-domain self_view codes (loan.self_view,
-- payment.self_view, wallet.self_view) — "View own financial statement"
-- is one coherent feature, not four. Granted to every role exactly
-- like member.view/group.view: every person, regardless of officer
-- role, is also a member with their own finances to see, and (unlike
-- contribution.self_view, used as an OR-fallback alongside officer
-- view) this RPC has no officer-view fallback at all, so every role
-- needs it independently to read their own data.
-- =========================================================================

insert into public.permissions (code, name, description) values
  ('financial_report.self_view', 'View own financial statement', 'View the caller''s own contribution, payment, loan, and wallet activity.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code = 'financial_report.self_view'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'financial_report.self_view'
where r.code in ('CHAIRPERSON', 'SECRETARY', 'TREASURER', 'MEMBER');

-- =========================================================================
-- B. As-of derivation helpers (09G-B3-B-FIX-01).
--
-- Each mirrors its current-state sibling's EXACT netting algorithm,
-- adding only an inclusive effective-date cutoff. The original
-- functions (contribution_charge_component_states/
-- loan_installment_component_states) are never redefined — zero risk
-- to any existing caller. Locked-down internal helpers, same posture
-- as every other primitive in this file: revoked from public/anon/
-- authenticated, callable only via the function-owner's implicit
-- execute right from within another SECURITY DEFINER function.
-- =========================================================================

create or replace function public.contribution_charge_component_states_as_of(
  p_charge_id uuid,
  p_as_of_date date
)
returns table (
  component_id uuid,
  component_type text,
  priority integer,
  outstanding numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with components as (
    select
      c.id,
      c.component_type::text as component_type,
      c.assessed_amount,
      c.created_at,
      c.sequence,
      case c.component_type::text
        when 'BASE' then 1
        when 'PENALTY' then 2
        when 'ADJUSTMENT' then case when c.assessed_amount > 0 then 3 else 99 end
        when 'OPENING_BALANCE' then 4
        else 99
      end as priority
    from public.contribution_charge_components c
    where c.charge_id = p_charge_id
      and c.effective_at <= p_as_of_date
  ),
  positives as (
    select * from components where priority < 99
  ),
  reduction_total as (
    select coalesce(sum(-assessed_amount), 0) as total
    from components
    where priority = 99
  ),
  running as (
    select
      p.*,
      coalesce(
        sum(p.assessed_amount) over (
          order by p.priority, p.sequence, p.created_at
          rows between unbounded preceding and 1 preceding
        ),
        0
      ) as prior_gross
    from positives p
  ),
  allocated_totals as (
    select pa.charge_component_id, sum(pa.amount) as allocated
    from public.payment_allocations pa
    left join public.payments pay on pay.id = pa.payment_id
    left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
    where (
      (pa.wallet_entry_id is not null and we.effective_at <= p_as_of_date)
      or (pay.status = 'POSTED' and pay.effective_at <= p_as_of_date)
    )
    group by pa.charge_component_id
  )
  select
    r.id as component_id,
    r.component_type,
    r.priority,
    greatest(
      0,
      greatest(0, r.assessed_amount - greatest(0, (select total from reduction_total) - r.prior_gross))
        - coalesce(a.allocated, 0)
    ) as outstanding
  from running r
  left join allocated_totals a on a.charge_component_id = r.id
  order by r.priority, r.sequence, r.created_at;
$$;

revoke all on function public.contribution_charge_component_states_as_of(uuid, date) from public, anon, authenticated;

comment on function public.contribution_charge_component_states_as_of(uuid, date) is
  'As-of sibling of contribution_charge_component_states(): identical
  netting algorithm, with components assessed after p_as_of_date
  excluded and allocations counted only if their payment/wallet-entry
  effective_at <= p_as_of_date. The original function is never
  redefined by this — zero behavior change for any existing caller.';

create or replace function public.loan_installment_component_states_as_of(
  p_loan_installment_id uuid,
  p_as_of_date date
)
returns table (
  component_type text,
  priority integer,
  outstanding numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with gross_components as (
    select 'PENALTY'::text as component_type, 0 as priority,
      coalesce((
        select sum(c.penalty_amount) from public.loan_penalty_charges c
        where c.loan_installment_id = p_loan_installment_id
          and c.assessment_date <= p_as_of_date
      ), 0)
      + coalesce((
        select sum(oa.amount) from public.loan_obligation_adjustments oa
        join public.loan_penalty_charges c on c.id = oa.loan_penalty_charge_id
        where c.loan_installment_id = p_loan_installment_id
          and oa.effective_date <= p_as_of_date
      ), 0) as gross
    union all
    select 'INTEREST'::text, 1,
      (case when li.cancelled_at is not null then 0 else li.interest_due end)
      + coalesce((
        select sum(oa.amount) from public.loan_obligation_adjustments oa
        where oa.loan_installment_id = p_loan_installment_id and oa.target_type = 'LOAN_INTEREST'
          and oa.effective_date <= p_as_of_date
      ), 0)
    from public.loan_installments li
    where li.id = p_loan_installment_id
    union all
    select 'PRINCIPAL'::text, 2,
      case when li.cancelled_at is not null then 0 else li.principal_due end
    from public.loan_installments li
    where li.id = p_loan_installment_id
  ),
  allocated_totals as (
    select
      case pa.allocation_target_type
        when 'LOAN_INTEREST' then 'INTEREST'
        when 'LOAN_PENALTY' then 'PENALTY'
        else 'PRINCIPAL'
      end as component_type,
      sum(pa.amount) as allocated
    from public.payment_allocations pa
    left join public.payments pay on pay.id = pa.payment_id
    left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
    where pa.loan_installment_id = p_loan_installment_id
      and (
        (pa.wallet_entry_id is not null and we.effective_at <= p_as_of_date)
        or (pay.status = 'POSTED' and pay.effective_at <= p_as_of_date)
      )
    group by 1
  )
  select
    g.component_type,
    g.priority,
    greatest(0, g.gross - coalesce(a.allocated, 0)) as outstanding
  from gross_components g
  left join allocated_totals a on a.component_type = g.component_type
  order by g.priority;
$$;

revoke all on function public.loan_installment_component_states_as_of(uuid, date) from public, anon, authenticated;

comment on function public.loan_installment_component_states_as_of(uuid, date) is
  'As-of sibling of loan_installment_component_states(): identical
  formula, with penalty assessments/obligation adjustments dated after
  p_as_of_date excluded and allocations counted only if their
  payment/wallet-entry effective_at <= p_as_of_date. The original
  function is never redefined by this.';

-- loan_account_outstanding_as_of — per-loan aggregate, mirroring
-- rpc_get_loan_statement''s own WRITTEN_OFF-is-zero convention: a loan
-- not yet disbursed by p_as_of_date contributes nothing (no receivable
-- existed yet); a loan already written off by p_as_of_date (and not
-- reversed by that same date) contributes zero outstanding too — its
-- write-off is a real, separate activity event, never double-counted
-- as both "written off" and "still outstanding".
create or replace function public.loan_account_outstanding_as_of(
  p_loan_account_id uuid,
  p_as_of_date date
)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_disbursed_at date;
  v_loan_origin text;
  v_written_off boolean;
begin
  select effective_at into v_disbursed_at
  from public.loan_disbursements
  where loan_account_id = p_loan_account_id;

  select loan_origin::text into v_loan_origin
  from public.loan_accounts
  where id = p_loan_account_id;

  -- A MIGRATED loan has no disbursement row by design (section 10,
  -- 20260909090000) — it represents a receivable that already existed
  -- before this system tracked it, present at every as-of date, never
  -- gated on a disbursement that structurally cannot exist for it.
  if v_loan_origin <> 'MIGRATED' and (v_disbursed_at is null or v_disbursed_at > p_as_of_date) then
    return 0;
  end if;

  select exists (
    select 1
    from public.loan_write_off_events wo
    where wo.loan_account_id = p_loan_account_id
      and wo.event_type = 'WRITE_OFF'
      and wo.effective_date <= p_as_of_date
      and not exists (
        select 1 from public.loan_write_off_events r
        where r.reverses_write_off_id = wo.id
          and r.effective_date <= p_as_of_date
      )
  ) into v_written_off;

  if v_written_off then
    return 0;
  end if;

  return coalesce((
    select sum(s.outstanding)
    from public.loan_installments li
    cross join lateral public.loan_installment_component_states_as_of(li.id, p_as_of_date) s
    where li.loan_account_id = p_loan_account_id
      and li.cancelled_at is null
  ), 0);
end;
$$;

revoke all on function public.loan_account_outstanding_as_of(uuid, date) from public, anon, authenticated;

comment on function public.loan_account_outstanding_as_of(uuid, date) is
  'As-of total outstanding for one loan account — 0 if not yet
  disbursed by p_as_of_date (NEW loans only; a MIGRATED loan has no
  disbursement row by design and is never gated on one — it represents
  a receivable that already existed before this system tracked it, so
  it is present at every as-of date, never a fabricated disbursement),
  0 if written off (and not reversed) by p_as_of_date (matching
  rpc_get_loan_statement''s current-state convention), else the sum of
  loan_installment_component_states_as_of across its installments.';

create or replace function public.member_wallet_balance_as_of_membership(
  p_membership_id uuid,
  p_as_of_date date
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    sum(case when entry_type = 'PAYMENT_CREDIT' then amount else -amount end),
    0
  )
  from public.member_wallet_entries
  where membership_id = p_membership_id
    and effective_at <= p_as_of_date;
$$;

revoke all on function public.member_wallet_balance_as_of_membership(uuid, date) from public, anon, authenticated;

comment on function public.member_wallet_balance_as_of_membership(uuid, date) is
  'As-of sibling of member_wallet_balance() for ONE membership (the
  existing member_wallet_balance_as_of() is group-wide, used by
  rpc_get_financial_position — a different aggregation, not reused
  here to avoid conflating the two). Current (p_as_of_date = today or
  later) is always identical to member_wallet_balance().';

-- =========================================================================
-- C. rpc_get_my_member_statement
-- =========================================================================

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

  -- Loan outstanding/penalty: only ACTIVE loans carry a live schedule
  -- position (matching rpc_get_loan_statement's own convention — a
  -- WRITTEN_OFF loan's "outstanding" is reported as 0 there too; its
  -- remaining-recoverable amount is a separate concept, not surfaced
  -- here since officer loan.view governs that detail, not this
  -- member-facing summary). DRAFT/SUBMITTED/APPROVED/REJECTED/
  -- CANCELLED loans were never disbursed and contribute nothing.
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
  --
  -- opening = the position immediately BEFORE p_from_date (cutoff =
  -- p_from_date - 1 day, inclusive of everything up to and including
  -- the day before). closing = the position AS OF the end of p_to_date
  -- (cutoff = p_to_date itself, inclusive). Both use the dedicated
  -- as-of helpers above — never the current-state helpers, never a
  -- hand-rolled duplicate formula. Omitted entirely (null) when the
  -- corresponding bound isn't supplied, rather than fabricating a
  -- zero — "no p_from_date" does not mean "opening is zero", it means
  -- "no opening position was requested".

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
  --
  -- Deterministic ordering tuple (locked contract, matching
  -- rpc_get_loan_statement's own precedent): effective_date ASC, then
  -- a fixed per-(domain,event_type) source_priority ASC, then
  -- created_at ASC, then id ASC as the final tie-breaker. Never
  -- created_at alone, never UUID ordering alone.
  --
  -- CONTRIBUTION: one item per charge component (BASE/PENALTY/
  -- ADJUSTMENT/WAIVER/OPENING_BALANCE) — preserves each component's
  -- own signed meaning, never collapsed into one generic "charge".
  --
  -- PAYMENT: one item per payment (POSTED or REVERSED), with nested
  -- allocation detail explaining how the cash was applied. Only the
  -- allocations (already netted inside the canonical *_component_states
  -- helpers) affect any outstanding figure — the payment item itself
  -- is purely informational, so it can never double-count against the
  -- same obligation its allocations already settled.
  --
  -- LOAN: one item per disbursement, one per write-off/reversal event,
  -- one per loan obligation adjustment (interest/penalty waiver or
  -- correction) — every one of these is already a real, existing,
  -- immutable/append-only row; none is recomputed here.
  --
  -- WALLET: one item per wallet ledger entry (PAYMENT_CREDIT/
  -- ALLOCATION_DEBIT/REVERSAL) — the member's own credit sub-ledger,
  -- shown as its own domain, never silently netted into contribution
  -- or loan outstanding.
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
        'allocations', coalesce((
          select jsonb_agg(jsonb_build_object(
            'amount', pa.amount,
            'target_type', pa.allocation_target_type,
            'charge_id', pa.charge_id,
            'charge_component_id', pa.charge_component_id,
            'loan_account_id', pa.loan_account_id,
            'loan_installment_id', pa.loan_installment_id
          ) order by pa.created_at, pa.id)
          from public.payment_allocations pa
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

    -- Prompt 09G-B3-B-FIX-02: a loan penalty assessment
    -- (loan_penalty_charges) is a real, immutable, effective-dated
    -- accrual event — distinct from any later PAYMENT that may settle
    -- it (see the PAYMENT branch above, whose own
    -- metadata.allocations already shows a LOAN_PENALTY allocation
    -- when/if that happens). Showing the assessment here never
    -- double-counts that later payment: one is an accrual (no cash),
    -- the other is cash — exactly the same distinction already drawn
    -- between a CONTRIBUTION PENALTY component (above) and its own
    -- later payment. assessment_date is the sole effective date used;
    -- penalty_amount is the persisted charge amount, never
    -- recalculated. Both origin='OPENING' (migrated historical
    -- penalty debt) and origin='ASSESSED' (09D penalty engine) rows
    -- are included unfiltered, matching rpc_get_loan_statement's own
    -- unfiltered precedent for this exact source table.
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

    -- Prompt 09G-B3-B-FIX-02: a confirmed restructure
    -- (loan_restructure_events) is a real, immutable, effective-dated
    -- contractual event — it replaces the loan's future schedule only
    -- (no payment_id/cash column on that table; see its own comment
    -- and rpc_restructure_loan) and never itself changes outstanding
    -- principal at the moment it happens. amount is therefore the
    -- true, non-fabricated zero cash movement, not a placeholder —
    -- mirroring the same zero-cash narrative design already proven in
    -- rpc_get_loan_statement's own LOAN_RESTRUCTURED branch. metadata
    -- carries only what the row actually persists (reason, the new
    -- contractual terms) — no old-term scalar is fabricated, since
    -- none is persisted as such (only the full old/new schedule
    -- snapshots, which are audit-only and not surfaced here).
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
  p_to_date) are computed via dedicated as-of helper variants
  (contribution_charge_component_states_as_of/
  loan_account_outstanding_as_of/member_wallet_balance_as_of_membership)
  that share the exact same netting algorithms as the current-state
  helpers, never a duplicated formula — both are null when the
  corresponding bound isn''t supplied. activity is a
  deterministically-ordered union of existing immutable/append-only
  rows only — no new ledger. A payment appears once as the
  cash-receipt event with its allocations nested; only the allocations
  affect any outstanding calculation, so a payment can never
  double-count against the obligation its own allocations already
  settled.';

revoke all on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) from public;
revoke execute on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) from anon;
grant execute on function public.rpc_get_my_member_statement(uuid, date, date, integer, integer) to authenticated;
