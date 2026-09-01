-- Prompt 09C-UAT-FIX-02: physical UAT found that Wallet → Loan
-- "Preview Allocation" showed bare "Interest — 20,000" / "Principal —
-- 20,000" lines with no indication of which loan (or, when a member
-- holds more than one ACTIVE loan, which OF THEM) was being settled.
-- This migration adds the one genuinely missing semantic field —
-- `loan_product_name` — to the same allocation-context surface that
-- already carried `loan_number`/`installment_number`/`due_date`
-- (09C/09C-UAT-FIX-01). UX/read-model only: no accounting rule,
-- allocation priority, or posting semantic changes anywhere below.
--
-- `loan_number`/`installment_number` are already resolved via a LIVE
-- join to loan_accounts/loan_installments (never snapshotted, since
-- 09B/09C never treated those as editable-after-the-fact the way a
-- contribution type's name is) — `loan_product_name` is added via the
-- exact same live-join pattern, joining loan_products, for full
-- consistency.

-- ---------------------------------------------------------------------
-- loan_member_allocatable_installments — adds loan_product_name as a
-- new output column. `create or replace` cannot change a function's
-- return-table shape, so the prior 3-arg overload is dropped first.
-- ---------------------------------------------------------------------

drop function if exists public.loan_member_allocatable_installments(uuid, uuid, date);

create function public.loan_member_allocatable_installments(
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
  loan_product_name text,
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
    lp.name as loan_product_name,
    la.created_at as loan_created_at
  from public.loan_installments li
  join public.loan_accounts la on la.id = li.loan_account_id
  join public.loan_products lp on lp.id = la.loan_product_id
  where la.group_id = p_group_id
    and la.membership_id = p_membership_id
    and la.status = 'ACTIVE'
    and li.due_date <= p_effective_date
  order by li.due_date asc, la.created_at asc, li.installment_number asc;
$$;

revoke all on function public.loan_member_allocatable_installments(uuid, uuid, date) from public, anon, authenticated;

comment on function public.loan_member_allocatable_installments(uuid, uuid, date) is
  'Locked-down internal helper. Only ACTIVE loans'' installments whose
  due_date is on or before p_effective_date are collectible (Prompt
  09C-UAT-FIX-01). Now also resolves loan_product_name via a live join
  to loan_products, so every caller can show which loan/product an
  allocation targets (09C-UAT-FIX-02) without a second lookup.';

-- ---------------------------------------------------------------------
-- payment_compute_combined_allocation_plan — adds loan_product_name,
-- passed straight through from the LOAN branch above. Same drop-first
-- requirement (new output column).
-- ---------------------------------------------------------------------

drop function if exists public.payment_compute_combined_allocation_plan(uuid, uuid, numeric, date);

create function public.payment_compute_combined_allocation_plan(
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
  loan_product_name text,
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
        null::text as loan_product_name,
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
        li.loan_product_name,
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
          loan_product_name := null;
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
          loan_product_name := v_group.loan_product_name;
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
  rpc_preview_wallet_allocation/rpc_allocate_member_wallet. Now also
  carries loan_product_name (09C-UAT-FIX-02) alongside loan_number/
  installment_number/due_date, so a caller with multiple ACTIVE loans
  can group/label allocations unambiguously. Ordering/allocatability
  logic is completely unchanged from 09C-UAT-FIX-01.';

-- ---------------------------------------------------------------------
-- rpc_preview_payment_allocation — same signature (returns jsonb,
-- unaffected by the table-shape change above); each allocation line now
-- also carries loan_product_name.
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
    'loan_product_name', plan.loan_product_name,
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
-- rpc_preview_wallet_allocation — same addition.
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
    'loan_product_name', plan.loan_product_name,
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

-- ---------------------------------------------------------------------
-- rpc_get_payment_detail / rpc_get_receipt — add loan_product_name to
-- already-posted allocation lines too (section 4/5 consistency), via
-- the same live join loan_number already uses (never snapshotted —
-- matches existing precedent for loan context, unlike contribution
-- type name which IS snapshotted since it is genuinely re-nameable in
-- a way that already mattered before this fix).
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_payment_detail(
  p_group_id uuid,
  p_payment_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_payment record;
  v_allocations jsonb;
  v_wallet_credit jsonb;
  v_cashbook_entry jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.view') then
    raise exception 'Not authorized to view payments in this group' using errcode = '42501';
  end if;

  select p.*, gm.display_name as member_display_name, gm.member_number, fa.name as financial_account_name
  into v_payment
  from public.payments p
  join public.group_memberships gm on gm.id = p.membership_id
  join public.financial_accounts fa on fa.id = p.financial_account_id
  where p.id = p_payment_id;

  if v_payment.group_id is null or v_payment.group_id <> p_group_id then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'allocation_id', pa.id,
    'allocation_target_type', pa.allocation_target_type,
    'charge_id', pa.charge_id,
    'component_id', pa.charge_component_id,
    'component_type', coalesce(cc.component_type::text, pa.allocation_target_type::text),
    'due_date', coalesce(c.due_date, li.due_date),
    'amount', pa.amount,
    'contribution_type_name', pa.contribution_type_name_snapshot,
    'period_label', pa.period_label_snapshot,
    'period_purpose', pa.period_purpose_snapshot,
    'loan_account_id', pa.loan_account_id,
    'loan_number', la.loan_number,
    'loan_product_name', lp.name,
    'loan_installment_id', pa.loan_installment_id,
    'installment_number', li.installment_number
  ) order by coalesce(c.due_date, li.due_date), pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  left join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.member_contribution_charges c on c.id = pa.charge_id
  left join public.loan_installments li on li.id = pa.loan_installment_id
  left join public.loan_accounts la on la.id = pa.loan_account_id
  left join public.loan_products lp on lp.id = la.loan_product_id
  where pa.payment_id = p_payment_id;

  select jsonb_build_object('amount', we.amount, 'created_at', we.created_at)
  into v_wallet_credit
  from public.member_wallet_entries we
  where we.source_type = 'PAYMENT' and we.source_id = p_payment_id and we.entry_type = 'PAYMENT_CREDIT';

  select jsonb_build_object('entry_id', fae.id, 'entry_type', fae.entry_type, 'amount', fae.amount)
  into v_cashbook_entry
  from public.financial_account_entries fae
  where fae.source_type = 'PAYMENT' and fae.source_id = p_payment_id and fae.entry_type = 'INFLOW';

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'membership_id', v_payment.membership_id,
    'member_display_name', v_payment.member_display_name,
    'member_number', v_payment.member_number,
    'financial_account_id', v_payment.financial_account_id,
    'financial_account_name', v_payment.financial_account_name,
    'amount', v_payment.amount,
    'effective_at', v_payment.effective_at,
    'payment_method', v_payment.payment_method,
    'external_reference', v_payment.external_reference,
    'notes', v_payment.notes,
    'receipt_number', v_payment.receipt_number,
    'status', v_payment.status,
    'created_at', v_payment.created_at,
    'reversed_at', v_payment.reversed_at,
    'reversed_by', v_payment.reversed_by,
    'reversal_reason', v_payment.reversal_reason,
    'allocations', v_allocations,
    'wallet_credit', v_wallet_credit,
    'cashbook_entry', v_cashbook_entry
  );
end;
$$;

revoke all on function public.rpc_get_payment_detail(uuid, uuid) from public;
grant execute on function public.rpc_get_payment_detail(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_payment_detail(uuid, uuid) from anon;

create or replace function public.rpc_get_receipt(
  p_group_id uuid,
  p_payment_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_payment record;
  v_allocations jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.receipt.view') then
    raise exception 'Not authorized to view receipts in this group' using errcode = '42501';
  end if;

  select p.*, gm.display_name as member_display_name, gm.member_number, fa.name as financial_account_name
  into v_payment
  from public.payments p
  join public.group_memberships gm on gm.id = p.membership_id
  join public.financial_accounts fa on fa.id = p.financial_account_id
  where p.id = p_payment_id;

  if v_payment.group_id is null or v_payment.group_id <> p_group_id then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'allocation_target_type', pa.allocation_target_type,
    'component_type', coalesce(cc.component_type::text, pa.allocation_target_type::text),
    'due_date', coalesce(c.due_date, li.due_date),
    'amount', pa.amount,
    'contribution_type_name', pa.contribution_type_name_snapshot,
    'period_label', pa.period_label_snapshot,
    'period_purpose', pa.period_purpose_snapshot,
    'loan_number', la.loan_number,
    'loan_product_name', lp.name,
    'installment_number', li.installment_number
  ) order by coalesce(c.due_date, li.due_date), pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  left join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.member_contribution_charges c on c.id = pa.charge_id
  left join public.loan_installments li on li.id = pa.loan_installment_id
  left join public.loan_accounts la on la.id = pa.loan_account_id
  left join public.loan_products lp on lp.id = la.loan_product_id
  where pa.payment_id = p_payment_id;

  return jsonb_build_object(
    'receipt_number', v_payment.receipt_number,
    'payment_id', v_payment.id,
    'member_display_name', v_payment.member_display_name,
    'member_number', v_payment.member_number,
    'financial_account_name', v_payment.financial_account_name,
    'amount', v_payment.amount,
    'effective_at', v_payment.effective_at,
    'payment_method', v_payment.payment_method,
    'status', v_payment.status,
    'allocations', v_allocations
  );
end;
$$;

revoke all on function public.rpc_get_receipt(uuid, uuid) from public;
grant execute on function public.rpc_get_receipt(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_receipt(uuid, uuid) from anon;
