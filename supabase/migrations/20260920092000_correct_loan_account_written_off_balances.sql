-- Prompt 09G-02: correct rpc_get_loan_account's WRITTEN_OFF balance
-- behavior (09G-01 sections H/L — locked product decision).
--
-- ROOT ISSUE (confirmed during 09G-00/09G-01 discovery): principal_
-- outstanding/interest_outstanding/penalty_outstanding/total_outstanding/
-- next_due_date/overdue_amount are all derived from loan_account_summary,
-- which is itself a pure rollup of loan_installment_component_states —
-- a helper with NO awareness of loan_accounts.status. A write-off never
-- mutates any installment/penalty-charge row (by design — see
-- 20260919090000), so these fields silently kept reporting the exact
-- same numbers as the instant before write-off, forever, never
-- decreasing even as recoveries were posted against the write-off
-- (recovery payment_allocations use LOAN_RECOVERY_* target types with
-- no loan_installment_id, structurally invisible to
-- loan_installment_component_states). Any UI/report reading these
-- fields for a WRITTEN_OFF loan therefore overstated its true
-- remaining exposure by exactly the recovered amount.
--
-- FIX (additive + narrowly-scoped value change, WRITTEN_OFF only):
--   * ACTIVE/CLOSED/DRAFT/SUBMITTED/APPROVED/REJECTED/CANCELLED: zero
--     behavioral change — still loan_account_summary's live figures,
--     byte-for-byte the same query as before.
--   * WRITTEN_OFF: principal_outstanding/interest_outstanding/
--     penalty_outstanding/total_outstanding/overdue_amount become 0,
--     next_due_date becomes null — this loan is no longer an active
--     contractual receivable, so asking "what's currently due" no
--     longer has an ordinary-servicing answer.
--   * NEW flat, additive, nullable fields (null unless the loan has
--     ever been written off): written_off_total,
--     remaining_recoverable_total, remaining_recoverable_principal,
--     remaining_recoverable_interest, remaining_recoverable_penalty —
--     sourced from the same loan_write_off_recovery_state() helper
--     rpc_get_loan_statement uses, so the two RPCs can never disagree.
--
-- No field is renamed, removed, or repurposed to mean something
-- different for any other status. loan_account_summary itself is left
-- completely unmodified (it is also used by rpc_list_loan_accounts,
-- out of scope for this patch).

