-- Prompt 08B: manual group income/expense RPCs.

-- ---------------------------------------------------------------------
-- rpc_record_manual_income — posts group income that does NOT
-- originate from a member contribution payment (section 4). Creates
-- exactly one financial_manual_entries row + one cashbook INFLOW
-- (source_type = 'MANUAL_INCOME'). Never touches payments/
-- payment_allocations/member_wallet_entries/contribution charges.
-- ---------------------------------------------------------------------

create or replace function public.rpc_record_manual_income(
  p_group_id uuid,
  p_financial_account_id uuid,
  p_category_id uuid,
  p_amount numeric,
  p_effective_at date,
  p_description text default null,
  p_reference text default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account record;
  v_category record;
  v_existing record;
  v_entry_id uuid;
  v_cashbook_entry_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_income.create') then
    raise exception 'Not authorized to record income in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCIAL_MANUAL_ENTRY_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  -- Row lock: consistent with every other balance-affecting RPC
  -- (rpc_post_payment, rpc_record_financial_account_transfer) —
  -- serializes concurrent postings against the same account.
  select id, group_id, is_active into v_account
  from public.financial_accounts
  where id = p_financial_account_id
  for update;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;
  if not v_account.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  select id, group_id, category_type, is_active into v_category
  from public.financial_categories
  where id = p_category_id;

  if v_category.group_id is null or v_category.group_id <> p_group_id then
    raise exception 'Financial category not found in group' using errcode = '22023';
  end if;
  if v_category.category_type <> 'INCOME' then
    raise exception 'FINANCIAL_CATEGORY_WRONG_TYPE' using errcode = '22023';
  end if;
  if not v_category.is_active then
    raise exception 'FINANCIAL_CATEGORY_INACTIVE' using errcode = 'P0001';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.financial_manual_entries
    where financial_account_id = p_financial_account_id and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      if v_existing.entry_kind <> 'INCOME'
        or v_existing.category_id <> p_category_id
        or v_existing.amount <> p_amount
        or v_existing.effective_at <> p_effective_at
        or coalesce(v_existing.description, '') <> coalesce(p_description, '')
        or coalesce(v_existing.reference, '') <> coalesce(p_reference, '') then
        raise exception 'FINANCIAL_MANUAL_ENTRY_IDEMPOTENCY_KEY_CONFLICT' using errcode = 'P0001';
      end if;

      return jsonb_build_object(
        'entry_id', v_existing.id,
        'entry_kind', v_existing.entry_kind,
        'financial_account_id', v_existing.financial_account_id,
        'category_id', v_existing.category_id,
        'amount', v_existing.amount,
        'already_posted', true,
        'financial_account_balance', public.financial_account_balance(v_existing.financial_account_id)
      );
    end if;
  end if;

  insert into public.financial_manual_entries (
    group_id, financial_account_id, category_id, entry_kind, amount, effective_at,
    description, reference, idempotency_key, created_by
  ) values (
    p_group_id, p_financial_account_id, p_category_id, 'INCOME', p_amount, p_effective_at,
    p_description, p_reference, p_idempotency_key, v_uid
  )
  returning id into v_entry_id;

  v_cashbook_entry_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'INFLOW',
    p_amount => p_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => p_description,
    p_reference => p_reference,
    p_source_type => 'MANUAL_INCOME',
    p_source_id => v_entry_id
  );

  return jsonb_build_object(
    'entry_id', v_entry_id,
    'entry_kind', 'INCOME',
    'financial_account_id', p_financial_account_id,
    'category_id', p_category_id,
    'amount', p_amount,
    'already_posted', false,
    'cashbook_entry_id', v_cashbook_entry_id,
    'financial_account_balance', public.financial_account_balance(p_financial_account_id)
  );
end;
$$;

