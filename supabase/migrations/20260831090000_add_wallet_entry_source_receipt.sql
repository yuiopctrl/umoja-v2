-- Prompt 07 UAT-FIX-02, section 10: wallet ledger rows must show
-- meaningful wording (never a raw entry_type enum) and, where a source
-- payment exists, its receipt number — without Flutter fabricating
-- that linkage itself. Extends `rpc_list_member_wallet_entries` (same
-- signature) with `source_receipt_number`, populated only for a
-- PAYMENT_CREDIT entry whose `source_type = 'PAYMENT'`. Wallet ledger
-- semantics, balance derivation, and every other field are unchanged.

create or replace function public.rpc_list_member_wallet_entries(
  p_group_id uuid,
  p_membership_id uuid,
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
  v_membership record;
  v_limit integer;
  v_offset integer;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'wallet.view') then
    raise exception 'Not authorized to view member wallets in this group' using errcode = '42501';
  end if;

  select id, group_id into v_membership from public.group_memberships where id = p_membership_id;
  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select count(*) into v_total
  from public.member_wallet_entries
  where membership_id = p_membership_id;

  with page as (
    select *
    from public.member_wallet_entries
    where membership_id = p_membership_id
    order by created_at desc
    limit v_limit
    offset v_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'entry_id', page.id,
    'entry_type', page.entry_type,
    'amount', page.amount,
    'effective_at', page.effective_at,
    'source_type', page.source_type,
    'source_id', page.source_id,
    'source_receipt_number', pay.receipt_number,
    'created_at', page.created_at
  ) order by page.created_at desc), '[]'::jsonb)
  into v_items
  from page
  left join public.payments pay
    on page.source_type = 'PAYMENT' and pay.id = page.source_id;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_list_member_wallet_entries(uuid, uuid, integer, integer) from public;
grant execute on function public.rpc_list_member_wallet_entries(uuid, uuid, integer, integer) to authenticated;
revoke execute on function public.rpc_list_member_wallet_entries(uuid, uuid, integer, integer) from anon;

comment on function public.rpc_list_member_wallet_entries(uuid, uuid, integer, integer) is
  'Prompt 07, extended by UAT-FIX-02: paginated wallet ledger for one
  membership, bundling the current wallet_balance. `source_receipt_number`
  is populated only for a PAYMENT_CREDIT entry sourced from a payment
  (source_type = ''PAYMENT''), letting the UI show the originating
  receipt without reconstructing that linkage client-side. Null for
  ALLOCATION_DEBIT/REVERSAL entries and for any entry whose source
  payment no longer resolves.';
