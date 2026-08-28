-- Prompt 07: internal allocation-computation helpers. Locked down like
-- financial_account_balance()/contribution_charge_net_assessed() —
-- never granted to anon/authenticated, callable only by other
-- SECURITY DEFINER functions owned by the same role.
--
-- These are the single source of truth for "what is still payable, in
-- what order" — used identically by the non-posting preview RPC and
-- the posting RPC, so preview and actual posting can never diverge
-- given the same inputs.

-- ---------------------------------------------------------------------
-- contribution_charge_component_states — for one charge, every
-- component in deterministic allocation order (BASE, then PENALTY by
-- sequence, then positive ADJUSTMENT by created_at, then
-- OPENING_BALANCE), with WAIVER and negative ADJUSTMENT netted off
-- front-to-back against that ordered list before allocated/outstanding
-- are computed. contribution_charge_components never mutates —
-- "allocated" is derived from payment_allocations joined to
-- payments.status = 'POSTED'.
-- ---------------------------------------------------------------------

create or replace function public.contribution_charge_component_states(p_charge_id uuid)
returns table (
  component_id uuid,
  component_type text,
  priority integer,
  component_created_at timestamptz,
  gross_after_corrections numeric,
  allocated numeric,
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
    -- A wallet-sourced allocation (wallet_entry_id set) is always
    -- valid — wallet allocations are not reversible in this phase. A
    -- payment-sourced allocation counts only while its parent payment
    -- is still POSTED, so a reversed payment's settled debt becomes
    -- outstanding again automatically, with no allocation row ever
    -- mutated or deleted.
    select pa.charge_component_id, sum(pa.amount) as allocated
    from public.payment_allocations pa
    left join public.payments p on p.id = pa.payment_id
    where pa.wallet_entry_id is not null or p.status = 'POSTED'
    group by pa.charge_component_id
  )
  select
    r.id as component_id,
    r.component_type,
    r.priority,
    r.created_at as component_created_at,
    greatest(0, r.assessed_amount - greatest(0, (select total from reduction_total) - r.prior_gross))
      as gross_after_corrections,
    coalesce(a.allocated, 0) as allocated,
    greatest(
      0,
      greatest(0, r.assessed_amount - greatest(0, (select total from reduction_total) - r.prior_gross))
        - coalesce(a.allocated, 0)
    ) as outstanding
  from running r
  left join allocated_totals a on a.charge_component_id = r.id
  order by r.priority, r.sequence, r.created_at;
$$;

revoke all on function public.contribution_charge_component_states(uuid) from public, anon, authenticated;

comment on function public.contribution_charge_component_states(uuid) is
  'Locked-down internal helper. For one charge: every payable
  (non-WAIVER, non-negative-ADJUSTMENT) component in deterministic
  allocation order, with corrections netted off front-to-back and
  already-POSTED allocations subtracted. Reused unchanged by
  rpc_preview_payment_allocation and rpc_post_payment so preview and
  posting can never diverge.';

-- ---------------------------------------------------------------------
-- contribution_member_allocatable_charges — every charge for one
-- membership, ordered oldest-due-date-first. Since "overdue" is
-- exactly due_date < as-of-date, sorting by due_date ascending alone
-- already satisfies "overdue charges before current charges, oldest
-- due date first" — every overdue charge's due_date is by definition
-- earlier than every not-yet-due charge's due_date.
-- ---------------------------------------------------------------------

create or replace function public.contribution_member_allocatable_charges(
  p_group_id uuid,
  p_membership_id uuid
)
returns table (
  charge_id uuid,
  due_date date,
  charge_created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id as charge_id, c.due_date, c.created_at as charge_created_at
  from public.member_contribution_charges c
  where c.group_id = p_group_id and c.membership_id = p_membership_id
  order by c.due_date asc, c.created_at asc;
$$;

revoke all on function public.contribution_member_allocatable_charges(uuid, uuid) from public, anon, authenticated;

comment on function public.contribution_member_allocatable_charges(uuid, uuid) is
  'Locked-down internal helper. Charge-level ordering for payment
  allocation across a member''s obligations: oldest due_date first
  (which — since overdue is exactly due_date < today — already places
  every overdue charge before every not-yet-due charge). An
  OPENING_BALANCE charge''s due_date equals its cutover effective_at
  (06C), so it naturally sorts as one of the oldest.';

-- ---------------------------------------------------------------------
-- contribution_compute_payment_allocation_plan — the shared
-- allocation walk. Given an amount, walks charges (oldest due_date
-- first) then components within each charge (priority order),
-- greedily allocating until the amount is exhausted. Returns an empty
-- set if there is nothing left to allocate — the whole amount then
-- becomes wallet credit in the caller.
-- ---------------------------------------------------------------------

create or replace function public.contribution_compute_payment_allocation_plan(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric
)
returns table (
  charge_id uuid,
  component_id uuid,
  component_type text,
  allocate_amount numeric
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
  walk shared by rpc_preview_payment_allocation (read-only) and
  rpc_post_payment (which persists exactly this plan as
  payment_allocations rows). Never called with a stale read outside a
  transaction that has already taken the per-member row lock — see
  rpc_post_payment.';

-- ---------------------------------------------------------------------
-- member_wallet_balance — always derived, never stored. Mirrors
-- financial_account_balance() exactly.
-- ---------------------------------------------------------------------

create or replace function public.member_wallet_balance(p_membership_id uuid)
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
  where membership_id = p_membership_id;
$$;

revoke all on function public.member_wallet_balance(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- payment_generate_receipt_number — collision-safe, concurrency-safe
-- sequential receipt number. Global (not per-group) counter, so the
-- text needs no embedded group identifier to stay unique.
-- ---------------------------------------------------------------------

create or replace function public.payment_generate_receipt_number(p_effective_at date)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year integer := extract(year from p_effective_at)::integer;
  v_seq integer;
begin
  insert into public.receipt_number_counters (year, last_seq)
  values (v_year, 1)
  on conflict (year) do update set last_seq = public.receipt_number_counters.last_seq + 1
  returning last_seq into v_seq;

  return format('UMOJA-RCP-%s-%s', v_year, lpad(v_seq::text, 6, '0'));
end;
$$;

revoke all on function public.payment_generate_receipt_number(date) from public, anon, authenticated;

comment on function public.payment_generate_receipt_number(date) is
  'Format: UMOJA-RCP-{year}-{seq:06d}. Global counter (shared across
  every group) via INSERT ... ON CONFLICT DO UPDATE ... RETURNING on
  receipt_number_counters, whose row lock serializes concurrent
  callers within the same year — collision-safe under concurrency.';
