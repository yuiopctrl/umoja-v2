-- Prompt 09C-UAT-FIX-01: physical-device UAT found that a large enough
-- payment silently prepaid a borrower's ENTIRE future loan schedule,
-- recognizing future interest early and potentially closing a loan
-- months ahead of its actual due dates. This is an authoritative
-- accounting/business-rule fix, not merely a Flutter display fix.
--
-- Locked policy: a loan installment component is automatically
-- allocatable only when the loan is ACTIVE AND its due_date <= the
-- payment's own effective date AND the component still has positive
-- outstanding. An installment whose due_date is after the effective
-- date is UPCOMING and is never included in the automatic allocation
-- plan — explicit loan prepayment is a deferred, separate policy
-- decision (see docs/product/loans.md).
--
-- Contribution allocation is UNCHANGED — Prompt 07 already allows a
-- not-yet-due contribution charge to be settled early, and nothing in
-- this fix alters that locked behavior or the priority rule (oldest
-- due_date first; contribution before loan on an exact tie; interest
-- before principal within an installment).

-- ---------------------------------------------------------------------
-- loan_member_allocatable_installments — now filtered by an explicit
-- effective date (defaults to current_date only so any other internal
-- caller that never passes one keeps working; every real caller below
-- passes it explicitly).
-- ---------------------------------------------------------------------

-- `create or replace function` only replaces a function with the exact
-- same argument-type list; adding a new trailing parameter creates a
-- SECOND overload instead of replacing the original, which then makes
-- every existing 2-arg call site ambiguous ("function ... is not
-- unique"). Drop the old-signature overloads explicitly before
-- (re)creating the extended versions.
drop function if exists public.loan_member_allocatable_installments(uuid, uuid);
drop function if exists public.payment_compute_combined_allocation_plan(uuid, uuid, numeric);
drop function if exists public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric);

