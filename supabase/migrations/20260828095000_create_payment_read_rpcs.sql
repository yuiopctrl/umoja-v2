-- Prompt 07: read RPCs — paginated payment history, payment detail,
-- receipt, member wallet + ledger, and member contribution statement.
-- Also extends two locked 06C read RPCs (CREATE OR REPLACE on their
-- exact existing signatures, never editing their original migration)
-- to expose payment-aware outstanding — a contribution-domain figure,
-- safe to reach via the existing contribution.self_view path. Wallet
-- balance is exposed only via rpc_get_member_wallet (wallet.view) —
-- deliberately never folded into a self-view-reachable RPC, since
-- MEMBER does not hold wallet.view in this phase (see 20260828090000,
-- section 37 deferral).

-- ---------------------------------------------------------------------
-- rpc_list_member_payments — paginated, filterable group-wide payment
-- history. Gated by payment.view only (MEMBER has no self-view here
-- in this phase — see the deferral note above).
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_member_payments(
  p_group_id uuid,
  p_membership_id uuid default null,
  p_status public.payment_status default null,
  p_financial_account_id uuid default null,
  p_search text default null,
  p_date_from date default null,
  p_date_to date default null,
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
  v_limit integer;
  v_offset integer;
  v_search text;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.view') then
    raise exception 'Not authorized to view payments in this group' using errcode = '42501';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset := greatest(0, coalesce(p_offset, 0));
  v_search := nullif(btrim(coalesce(p_search, '')), '');

  if v_search is not null and char_length(v_search) > 100 then
    raise exception 'Search term too long' using errcode = '22023';
  end if;

  select count(*)
  into v_total
  from public.payments p
  join public.group_memberships gm on gm.id = p.membership_id
  where p.group_id = p_group_id
    and (p_membership_id is null or p.membership_id = p_membership_id)
    and (p_status is null or p.status = p_status)
    and (p_financial_account_id is null or p.financial_account_id = p_financial_account_id)
    and (p_date_from is null or p.effective_at >= p_date_from)
    and (p_date_to is null or p.effective_at <= p_date_to)
    and (
      v_search is null
      or gm.display_name ilike '%' || v_search || '%'
      or gm.member_number ilike '%' || v_search || '%'
      or p.receipt_number ilike '%' || v_search || '%'
      or p.external_reference ilike '%' || v_search || '%'
    );

  with page as (
    select p.*, gm.display_name as member_display_name, gm.member_number, fa.name as financial_account_name
    from public.payments p
    join public.group_memberships gm on gm.id = p.membership_id
    join public.financial_accounts fa on fa.id = p.financial_account_id
    where p.group_id = p_group_id
      and (p_membership_id is null or p.membership_id = p_membership_id)
      and (p_status is null or p.status = p_status)
      and (p_financial_account_id is null or p.financial_account_id = p_financial_account_id)
      and (p_date_from is null or p.effective_at >= p_date_from)
      and (p_date_to is null or p.effective_at <= p_date_to)
      and (
        v_search is null
        or gm.display_name ilike '%' || v_search || '%'
        or gm.member_number ilike '%' || v_search || '%'
        or p.receipt_number ilike '%' || v_search || '%'
        or p.external_reference ilike '%' || v_search || '%'
      )
    order by p.effective_at desc, p.created_at desc
    limit v_limit
    offset v_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'payment_id', page.id,
    'membership_id', page.membership_id,
    'member_display_name', page.member_display_name,
    'member_number', page.member_number,
    'financial_account_id', page.financial_account_id,
    'financial_account_name', page.financial_account_name,
    'amount', page.amount,
    'effective_at', page.effective_at,
    'payment_method', page.payment_method,
    'receipt_number', page.receipt_number,
    'status', page.status,
    'created_at', page.created_at
  ) order by page.effective_at desc, page.created_at desc), '[]'::jsonb)
  into v_items
  from page;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$$;

revoke all on function public.rpc_list_member_payments(
  uuid, uuid, public.payment_status, uuid, text, date, date, integer, integer
) from public;
grant execute on function public.rpc_list_member_payments(
  uuid, uuid, public.payment_status, uuid, text, date, date, integer, integer
) to authenticated;
revoke execute on function public.rpc_list_member_payments(
  uuid, uuid, public.payment_status, uuid, text, date, date, integer, integer
) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_payment_detail — full detail: metadata, member, financial
-- account, allocations, wallet credit, cashbook linkage, reversal
-- status. Flutter must never reconstruct these totals itself.
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
    'amount', pa.amount
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
-- rpc_get_receipt — the always-exactly-one-per-payment receipt
-- projection. Gated by payment.receipt.view specifically (distinct
-- from payment.view, even though every role holding one currently
-- holds the other). Remains valid after later debt changes — it
-- reflects what was true and posted at payment time (the payment
-- record and its own allocations never change).
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
    'amount', pa.amount
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
-- rpc_get_member_wallet / rpc_list_member_wallet_entries — gated by
-- wallet.view. MEMBER never receives this permission in this phase.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_member_wallet(
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

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_get_member_wallet(uuid, uuid) from public;
grant execute on function public.rpc_get_member_wallet(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_wallet(uuid, uuid) from anon;

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
    'created_at', page.created_at
  ) order by page.created_at desc), '[]'::jsonb)
  into v_items
  from page;

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

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_statement — full statement across
-- obligations/adjustments/waivers/penalties/allocations/outstanding/
-- wallet. Gated by contribution.view AND payment.view AND wallet.view
-- together (full-view only, no self-view path in this phase) — this
-- keeps the deferral in section 37 clean: a statement that surfaces
-- wallet balance and payment history must not be reachable by MEMBER
-- until self-service portal access is deliberately designed.
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

  select id, group_id into v_membership from public.group_memberships where id = p_membership_id;
  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'charge_id', c.id,
    'period_id', c.period_id,
    'due_date', c.due_date,
    'components', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'component_type', s.component_type,
        'gross_after_corrections', s.gross_after_corrections,
        'allocated', s.allocated,
        'outstanding', s.outstanding
      ) order by s.priority, s.component_created_at), '[]'::jsonb)
      from public.contribution_charge_component_states(c.id) s
    )
  ) order by c.due_date), '[]'::jsonb),
  coalesce(sum((
    select coalesce(sum(s.outstanding), 0) from public.contribution_charge_component_states(c.id) s
  )), 0)
  into v_charges, v_total_outstanding
  from public.member_contribution_charges c
  where c.group_id = p_group_id and c.membership_id = p_membership_id;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'charges', v_charges,
    'total_outstanding', v_total_outstanding,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_get_member_contribution_statement(uuid, uuid) from public;