create or replace function public.rpc_get_loan_account(
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
  v_result jsonb;
  v_installments jsonb;
  v_events jsonb;
  v_disbursement jsonb;
  v_opening_position jsonb;
  v_prepayment_events jsonb;
  v_restructure_events jsonb;
  v_summary record;
  v_status text;
  v_write_off_state jsonb;
  v_principal_outstanding numeric;
  v_interest_outstanding numeric;
  v_penalty_outstanding numeric;
  v_total_outstanding numeric;
  v_next_due_date date;
  v_overdue_amount numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select la.status into v_status
  from public.loan_accounts la
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id,
    'group_id', i.group_id,
    'loan_account_id', i.loan_account_id,
    'installment_number', i.installment_number,
    'due_date', i.due_date,
    'principal_due', i.principal_due,
    'interest_due', i.interest_due,
    'total_due', i.total_due,
    'created_at', i.created_at,
    'cancelled_at', i.cancelled_at,
    'cancellation_reason', i.cancellation_reason,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', coalesce(pc.outstanding, 0),
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', coalesce(ic.outstanding, 0),
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', coalesce(penc.outstanding, 0),
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0),
    'status', (
      case
        when i.cancelled_at is not null then 'CANCELLED'
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) + coalesce(penc.allocated, 0) > 0 then 'PARTIALLY_PAID'
        when i.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end
    )
  ) order by i.installment_number), '[]'::jsonb)
  into v_installments
  from public.loan_installments i
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PRINCIPAL'
  ) pc on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'INTEREST'
  ) ic on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PENALTY'
  ) penc on true
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
  into v_events
  from public.loan_account_events e
  where e.loan_account_id = p_loan_account_id and e.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(pe) order by pe.created_at), '[]'::jsonb)
  into v_prepayment_events
  from public.loan_prepayment_events pe
  where pe.loan_account_id = p_loan_account_id and pe.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(re) order by re.created_at), '[]'::jsonb)
  into v_restructure_events
  from public.loan_restructure_events re
  where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id;

  select jsonb_build_object(
    'id', d.id, 'financial_account_id', d.financial_account_id,
    'financial_account_name', fa.name,
    'amount', d.amount, 'effective_at', d.effective_at,
    'reference', d.reference, 'notes', d.notes, 'created_at', d.created_at
  )
  into v_disbursement
  from public.loan_disbursements d
  join public.financial_accounts fa on fa.id = d.financial_account_id
  where d.loan_account_id = p_loan_account_id and d.group_id = p_group_id;

  select jsonb_build_object(
    'opening_as_of_date', o.opening_as_of_date,
    'original_disbursement_date', o.original_disbursement_date,
    'original_loan_number', o.original_loan_number,
    'original_principal', o.original_principal,
    'opening_principal_outstanding', o.opening_principal_outstanding,
    'opening_principal_arrears', o.opening_principal_arrears,
    'opening_interest_arrears', o.opening_interest_arrears,
    'opening_penalty_arrears', o.opening_penalty_arrears,
    'future_scheduled_principal', o.future_scheduled_principal,
    'future_scheduled_interest', o.future_scheduled_interest,
    'arrears_due_date', o.arrears_due_date,
    'remaining_installment_count', o.remaining_installment_count,
    'next_due_date', o.next_due_date,
    'notes', o.notes,
    'created_at', o.created_at
  )
  into v_opening_position
  from public.loan_opening_positions o
  where o.loan_account_id = p_loan_account_id and o.group_id = p_group_id;

  select * into v_summary from public.loan_account_summary(p_loan_account_id);

  v_write_off_state := public.loan_write_off_recovery_state(p_loan_account_id);

  if v_status = 'WRITTEN_OFF' then
    -- Prompt 09G-02: no longer an active contractual receivable — never
    -- report the frozen pre-write-off/pre-recovery schedule figures as
    -- "current outstanding". See loan_write_off_recovery_state /
    -- rpc_get_loan_statement for the correct recovery-aware figures.
    v_principal_outstanding := 0;
    v_interest_outstanding := 0;
    v_penalty_outstanding := 0;
    v_total_outstanding := 0;
    v_next_due_date := null;
    v_overdue_amount := 0;
  else
    v_principal_outstanding := v_summary.principal_outstanding;
    v_interest_outstanding := v_summary.interest_outstanding;
    v_penalty_outstanding := v_summary.penalty_outstanding;
    v_total_outstanding := v_summary.total_outstanding;
    v_next_due_date := v_summary.next_due_date;
    v_overdue_amount := v_summary.overdue_amount;
  end if;

  select jsonb_build_object(
    'id', la.id, 'group_id', la.group_id, 'membership_id', la.membership_id,
    'borrower_display_name', gm.display_name, 'borrower_member_number', gm.member_number,
    'loan_product_id', la.loan_product_id, 'loan_product_name', lp.name, 'loan_product_code', lp.code,
    'loan_number', la.loan_number,
    'loan_origin', la.loan_origin,
    'principal_amount', la.principal_amount, 'interest_rate', la.interest_rate,
    'interest_rate_basis', la.interest_rate_basis, 'interest_method', la.interest_method,
    'term', la.term, 'term_unit', la.term_unit, 'repayment_frequency', la.repayment_frequency,
    'application_date', la.application_date,
    'proposed_disbursement_date', la.proposed_disbursement_date,
    'first_repayment_date', la.first_repayment_date,
    'status', la.status,
    'penalty_enabled', la.penalty_enabled, 'penalty_type', la.penalty_type,
    'penalty_frequency', la.penalty_frequency, 'penalty_grace_days', la.penalty_grace_days,
    'penalty_fixed_amount', la.penalty_fixed_amount, 'penalty_rate', la.penalty_rate,
    'penalty_basis', la.penalty_basis,
    'created_at', la.created_at, 'updated_at', la.updated_at,
    'installments', v_installments,
    'events', v_events,
    'prepayment_events', v_prepayment_events,
    'restructure_events', v_restructure_events,
    'disbursement', v_disbursement,
    'opening_position', v_opening_position,
    'principal_repaid', v_summary.principal_repaid,
    'principal_outstanding', v_principal_outstanding,
    'interest_recognized', v_summary.interest_recognized,
    'interest_outstanding', v_interest_outstanding,
    'penalty_paid', v_summary.penalty_paid,
    'penalty_outstanding', v_penalty_outstanding,
    'total_outstanding', v_total_outstanding,
    'next_due_date', v_next_due_date,
    'overdue_amount', v_overdue_amount,
    'written_off_total', v_write_off_state->'amount_written_off',
    'remaining_recoverable_total', v_write_off_state->'remaining_recoverable',
    'remaining_recoverable_principal', v_write_off_state->'remaining_recoverable_principal',
    'remaining_recoverable_interest', v_write_off_state->'remaining_recoverable_interest',
    'remaining_recoverable_penalty', v_write_off_state->'remaining_recoverable_penalty'
  )
  into v_result
  from public.loan_accounts la
  join public.group_memberships gm on gm.id = la.membership_id
  join public.loan_products lp on lp.id = la.loan_product_id
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  if v_result is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$$;

revoke all on function public.rpc_get_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_account(uuid, uuid) from anon;

comment on function public.rpc_get_loan_account(uuid, uuid) is
  'Prompt 09A-09G: full loan detail read model. Prompt 09G-02: for a
  WRITTEN_OFF loan, principal_outstanding/interest_outstanding/
  penalty_outstanding/total_outstanding/overdue_amount are 0 and
  next_due_date is null — never the frozen pre-write-off schedule
  figures. written_off_total/remaining_recoverable_* are additive,
  null unless the loan has ever been written off, sourced from
  loan_write_off_recovery_state() (the same helper
  rpc_get_loan_statement uses). Every other status is byte-for-byte
  unchanged from the pre-09G-02 behavior.';