create or replace function public.loan_member_allocatable_installments(
  p_group_id uuid,
  p_membership_id uuid,
  p_effective_date date default current_date
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
    and li.due_date <= p_effective_date
  order by li.due_date asc, la.created_at asc, li.installment_number asc;
$$;

revoke all on function public.loan_member_allocatable_installments(uuid, uuid, date) from public, anon, authenticated;

comment on function public.loan_member_allocatable_installments(uuid, uuid, date) is
  'Locked-down internal helper. Only ACTIVE loans'' installments whose
  due_date is on or before p_effective_date are collectible — an
  UPCOMING installment (due_date > p_effective_date) is structurally
  excluded here, never merely hidden in the UI (Prompt 09C-UAT-FIX-01).
  DRAFT/SUBMITTED/APPROVED/REJECTED/CANCELLED/CLOSED loans remain
  excluded by status exactly as before.';

-- ---------------------------------------------------------------------
-- payment_compute_combined_allocation_plan — passes the effective date
-- through to the loan side only; the contribution side is completely
-- unchanged (a not-yet-due contribution charge remains allocatable,
-- matching Prompt 07's existing, unaltered policy).
-- ---------------------------------------------------------------------

create or replace function public.payment_compute_combined_allocation_plan(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric,
  p_effective_date date default current_date
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
      from public.loan_member_allocatable_installments(p_group_id, p_membership_id, p_effective_date) li
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

revoke all on function public.payment_compute_combined_allocation_plan(uuid, uuid, numeric, date)
  from public, anon, authenticated;

comment on function public.payment_compute_combined_allocation_plan(uuid, uuid, numeric, date) is
  'Locked-down internal helper — the single deterministic allocation
  walk shared by rpc_preview_payment_allocation/rpc_post_payment/
  rpc_preview_wallet_allocation/rpc_allocate_member_wallet. p_effective_date
  (Prompt 09C-UAT-FIX-01) gates ONLY the loan side — a loan installment
  due after this date is never included. Contribution ordering/
  allocatability is completely unchanged. Ordering otherwise unchanged:
  oldest due_date first across both kinds; contribution before loan on
  an exact tie; within a loan installment, INTEREST before PRINCIPAL.';

-- ---------------------------------------------------------------------
-- rpc_preview_payment_allocation — gains p_effective_at (defaults to
-- current_date so any caller that omits it still behaves sanely), used
-- as the SAME basis rpc_post_payment uses below, so preview and posting
-- can never diverge on collectibility.
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_payment_allocation(
  p_group_id uuid,
  p_membership_id uuid,
  p_financial_account_id uuid,
  p_amount numeric,
  p_effective_at date default current_date
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_account record;
  v_allocations jsonb;
  v_total_allocated numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.create') then
    raise exception 'Not authorized to record payments in this group' using errcode = '42501';
  end if;

  select id, group_id into v_membership
  from public.group_memberships
  where id = p_membership_id;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id, group_id, name, is_active into v_account
  from public.financial_accounts
  where id = p_financial_account_id;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  if not v_account.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'PAYMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'obligation_kind', plan.obligation_kind,
    'charge_id', plan.charge_id,
    'component_id', plan.component_id,
    'component_type', plan.component_type,
    'due_date', plan.due_date,
    'allocate_amount', plan.allocate_amount,
    'contribution_type_name', plan.contribution_type_name,
    'period_id', plan.period_id,
    'period_label', plan.period_label,
    'period_purpose', plan.period_purpose,
    'loan_account_id', plan.loan_account_id,
    'loan_installment_id', plan.loan_installment_id,
    'loan_number', plan.loan_number,
    'installment_number', plan.installment_number,
    'component_outstanding_before', plan.component_outstanding_before
  ) order by plan.due_date, coalesce(plan.component_id, plan.loan_installment_id)), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.payment_compute_combined_allocation_plan(
    p_group_id, p_membership_id, p_amount, coalesce(p_effective_at, current_date)
  ) plan;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'financial_account_id', p_financial_account_id,
    'financial_account_name', v_account.name,
    'amount', p_amount,
    'allocations', v_allocations,
    'total_allocated', v_total_allocated,
    'wallet_credit_amount', p_amount - v_total_allocated
  );
end;
$$;

revoke all on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric, date) from public;
grant execute on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric, date) to authenticated;
revoke execute on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_post_payment — now passes its own (already-existing) p_effective_at
-- through to the combined plan, instead of the plan silently defaulting
-- to current_date. This is the fix for "preview and post must use the
-- identical date basis" — a backdated or postdated p_effective_at now
-- genuinely controls loan collectibility, exactly as it already
-- controlled which contribution charges look overdue.
-- ---------------------------------------------------------------------

