-- Prompt 09G-02: rpc_get_loan_statement — the single authoritative
-- chronological per-loan statement (09G-01 sections B-K). Composes
-- EXISTING immutable event/accounting sources; introduces no new
-- ledger/event table and no new mutation mechanism.
--
-- Source priority table (locked — documented here so a future event
-- source addition can never silently reorder existing history; see
-- 09G-01 section D):
--   0 = loan_account_events   (lifecycle transitions + early settlement;
--       EXCLUDES event types that have their own richer dedicated
--       source below, to avoid double-listing the same economic event:
--       PRINCIPAL_PREPAID, RESTRUCTURED, WRITTEN_OFF, WRITE_OFF_REVERSED,
--       RECOVERY_RECORDED, RECOVERY_REVERSED)
--   1 = payments               (one row per payment; allocations are
--       aggregated as component breakdown, never separate rows)
--   2 = loan_penalty_charges   (penalty assessment)
--   3 = loan_obligation_adjustments (waiver/correction/reversal)
--   4 = loan_prepayment_events
--   5 = loan_restructure_events
--   6 = loan_write_off_events  (both WRITE_OFF and REVERSAL rows)
--   7 = loan_recovery_events
--
-- Ordering: primary key is business effective_at date; ties broken by
-- source_priority, then entry_no where the source table has one
-- (adjustments/write-off/recovery — globally monotonic), then
-- created_at, then row id as a final deterministic (not necessarily
-- causal) tie-break. Never ORDER BY created_at alone — see 09G-01
-- section D for the exact same-transaction-collision rationale already
-- proven in 09F-B.

