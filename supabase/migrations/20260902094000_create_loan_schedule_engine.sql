-- Prompt 09A: Loan Schedule Engine — deterministic, server-side-only
-- schedule generation (section J/L/M/N/O). Split into two layers:
--
--   loan_schedule_compute(...)  — pure, side-effect-free calculation.
--     Returns the schedule as a table without touching any table.
--     Used BOTH for the "Preview Schedule" step (section W step 4,
--     before a loan account even exists) and internally by
--     loan_schedule_generate() below — one formula, never duplicated,
--     and Flutter never reimplements it (section J/AB: Flutter may
--     display a preview but is never authoritative for the
--     calculation itself).
--
--   loan_schedule_generate(loan_account_id) — persists the pure
--     computation's result for an existing loan account, replacing
--     its installments atomically. Internal only; never granted
--     directly, only reachable via the controlled RPCs in
--     20260902095000_create_loan_account_rpcs.sql.
--
-- RATE NORMALIZATION (section M): interest_rate is always interpreted
-- per interest_rate_basis and normalized to an effective MONTHLY rate
-- before any calculation, since repayment frequency is MONTHLY-only
-- in 09A:
--   MONTHLY basis: effective_monthly_rate = interest_rate / 100
--   ANNUAL basis:  effective_monthly_rate = (interest_rate / 100) / 12
-- This is a plain linear (rate ÷ 12) normalization — deliberately NOT
-- a day-count convention (section M explicitly asks 09A to avoid
-- that complexity).
--
-- MONTH-END DATE POLICY (section O): installment i's due date is
-- always computed as `first_repayment_date + (i - 1) months`, anchored
-- to the ORIGINAL first_repayment_date every time — never by adding a
-- month to the PREVIOUS installment's date. Verified directly against
-- PostgreSQL's own date+interval semantics: `date + 'N months'`
-- clips to the last valid day of the target month (e.g.
-- 2026-01-31 + 1 month = 2026-02-28, + 2 months = 2026-03-31, NOT a
-- drifted 2026-03-28) and correctly resolves leap years (2024-01-31 +
-- 1 month = 2024-02-29). Anchoring to the original date on every
-- installment — rather than repeatedly adding one month to the
-- previous result — is exactly what prevents cumulative drift.
--
-- ROUNDING POLICY (section L/N): every money amount is numeric(14,2).
-- FLAT: total interest is computed once and rounded to 2dp, then both
-- principal and (already-rounded) total interest are split into equal
-- per-installment shares via `trunc(total / term, 2)`, with the exact
-- remainder (total - base*term) added to the FINAL installment only —
-- guaranteeing SUM(principal_due) = principal_amount and
-- SUM(interest_due) = calculated total interest exactly, with no lost
-- shillings. REDUCING_BALANCE: principal is split the same way (equal
-- shares + remainder on the final installment, so the closing balance
-- reaches exactly zero); interest for each installment is computed
-- independently as `round(opening_balance * effective_monthly_rate, 2)`
-- on that installment's own opening balance, since each is a genuinely
-- distinct amount rather than a split of one pre-computed total.

create function public.loan_schedule_compute(
  p_principal_amount numeric,
  p_interest_rate numeric,
  p_interest_rate_basis public.loan_interest_rate_basis,
  p_interest_method public.loan_interest_method,
  p_term integer,
  p_first_repayment_date date
)
returns table (
  installment_number integer,
  due_date date,
  principal_due numeric,
  interest_due numeric
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_effective_monthly_rate numeric;
  v_base_principal numeric(14, 2);
  v_remainder_principal numeric(14, 2);
  v_base_interest numeric(14, 2);
  v_remainder_interest numeric(14, 2);
  v_total_interest numeric(14, 2);
  v_opening_balance numeric(14, 2);
  i integer;
begin
  v_effective_monthly_rate := case p_interest_rate_basis
    when 'MONTHLY' then p_interest_rate / 100
    when 'ANNUAL' then (p_interest_rate / 100) / 12
  end;

  v_base_principal := trunc(p_principal_amount / p_term, 2);
  v_remainder_principal := p_principal_amount - (v_base_principal * p_term);

  if p_interest_method = 'FLAT' then
    v_total_interest := round(p_principal_amount * v_effective_monthly_rate * p_term, 2);
    v_base_interest := trunc(v_total_interest / p_term, 2);
    v_remainder_interest := v_total_interest - (v_base_interest * p_term);

    for i in 1..p_term loop
      installment_number := i;
      due_date := p_first_repayment_date + ((i - 1) || ' months')::interval;
      principal_due := v_base_principal + (case when i = p_term then v_remainder_principal else 0 end);
      interest_due := v_base_interest + (case when i = p_term then v_remainder_interest else 0 end);
      return next;
    end loop;

  elsif p_interest_method = 'REDUCING_BALANCE' then
    v_opening_balance := p_principal_amount;

    for i in 1..p_term loop
      installment_number := i;
      due_date := p_first_repayment_date + ((i - 1) || ' months')::interval;
      principal_due := v_base_principal + (case when i = p_term then v_remainder_principal else 0 end);
      interest_due := round(v_opening_balance * v_effective_monthly_rate, 2);
      return next;

      v_opening_balance := v_opening_balance - principal_due;
    end loop;
  else
    raise exception 'Unsupported interest method' using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function public.loan_schedule_compute(
  numeric, numeric, public.loan_interest_rate_basis, public.loan_interest_method, integer, date
) from public, anon, authenticated;

create function public.loan_schedule_generate(
  p_loan_account_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_loan record;
begin
  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.id is null then
    raise exception 'Loan account not found' using errcode = '22023';
  end if;

  -- Atomic replace: a DRAFT's schedule is always fully replaced, never
  -- half-old/half-new (section P). Safe on first generation too, when
  -- no rows exist yet.
  delete from public.loan_installments where loan_account_id = p_loan_account_id;

  insert into public.loan_installments (
    group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
  )
  select
    v_loan.group_id, p_loan_account_id, s.installment_number, s.due_date, s.principal_due, s.interest_due
  from public.loan_schedule_compute(
    v_loan.principal_amount, v_loan.interest_rate, v_loan.interest_rate_basis,
    v_loan.interest_method, v_loan.term, v_loan.first_repayment_date
  ) s;
end;
$$;

revoke all on function public.loan_schedule_generate(uuid) from public, anon, authenticated;