create or replace function public.rpc_post_payment(
  p_group_id uuid,
  p_membership_id uuid,
  p_financial_account_id uuid,
  p_amount numeric,
  p_effective_at date,
  p_payment_method public.payment_method,
  p_external_reference text default null,
  p_notes text default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_account record;
  v_existing record;
  v_payment_id uuid;
  v_receipt_number text;
  v_plan record;
  v_loan_id uuid;
  v_total_allocated numeric := 0;
  v_wallet_credit_amount numeric;
  v_wallet_entry_id uuid;
  v_already_posted boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.create') then
    raise exception 'Not authorized to record payments in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'PAYMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select id, group_id into v_membership
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id, group_id, is_active into v_account
  from public.financial_accounts
  where id = p_financial_account_id;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  if not v_account.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.payments
    where group_id = p_group_id and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      if v_existing.membership_id <> p_membership_id
        or v_existing.financial_account_id <> p_financial_account_id
        or v_existing.amount <> p_amount
        or v_existing.effective_at <> p_effective_at
        or v_existing.payment_method <> p_payment_method
        or coalesce(v_existing.external_reference, '') <> coalesce(p_external_reference, '') then
        raise exception 'PAYMENT_IDEMPOTENCY_KEY_CONFLICT' using errcode = 'P0001';
      end if;

      select coalesce(sum(amount), 0) into v_total_allocated
      from public.payment_allocations
      where payment_id = v_existing.id;

      select coalesce(sum(amount), 0) into v_wallet_credit_amount
      from public.member_wallet_entries
      where source_type = 'PAYMENT' and source_id = v_existing.id and entry_type = 'PAYMENT_CREDIT';

      return jsonb_build_object(
        'payment_id', v_existing.id,
        'receipt_number', v_existing.receipt_number,
        'membership_id', v_existing.membership_id,
        'financial_account_id', v_existing.financial_account_id,
        'amount', v_existing.amount,
        'total_allocated', v_total_allocated,
        'wallet_credit_amount', v_wallet_credit_amount,
        'already_posted', true,
        'financial_account_balance', public.financial_account_balance(v_existing.financial_account_id),
        'wallet_balance', public.member_wallet_balance(v_existing.membership_id)
      );
    end if;
  end if;

  v_receipt_number := public.payment_generate_receipt_number(p_effective_at);

  insert into public.payments (
    group_id, membership_id, financial_account_id, amount, effective_at,
    payment_method, external_reference, notes, receipt_number, idempotency_key, created_by
  ) values (
    p_group_id, p_membership_id, p_financial_account_id, p_amount, p_effective_at,
    p_payment_method, p_external_reference, p_notes, v_receipt_number, p_idempotency_key, v_uid
  )
  returning id into v_payment_id;

  for v_plan in
    select * from public.payment_compute_combined_allocation_plan(
      p_group_id, p_membership_id, p_amount, p_effective_at
    )
  loop
    if v_plan.obligation_kind = 'CONTRIBUTION' then
      insert into public.payment_allocations (
        group_id, payment_id, membership_id, charge_id, charge_component_id, amount,
        allocation_target_type,
        contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
        created_by
      ) values (
        p_group_id, v_payment_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
        'CONTRIBUTION_COMPONENT',
        v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
        v_uid
      );
    else
      insert into public.payment_allocations (
        group_id, payment_id, membership_id, amount,
        allocation_target_type, loan_account_id, loan_installment_id,
        created_by
      ) values (
        p_group_id, v_payment_id, p_membership_id, v_plan.allocate_amount,
        (case v_plan.obligation_kind when 'LOAN_INTEREST' then 'LOAN_INTEREST' else 'LOAN_PRINCIPAL' end)::public.payment_allocation_target_type,
        v_plan.loan_account_id, v_plan.loan_installment_id,
        v_uid
      );
    end if;
    v_total_allocated := v_total_allocated + v_plan.allocate_amount;
  end loop;

  v_wallet_credit_amount := p_amount - v_total_allocated;
  if v_wallet_credit_amount > 0 then
    insert into public.member_wallet_entries (
      group_id, membership_id, entry_type, amount, effective_at, source_type, source_id, created_by
    ) values (
      p_group_id, p_membership_id, 'PAYMENT_CREDIT', v_wallet_credit_amount, p_effective_at, 'PAYMENT', v_payment_id, v_uid
    )
    returning id into v_wallet_entry_id;
  end if;

  -- Exactly one cashbook INFLOW for the FULL payment amount, never
  -- just the allocated portion — invariant B, unchanged.
  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'INFLOW',
    p_amount => p_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => 'Payment ' || v_receipt_number,
    p_reference => p_external_reference,
    p_source_type => 'PAYMENT',
    p_source_id => v_payment_id
  );

  for v_loan_id in
    select distinct loan_account_id from public.payment_allocations
    where payment_id = v_payment_id and loan_account_id is not null
  loop
    perform public.loan_account_recheck_closure(p_group_id, v_loan_id, v_uid);
  end loop;

  return jsonb_build_object(
    'payment_id', v_payment_id,
    'receipt_number', v_receipt_number,
    'membership_id', p_membership_id,
    'financial_account_id', p_financial_account_id,
    'amount', p_amount,
    'total_allocated', v_total_allocated,
    'wallet_credit_amount', v_wallet_credit_amount,
    'already_posted', v_already_posted,
    'financial_account_balance', public.financial_account_balance(p_financial_account_id),
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) from public;
grant execute on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) to authenticated;
revoke execute on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) from anon;