grant execute on function public.rpc_get_member_contribution_statement(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_contribution_statement(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_summary — extended (06C's version
-- documented "no paid/outstanding concept — payments don't exist
-- yet"; they do now). Same signature, same self-view gating as
-- 06C — total_allocated/total_outstanding are contribution-domain
-- figures, safe for a member to see about themselves. Wallet balance
-- is deliberately NOT added here — see rpc_get_member_wallet.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_member_contribution_summary(
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
  v_full_view boolean;
  v_base numeric;
  v_penalty numeric;
  v_adjustment numeric;
  v_waiver numeric;
  v_opening_balance numeric;
  v_total_allocated numeric;
  v_total_outstanding numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select id, group_id, user_id into v_membership
  from public.group_memberships
  where id = p_membership_id;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  v_full_view := public.has_group_permission(p_group_id, 'contribution.view');
  if not v_full_view then
    if not (
      public.has_group_permission(p_group_id, 'contribution.self_view')
      and v_membership.user_id = v_uid
    ) then
      raise exception 'Not authorized to view this member''s contribution summary' using errcode = '42501';
    end if;
  end if;

  select
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'BASE'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'PENALTY'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'ADJUSTMENT'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'WAIVER'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'OPENING_BALANCE'), 0)
  into v_base, v_penalty, v_adjustment, v_waiver, v_opening_balance
  from public.member_contribution_charges c
  join public.contribution_charge_components cc on cc.charge_id = c.id
  where c.membership_id = p_membership_id and c.group_id = p_group_id;

  select
    coalesce(sum(s.allocated), 0),
    coalesce(sum(s.outstanding), 0)
  into v_total_allocated, v_total_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.membership_id = p_membership_id and c.group_id = p_group_id;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'base_assessed', v_base,
    'penalties_assessed', v_penalty,
    'adjustments_assessed', v_adjustment,
    'waivers_assessed', v_waiver,
    'opening_balances_assessed', v_opening_balance,
    'net_assessed', v_base + v_penalty + v_adjustment + v_waiver + v_opening_balance,
    'total_allocated', v_total_allocated,
    'total_outstanding', v_total_outstanding
  );
end;
$$;

revoke all on function public.rpc_get_member_contribution_summary(uuid, uuid) from public;
grant execute on function public.rpc_get_member_contribution_summary(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_contribution_summary(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_contribution_charge_detail — extended with per-component
-- outstanding + a charge-level total_outstanding. Same signature/
-- gating as 06C.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_contribution_charge_detail(
  p_group_id uuid,
  p_charge_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_charge record;
  v_full_view boolean;
  v_components jsonb;
  v_total_outstanding numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select c.*, gm.user_id as membership_user_id into v_charge
  from public.member_contribution_charges c
  join public.group_memberships gm on gm.id = c.membership_id
  where c.id = p_charge_id;

  if v_charge.group_id is null or v_charge.group_id <> p_group_id then
    raise exception 'Contribution charge not found in group' using errcode = '22023';
  end if;

  v_full_view := public.has_group_permission(p_group_id, 'contribution.view');
  if not v_full_view then
    if not (
      public.has_group_permission(p_group_id, 'contribution.self_view')
      and v_charge.membership_user_id = v_uid
    ) then
      raise exception 'Not authorized to view this contribution charge' using errcode = '42501';
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'component_id', cc.id,
    'component_type', cc.component_type,
    'amount', cc.assessed_amount,
    'reason', cc.reason,
    'effective_at', cc.effective_at,
    'sequence', cc.sequence,
    'created_at', cc.created_at,
    'created_by', cc.created_by,
    'outstanding', s.outstanding
  ) order by cc.effective_at, cc.created_at), '[]'::jsonb)
  into v_components
  from public.contribution_charge_components cc
  left join public.contribution_charge_component_states(p_charge_id) s on s.component_id = cc.id
  where cc.charge_id = p_charge_id;

  select coalesce(sum(outstanding), 0) into v_total_outstanding
  from public.contribution_charge_component_states(p_charge_id);

  return jsonb_build_object(
    'charge_id', v_charge.id,
    'group_id', v_charge.group_id,
    'period_id', v_charge.period_id,
    'membership_id', v_charge.membership_id,
    'member_number_snapshot', v_charge.member_number_snapshot,
    'member_name_snapshot', v_charge.member_name_snapshot,
    'effective_at', v_charge.effective_at,
    'due_date', v_charge.due_date,
    'components', v_components,
    'net_assessed', public.contribution_charge_net_assessed(p_charge_id),
    'total_outstanding', v_total_outstanding
  );
end;
$$;

revoke all on function public.rpc_get_contribution_charge_detail(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_charge_detail(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_charge_detail(uuid, uuid) from anon;
