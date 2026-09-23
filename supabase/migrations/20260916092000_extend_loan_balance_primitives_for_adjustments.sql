-- Prompt 09F-A section 8: extend the two shared authoritative balance
-- primitives to net loan_obligation_adjustments into effective
-- outstanding. This is the single, central hook — every caller
-- (payment allocation, prepayment/restructure eligibility, early
-- settlement quoting, closure) already goes through one of these two
-- functions (see the 09F-A audit report section 5/17), so no other RPC
-- needs to change to become adjustment-aware.
--
-- Gross historical values (loan_penalty_charges.penalty_amount,
-- loan_installments.interest_due) are never rewritten — "gross" below
-- stays exactly what it always was; only "outstanding" nets in the
-- signed adjustment effect, matching the locked formula (section 8):
--   effective outstanding = gross + net adjustment - allocated
-- floored at 0 (defensive; posting-time validation already guarantees
-- this never actually goes negative — section 8/10 "never allow
-- effective outstanding below zero").
--
-- Same return shape as before (a plain create-or-replace suffices, no
-- drop needed) — every existing caller keeps working unmodified.

create or replace function public.loan_penalty_charge_states(p_loan_installment_id uuid)
returns table (
  charge_id uuid,
  assessment_date date,
  sequence_number integer,
  gross numeric,
  allocated numeric,
  outstanding numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id as charge_id,
    c.assessment_date,
    c.sequence_number,
    c.penalty_amount as gross,
    coalesce(a.allocated, 0) as allocated,
    greatest(0, c.penalty_amount + coalesce(adj.net_adjustment, 0) - coalesce(a.allocated, 0)) as outstanding
  from public.loan_penalty_charges c
  left join (
    select pa.loan_penalty_charge_id, sum(pa.amount) as allocated
    from public.payment_allocations pa
    left join public.payments p on p.id = pa.payment_id
    where pa.loan_penalty_charge_id is not null
      and (pa.wallet_entry_id is not null or p.status = 'POSTED')
    group by pa.loan_penalty_charge_id
  ) a on a.loan_penalty_charge_id = c.id
  left join (
    select oa.loan_penalty_charge_id, sum(oa.amount) as net_adjustment
    from public.loan_obligation_adjustments oa
    where oa.loan_penalty_charge_id is not null
    group by oa.loan_penalty_charge_id
  ) adj on adj.loan_penalty_charge_id = c.id
  where c.loan_installment_id = p_loan_installment_id
  order by c.assessment_date asc, c.sequence_number asc;
$$;

revoke all on function public.loan_penalty_charge_states(uuid) from public, anon, authenticated;

comment on function public.loan_penalty_charge_states(uuid) is
  'Locked-down internal helper. Every outstanding penalty charge for one
  installment, oldest assessment_date/sequence first. Prompt 09F-A:
  outstanding now nets in loan_obligation_adjustments (WAIVER/
  CORRECTION_DECREASE/CORRECTION_INCREASE/REVERSAL) for this exact
  charge — gross (penalty_amount) is never rewritten.';

create or replace function public.loan_installment_component_states(p_loan_installment_id uuid)
returns table (
  component_type text,
  priority integer,
  gross numeric,
  allocated numeric,
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
      ), 0)
      + coalesce((
        select sum(oa.amount) from public.loan_obligation_adjustments oa
        join public.loan_penalty_charges c on c.id = oa.loan_penalty_charge_id
        where c.loan_installment_id = p_loan_installment_id
      ), 0) as gross
    union all
    select 'INTEREST'::text, 1,
      (case when li.cancelled_at is not null then 0 else li.interest_due end)
      + coalesce((
        select sum(oa.amount) from public.loan_obligation_adjustments oa
        where oa.loan_installment_id = p_loan_installment_id and oa.target_type = 'LOAN_INTEREST'
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
    left join public.payments p on p.id = pa.payment_id
    where pa.loan_installment_id = p_loan_installment_id
      and (pa.wallet_entry_id is not null or p.status = 'POSTED')
    group by 1
  )
  select
    g.component_type,
    g.priority,
    g.gross,
    coalesce(a.allocated, 0) as allocated,
    greatest(0, g.gross - coalesce(a.allocated, 0)) as outstanding
  from gross_components g
  left join allocated_totals a on a.component_type = g.component_type
  order by g.priority;
$$;

revoke all on function public.loan_installment_component_states(uuid) from public, anon, authenticated;

comment on function public.loan_installment_component_states(uuid) is
  'Locked-down internal helper. For one loan installment: PENALTY
  (aggregate), INTEREST, PRINCIPAL (priority order). Prompt 09F-A: PENALTY
  gross now includes the net of every loan_obligation_adjustments row
  anchored to one of this installment''s penalty charges; INTEREST gross
  now includes the net of every LOAN_INTEREST adjustment anchored
  directly to this installment. PRINCIPAL is never adjustable (09F-A
  scope) and is untouched. A CANCELLED installment still contributes
  zero INTEREST/PRINCIPAL gross exactly as before 09F-A; RPC-level
  validation (never this function) is what keeps an adjustment from ever
  landing on an already-cancelled installment in the first place.';

-- ---------------------------------------------------------------------
-- loan_obligation_adjustment_target_state — shared internal resolver
-- used by every waiver/correction/reversal RPC (section 15 — "use
-- internal helper(s) where that reduces duplicated accounting
-- arithmetic") so the target-resolution + current-effective-state
-- arithmetic exists in exactly one place. Returns zero rows if the
-- target does not exist, or does not belong to the given group/loan —
-- callers treat "not found" (due_date is null) as
-- LOAN_ADJUSTMENT_TARGET_INVALID.
-- ---------------------------------------------------------------------

create or replace function public.loan_obligation_adjustment_target_state(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_target_type text,
  p_target_id uuid
)
returns table (
  loan_installment_id uuid,
  loan_penalty_charge_id uuid,
  due_date date,
  installment_cancelled boolean,
  gross numeric,
  net_adjustment numeric,
  allocated numeric,
  outstanding numeric,
  penalty_type public.loan_penalty_type,
  basis_amount numeric,
  rate numeric,
  fixed_amount numeric,
  penalty_amount numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_charge record;
  v_installment record;
  v_state record;
begin
  if p_target_type = 'LOAN_PENALTY' then
    select c.* into v_charge
    from public.loan_penalty_charges c
    where c.id = p_target_id and c.group_id = p_group_id and c.loan_account_id = p_loan_account_id;

    if v_charge.id is null then
      return;
    end if;

    select li.due_date, li.cancelled_at into v_installment
    from public.loan_installments li where li.id = v_charge.loan_installment_id;

    select s.allocated, s.outstanding into v_state
    from public.loan_penalty_charge_states(v_charge.loan_installment_id) s
    where s.charge_id = v_charge.id;

    select coalesce(sum(oa.amount), 0) into net_adjustment
    from public.loan_obligation_adjustments oa
    where oa.loan_penalty_charge_id = v_charge.id;

    loan_installment_id := v_charge.loan_installment_id;
    loan_penalty_charge_id := v_charge.id;
    due_date := v_installment.due_date;
    installment_cancelled := v_installment.cancelled_at is not null;
    gross := v_charge.penalty_amount;
    penalty_amount := v_charge.penalty_amount;
    allocated := coalesce(v_state.allocated, 0);
    outstanding := coalesce(v_state.outstanding, 0);
    penalty_type := v_charge.penalty_type;
    basis_amount := v_charge.basis_amount;
    rate := v_charge.rate;
    fixed_amount := v_charge.fixed_amount;
    return next;

  elsif p_target_type = 'LOAN_INTEREST' then
    select li.* into v_installment
    from public.loan_installments li
    where li.id = p_target_id and li.group_id = p_group_id and li.loan_account_id = p_loan_account_id;

    if v_installment.id is null then
      return;
    end if;

    select s.allocated, s.outstanding into v_state
    from public.loan_installment_component_states(v_installment.id) s
    where s.component_type = 'INTEREST';

    select coalesce(sum(oa.amount), 0) into net_adjustment
    from public.loan_obligation_adjustments oa
    where oa.loan_installment_id = v_installment.id and oa.target_type = 'LOAN_INTEREST';

    loan_installment_id := v_installment.id;
    loan_penalty_charge_id := null;
    due_date := v_installment.due_date;
    installment_cancelled := v_installment.cancelled_at is not null;
    gross := v_installment.interest_due;
    penalty_amount := null;
    allocated := coalesce(v_state.allocated, 0);
    outstanding := coalesce(v_state.outstanding, 0);
    penalty_type := null;
    basis_amount := null;
    rate := null;
    fixed_amount := null;
    return next;
  end if;
end;
$$;

revoke all on function public.loan_obligation_adjustment_target_state(uuid, uuid, text, uuid)
  from public, anon, authenticated;

comment on function public.loan_obligation_adjustment_target_state(uuid, uuid, text, uuid) is
  'Locked-down internal helper (Prompt 09F-A). Resolves a LOAN_PENALTY/
  LOAN_INTEREST adjustment target scoped to one group+loan, returning its
  current gross/net_adjustment/allocated/outstanding plus (for penalty)
  the frozen policy snapshot used by the correction-increase sanity
  bound. Returns zero rows if the target does not exist or does not
  belong to the given group/loan — callers treat that as
  LOAN_ADJUSTMENT_TARGET_INVALID.';