-- ---------------------------------------------------------------------
-- rpc_preview_wallet_allocation / rpc_allocate_member_wallet — wallet
-- allocation has no established "effective date" concept of its own
-- (every wallet posting in this codebase is always dated current_date
-- — see the ALLOCATION_DEBIT insert below, unchanged). Per the locked
-- policy, "if wallet has no different established rule, use the same
-- rule" — so wallet allocation now also excludes UPCOMING loan
-- installments, gated on current_date.
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_wallet_allocation(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_balance numeric;
  v_allocations jsonb;
  v_total_allocated numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'wallet.allocate') then
    raise exception 'Not authorized to allocate member wallets in this group' using errcode = '42501';
  end if;

  select id, group_id into v_membership
  from public.group_memberships
  where id = p_membership_id;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'WALLET_ALLOCATION_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  v_balance := public.member_wallet_balance(p_membership_id);
  if p_amount > v_balance then
    raise exception 'WALLET_INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'obligation_kind', plan.obligation_kind,
    'charge_id', plan.charge_id,
    'component_id', plan.component_id,
    'component_type', plan.component_type,
    'due_date', plan.due_date,
    'allocate_amount', plan.allocate_amount,
    'contribution_type_name', plan.contribution_type_name,
    'period_id', plan.period_id,
    'period_label', plan.period_label,
    'period_purpose', plan.period_purpose,
    'loan_account_id', plan.loan_account_id,
    'loan_installment_id', plan.loan_installment_id,
    'loan_number', plan.loan_number,
    'installment_number', plan.installment_number,
    'component_outstanding_before', plan.component_outstanding_before
  ) order by plan.due_date, coalesce(plan.component_id, plan.loan_installment_id)), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date) plan;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'wallet_balance', v_balance,
    'amount', p_amount,
    'allocations', v_allocations,
    'total_allocated', v_total_allocated
  );
end;
$$;

revoke all on function public.rpc_preview_wallet_allocation(uuid, uuid, numeric) from public;
grant execute on function public.rpc_preview_wallet_allocation(uuid, uuid, numeric) to authenticated;
revoke execute on function public.rpc_preview_wallet_allocation(uuid, uuid, numeric) from anon;

create or replace function public.rpc_allocate_member_wallet(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_existing record;
  v_balance numeric;
  v_wallet_entry_id uuid;
  v_plan record;
  v_loan_id uuid;
  v_total_allocated numeric := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'wallet.allocate') then
    raise exception 'Not authorized to allocate member wallets in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'WALLET_ALLOCATION_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  select id, group_id into v_membership
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.member_wallet_entries
    where membership_id = p_membership_id
      and idempotency_key = p_idempotency_key
      and entry_type = 'ALLOCATION_DEBIT';

    if v_existing.id is not null then
      if v_existing.amount <> p_amount then
        raise exception 'WALLET_ALLOCATION_IDEMPOTENCY_KEY_CONFLICT' using errcode = 'P0001';
      end if;

      select coalesce(sum(amount), 0) into v_total_allocated
      from public.payment_allocations
      where wallet_entry_id = v_existing.id;

      return jsonb_build_object(
        'membership_id', p_membership_id,
        'amount', v_existing.amount,
        'total_allocated', v_total_allocated,
        'already_posted', true,
        'wallet_balance', public.member_wallet_balance(p_membership_id)
      );
    end if;
  end if;

  v_balance := public.member_wallet_balance(p_membership_id);
  if p_amount > v_balance then
    raise exception 'WALLET_INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  select coalesce(sum(allocate_amount), 0) into v_total_allocated
  from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date);

  if v_total_allocated <= 0 then
    raise exception 'WALLET_ALLOCATION_NOTHING_TO_ALLOCATE' using errcode = 'P0001';
  end if;

  insert into public.member_wallet_entries (
    group_id, membership_id, entry_type, amount, effective_at, source_type, idempotency_key, created_by
  ) values (
    p_group_id, p_membership_id, 'ALLOCATION_DEBIT', v_total_allocated, current_date, 'PAYMENT_ALLOCATION_BATCH', p_idempotency_key, v_uid
  )
  returning id into v_wallet_entry_id;

  for v_plan in
    select * from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date)
  loop
    if v_plan.obligation_kind = 'CONTRIBUTION' then
      insert into public.payment_allocations (
        group_id, wallet_entry_id, membership_id, charge_id, charge_component_id, amount,
        allocation_target_type,
        contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
        created_by
      ) values (
        p_group_id, v_wallet_entry_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
        'CONTRIBUTION_COMPONENT',
        v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
        v_uid
      );
    else
      insert into public.payment_allocations (
        group_id, wallet_entry_id, membership_id, amount,
        allocation_target_type, loan_account_id, loan_installment_id,
        created_by
      ) values (
        p_group_id, v_wallet_entry_id, p_membership_id, v_plan.allocate_amount,
        (case v_plan.obligation_kind when 'LOAN_INTEREST' then 'LOAN_INTEREST' else 'LOAN_PRINCIPAL' end)::public.payment_allocation_target_type,
        v_plan.loan_account_id, v_plan.loan_installment_id,
        v_uid
      );
    end if;
  end loop;

  for v_loan_id in
    select distinct loan_account_id from public.payment_allocations
    where wallet_entry_id = v_wallet_entry_id and loan_account_id is not null
  loop
    perform public.loan_account_recheck_closure(p_group_id, v_loan_id, v_uid);
  end loop;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'amount', p_amount,
    'total_allocated', v_total_allocated,
    'already_posted', false,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) from public;
