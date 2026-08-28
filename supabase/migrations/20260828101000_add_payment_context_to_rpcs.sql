-- Prompt 07 UAT-FIX-01: propagate the new allocation context (see
-- 20260828100000_add_payment_allocation_context.sql) through every
-- RPC that reads or posts allocations. Every function below keeps its
-- exact existing signature, permission checks, validation, idempotency
-- and locking behavior — only the allocation-related SELECT/INSERT
-- columns change.

-- ---------------------------------------------------------------------
-- rpc_preview_payment_allocation — each allocation line now carries
-- contribution_type_name/period_label/period_purpose/
-- component_outstanding_before alongside the existing fields. due_date
-- now comes directly from the plan function, so the join to
-- member_contribution_charges is no longer needed here.
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_payment_allocation(
  p_group_id uuid,
  p_membership_id uuid,
  p_financial_account_id uuid,
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
    'charge_id', plan.charge_id,
    'component_id', plan.component_id,
    'component_type', plan.component_type,
    'due_date', plan.due_date,
    'allocate_amount', plan.allocate_amount,
    'contribution_type_name', plan.contribution_type_name,
    'period_id', plan.period_id,
    'period_label', plan.period_label,
    'period_purpose', plan.period_purpose,
    'component_outstanding_before', plan.component_outstanding_before
  ) order by plan.due_date, plan.component_id), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount) plan;

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

revoke all on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric) from public;
grant execute on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric) to authenticated;
revoke execute on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric) from anon;

-- ---------------------------------------------------------------------
-- rpc_post_payment — each payment_allocations row now snapshots the
-- allocation's contribution/period context at posting time (never
-- re-derived from the live, possibly-since-renamed contribution_types/
-- contribution_periods rows). Every other step (auth, validation,
-- idempotency, locking, wallet credit, cashbook INFLOW) is unchanged.
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

  -- Single lock point for this membership — see the posting RPCs'
  -- header comment in 20260828093000 for the full concurrency
  -- rationale.
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
    select * from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount)
  loop
    insert into public.payment_allocations (
      group_id, payment_id, membership_id, charge_id, charge_component_id, amount,
      contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
      created_by
    ) values (
      p_group_id, v_payment_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
      v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
      v_uid
    );
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
  -- just the allocated portion — invariant B.
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
-- rpc_preview_wallet_allocation — same context fields as the payment
-- preview.
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
    'charge_id', plan.charge_id,
    'component_id', plan.component_id,
    'component_type', plan.component_type,
    'due_date', plan.due_date,
    'allocate_amount', plan.allocate_amount,
    'contribution_type_name', plan.contribution_type_name,
    'period_id', plan.period_id,
    'period_label', plan.period_label,
    'period_purpose', plan.period_purpose,
    'component_outstanding_before', plan.component_outstanding_before
  ) order by plan.due_date, plan.component_id), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount) plan;

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
-- rpc_allocate_member_wallet — same snapshotting as rpc_post_payment,
-- onto the wallet_entry_id-sourced payment_allocations rows.
-- ---------------------------------------------------------------------

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

  -- Only debit the wallet for what actually gets applied to
  -- outstanding obligations — see 20260828093000's header comment for
  -- the full "no overflow-back-to-wallet" rationale.
  select coalesce(sum(allocate_amount), 0) into v_total_allocated
  from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount);

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
    select * from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount)
  loop
    insert into public.payment_allocations (
      group_id, wallet_entry_id, membership_id, charge_id, charge_component_id, amount,
      contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
      created_by
    ) values (
      p_group_id, v_wallet_entry_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
      v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
      v_uid
    );
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
-- rpc_get_payment_detail — allocations now carry the snapshotted
-- context. due_date still comes from the (immutable) charge row.
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
    'charge_id', pa.charge_id,
    'component_id', pa.charge_component_id,
    'component_type', cc.component_type,
    'due_date', c.due_date,
    'amount', pa.amount,
    'contribution_type_name', pa.contribution_type_name_snapshot,
    'period_label', pa.period_label_snapshot,
    'period_purpose', pa.period_purpose_snapshot
  ) order by c.due_date, pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  join public.member_contribution_charges c on c.id = pa.charge_id
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

-- ---------------------------------------------------------------------
-- rpc_get_receipt — allocations now carry the snapshotted context
-- instead of a bare component_type. This is exactly the immutability
-- fix from the header comment: never joins to the live
-- contribution_types/contribution_periods rows.
-- ---------------------------------------------------------------------

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
    'component_type', cc.component_type,
    'due_date', c.due_date,
    'amount', pa.amount,
    'contribution_type_name', pa.contribution_type_name_snapshot,
    'period_label', pa.period_label_snapshot,
    'period_purpose', pa.period_purpose_snapshot
  ) order by c.due_date, pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  join public.member_contribution_charges c on c.id = pa.charge_id
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

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_statement — the "before payment"
-- authoritative summary (section 1/2 of UAT-FIX-01). Extended with
-- member identity fields and per-charge contribution/period context,
-- and now only includes charges/components that are still
-- outstanding (never a fully-settled charge cluttering the list).
-- Gating unchanged: contribution.view AND payment.view AND wallet.view
-- together (no self-view path — see the deferral note in
-- docs/product/payments.md).
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
    coalesce(sum(x.charge_outstanding), 0)
  into v_charges, v_total_outstanding
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

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'member_display_name', v_membership.display_name,
    'member_number', v_membership.member_number,
    'membership_status', v_membership.status,
    'charges', v_charges,
    'total_outstanding', v_total_outstanding,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_get_member_contribution_statement(uuid, uuid) from public;
grant execute on function public.rpc_get_member_contribution_statement(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_contribution_statement(uuid, uuid) from anon;