revoke all on function public.rpc_record_manual_income(uuid, uuid, uuid, numeric, date, text, text, text) from public;
grant execute on function public.rpc_record_manual_income(uuid, uuid, uuid, numeric, date, text, text, text) to authenticated;
revoke execute on function public.rpc_record_manual_income(uuid, uuid, uuid, numeric, date, text, text, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_record_expense — posts a manual group expense (section 5).
-- Financial accounts must not go negative in this phase: insufficient
-- balance is rejected atomically (checked under the same row lock that
-- serializes concurrent spends against this account).
-- ---------------------------------------------------------------------

create or replace function public.rpc_record_expense(
  p_group_id uuid,
  p_financial_account_id uuid,
  p_category_id uuid,
  p_amount numeric,
  p_effective_at date,
  p_description text default null,
  p_reference text default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account record;
  v_category record;
  v_existing record;
  v_entry_id uuid;
  v_cashbook_entry_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_expense.create') then
    raise exception 'Not authorized to record expenses in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCIAL_MANUAL_ENTRY_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select id, group_id, is_active into v_account
  from public.financial_accounts
  where id = p_financial_account_id
  for update;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;
  if not v_account.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  select id, group_id, category_type, is_active into v_category
  from public.financial_categories
  where id = p_category_id;

  if v_category.group_id is null or v_category.group_id <> p_group_id then
    raise exception 'Financial category not found in group' using errcode = '22023';
  end if;
  if v_category.category_type <> 'EXPENSE' then
    raise exception 'FINANCIAL_CATEGORY_WRONG_TYPE' using errcode = '22023';
  end if;
  if not v_category.is_active then
    raise exception 'FINANCIAL_CATEGORY_INACTIVE' using errcode = 'P0001';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.financial_manual_entries
    where financial_account_id = p_financial_account_id and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      if v_existing.entry_kind <> 'EXPENSE'
        or v_existing.category_id <> p_category_id
        or v_existing.amount <> p_amount
        or v_existing.effective_at <> p_effective_at
        or coalesce(v_existing.description, '') <> coalesce(p_description, '')
        or coalesce(v_existing.reference, '') <> coalesce(p_reference, '') then
        raise exception 'FINANCIAL_MANUAL_ENTRY_IDEMPOTENCY_KEY_CONFLICT' using errcode = 'P0001';
      end if;

      return jsonb_build_object(
        'entry_id', v_existing.id,
        'entry_kind', v_existing.entry_kind,
        'financial_account_id', v_existing.financial_account_id,
        'category_id', v_existing.category_id,
        'amount', v_existing.amount,
        'already_posted', true,
        'financial_account_balance', public.financial_account_balance(v_existing.financial_account_id)
      );
    end if;
  end if;

  -- Default policy for Phase 08B: a financial account must never go
  -- negative. Checked under the row lock taken above, so two
  -- concurrent expenses can never both spend the same available
  -- balance (section 29).
  if p_amount > public.financial_account_balance(p_financial_account_id) then
    raise exception 'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  insert into public.financial_manual_entries (
    group_id, financial_account_id, category_id, entry_kind, amount, effective_at,
    description, reference, idempotency_key, created_by
  ) values (
    p_group_id, p_financial_account_id, p_category_id, 'EXPENSE', p_amount, p_effective_at,
    p_description, p_reference, p_idempotency_key, v_uid
  )
  returning id into v_entry_id;

  v_cashbook_entry_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'OUTFLOW',
    p_amount => p_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => p_description,
    p_reference => p_reference,
    p_source_type => 'EXPENSE',
    p_source_id => v_entry_id
  );

  return jsonb_build_object(
    'entry_id', v_entry_id,
    'entry_kind', 'EXPENSE',
    'financial_account_id', p_financial_account_id,
    'category_id', p_category_id,
    'amount', p_amount,
    'already_posted', false,
    'cashbook_entry_id', v_cashbook_entry_id,
    'financial_account_balance', public.financial_account_balance(p_financial_account_id)
  );
end;
$$;

