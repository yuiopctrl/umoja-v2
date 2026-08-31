-- Prompt 08B: reconciliation RPCs.

-- ---------------------------------------------------------------------
-- rpc_create_financial_reconciliation — computes system_balance
-- authoritatively (financial_account_balance()) at call time and
-- records it alongside the user-entered stated_balance. Idempotent on
-- (financial_account_id, reconciliation_at) is deliberately NOT
-- enforced — a treasurer may legitimately reconcile the same account
-- more than once on the same date (e.g. a second cash count), and each
-- is its own immutable record; this is a read/audit artifact, not a
-- balance-affecting mutation, so double-submission carries no
-- financial risk the way a payment/expense would.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_financial_reconciliation(
  p_group_id uuid,
  p_financial_account_id uuid,
  p_stated_balance numeric,
  p_reconciliation_at date default current_date,
  p_period_start date default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account record;
  v_system_balance numeric;
  v_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_reconciliation.create') then
    raise exception 'Not authorized to create reconciliations in this group' using errcode = '42501';
  end if;

  if p_stated_balance is null then
    raise exception 'Statement/count balance is required' using errcode = '22023';
  end if;

  if p_reconciliation_at is null then
    raise exception 'Reconciliation date is required' using errcode = '22023';
  end if;

  select id, group_id into v_account
  from public.financial_accounts
  where id = p_financial_account_id;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  v_system_balance := public.financial_account_balance(p_financial_account_id);

  insert into public.financial_reconciliations (
    group_id, financial_account_id, period_start, reconciliation_at,
    system_balance, stated_balance, difference, notes, reconciled_by
  ) values (
    p_group_id, p_financial_account_id, p_period_start, p_reconciliation_at,
    v_system_balance, p_stated_balance, p_stated_balance - v_system_balance, p_notes, v_uid
  )
  returning id into v_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'financial_account_id', financial_account_id,
    'period_start', period_start, 'reconciliation_at', reconciliation_at,
    'system_balance', system_balance, 'stated_balance', stated_balance,
    'difference', difference, 'status', status, 'notes', notes,
    'reconciled_by', reconciled_by, 'reconciled_at', reconciled_at,
    'created_at', created_at
  )
  into v_result
  from public.financial_reconciliations
  where id = v_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_financial_reconciliation(uuid, uuid, numeric, date, date, text) from public;
grant execute on function public.rpc_create_financial_reconciliation(uuid, uuid, numeric, date, date, text) to authenticated;
revoke execute on function public.rpc_create_financial_reconciliation(uuid, uuid, numeric, date, date, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_cancel_financial_reconciliation — the only allowed mutation
-- against a reconciliation row: RECONCILED -> CANCELLED, once. Every
-- other field (system_balance/stated_balance/difference/reconciled_at)
-- is untouched, preserving the original evidence.
-- ---------------------------------------------------------------------

create or replace function public.rpc_cancel_financial_reconciliation(
  p_group_id uuid,
  p_reconciliation_id uuid,
  p_cancellation_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_reconciliation record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_reconciliation.create') then
    raise exception 'Not authorized to cancel reconciliations in this group' using errcode = '42501';
  end if;

  if p_cancellation_reason is null or btrim(p_cancellation_reason) = '' then
    raise exception 'FINANCIAL_RECONCILIATION_CANCELLATION_REASON_REQUIRED' using errcode = '22023';
  end if;

  select * into v_reconciliation
  from public.financial_reconciliations
  where id = p_reconciliation_id
  for update;

  if v_reconciliation.group_id is null or v_reconciliation.group_id <> p_group_id then
    raise exception 'Financial reconciliation not found in group' using errcode = '22023';
  end if;

  if v_reconciliation.status <> 'RECONCILED' then
    raise exception 'FINANCIAL_RECONCILIATION_ALREADY_CANCELLED' using errcode = 'P0001';
  end if;

  update public.financial_reconciliations
  set status = 'CANCELLED', cancelled_at = now(), cancelled_by = v_uid, cancellation_reason = p_cancellation_reason
  where id = p_reconciliation_id;

  return jsonb_build_object('id', p_reconciliation_id, 'status', 'CANCELLED');
end;
$$;

revoke all on function public.rpc_cancel_financial_reconciliation(uuid, uuid, text) from public;
grant execute on function public.rpc_cancel_financial_reconciliation(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_cancel_financial_reconciliation(uuid, uuid, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_financial_account_reconciliations — history per account,
-- newest first (section 19: "Show reconciliation history per
-- account").
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_financial_account_reconciliations(
  p_group_id uuid,
  p_financial_account_id uuid,
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

  if not public.has_group_permission(p_group_id, 'financial_reconciliation.view') then
    raise exception 'Not authorized to view reconciliations in this group' using errcode = '42501';
  end if;

  select group_id into v_account_group_id from public.financial_accounts where id = p_financial_account_id;
  if v_account_group_id is null or v_account_group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  select count(*) into v_total
  from public.financial_reconciliations
  where financial_account_id = p_financial_account_id;

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.reconciliation_at desc, rows.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select
      id, financial_account_id, period_start, reconciliation_at,
      system_balance, stated_balance, difference, status, notes,
      reconciled_by, reconciled_at, cancelled_at, cancelled_by, cancellation_reason,
      created_at
    from public.financial_reconciliations
    where financial_account_id = p_financial_account_id
    order by reconciliation_at desc, created_at desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_financial_account_reconciliations(uuid, uuid, integer, integer) from public;
grant execute on function public.rpc_list_financial_account_reconciliations(uuid, uuid, integer, integer) to authenticated;
revoke execute on function public.rpc_list_financial_account_reconciliations(uuid, uuid, integer, integer) from anon;