create or replace function public.rpc_get_loan_statement(
  p_group_id uuid,
  p_loan_account_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_header jsonb;
  v_status text;
  v_current_state jsonb;
  v_position record;
  v_write_off_state jsonb;
  v_timeline jsonb;
  v_schedule_current jsonb;
  v_schedule_history jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'loan_account_id', la.id,
    'loan_number', la.loan_number,
    'loan_product_id', la.loan_product_id,
    'loan_product_name', lp.name,
    'membership_id', la.membership_id,
    'borrower_display_name', gm.display_name,
    'borrower_member_number', gm.member_number,
    'loan_origin', la.loan_origin,
    'principal_amount', la.principal_amount,
    'interest_rate', la.interest_rate,
    'interest_rate_basis', la.interest_rate_basis,
    'interest_method', la.interest_method,
    'term', la.term,
    'term_unit', la.term_unit,
    'first_repayment_date', la.first_repayment_date,
    'application_date', la.application_date,
    'status', la.status
  ), la.status
  into v_header, v_status
  from public.loan_accounts la
  join public.group_memberships gm on gm.id = la.membership_id
  join public.loan_products lp on lp.id = la.loan_product_id
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  if v_header is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  -- current_state -------------------------------------------------------

  v_write_off_state := public.loan_write_off_recovery_state(p_loan_account_id);

  if v_status = 'WRITTEN_OFF' then
    v_current_state := jsonb_build_object(
      'status', v_status,
      'principal_outstanding', 0,
      'earned_interest_outstanding', 0,
      'penalty_outstanding', 0,
      'total_outstanding', 0,
      'scheduled_unearned_interest', 0,
      'overdue_principal', 0,
      'overdue_interest', 0,
      'overdue_penalty', 0,
      'total_overdue', 0,
      'write_off', v_write_off_state
    );
  else
    select * into v_position
    from public.loan_statement_schedule_position(p_loan_account_id, current_date);

    v_current_state := jsonb_build_object(
      'status', v_status,
      'principal_outstanding', v_position.principal_outstanding,
      'earned_interest_outstanding', v_position.earned_interest_outstanding,
      'penalty_outstanding', v_position.penalty_outstanding,
      'total_outstanding', v_position.total_outstanding,
      'scheduled_unearned_interest', v_position.scheduled_unearned_interest,
      'overdue_principal', v_position.overdue_principal,
      'overdue_interest', v_position.overdue_interest,
      'overdue_penalty', v_position.overdue_penalty,
      'total_overdue', v_position.total_overdue,
      'write_off', v_write_off_state
    );
  end if;

  -- timeline --------------------------------------------------------------

  with events as (
    -- priority 0: loan lifecycle events (excluding types with their own
    -- richer dedicated source below)
    select
      '0:' || e.id::text as event_id,
      case e.event_type::text
        when 'CREATED' then 'LOAN_CREATED'
        when 'SUBMITTED' then 'LOAN_SUBMITTED'
        when 'APPROVED' then 'LOAN_APPROVED'
        when 'REJECTED' then 'LOAN_REJECTED'
        when 'CANCELLED' then 'LOAN_CANCELLED'
        when 'DISBURSED' then 'LOAN_DISBURSED'
        when 'CLOSED' then 'LOAN_CLOSED'
        when 'REOPENED' then 'LOAN_REOPENED'
        when 'MIGRATED' then 'LOAN_MIGRATED'
        when 'EARLY_SETTLED' then 'EARLY_SETTLEMENT'
        else e.event_type::text
      end as event_type,
      null::text as event_subtype,
      e.created_at::date as effective_at,
      e.created_at as created_at,
      0 as source_priority,
      null::bigint as local_seq,
      e.id as row_id,
      case e.event_type::text
        when 'CREATED' then 'LOAN_CREATED'
        when 'SUBMITTED' then 'LOAN_SUBMITTED'
        when 'APPROVED' then 'LOAN_APPROVED'
        when 'REJECTED' then 'LOAN_REJECTED'
        when 'CANCELLED' then 'LOAN_CANCELLED'
        when 'DISBURSED' then 'LOAN_DISBURSED'
        when 'CLOSED' then 'LOAN_CLOSED'
        when 'REOPENED' then 'LOAN_REOPENED'
        when 'MIGRATED' then 'LOAN_MIGRATED'
        when 'EARLY_SETTLED' then 'EARLY_SETTLEMENT'
        else e.event_type::text
      end as title_code,
      e.created_by as actor_user_id,
      false as is_reversed,
      null::text as reversed_by_event_id,
      null::numeric as amount,
      null::jsonb as components,
      jsonb_build_object() as "references",
      jsonb_build_object('reason', e.reason, 'from_status', e.from_status, 'to_status', e.to_status) as metadata
    from public.loan_account_events e
    where e.loan_account_id = p_loan_account_id and e.group_id = p_group_id
      and e.event_type::text not in (
        'PRINCIPAL_PREPAID', 'RESTRUCTURED', 'WRITTEN_OFF', 'WRITE_OFF_REVERSED',
        'RECOVERY_RECORDED', 'RECOVERY_REVERSED'
      )

    union all

    -- priority 1: payments (one row per payment; components aggregated,
    -- scoped strictly to THIS loan's own allocations so a payment that
    -- also touches another loan/contribution never leaks foreign amounts
    -- into this loan's statement)
    select
      '1:' || p.id::text,
      'PAYMENT_POSTED',
      case
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type = 'LOAN_PRINCIPAL_PREPAYMENT'
        ) then 'PRINCIPAL_PREPAYMENT'
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in (
              'LOAN_RECOVERY_PRINCIPAL', 'LOAN_RECOVERY_INTEREST', 'LOAN_RECOVERY_PENALTY'
            )
        ) then 'LOAN_RECOVERY'
        else 'ORDINARY_REPAYMENT'
      end,
      p.effective_at,
      p.created_at,
      1,
      null::bigint,
      p.id,
      case
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type = 'LOAN_PRINCIPAL_PREPAYMENT'
        ) then 'PRINCIPAL_PREPAYMENT'
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in (
              'LOAN_RECOVERY_PRINCIPAL', 'LOAN_RECOVERY_INTEREST', 'LOAN_RECOVERY_PENALTY'
            )
        ) then 'LOAN_RECOVERY'
        else 'ORDINARY_REPAYMENT'
      end,
      p.created_by,
      (p.status = 'REVERSED'),
      null::text,
      coalesce((
        select sum(pa2.amount) from public.payment_allocations pa2
        where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
      ), 0),
      jsonb_build_object(
        'principal', coalesce((
          select sum(pa2.amount) from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT', 'LOAN_RECOVERY_PRINCIPAL')
        ), 0),
        'interest', coalesce((
          select sum(pa2.amount) from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in ('LOAN_INTEREST', 'LOAN_RECOVERY_INTEREST')
        ), 0),
        'penalty', coalesce((
          select sum(pa2.amount) from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in ('LOAN_PENALTY', 'LOAN_RECOVERY_PENALTY')
        ), 0)
      ),
      jsonb_build_object('payment_id', p.id, 'receipt_number', p.receipt_number),
      jsonb_build_object(
        'payment_method', p.payment_method,
        'financial_account_id', p.financial_account_id,
        'payment_amount', p.amount,
        'reversed_at', p.reversed_at,
        'reversed_by', p.reversed_by,
        'reversal_reason', p.reversal_reason
      )
    from public.payments p
    where p.group_id = p_group_id
      and exists (
        select 1 from public.payment_allocations pa
        where pa.payment_id = p.id and pa.loan_account_id = p_loan_account_id
      )

    union all

    -- priority 2: penalty assessments
    select
      '2:' || c.id::text,
      'PENALTY_ASSESSED',
      c.origin::text,
      c.assessment_date,
      c.created_at,
      2,
      null::bigint,
      c.id,
      'PENALTY_ASSESSED',
      c.created_by,
      false,
      null::text,
      c.penalty_amount,
      jsonb_build_object('principal', 0, 'interest', 0, 'penalty', c.penalty_amount),
      jsonb_build_object(
        'penalty_charge_id', c.id, 'installment_id', c.loan_installment_id
      ),
      jsonb_build_object('sequence_number', c.sequence_number, 'origin', c.origin)
    from public.loan_penalty_charges c
    where c.loan_account_id = p_loan_account_id and c.group_id = p_group_id

    union all

    -- priority 3: obligation adjustments (waiver/correction/reversal)
    select
      '3:' || oa.id::text,
      case oa.adjustment_type
        when 'WAIVER' then 'OBLIGATION_WAIVER'
        when 'CORRECTION_INCREASE' then 'OBLIGATION_CORRECTION_INCREASE'
        when 'CORRECTION_DECREASE' then 'OBLIGATION_CORRECTION_DECREASE'
        when 'REVERSAL' then 'OBLIGATION_ADJUSTMENT_REVERSED'
        else oa.adjustment_type
      end,
      oa.target_type,
      oa.effective_date,
      oa.created_at,
      3,
      oa.entry_no,
      oa.id,
      case oa.adjustment_type
        when 'WAIVER' then 'OBLIGATION_WAIVER'
        when 'CORRECTION_INCREASE' then 'OBLIGATION_CORRECTION_INCREASE'
        when 'CORRECTION_DECREASE' then 'OBLIGATION_CORRECTION_DECREASE'
        when 'REVERSAL' then 'OBLIGATION_ADJUSTMENT_REVERSED'
        else oa.adjustment_type
      end,
      oa.created_by,
      case
        when oa.adjustment_type = 'REVERSAL' then false
        else exists (
          select 1 from public.loan_obligation_adjustments r
          where r.reverses_adjustment_id = oa.id
        )
      end,
      (
        select '3:' || r.id::text from public.loan_obligation_adjustments r
        where r.reverses_adjustment_id = oa.id
      ),
      oa.amount,
      jsonb_build_object(
        'principal', 0,
        'interest', case when oa.target_type = 'LOAN_INTEREST' then oa.amount else 0 end,
        'penalty', case when oa.target_type = 'LOAN_PENALTY' then oa.amount else 0 end
      ),
      jsonb_build_object(
        'adjustment_id', oa.id,
        'installment_id', oa.loan_installment_id,
        'penalty_charge_id', oa.loan_penalty_charge_id,
        'reverses_adjustment_id', oa.reverses_adjustment_id
      ),
      jsonb_build_object('reason_code', oa.reason_code, 'note', oa.note)
    from public.loan_obligation_adjustments oa
    where oa.loan_account_id = p_loan_account_id and oa.group_id = p_group_id

    union all

    -- priority 4: principal prepayment
    select
      '4:' || pe.id::text,
      'PRINCIPAL_PREPAYMENT',
      pe.treatment::text,
      pe.effective_date,
      pe.created_at,
      4,
      null::bigint,
      pe.id,
      'PRINCIPAL_PREPAYMENT',
      pe.created_by,
      false,
      null::text,
      pe.amount,
      jsonb_build_object('principal', pe.amount, 'interest', 0, 'penalty', 0),
      jsonb_build_object('prepayment_event_id', pe.id, 'payment_id', pe.payment_id),
      jsonb_build_object('treatment', pe.treatment)
    from public.loan_prepayment_events pe
    where pe.loan_account_id = p_loan_account_id and pe.group_id = p_group_id

    union all

    -- priority 5: restructure
    select
      '5:' || re.id::text,
      'LOAN_RESTRUCTURED',
      null::text,
      re.effective_date,
      re.created_at,
      5,
      null::bigint,
      re.id,
      'LOAN_RESTRUCTURED',
      re.created_by,
      false,
      null::text,
      null::numeric,
      null::jsonb,
      jsonb_build_object('restructure_event_id', re.id),
      jsonb_build_object(
        'reason', re.reason,
        'new_interest_rate', re.new_interest_rate,
        'new_term', re.new_term,
        'new_first_installment_date', re.new_first_installment_date
      )
    from public.loan_restructure_events re
    where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id

    union all

    -- priority 6: write-off (both WRITE_OFF and REVERSAL rows)
    select
      '6:' || w.id::text,
      case w.event_type when 'WRITE_OFF' then 'WRITE_OFF' else 'WRITE_OFF_REVERSED' end,
      null::text,
      w.effective_date,
      w.created_at,
      6,
      w.entry_no,
      w.id,
      case w.event_type when 'WRITE_OFF' then 'WRITE_OFF' else 'WRITE_OFF_REVERSED' end,
      w.created_by,
      case
        when w.event_type = 'WRITE_OFF' then exists (
          select 1 from public.loan_write_off_events r where r.reverses_write_off_id = w.id
        )
        else false
      end,
      (
        select '6:' || r.id::text from public.loan_write_off_events r
        where r.reverses_write_off_id = w.id
      ),
      w.principal_amount + w.interest_amount + w.penalty_amount,
      jsonb_build_object('principal', w.principal_amount, 'interest', w.interest_amount, 'penalty', w.penalty_amount),
      jsonb_build_object('write_off_event_id', w.id, 'reverses_write_off_id', w.reverses_write_off_id),
      jsonb_build_object('reason_code', w.reason_code, 'note', w.note)
    from public.loan_write_off_events w
    where w.loan_account_id = p_loan_account_id and w.group_id = p_group_id

    union all

    -- priority 7: recovery
    select
      '7:' || re.id::text,
      'RECOVERY_POSTED',
      null::text,
      p.effective_at,
      re.created_at,
      7,
      re.entry_no,
      re.id,
      'RECOVERY_POSTED',
      re.created_by,
      (p.status = 'REVERSED'),
      null::text,
      re.principal_recovered + re.interest_recovered + re.penalty_recovered,
      jsonb_build_object('principal', re.principal_recovered, 'interest', re.interest_recovered, 'penalty', re.penalty_recovered),
      jsonb_build_object(
        'recovery_event_id', re.id, 'write_off_event_id', re.write_off_event_id,
        'payment_id', re.payment_id, 'receipt_number', p.receipt_number
      ),
      jsonb_build_object('reversed_at', p.reversed_at, 'reversed_by', p.reversed_by, 'reversal_reason', p.reversal_reason)
    from public.loan_recovery_events re
    join public.payments p on p.id = re.payment_id
    where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'event_id', event_id,
      'event_type', event_type,
      'event_subtype', event_subtype,
      'effective_at', effective_at,
      'created_at', created_at,
      'sequence_key', source_priority::text || ':' || coalesce(local_seq::text, '') || ':' || row_id::text,
      'title_code', title_code,
      'actor_user_id', actor_user_id,
      'is_reversed', is_reversed,
      'reversed_by_event_id', reversed_by_event_id,
      'amount', amount,
      'components', components,
      'references', "references",
      'metadata', metadata
    )
    order by effective_at, source_priority, local_seq nulls last, created_at, row_id
  ), '[]'::jsonb)
  into v_timeline
  from events;

  -- schedule ----------------------------------------------------------

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', li.id,
    'installment_number', li.installment_number,
    'due_date', li.due_date,
    'principal_due', li.principal_due,
    'interest_due', li.interest_due,
    'total_due', li.total_due,
    'principal_outstanding', pc.outstanding,
    'interest_outstanding', ic.outstanding,
    'penalty_outstanding', penc.outstanding
  ) order by li.installment_number), '[]'::jsonb)
  into v_schedule_current
  from public.loan_installments li
  cross join lateral (
    select outstanding from public.loan_installment_component_states(li.id) where component_type = 'PRINCIPAL'
  ) pc
  cross join lateral (
    select outstanding from public.loan_installment_component_states(li.id) where component_type = 'INTEREST'
  ) ic
  cross join lateral (
    select outstanding from public.loan_installment_component_states(li.id) where component_type = 'PENALTY'
  ) penc
  where li.loan_account_id = p_loan_account_id and li.group_id = p_group_id
    and li.cancelled_at is null;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', li.id,
    'installment_number', li.installment_number,
    'due_date', li.due_date,
    'principal_due', li.principal_due,
    'interest_due', li.interest_due,
    'cancelled_at', li.cancelled_at,
    'cancellation_reason', li.cancellation_reason,
    'cancelled_by_payment_id', li.cancelled_by_payment_id,
    'created_by_payment_id', li.created_by_payment_id
  ) order by li.installment_number, li.cancelled_at), '[]'::jsonb)
  into v_schedule_history
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.group_id = p_group_id
    and li.cancelled_at is not null;

  return jsonb_build_object(
    'header', v_header,
    'current_state', v_current_state,
    'timeline', v_timeline,
    'schedule', jsonb_build_object('current', v_schedule_current, 'history', v_schedule_history)
  );
end;
$$;

revoke all on function public.rpc_get_loan_statement(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_statement(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_statement(uuid, uuid) from anon;

comment on function public.rpc_get_loan_statement(uuid, uuid) is
  'Prompt 09G-02: the single authoritative chronological per-loan
  statement. Read-only (STABLE) — composes existing immutable event/
  accounting sources, never mutates any row. Gated on loan.view (no new
  permission). timeline is deterministically ordered by business
  effective_at, then a fixed source_priority, then entry_no where
  available, then created_at, then row id — never by created_at alone.
  Future/scheduled installments are never listed as timeline events
  (see schedule.current/history instead).';
