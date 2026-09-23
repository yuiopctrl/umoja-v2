-- Prompt 09G-02: Loan Statement & Write-Off-Aware Balance
-- Reconciliation — internal read-model helpers.
--
-- Two locked-down internal helpers, each composing the EXISTING
-- authoritative primitive (loan_installment_component_states /
-- loan_recovery_remaining_balance) rather than reimplementing any
-- payment/adjustment arithmetic — matching the exact precedent already
-- set by loan_write_off_compute_amounts/loan_prepayment_eligibility/
-- loan_compute_early_settlement_plan (each is its own due-date-scoped
-- rollup of the same shared low-level helper).

-- ---------------------------------------------------------------------
-- loan_statement_schedule_position — the "current contractual
-- schedule" figures for a loan that is NOT written off (09G-01 section
-- A/C). Deliberately distinct from loan_account_summary: this splits
-- interest into earned (due_date <= p_effective_date) vs
-- scheduled-unearned, and additionally splits "overdue" (due_date <
-- p_effective_date, matching the existing installment-status-label
-- convention in rpc_get_loan_account) by component — neither of which
-- loan_account_summary provides. Principal and penalty are never
-- due-date-gated (all due dates included), matching the existing
-- early-settlement/prepayment/write-off precedent exactly.
-- ---------------------------------------------------------------------

create or replace function public.loan_statement_schedule_position(
  p_loan_account_id uuid,
  p_effective_date date
)
returns table (
  principal_outstanding numeric,
  earned_interest_outstanding numeric,
  penalty_outstanding numeric,
  total_outstanding numeric,
  scheduled_unearned_interest numeric,
  overdue_principal numeric,
  overdue_interest numeric,
  overdue_penalty numeric,
  total_overdue numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PRINCIPAL'), 0),
    coalesce(sum(s.outstanding) filter (
      where s.component_type = 'INTEREST' and li.due_date <= p_effective_date
    ), 0),
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PENALTY'), 0),
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PRINCIPAL'), 0)
      + coalesce(sum(s.outstanding) filter (
          where s.component_type = 'INTEREST' and li.due_date <= p_effective_date
        ), 0)
      + coalesce(sum(s.outstanding) filter (where s.component_type = 'PENALTY'), 0),
    coalesce(sum(s.outstanding) filter (
      where s.component_type = 'INTEREST' and li.due_date > p_effective_date
    ), 0),
    coalesce(sum(s.outstanding) filter (
      where s.component_type = 'PRINCIPAL' and li.due_date < p_effective_date
    ), 0),
    coalesce(sum(s.outstanding) filter (
      where s.component_type = 'INTEREST' and li.due_date < p_effective_date
    ), 0),
    coalesce(sum(s.outstanding) filter (
      where s.component_type = 'PENALTY' and li.due_date < p_effective_date
    ), 0),
    coalesce(sum(s.outstanding) filter (where li.due_date < p_effective_date), 0)
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id
    and li.cancelled_at is null;
$$;

revoke all on function public.loan_statement_schedule_position(uuid, date) from public, anon, authenticated;

comment on function public.loan_statement_schedule_position(uuid, date) is
  'Locked-down internal helper (Prompt 09G-02). The "current
  contractual schedule position" for a loan that is currently an
  active receivable (never called for a WRITTEN_OFF loan — that state
  is represented separately by loan_write_off_recovery_state, never by
  this helper). total_outstanding = principal + earned interest +
  penalty (future/unearned interest is never included). overdue_* uses
  due_date < p_effective_date, matching the existing OVERDUE
  installment-status-label convention.';

-- ---------------------------------------------------------------------
-- loan_write_off_recovery_state — the full write-off/recovery current
-- state for a loan, or NULL if the loan has never had a write-off
-- event at all. Reused by both rpc_get_loan_statement (nested under
-- current_state.write_off) and the WRITTEN_OFF correction to
-- rpc_get_loan_account, so the two can never disagree — mirrors the
-- exact "one shared helper, two callers" precedent already set by
-- loan_account_summary (shared by rpc_get_loan_account and
-- rpc_list_loan_accounts).
--
-- is_active = true iff the most recent WRITE_OFF event for this loan
-- has not itself been reversed (i.e. loan_accounts.status is currently
-- WRITTEN_OFF because of it). Once reversed, this helper still returns
-- the historical write-off's frozen amounts with is_active=false —
-- write-off history is never hidden merely because it was later
-- reversed (09G-01 locked decision).
-- ---------------------------------------------------------------------

create or replace function public.loan_write_off_recovery_state(p_loan_account_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_write_off record;
  v_remaining record;
  v_recovered record;
begin
  select *
  into v_write_off
  from public.loan_write_off_events
  where loan_account_id = p_loan_account_id and event_type = 'WRITE_OFF'
  order by entry_no desc
  limit 1;

  if v_write_off.id is null then
    return null;
  end if;

  select * into v_remaining
  from public.loan_recovery_remaining_balance(v_write_off.id);

  select
    coalesce(sum(re.principal_recovered), 0) as principal,
    coalesce(sum(re.interest_recovered), 0) as interest,
    coalesce(sum(re.penalty_recovered), 0) as penalty
  into v_recovered
  from public.loan_recovery_events re
  join public.payments p on p.id = re.payment_id
  where re.write_off_event_id = v_write_off.id and p.status = 'POSTED';

  return jsonb_build_object(
    'is_active', not exists (
      select 1 from public.loan_write_off_events r
      where r.reverses_write_off_id = v_write_off.id
    ),
    'write_off_event_id', v_write_off.id,
    'effective_date', v_write_off.effective_date,
    'reason_code', v_write_off.reason_code,
    'note', v_write_off.note,
    'principal_written_off', v_write_off.principal_amount,
    'interest_written_off', v_write_off.interest_amount,
    'penalty_written_off', v_write_off.penalty_amount,
    'amount_written_off',
      v_write_off.principal_amount + v_write_off.interest_amount + v_write_off.penalty_amount,
    'recovered_principal', v_recovered.principal,
    'recovered_interest', v_recovered.interest,
    'recovered_penalty', v_recovered.penalty,
    'total_recovered', v_recovered.principal + v_recovered.interest + v_recovered.penalty,
    'remaining_recoverable_principal', v_remaining.principal_remaining,
    'remaining_recoverable_interest', v_remaining.interest_remaining,
    'remaining_recoverable_penalty', v_remaining.penalty_remaining,
    'remaining_recoverable',
      v_remaining.principal_remaining + v_remaining.interest_remaining + v_remaining.penalty_remaining
  );
end;
$$;

revoke all on function public.loan_write_off_recovery_state(uuid) from public, anon, authenticated;

comment on function public.loan_write_off_recovery_state(uuid) is
  'Locked-down internal helper (Prompt 09G-02). NULL iff the loan has
  never had a write-off event. Otherwise the most recent write-off''s
  frozen amounts, live recovered totals (non-reversed POSTED payments
  only, via loan_recovery_remaining_balance), and remaining recoverable
  balance — the single source of truth reused by rpc_get_loan_statement
  and the WRITTEN_OFF correction in rpc_get_loan_account, so the two
  RPCs can never disagree.';
