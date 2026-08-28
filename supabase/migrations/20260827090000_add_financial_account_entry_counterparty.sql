-- Prompt 08A-UAT-FIX-03: transfer ledger counterparty context.
--
-- Physical UAT: an account's ledger showed only "Transfer Out"/
-- "Transfer In" with no indication of which OTHER account the money
-- moved to/from. TRANSFER_OUT and TRANSFER_IN rows are always posted
-- as a pair sharing one `transfer_reference` on two different
-- `financial_account_id`s (see rpc_record_financial_account_transfer)
-- — this migration extends the existing read RPC to resolve that
-- paired row and return the counterparty account's id/name, rather
-- than persisting a duplicated account-name string onto the
-- immutable entry itself.
--
-- No new column, no new table: this is a read-model-only change
-- (CREATE OR REPLACE on the same function signature). Non-transfer
-- entries (INFLOW/OUTFLOW, including opening balances) always return
-- null counterparty fields — never a fabricated one.

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
      e.id as entry_id, e.entry_type, e.amount, e.effective_at, e.description,
      e.reference, e.transfer_reference, e.source_type, e.source_id,
      e.reverses_entry_id, e.created_at, e.created_by,
      counterparty.id as counterparty_account_id,
      counterparty.name as counterparty_account_name
    from public.financial_account_entries e
    left join public.financial_account_entries pair
      on pair.transfer_reference = e.transfer_reference
      and pair.financial_account_id <> e.financial_account_id
      and e.transfer_reference is not null
    left join public.financial_accounts counterparty
      on counterparty.id = pair.financial_account_id
    where e.financial_account_id = p_account_id
    order by e.effective_at desc, e.created_at desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

comment on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) is
  'Paginated ledger for one account. For TRANSFER_OUT/TRANSFER_IN rows,
  counterparty_account_id/counterparty_account_name resolve the OTHER
  account in the pair (same transfer_reference, different
  financial_account_id) — never fabricated client-side. Both are null
  for every non-transfer entry (INFLOW/OUTFLOW, including opening
  balances).';

revoke all on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) from public;
grant execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) to authenticated;
revoke execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer) from anon;
