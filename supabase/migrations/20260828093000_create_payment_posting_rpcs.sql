-- Prompt 07: payment preview/posting/reversal + wallet preview/allocate
-- RPCs — the client-facing surface for the allocation engine built in
-- 20260828092000_create_payment_allocation_helpers.sql.
--
-- Concurrency: every mutating RPC below first takes
-- `select 1 from public.group_memberships where id = p_membership_id
-- for update` — a single lock point per membership that serializes
-- every payment post / payment reversal / wallet allocation touching
-- that member's obligations, wallet, and allocations against each
-- other. This is what makes the allocation plan computed inside one
-- of these transactions authoritative: a second transaction for the
-- same membership can only proceed (and recompute a fresh plan) after
-- the first has committed or rolled back.

-- ---------------------------------------------------------------------
-- rpc_preview_payment_allocation — non-posting preview (section 41).
-- Computes the exact same plan rpc_post_payment would persist, without
-- writing anything. Gated by payment.create (previewing is part of the
-- record-payment flow, not a separate read permission).
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
    'due_date', c.due_date,
    'allocate_amount', plan.allocate_amount
  ) order by c.due_date, plan.component_id), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount) plan
  join public.member_contribution_charges c on c.id = plan.charge_id;

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
-- rpc_post_payment — the atomic posting RPC (section 42).
--
-- One external payment -> one payment record -> zero or more
-- allocations -> optional wallet credit -> exactly one cashbook
-- INFLOW, for the FULL payment amount. Idempotent: a retry with the
-- same (group_id, idempotency_key) and an identical payload returns
-- the original result; a conflicting payload is rejected.
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

  -- Single lock point for this membership — see header comment.
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
      group_id, payment_id, membership_id, charge_id, charge_component_id, amount, created_by
    ) values (
      p_group_id, v_payment_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount, v_uid
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
-- rpc_reverse_payment — atomic reversal (section 46-48).
--
-- Never edits/deletes the original payment, its allocations, or its
-- cashbook INFLOW. Flips payments.status to REVERSED (which alone
-- makes the settled debt outstanding again, per
-- contribution_charge_component_states), reverses any still-unspent
-- PAYMENT_CREDIT it created, and posts one new immutable OUTFLOW
-- cashbook entry via reverses_entry_id — never a second inflow-side
-- edit.
-- ---------------------------------------------------------------------

create or replace function public.rpc_reverse_payment(
  p_group_id uuid,
  p_payment_id uuid,
  p_reversal_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership_id uuid;
  v_payment record;
  v_credit_entry record;
  v_wallet_balance numeric;
  v_original_entry_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.reverse') then
    raise exception 'Not authorized to reverse payments in this group' using errcode = '42501';
  end if;

  if p_reversal_reason is null or btrim(p_reversal_reason) = '' then
    raise exception 'PAYMENT_REVERSAL_REASON_REQUIRED' using errcode = '22023';
  end if;

  select membership_id into v_membership_id from public.payments where id = p_payment_id;
  if v_membership_id is null then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  -- Same lock point rpc_post_payment/rpc_allocate_member_wallet use —
  -- consistent lock ordering (membership row first) avoids deadlocks.
  perform 1 from public.group_memberships where id = v_membership_id for update;

  select * into v_payment from public.payments where id = p_payment_id for update;
  if v_payment.group_id is null or v_payment.group_id <> p_group_id then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  if v_payment.status <> 'POSTED' then
    raise exception 'PAYMENT_ALREADY_REVERSED' using errcode = 'P0001';
  end if;

  select * into v_credit_entry
  from public.member_wallet_entries
  where source_type = 'PAYMENT' and source_id = p_payment_id and entry_type = 'PAYMENT_CREDIT';

  if v_credit_entry.id is not null then
    v_wallet_balance := public.member_wallet_balance(v_payment.membership_id);
    if v_wallet_balance - v_credit_entry.amount < 0 then
      -- The credit this payment created has already been spent via a
      -- wallet allocation — never silently reverse unrelated wallet
      -- value belonging to other payments.
      raise exception 'PAYMENT_REVERSAL_BLOCKED_WALLET_CREDIT_CONSUMED' using errcode = 'P0001';
    end if;

    insert into public.member_wallet_entries (
      group_id, membership_id, entry_type, amount, effective_at,
      source_type, source_id, reverses_entry_id, created_by
    ) values (
      p_group_id, v_payment.membership_id, 'REVERSAL', v_credit_entry.amount, current_date,
      'PAYMENT_REVERSAL', p_payment_id, v_credit_entry.id, v_uid
    );
  end if;

  select id into v_original_entry_id
  from public.financial_account_entries
  where source_type = 'PAYMENT' and source_id = p_payment_id and entry_type = 'INFLOW';

  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => v_payment.financial_account_id,
    p_entry_type => 'OUTFLOW',
    p_amount => v_payment.amount,
    p_effective_at => current_date,
    p_uid => v_uid,
    p_description => 'Reversal of ' || v_payment.receipt_number,
    p_source_type => 'PAYMENT_REVERSAL',
    p_source_id => p_payment_id,
    p_reverses_entry_id => v_original_entry_id
  );

  update public.payments
  set status = 'REVERSED', reversed_at = now(), reversed_by = v_uid, reversal_reason = p_reversal_reason
  where id = p_payment_id;

  return jsonb_build_object(
    'payment_id', p_payment_id,
    'status', 'REVERSED',
    'reversal_reason', p_reversal_reason,
    'financial_account_balance', public.financial_account_balance(v_payment.financial_account_id),
    'wallet_balance', public.member_wallet_balance(v_payment.membership_id)
  );
end;
$$;

revoke all on function public.rpc_reverse_payment(uuid, uuid, text) from public;
grant execute on function public.rpc_reverse_payment(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reverse_payment(uuid, uuid, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_preview_wallet_allocation / rpc_allocate_member_wallet (section
-- 32-33). Manual, atomic, creates no payment/receipt/cashbook entry —
-- invariant C. Reuses the exact same allocation-plan helper as
-- payments, so a wallet allocation settles obligations in the
-- identical deterministic order.
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
    'due_date', c.due_date,
    'allocate_amount', plan.allocate_amount
  ) order by c.due_date, plan.component_id), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.contribution_compute_payment_allocation_plan(p_group_id, p_membership_id, p_amount) plan
  join public.member_contribution_charges c on c.id = plan.charge_id;

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
  -- outstanding obligations — if p_amount exceeds total payable debt,
  -- the unapplied remainder simply stays in the wallet rather than
  -- being debited and stranded (there is no wallet-to-wallet or
  -- overflow-back-to-wallet path in this phase because it never left
  -- the wallet to begin with).
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
      group_id, wallet_entry_id, membership_id, charge_id, charge_component_id, amount, created_by
    ) values (
      p_group_id, v_wallet_entry_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount, v_uid
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
