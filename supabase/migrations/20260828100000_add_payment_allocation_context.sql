-- Prompt 07 UAT-FIX-01: the allocation preview/receipt showed only bare
-- "Base 20,000 / Base 10,000" rows — technically correct component
-- data, operationally meaningless (no contribution/period identity).
-- This migration extends the allocation read model with that context.
--
-- Accounting semantics, allocation ordering, and already-posted
-- payment history are all UNCHANGED — every function below is
-- extended with additional OUTPUT columns only; the underlying
-- amounts/ordering computed by the existing walk are untouched.
--
-- Historical-receipt strategy (see docs/product/payments.md): a
-- receipt/payment-detail must not become misleading if a contribution
-- type or period is renamed later. contribution_types.name and
-- contribution_periods.label are both live-editable, so the display
-- context for an ALREADY-POSTED allocation is snapshotted onto
-- payment_allocations at posting time (mirroring the
-- member_number_snapshot/member_name_snapshot precedent already
-- established on member_contribution_charges in 06A/06C) — never
-- re-derived from current contribution_types/contribution_periods for
-- historical display. Only PRE-posting reads (preview, the
-- outstanding-obligations list) join to the live tables, since nothing
-- has been posted yet and there is nothing to snapshot.

-- ---------------------------------------------------------------------
-- payment_allocations — nullable snapshot columns. Null for any row
-- that predates this migration; callers must render such rows using
-- only component_type (never crash on a missing snapshot).
-- ---------------------------------------------------------------------

alter table public.payment_allocations
  add column contribution_type_name_snapshot text,
  add column period_label_snapshot text,
  add column period_purpose_snapshot text;

comment on column public.payment_allocations.contribution_type_name_snapshot is
  'contribution_types.name as it was at posting time — never re-derived
  from the live (possibly since-renamed) row. Null only for rows
  posted before this column existed.';
comment on column public.payment_allocations.period_label_snapshot is
  'contribution_periods.label as it was at posting time — same
  immutability reasoning as contribution_type_name_snapshot.';
comment on column public.payment_allocations.period_purpose_snapshot is
  'contribution_periods.purpose (''NORMAL''/''OPENING_BALANCE'') as text,
  snapshotted so historical display formatting (e.g. omitting the
  period suffix for an opening-balance charge) never depends on the
  live period row.';

-- ---------------------------------------------------------------------
-- contribution_member_allocatable_charges — extended with contribution
-- type/period context per charge. Ordering (due_date asc, created_at
-- asc) is completely unchanged.
-- ---------------------------------------------------------------------

-- `returns table (...)` changes its OUT-parameter row type, which
-- `create or replace function` cannot alter in place — the function
-- must be dropped and recreated. Nothing outside this migration calls
-- it directly (only contribution_compute_payment_allocation_plan
-- below, replaced in this same migration), so this is safe.
drop function if exists public.contribution_member_allocatable_charges(uuid, uuid);

create function public.contribution_member_allocatable_charges(
  p_group_id uuid,
  p_membership_id uuid
)
returns table (
  charge_id uuid,
  due_date date,
  charge_created_at timestamptz,
  contribution_type_name text,
  period_id uuid,
  period_label text,
  period_purpose text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id as charge_id,
    c.due_date,
    c.created_at as charge_created_at,
    ct.name as contribution_type_name,
    c.period_id,
    p.label as period_label,
    p.purpose::text as period_purpose
  from public.member_contribution_charges c
  join public.contribution_periods p on p.id = c.period_id
  join public.contribution_setups st on st.id = c.contribution_setup_id
  join public.contribution_types ct on ct.id = st.contribution_type_id
  where c.group_id = p_group_id and c.membership_id = p_membership_id
  order by c.due_date asc, c.created_at asc;
$$;

revoke all on function public.contribution_member_allocatable_charges(uuid, uuid) from public, anon, authenticated;

comment on function public.contribution_member_allocatable_charges(uuid, uuid) is
  'Locked-down internal helper. Charge-level ordering for payment
  allocation across a member''s obligations: oldest due_date first
  (which — since overdue is exactly due_date < today — already places
  every overdue charge before every not-yet-due charge). Now also
  carries contribution_type_name/period_label/period_purpose so
  callers never need a second lookup or client-side join (UAT-FIX-01).';

-- ---------------------------------------------------------------------
-- contribution_compute_payment_allocation_plan — the shared allocation
-- walk. The greedy walk itself, and the amounts/order it produces, are
-- byte-for-byte unchanged; each returned row now also carries the
-- charge's contribution/period context and the component's outstanding
-- amount immediately before this allocation was taken from it.
-- ---------------------------------------------------------------------

drop function if exists public.contribution_compute_payment_allocation_plan(uuid, uuid, numeric);

create function public.contribution_compute_payment_allocation_plan(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric
)
returns table (
  charge_id uuid,
  component_id uuid,
  component_type text,
  allocate_amount numeric,
  contribution_type_name text,
  period_id uuid,
  period_label text,
  period_purpose text,
  due_date date,
  component_outstanding_before numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_remaining numeric := coalesce(p_amount, 0);
  v_charge record;
  v_component record;
  v_take numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  for v_charge in
    select * from public.contribution_member_allocatable_charges(p_group_id, p_membership_id)
  loop
    exit when v_remaining <= 0;

    for v_component in
      select *
      from public.contribution_charge_component_states(v_charge.charge_id)
      where outstanding > 0
    loop
      exit when v_remaining <= 0;

      v_take := least(v_remaining, v_component.outstanding);
      if v_take > 0 then
        charge_id := v_charge.charge_id;
        component_id := v_component.component_id;
        component_type := v_component.component_type;
        allocate_amount := v_take;
        contribution_type_name := v_charge.contribution_type_name;
        period_id := v_charge.period_id;
        period_label := v_charge.period_label;
        period_purpose := v_charge.period_purpose;
        due_date := v_charge.due_date;
        component_outstanding_before := v_component.outstanding;
        return next;
        v_remaining := v_remaining - v_take;
      end if;
    end loop;
  end loop;
end;
$$;

revoke all on function public.contribution_compute_payment_allocation_plan(uuid, uuid, numeric)
  from public, anon, authenticated;

comment on function public.contribution_compute_payment_allocation_plan(uuid, uuid, numeric) is
  'Locked-down internal helper — the single deterministic allocation
  walk shared by rpc_preview_payment_allocation/rpc_preview_wallet_
  allocation (read-only) and rpc_post_payment/rpc_allocate_member_
  wallet (which persist exactly this plan, snapshotting the context
  columns onto payment_allocations). UAT-FIX-01 added
  contribution_type_name/period_label/period_purpose/due_date/
  component_outstanding_before as additional descriptive output
  columns only — the walk''s amounts and ordering are unchanged.';
