-- Prompt 09D: internal allocation-computation helpers for loan
-- penalties, locked down exactly like every other allocation helper in
-- this codebase (contribution_charge_component_states,
-- loan_installment_component_states) — never granted to
-- anon/authenticated, callable only from other SECURITY DEFINER
-- functions owned by the same role.

-- ---------------------------------------------------------------------
-- loan_penalty_charge_states — for one installment, EVERY outstanding
-- penalty charge (there may be more than one under RECURRING_MONTHLY),
-- oldest assessment_date/sequence first, each with its own derived
-- outstanding. "Active" allocation is the SAME rule used everywhere
-- else in this codebase: wallet-sourced always counts, payment-sourced
-- counts only while the parent payment is still POSTED.
-- ---------------------------------------------------------------------

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
    greatest(0, c.penalty_amount - coalesce(a.allocated, 0)) as outstanding
  from public.loan_penalty_charges c
  left join (
    select pa.loan_penalty_charge_id, sum(pa.amount) as allocated
    from public.payment_allocations pa
    left join public.payments p on p.id = pa.payment_id
    where pa.loan_penalty_charge_id is not null
      and (pa.wallet_entry_id is not null or p.status = 'POSTED')
    group by pa.loan_penalty_charge_id
  ) a on a.loan_penalty_charge_id = c.id
  where c.loan_installment_id = p_loan_installment_id
  order by c.assessment_date asc, c.sequence_number asc;
$$;

revoke all on function public.loan_penalty_charge_states(uuid) from public, anon, authenticated;

comment on function public.loan_penalty_charge_states(uuid) is
  'Locked-down internal helper. Every outstanding penalty charge for
  one installment, oldest assessment_date/sequence first — used only
  by payment_compute_combined_allocation_plan to attribute an
  allocation to the exact charge it settles (FIFO), never to compute a
  single aggregate figure (see loan_installment_component_states for
  that).';

-- ---------------------------------------------------------------------
-- loan_installment_component_states — extended with a PENALTY
-- aggregate row (priority 0, before INTEREST=1/PRINCIPAL=2 — section
-- 17's locked priority PENALTY -> INTEREST -> PRINCIPAL). Same
-- signature/return shape as before (a UNION ALL branch is additive,
-- not a shape change) so this is a plain create or replace, no drop
-- needed. Used for: closure-check totals (loan_account_recheck_closure
-- sums outstanding across every component_type here, so it now
-- automatically includes penalty with zero code change — section 23),
-- and every read-model aggregate (loan_account_summary, installment
-- lists) that wants "how much penalty is outstanding on this
-- installment" as one number.
-- ---------------------------------------------------------------------

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
      ), 0) as gross
    union all
    select 'INTEREST'::text, 1, li.interest_due
    from public.loan_installments li
    where li.id = p_loan_installment_id
    union all
    select 'PRINCIPAL'::text, 2, li.principal_due
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
  (aggregate across every loan_penalty_charges row for this
  installment), then INTEREST, then PRINCIPAL (priority order — Prompt
  09D section 17), each with gross/allocated/outstanding. Never a
  stored balance — always derived. PENALTY here is an AGGREGATE figure
  (for closure checks and summary reads); actual allocation posting
  uses loan_penalty_charge_states to attribute to the specific
  charge(s) settled.';