grant execute on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) to authenticated;
revoke execute on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_statement — the "before payment"
-- authoritative summary shown immediately after selecting a member,
-- BEFORE any amount is entered (UAT-FIX-01 section 8/13). Now also
-- returns a `loans` block per ACTIVE loan (overdue/due-now/currently-
-- payable amounts, next due date, and a separately-labeled upcoming
-- figure), plus a contribution overdue/due-now breakdown, and a
-- `total_payable_now` combining both domains under the SAME
-- currently-payable rule the allocator itself now enforces. Same exact
-- signature as before — no new parameters needed.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_member_contribution_statement(
  p_group_id uuid,
  p_membership_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_charges jsonb;
  v_total_outstanding numeric;
  v_total_allocated numeric;
  v_contribution_overdue numeric;
  v_contribution_due_now numeric;
  v_loans jsonb;
  v_total_loans_currently_payable numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not (
    public.has_group_permission(p_group_id, 'contribution.view')
    and public.has_group_permission(p_group_id, 'payment.view')
    and public.has_group_permission(p_group_id, 'wallet.view')
  ) then
    raise exception 'Not authorized to view this member''s contribution statement' using errcode = '42501';
  end if;

  select id, group_id, display_name, member_number, status into v_membership
  from public.group_memberships
  where id = p_membership_id;
  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select
    coalesce(jsonb_agg(x.entry order by x.due_date), '[]'::jsonb),
    coalesce(sum(x.charge_outstanding), 0),
    coalesce(sum(x.charge_outstanding) filter (where x.due_date < current_date), 0),
    coalesce(sum(x.charge_outstanding) filter (where x.due_date = current_date), 0)
  into v_charges, v_total_outstanding, v_contribution_overdue, v_contribution_due_now
  from (
    select
      c.due_date,
      (select coalesce(sum(s.outstanding), 0) from public.contribution_charge_component_states(c.id) s)
        as charge_outstanding,
      jsonb_build_object(
        'charge_id', c.id,
        'period_id', c.period_id,
        'due_date', c.due_date,
        'contribution_type_name', ct.name,
        'period_label', p.label,
        'period_purpose', p.purpose::text,
        'components', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'component_type', s.component_type,
            'gross_after_corrections', s.gross_after_corrections,
            'allocated', s.allocated,
            'outstanding', s.outstanding
          ) order by s.priority, s.component_created_at), '[]'::jsonb)
          from public.contribution_charge_component_states(c.id) s
          where s.outstanding > 0
        )
      ) as entry
    from public.member_contribution_charges c
    join public.contribution_periods p on p.id = c.period_id
    join public.contribution_setups st on st.id = c.contribution_setup_id
    join public.contribution_types ct on ct.id = st.contribution_type_id
    where c.group_id = p_group_id and c.membership_id = p_membership_id
  ) x
  where x.charge_outstanding > 0;

  -- Global total across EVERY charge for this membership, regardless of
  -- whether that charge is still outstanding (a fully-settled charge's
  -- allocations still count toward "how much has this member paid/been
  -- allocated in total", even though it no longer appears in `charges`
  -- above) — unchanged from the pre-09C-UAT-FIX-01 contract.
  select coalesce(sum(s.allocated), 0)
  into v_total_allocated
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.group_id = p_group_id and c.membership_id = p_membership_id;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'loan_account_id', loan.loan_account_id,
      'loan_number', loan.loan_number,
      'overdue_amount', loan.overdue_amount,
      'due_now_amount', loan.due_now_amount,
      'currently_payable_amount', loan.currently_payable_amount,
      'next_due_date', loan.next_due_date,
      'upcoming_amount', loan.upcoming_amount
    ) order by loan.loan_number), '[]'::jsonb),
    coalesce(sum(loan.currently_payable_amount), 0)
  into v_loans, v_total_loans_currently_payable
  from (
    select
      la.id as loan_account_id,
      la.loan_number,
      coalesce(sum(it.installment_outstanding) filter (where it.due_date < current_date), 0) as overdue_amount,
      coalesce(sum(it.installment_outstanding) filter (where it.due_date = current_date), 0) as due_now_amount,
      coalesce(sum(it.installment_outstanding) filter (where it.due_date <= current_date), 0) as currently_payable_amount,
      (select min(it2.due_date) from (
        select li2.due_date,
          coalesce((select sum(s2.outstanding) from public.loan_installment_component_states(li2.id) s2), 0) as outstanding
        from public.loan_installments li2 where li2.loan_account_id = la.id
      ) it2 where it2.outstanding > 0) as next_due_date,
      coalesce(sum(it.installment_outstanding) filter (where it.due_date > current_date), 0) as upcoming_amount
    from public.loan_accounts la
    cross join lateral (
      select li.due_date,
        coalesce((select sum(s.outstanding) from public.loan_installment_component_states(li.id) s), 0) as installment_outstanding
      from public.loan_installments li
      where li.loan_account_id = la.id
    ) it
    where la.group_id = p_group_id and la.membership_id = p_membership_id and la.status = 'ACTIVE'
    group by la.id, la.loan_number
  ) loan;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'member_display_name', v_membership.display_name,
    'member_number', v_membership.member_number,
    'membership_status', v_membership.status,
    'charges', v_charges,
    'total_outstanding', v_total_outstanding,
    'total_allocated', v_total_allocated,
    'contribution_overdue_amount', v_contribution_overdue,
    'contribution_due_now_amount', v_contribution_due_now,
    'loans', v_loans,
    'total_loans_currently_payable_amount', v_total_loans_currently_payable,
    'total_payable_now', v_total_outstanding + v_total_loans_currently_payable,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_get_member_contribution_statement(uuid, uuid) from public;
grant execute on function public.rpc_get_member_contribution_statement(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_contribution_statement(uuid, uuid) from anon;

comment on function public.rpc_get_member_contribution_statement(uuid, uuid) is
  'The authoritative "before payment" summary (UAT-FIX-01 to Prompt 07,
  extended 09C-UAT-FIX-01) — member identity, contribution outstanding
  (with overdue/due-now breakdown), per-ACTIVE-loan overdue/due-now/
  currently-payable amounts and next due date, a separately-labeled
  upcoming (not-yet-payable) loan amount, wallet balance, and
  total_payable_now = contribution total_outstanding + loan currently-
  payable total — computed under the exact same currently-due rule the
  allocator itself enforces, using current_date as the basis (shown
  before any payment date is chosen).';