revoke all on function public.rpc_record_expense(uuid, uuid, uuid, numeric, date, text, text, text) from public;
grant execute on function public.rpc_record_expense(uuid, uuid, uuid, numeric, date, text, text, text) to authenticated;
revoke execute on function public.rpc_record_expense(uuid, uuid, uuid, numeric, date, text, text, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_reverse_financial_manual_entry — controlled reversal (section
-- 13). Original row never edited; posts one compensating cashbook
-- entry in the opposite direction, linked via reverses_entry_id.
-- Reversing an INCOME entry that would take the account negative is
-- rejected (never lets a reversal manufacture a negative balance);
-- reversing an EXPENSE entry always succeeds (it can only increase the
-- balance).
-- ---------------------------------------------------------------------

create or replace function public.rpc_reverse_financial_manual_entry(
  p_group_id uuid,
  p_entry_id uuid,
  p_reversal_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_entry record;
  v_original_cashbook_id uuid;
  v_reversal_cashbook_id uuid;
  v_reversal_entry_type public.financial_account_entry_type;
  v_reversal_source_type text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_entry.reverse') then
    raise exception 'Not authorized to reverse financial entries in this group' using errcode = '42501';
  end if;

  if p_reversal_reason is null or btrim(p_reversal_reason) = '' then
    raise exception 'FINANCIAL_ENTRY_REVERSAL_REASON_REQUIRED' using errcode = '22023';
  end if;

  select * into v_entry
  from public.financial_manual_entries
  where id = p_entry_id
  for update;

  if v_entry.group_id is null or v_entry.group_id <> p_group_id then
    raise exception 'Financial entry not found in group' using errcode = '22023';
  end if;

  if v_entry.status <> 'POSTED' then
    raise exception 'FINANCIAL_MANUAL_ENTRY_ALREADY_REVERSED' using errcode = 'P0001';
  end if;

  -- Lock the account row too, matching every other balance-affecting
  -- RPC's lock ordering (account after the owning row).
  perform 1 from public.financial_accounts where id = v_entry.financial_account_id for update;

  select id into v_original_cashbook_id
  from public.financial_account_entries
  where source_type = (case when v_entry.entry_kind = 'INCOME' then 'MANUAL_INCOME' else 'EXPENSE' end)
    and source_id = p_entry_id
    and entry_type = (case when v_entry.entry_kind = 'INCOME' then 'INFLOW' else 'OUTFLOW' end)::public.financial_account_entry_type;

  if v_entry.entry_kind = 'INCOME' then
    v_reversal_entry_type := 'OUTFLOW';
    v_reversal_source_type := 'MANUAL_INCOME_REVERSAL';
    if v_entry.amount > public.financial_account_balance(v_entry.financial_account_id) then
      raise exception 'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE' using errcode = 'P0001';
    end if;
  else
    v_reversal_entry_type := 'INFLOW';
    v_reversal_source_type := 'EXPENSE_REVERSAL';
  end if;

  update public.financial_manual_entries
  set status = 'REVERSED', reversed_at = now(), reversed_by = v_uid, reversal_reason = p_reversal_reason
  where id = p_entry_id;

  v_reversal_cashbook_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => v_entry.financial_account_id,
    p_entry_type => v_reversal_entry_type,
    p_amount => v_entry.amount,
    p_effective_at => current_date,
    p_uid => v_uid,
    p_description => p_reversal_reason,
    p_source_type => v_reversal_source_type,
    p_source_id => p_entry_id,
    p_reverses_entry_id => v_original_cashbook_id
  );

  return jsonb_build_object(
    'entry_id', p_entry_id,
    'entry_kind', v_entry.entry_kind,
    'financial_account_id', v_entry.financial_account_id,
    'reversal_cashbook_entry_id', v_reversal_cashbook_id,
    'financial_account_balance', public.financial_account_balance(v_entry.financial_account_id)
  );
end;
$$;

revoke all on function public.rpc_reverse_financial_manual_entry(uuid, uuid, text) from public;
grant execute on function public.rpc_reverse_financial_manual_entry(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reverse_financial_manual_entry(uuid, uuid, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_financial_manual_entry — single-entry detail (mirrors
-- rpc_get_payment_detail's shape/purpose), including its category name
-- for display.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_financial_manual_entry(
  p_group_id uuid,
  p_entry_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_entry record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_entry.view') then
    raise exception 'Not authorized to view financial entries in this group' using errcode = '42501';
  end if;

  select e.*, a.name as account_name, c.name as category_name
  into v_entry
  from public.financial_manual_entries e
  join public.financial_accounts a on a.id = e.financial_account_id
  join public.financial_categories c on c.id = e.category_id
  where e.id = p_entry_id;

  if v_entry.group_id is null or v_entry.group_id <> p_group_id then
    raise exception 'Financial entry not found in group' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'entry_id', v_entry.id,
    'financial_account_id', v_entry.financial_account_id,
    'financial_account_name', v_entry.account_name,
    'category_id', v_entry.category_id,
    'category_name', v_entry.category_name,
    'entry_kind', v_entry.entry_kind,
    'amount', v_entry.amount,
    'effective_at', v_entry.effective_at,
    'description', v_entry.description,
    'reference', v_entry.reference,
    'status', v_entry.status,
    'reversed_at', v_entry.reversed_at,
    'reversed_by', v_entry.reversed_by,
    'reversal_reason', v_entry.reversal_reason,
    'created_at', v_entry.created_at
  );
end;
$$;

revoke all on function public.rpc_get_financial_manual_entry(uuid, uuid) from public;
grant execute on function public.rpc_get_financial_manual_entry(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_financial_manual_entry(uuid, uuid) from anon;
