-- Prompt 09C: internal allocation-computation helpers for loan
-- repayment, locked down exactly like every other allocation helper in
-- this codebase (contribution_charge_component_states,
-- contribution_compute_payment_allocation_plan) — never granted to
-- anon/authenticated, callable only from other SECURITY DEFINER
-- functions owned by the same role.

-- ---------------------------------------------------------------------
-- loan_installment_component_states — for one installment, its
-- principal and interest components in allocation order (INTEREST
-- before PRINCIPAL, per the documented priority — section 7/8), each
-- with gross/allocated/outstanding. Mirrors
-- contribution_charge_component_states exactly: nothing is stored,
-- "allocated" is derived from payment_allocations rows that are either
-- wallet-sourced (always valid — wallet allocations are not reversible)
-- or payment-sourced with a still-POSTED parent payment.
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
    select 'INTEREST'::text as component_type, 1 as priority, li.interest_due as gross
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
  'Locked-down internal helper. For one loan installment: INTEREST then
  PRINCIPAL (priority order), each with gross/allocated/outstanding.
  Never a stored balance — always derived from
  loan_installments.principal_due/interest_due minus active
  payment_allocations rows.';

-- ---------------------------------------------------------------------
-- loan_member_allocatable_installments — every installment belonging
-- to one member's collectible (ACTIVE) loans, oldest due_date first.
-- Collectibility (section 12): DRAFT/SUBMITTED/APPROVED/REJECTED/
-- CANCELLED/CLOSED loans are excluded structurally by the status filter
-- below, never merely by a UI hint.
-- ---------------------------------------------------------------------

