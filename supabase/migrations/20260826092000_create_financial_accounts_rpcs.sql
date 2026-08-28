-- Financial Accounts RPCs (Prompt 08A).
--
-- financial_account_balance() and financial_account_post_entry() are
-- internal helpers only — like contribution_charge_net_assessed(),
-- they do no group-scoping/permission check themselves, so they are
-- locked to SECURITY DEFINER callers and never granted to any client
-- role directly.

-- ---------------------------------------------------------------------
-- financial_account_balance — server-authoritative derived balance.
-- Never a stored/mutable column.
-- ---------------------------------------------------------------------

create or replace function public.financial_account_balance(p_account_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(
    case
      when entry_type in ('INFLOW', 'TRANSFER_IN') then amount
      else -amount
    end
  ), 0)
  from public.financial_account_entries
  where financial_account_id = p_account_id;
$$;

comment on function public.financial_account_balance(uuid) is
  'credits (INFLOW + TRANSFER_IN) minus debits (OUTFLOW + TRANSFER_OUT)
  for one account. Derived from the immutable cashbook, never stored.';

revoke all on function public.financial_account_balance(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- financial_account_post_entry — the only INSERT path into the
-- cashbook. Internal helper reused by every RPC below, and the
-- extension point Prompt 07 will call directly (in its own
-- transaction) to post a payment's INFLOW / a reversal's OUTFLOW.
-- ---------------------------------------------------------------------

create or replace function public.financial_account_post_entry(
  p_group_id uuid,
  p_financial_account_id uuid,
  p_entry_type public.financial_account_entry_type,
  p_amount numeric,
  p_effective_at date,
  p_uid uuid,
  p_description text default null,
  p_reference text default null,
  p_transfer_reference uuid default null,
  p_source_type text default null,
  p_source_id uuid default null,
  p_reverses_entry_id uuid default null,
  p_idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCIAL_ACCOUNT_ENTRY_AMOUNT_MUST_BE_POSITIVE' using errcode = 'P0001';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  insert into public.financial_account_entries (
    group_id, financial_account_id, entry_type, amount, effective_at,
    description, reference, transfer_reference, source_type, source_id,
    reverses_entry_id, idempotency_key, created_by
  ) values (
    p_group_id, p_financial_account_id, p_entry_type, p_amount, p_effective_at,
    p_description, p_reference, p_transfer_reference, p_source_type, p_source_id,
    p_reverses_entry_id, p_idempotency_key, p_uid
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.financial_account_post_entry(
  uuid, uuid, public.financial_account_entry_type, numeric, date, uuid,
  text, text, uuid, text, uuid, uuid, text
) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_create_financial_account — optionally records an opening balance
-- as the account's first INFLOW entry, in the same transaction. Blank/
-- zero opening balance simply means no opening entry (matches 06C's
-- opening-balance convention); only a negative amount is an error.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_financial_account(
  p_group_id uuid,
  p_name text,
  p_account_type public.financial_account_type,
  p_opening_balance numeric default null,
  p_opening_balance_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.manage') then
    raise exception 'Not authorized to manage financial accounts in this group' using errcode = '42501';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Financial account name is required' using errcode = '22023';
  end if;

  insert into public.financial_accounts (group_id, name, account_type, created_by)
  values (p_group_id, btrim(p_name), p_account_type, v_uid)
  returning id into v_id;

  if p_opening_balance is not null and p_opening_balance <> 0 then
    if p_opening_balance < 0 then
      raise exception 'FINANCIAL_ACCOUNT_OPENING_BALANCE_MUST_BE_POSITIVE' using errcode = 'P0001';
    end if;

    if p_opening_balance_date is null then
      raise exception 'Effective date is required' using errcode = '22023';
    end if;

    perform public.financial_account_post_entry(
      p_group_id => p_group_id,
      p_financial_account_id => v_id,
      p_entry_type => 'INFLOW',
      p_amount => p_opening_balance,
      p_effective_at => p_opening_balance_date,
      p_uid => v_uid,
      p_source_type => 'OPENING_BALANCE'
    );
  end if;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'account_type', account_type,
    'is_active', is_active, 'balance', public.financial_account_balance(id),
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.financial_accounts
  where id = v_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_financial_account(uuid, text, public.financial_account_type, numeric, date) from public;
grant execute on function public.rpc_create_financial_account(uuid, text, public.financial_account_type, numeric, date) to authenticated;
revoke execute on function public.rpc_create_financial_account(uuid, text, public.financial_account_type, numeric, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_update_financial_account — rename and/or activate/deactivate
-- only. Never touches anything balance-affecting.
-- ---------------------------------------------------------------------

create or replace function public.rpc_update_financial_account(
  p_group_id uuid,
  p_account_id uuid,
  p_name text default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.manage') then
    raise exception 'Not authorized to manage financial accounts in this group' using errcode = '42501';
  end if;

  select * into v_account from public.financial_accounts where id = p_account_id for update;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  if p_name is not null and btrim(p_name) = '' then
    raise exception 'Financial account name is required' using errcode = '22023';
  end if;

  update public.financial_accounts
  set
    name = coalesce(btrim(p_name), name),
    is_active = coalesce(p_is_active, is_active)
  where id = p_account_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'account_type', account_type,
    'is_active', is_active, 'balance', public.financial_account_balance(id),
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.financial_accounts
  where id = p_account_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_update_financial_account(uuid, uuid, text, boolean) from public;
grant execute on function public.rpc_update_financial_account(uuid, uuid, text, boolean) to authenticated;
revoke execute on function public.rpc_update_financial_account(uuid, uuid, text, boolean) from anon;

-- ---------------------------------------------------------------------
-- rpc_record_financial_account_transfer — atomic paired TRANSFER_OUT/
-- TRANSFER_IN between two of the group's own accounts. Never an
-- external payment RPC path — money never leaves the group.
-- ---------------------------------------------------------------------

create or replace function public.rpc_record_financial_account_transfer(
  p_group_id uuid,
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount numeric,
  p_effective_at date default current_date,
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
  v_from record;
  v_to record;
  v_existing_id uuid;
  v_transfer_reference uuid;
  v_out_id uuid;
  v_in_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.transfer.create') then
    raise exception 'Not authorized to transfer between financial accounts in this group' using errcode = '42501';
  end if;

  if p_from_account_id = p_to_account_id then
    raise exception 'FINANCIAL_ACCOUNT_TRANSFER_SAME_ACCOUNT' using errcode = 'P0001';
  end if;

  select * into v_from from public.financial_accounts where id = p_from_account_id for update;
  if v_from.group_id is null or v_from.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;
  if not v_from.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  select * into v_to from public.financial_accounts where id = p_to_account_id for update;
  if v_to.group_id is null or v_to.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;
  if not v_to.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCIAL_ACCOUNT_TRANSFER_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  -- Idempotent retry: an identical (from_account, key) request returns
  -- the original transfer_reference instead of posting again.
  if p_idempotency_key is not null then
    select id, transfer_reference into v_existing_id, v_transfer_reference
    from public.financial_account_entries
    where financial_account_id = p_from_account_id
      and idempotency_key = p_idempotency_key;

    if v_existing_id is not null then
      return jsonb_build_object(
        'transfer_reference', v_transfer_reference,
        'from_account_id', p_from_account_id,
        'to_account_id', p_to_account_id,
        'amount', p_amount,
        'already_posted', true,
        'from_balance', public.financial_account_balance(p_from_account_id),
        'to_balance', public.financial_account_balance(p_to_account_id)
      );
    end if;
  end if;

  if p_amount > public.financial_account_balance(p_from_account_id) then
    raise exception 'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  v_transfer_reference := gen_random_uuid();

  v_out_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_from_account_id,
    p_entry_type => 'TRANSFER_OUT',
    p_amount => p_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => p_description,
    p_reference => p_reference,
    p_transfer_reference => v_transfer_reference,
    p_source_type => 'TRANSFER',
    p_idempotency_key => p_idempotency_key
  );

  v_in_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_to_account_id,
    p_entry_type => 'TRANSFER_IN',
    p_amount => p_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => p_description,
    p_reference => p_reference,
    p_transfer_reference => v_transfer_reference,
    p_source_type => 'TRANSFER',
    p_idempotency_key => p_idempotency_key
  );

  return jsonb_build_object(
    'transfer_reference', v_transfer_reference,
    'from_account_id', p_from_account_id,
    'to_account_id', p_to_account_id,
    'amount', p_amount,
    'already_posted', false,
    'from_balance', public.financial_account_balance(p_from_account_id),
    'to_balance', public.financial_account_balance(p_to_account_id)
  );
end;
$$;

revoke all on function public.rpc_record_financial_account_transfer(uuid, uuid, uuid, numeric, date, text, text, text) from public;
grant execute on function public.rpc_record_financial_account_transfer(uuid, uuid, uuid, numeric, date, text, text, text) to authenticated;
revoke execute on function public.rpc_record_financial_account_transfer(uuid, uuid, uuid, numeric, date, text, text, text) from anon;

-- ---------------------------------------------------------------------
-- Read RPCs
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_financial_account(
  p_group_id uuid,
  p_account_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.view') then
    raise exception 'Not authorized to view financial accounts in this group' using errcode = '42501';
  end if;

  select * into v_account from public.financial_accounts where id = p_account_id;
  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'id', v_account.id,
    'group_id', v_account.group_id,
    'name', v_account.name,
    'account_type', v_account.account_type,
    'is_active', v_account.is_active,
    'balance', public.financial_account_balance(p_account_id),
    'created_at', v_account.created_at,
    'updated_at', v_account.updated_at
  );
end;
$$;

revoke all on function public.rpc_get_financial_account(uuid, uuid) from public;
grant execute on function public.rpc_get_financial_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_financial_account(uuid, uuid) from anon;

create or replace function public.rpc_list_financial_accounts(
  p_group_id uuid,
  p_is_active boolean default null,
  p_search text default null,
  p_limit integer default 10,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.view') then
    raise exception 'Not authorized to view financial accounts in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.financial_accounts a
  where a.group_id = p_group_id
    and (p_is_active is null or a.is_active = p_is_active)
    and (p_search is null or btrim(p_search) = '' or a.name ilike '%' || btrim(p_search) || '%');

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.name), '[]'::jsonb)
  into v_items
  from (
    select
      a.id, a.group_id, a.name, a.account_type, a.is_active,
      public.financial_account_balance(a.id) as balance,
      a.created_at, a.updated_at
    from public.financial_accounts a
    where a.group_id = p_group_id
      and (p_is_active is null or a.is_active = p_is_active)
      and (p_search is null or btrim(p_search) = '' or a.name ilike '%' || btrim(p_search) || '%')
    order by a.name
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_financial_accounts(uuid, boolean, text, integer, integer) from public;
grant execute on function public.rpc_list_financial_accounts(uuid, boolean, text, integer, integer) to authenticated;
revoke execute on function public.rpc_list_financial_accounts(uuid, boolean, text, integer, integer) from anon;

create or replace function public.rpc_list_financial_account_entries(
  p_group_id uuid,
  p_account_id uuid,
  p_limit integer default 10,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_account_group_id uuid;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.view') then
    raise exception 'Not authorized to view financial accounts in this group' using errcode = '42501';
  end if;

  select group_id into v_account_group_id from public.financial_accounts where id = p_account_id;
  if v_account_group_id is null or v_account_group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  select count(*) into v_total
  from public.financial_account_entries
  where financial_account_id = p_account_id;

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.effective_at desc, rows.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select
      id as entry_id, entry_type, amount, effective_at, description,
      reference, transfer_reference, source_type, source_id,
      reverses_entry_id, created_at, created_by
    from public.financial_account_entries
    where financial_account_id = p_account_id
    order by effective_at desc, created_at desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) from public;
grant execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) to authenticated;
revoke execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) from anon;