create or replace function public.loan_member_allocatable_installments(
  p_group_id uuid,
  p_membership_id uuid
)
returns table (
  loan_account_id uuid,
  installment_id uuid,
  installment_number integer,
  due_date date,
  loan_number text,
  loan_created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    li.loan_account_id,
    li.id as installment_id,
    li.installment_number,
    li.due_date,
    la.loan_number,
    la.created_at as loan_created_at
  from public.loan_installments li
  join public.loan_accounts la on la.id = li.loan_account_id
  where la.group_id = p_group_id
    and la.membership_id = p_membership_id
    and la.status = 'ACTIVE'
  order by li.due_date asc, la.created_at asc, li.installment_number asc;
$$;

revoke all on function public.loan_member_allocatable_installments(uuid, uuid) from public, anon, authenticated;

comment on function public.loan_member_allocatable_installments(uuid, uuid) is
  'Locked-down internal helper. Only ACTIVE loans'' installments are
  collectible — DRAFT/SUBMITTED/APPROVED/REJECTED/CANCELLED/CLOSED are
  structurally excluded here, never merely hidden in the UI (section
  12/19/20).';

-- ---------------------------------------------------------------------
-- payment_compute_combined_allocation_plan — the single deterministic
-- allocation walk across BOTH contribution obligations and loan
-- obligations, shared by every preview/posting RPC so preview and
-- posting can never diverge (the exact guarantee
-- contribution_compute_payment_allocation_plan already gave for
-- contributions alone).
--
-- Priority rule (section 7 — no pre-existing repayment priority rule
-- was found in docs/product/*.md, so this is the documented, newly
-- locked policy):
--   1. oldest due_date first, across BOTH obligation kinds together
--   2. on an exact due_date tie: contribution obligations before loan
--      obligations
--   3. within a loan installment: INTEREST before PRINCIPAL
-- Contribution-side ordering/amounts are completely unchanged from the
-- existing contribution_charge_component_states walk.
-- ---------------------------------------------------------------------

create or replace function public.payment_compute_combined_allocation_plan(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric
)
returns table (
  obligation_kind text,
  charge_id uuid,
  component_id uuid,
  component_type text,
  contribution_type_name text,
  period_id uuid,
  period_label text,
  period_purpose text,
  loan_account_id uuid,
  loan_installment_id uuid,
  loan_number text,
  installment_number integer,
  due_date date,
  allocate_amount numeric,
  component_outstanding_before numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_remaining numeric := coalesce(p_amount, 0);
  v_group record;
  v_component record;
  v_take numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  for v_group in
    select * from (
      select
        0 as kind_order,
        'CONTRIBUTION'::text as kind,
        c.charge_id as ref_id,
        c.due_date,
        c.charge_created_at as tie_created_at,
        c.contribution_type_name,
        c.period_id,
        c.period_label,
        c.period_purpose,
        null::uuid as loan_account_id,
        null::text as loan_number,
        null::integer as installment_number
      from public.contribution_member_allocatable_charges(p_group_id, p_membership_id) c
      union all
      select
        1 as kind_order,
        'LOAN'::text as kind,
        li.installment_id as ref_id,
        li.due_date,
        li.loan_created_at as tie_created_at,
        null::text, null::uuid, null::text, null::text,
        li.loan_account_id,
        li.loan_number,
        li.installment_number
      from public.loan_member_allocatable_installments(p_group_id, p_membership_id) li
    ) combined
    order by combined.due_date asc, combined.kind_order asc, combined.tie_created_at asc, combined.ref_id asc
  loop
    exit when v_remaining <= 0;

    if v_group.kind = 'CONTRIBUTION' then
      for v_component in
        select * from public.contribution_charge_component_states(v_group.ref_id) where outstanding > 0
      loop
        exit when v_remaining <= 0;

        v_take := least(v_remaining, v_component.outstanding);
        if v_take > 0 then
          obligation_kind := 'CONTRIBUTION';
          charge_id := v_group.ref_id;
          component_id := v_component.component_id;
          component_type := v_component.component_type;
          contribution_type_name := v_group.contribution_type_name;
          period_id := v_group.period_id;
          period_label := v_group.period_label;
          period_purpose := v_group.period_purpose;
          loan_account_id := null;
          loan_installment_id := null;
          loan_number := null;
          installment_number := null;
          due_date := v_group.due_date;
          allocate_amount := v_take;
          component_outstanding_before := v_component.outstanding;
          return next;
          v_remaining := v_remaining - v_take;
        end if;
      end loop;
    else
      for v_component in
        select * from public.loan_installment_component_states(v_group.ref_id) where outstanding > 0 order by priority
      loop
        exit when v_remaining <= 0;

        v_take := least(v_remaining, v_component.outstanding);
        if v_take > 0 then
          obligation_kind := case v_component.component_type when 'INTEREST' then 'LOAN_INTEREST' else 'LOAN_PRINCIPAL' end;
          charge_id := null;
          component_id := null;
          component_type := v_component.component_type;
          contribution_type_name := null;
          period_id := null;
          period_label := null;
          period_purpose := null;
          loan_account_id := v_group.loan_account_id;
          loan_installment_id := v_group.ref_id;
          loan_number := v_group.loan_number;
          installment_number := v_group.installment_number;
          due_date := v_group.due_date;
          allocate_amount := v_take;
          component_outstanding_before := v_component.outstanding;
          return next;
          v_remaining := v_remaining - v_take;
        end if;
      end loop;
    end if;
  end loop;
end;
$$;

revoke all on function public.payment_compute_combined_allocation_plan(uuid, uuid, numeric)
  from public, anon, authenticated;

comment on function public.payment_compute_combined_allocation_plan(uuid, uuid, numeric) is
  'Locked-down internal helper — the single deterministic allocation
  walk shared by rpc_preview_payment_allocation/rpc_post_payment/
  rpc_preview_wallet_allocation/rpc_allocate_member_wallet (Prompt 09C).
  Ordering: oldest due_date first across both obligation kinds;
  contribution before loan on an exact tie; within a loan installment,
  INTEREST before PRINCIPAL. Documented policy — see
  docs/product/loans.md.';

-- ---------------------------------------------------------------------
-- loan_account_recheck_closure — after any allocation or reversal that
-- may have changed a loan's outstanding balance, atomically closes an
-- ACTIVE loan whose principal+interest are now fully settled, or
-- reopens a CLOSED loan whose outstanding balance was restored by a
-- reversal (section 19/20). Always locks the loan row first. A no-op
-- for any other status (e.g. never touches DRAFT/SUBMITTED/APPROVED/
-- REJECTED/CANCELLED).
-- ---------------------------------------------------------------------

create or replace function public.loan_account_recheck_closure(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_uid uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_loan record;
  v_outstanding numeric;
begin
  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;

  if v_loan.id is null or v_loan.status not in ('ACTIVE', 'CLOSED') then
    return;
  end if;

  select coalesce(sum(s.outstanding), 0)
  into v_outstanding
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id;

  if v_outstanding = 0 and v_loan.status = 'ACTIVE' then
    update public.loan_accounts set status = 'CLOSED', updated_by = p_uid where id = p_loan_account_id;
    insert into public.loan_account_events (
      group_id, loan_account_id, event_type, from_status, to_status, created_by
    ) values (
      p_group_id, p_loan_account_id, 'CLOSED', 'ACTIVE', 'CLOSED', p_uid
    );
  elsif v_outstanding > 0 and v_loan.status = 'CLOSED' then
    update public.loan_accounts set status = 'ACTIVE', updated_by = p_uid where id = p_loan_account_id;
    insert into public.loan_account_events (
      group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
    ) values (
      p_group_id, p_loan_account_id, 'REOPENED', 'CLOSED', 'ACTIVE',
      coalesce(p_reason, 'Payment reversal restored an outstanding balance'), p_uid
    );
  end if;
end;
$$;

revoke all on function public.loan_account_recheck_closure(uuid, uuid, uuid, text) from public, anon, authenticated;

comment on function public.loan_account_recheck_closure(uuid, uuid, uuid, text) is
  'Locked-down internal helper, called from rpc_post_payment/
  rpc_allocate_member_wallet (may CLOSE) and rpc_reverse_payment (may
  REOPEN). Closure condition is server-authoritative: principal
  outstanding = 0 AND interest outstanding = 0 across every
  installment, never merely "payment amount reached" or "installment
  count reached" (section 19).';
