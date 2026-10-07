-- Prompt 09G-B6-B: member-safe payments & receipts backend (append-only).
--
-- Member self-service "My Payments & Receipts": the caller's OWN external
-- payment records, their allocation breakdown, any wallet credit the
-- payment itself created, and the same-row reversal state — gated on the
-- new independent `payment.self_view` permission.
--
-- Locked decisions (09G-B6-B):
--   * My Payments = EXTERNAL payment rows only (payments.payment_id is not
--     null for every allocation it returns). A wallet-funded allocation
--     (payment_id IS NULL, wallet_entry_id set) is never a payment and is
--     never fabricated into one.
--   * One payment is one cash event; allocations are breakdown only.
--   * A payment-created wallet credit (member_wallet_entries.entry_type =
--     'PAYMENT_CREDIT', source_type = 'PAYMENT', source_id = payment id) is
--     part of that SAME payment's detail/receipt, never a second payment.
--   * Reversal stays on the same payments row (status/reversed_at/
--     reversal_reason). No synthetic negative/second payment, no second
--     receipt. `reversed_by` is never returned to the member.
--   * payments.amount is the canonical amount; payments.effective_at is the
--     canonical economic date. Neither is ever derived from
--     sum(payment_allocations) or created_at.
--   * Receipt reads are side-effect free: the existing receipt_number is
--     read, never regenerated. There is no separate receipts table and
--     none is created here.
--
-- B3 (rpc_get_my_member_statement) and the existing officer payment/
-- receipt RPCs are not touched. financial_account_name and payments.notes
-- are never returned to the member.

-- ---------------------------------------------------------------------------
-- 1. Permission. Independent self-service capability, seeded directly to
--    MEMBER and ADMIN only — never TREASURER/SECRETARY/CHAIRPERSON directly
--    (they reach it, if at all, only through the additive MEMBER baseline
--    the 09G-B5-B.1 trigger/backfill already guarantees; no second
--    baseline mechanism is added here).
-- ---------------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('payment.self_view', 'View own payments', 'View the caller''s own payments and receipts in their current group membership.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'payment.self_view'
where r.code in ('MEMBER', 'ADMIN')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Internal helpers (not client-executable).
-- ---------------------------------------------------------------------------

-- Resolves the caller's OWN membership for the group, after the auth,
-- operational-membership and payment.self_view checks. Shared by all three
-- RPCs, mirroring member_loan_membership_id() (09G-B5-B).
create or replace function public.member_payment_membership_id(p_group_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_group_id is null then
    raise exception 'p_group_id is required' using errcode = '22023';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  if not public.has_group_permission(p_group_id, 'payment.self_view') then
    raise exception 'Not authorized to view your payments in this group' using errcode = '42501';
  end if;

  return v_membership_id;
end;
$function$;

-- The full member-safe record for one payment: the payment's own fields,
-- the allocated total, the allocation breakdown, and any wallet credit
-- that payment created. Called once by both rpc_get_my_payment_detail and
-- rpc_get_my_receipt so the two can never diverge on the same payment.
-- Internal only; callers must already have verified ownership.
create or replace function public.member_payment_record(p_payment_id uuid)
returns table (
  payment_id uuid,
  effective_at date,
  amount numeric,
  payment_method text,
  external_reference text,
  receipt_number text,
  status text,
  reversed_at timestamptz,
  reversal_reason text,
  member_display_name text,
  member_number text,
  group_name text,
  allocated_amount numeric,
  wallet_credit jsonb,
  allocations jsonb
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    p.id,
    p.effective_at,
    p.amount,
    p.payment_method::text,
    p.external_reference,
    p.receipt_number,
    p.status::text,
    p.reversed_at,
    p.reversal_reason,
    gm.display_name,
    gm.member_number,
    g.name,
    coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.payment_id = p.id), 0),
    (
      select jsonb_build_object(
        'amount', we.amount,
        'is_reversed', exists (
          select 1 from public.member_wallet_entries r
          where r.reverses_entry_id = we.id and r.entry_type = 'REVERSAL'
        ),
        'reversed_at', (
          select r.effective_at from public.member_wallet_entries r
          where r.reverses_entry_id = we.id and r.entry_type = 'REVERSAL'
          order by r.created_at, r.id
          limit 1
        )
      )
      from public.member_wallet_entries we
      where we.source_type = 'PAYMENT' and we.source_id = p.id and we.entry_type = 'PAYMENT_CREDIT'
      limit 1
    ),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'allocation_id', a.id,
        'target_type', a.allocation_target_type,
        'amount', a.amount,
        'contribution_type_name', a.contribution_type_name_snapshot,
        'period_label', a.period_label_snapshot,
        'period_purpose', a.period_purpose_snapshot,
        'component_type', coalesce(cc.component_type::text, a.allocation_target_type::text),
        'loan_number', la.loan_number,
        'loan_product_name', lp.name,
        'installment_number', li.installment_number
      ) order by a.line_number, a.id)
      from public.payment_allocations a
      left join public.contribution_charge_components cc on cc.id = a.charge_component_id
      left join public.loan_installments li on li.id = a.loan_installment_id
      left join public.loan_accounts la on la.id = a.loan_account_id
      left join public.loan_products lp on lp.id = la.loan_product_id
      where a.payment_id = p.id
    ), '[]'::jsonb)
  from public.payments p
  join public.group_memberships gm on gm.id = p.membership_id
  join public.groups g on g.id = p.group_id
  where p.id = p_payment_id;
$function$;

-- ---------------------------------------------------------------------------
-- 3. RPC: my payments (list). EXTERNAL payment rows only — a wallet-funded
--    allocation has no payments row at all, so it can never appear here.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_payments(
  p_group_id uuid,
  p_status public.payment_status default null,
  p_from_date date default null,
  p_to_date date default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_limit integer;
  v_offset integer;
  v_total bigint;
  v_items jsonb;
begin
  v_membership_id := public.member_payment_membership_id(p_group_id);

  if p_from_date is not null and p_to_date is not null and p_from_date > p_to_date then
    raise exception 'p_from_date must not be after p_to_date' using errcode = '22023';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  select count(*)
  into v_total
  from public.payments p
  where p.group_id = p_group_id
    and p.membership_id = v_membership_id
    and (p_status is null or p.status = p_status)
    and (p_from_date is null or p.effective_at >= p_from_date)
    and (p_to_date is null or p.effective_at <= p_to_date);

  select coalesce(jsonb_agg(jsonb_build_object(
    'payment_id', page.id,
    'effective_at', page.effective_at,
    'amount', page.amount,
    'payment_method', page.payment_method,
    'external_reference', page.external_reference,
    'receipt_number', page.receipt_number,
    'status', page.status,
    'allocation_count', page.allocation_count
  ) order by page.effective_at desc, page.created_at desc, page.id desc), '[]'::jsonb)
  into v_items
  from (
    select
      p.id, p.effective_at, p.amount, p.payment_method, p.external_reference,
      p.receipt_number, p.status, p.created_at,
      (select count(*) from public.payment_allocations pa where pa.payment_id = p.id) as allocation_count
    from public.payments p
    where p.group_id = p_group_id
      and p.membership_id = v_membership_id
      and (p_status is null or p.status = p_status)
      and (p_from_date is null or p.effective_at >= p_from_date)
      and (p_to_date is null or p.effective_at <= p_to_date)
    order by p.effective_at desc, p.created_at desc, p.id desc
    limit v_limit offset v_offset
  ) page;

  return jsonb_build_object(
    'items', v_items,
    'pagination', jsonb_build_object(
      'limit', v_limit,
      'offset', v_offset,
      'total_count', v_total,
      'has_more', (v_offset + v_limit) < v_total
    )
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. RPC: my payment detail. Missing, foreign, and cross-group all report
--    the same not-found outcome — no existence oracle.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_payment_detail(p_group_id uuid, p_payment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_record record;
begin
  v_membership_id := public.member_payment_membership_id(p_group_id);

  if p_payment_id is null then
    raise exception 'p_payment_id is required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.payments p
    where p.id = p_payment_id and p.group_id = p_group_id and p.membership_id = v_membership_id
  ) then
    raise exception 'Payment not found' using errcode = '22023';
  end if;

  select * into v_record from public.member_payment_record(p_payment_id);

  return jsonb_build_object(
    'payment', jsonb_build_object(
      'payment_id', v_record.payment_id,
      'effective_at', v_record.effective_at,
      'amount', v_record.amount,
      'payment_method', v_record.payment_method,
      'external_reference', v_record.external_reference,
      'receipt_number', v_record.receipt_number,
      'status', v_record.status,
      'reversed_at', v_record.reversed_at,
      'reversal_reason', v_record.reversal_reason
    ),
    'summary', jsonb_build_object(
      'allocated_amount', v_record.allocated_amount,
      'wallet_credit_amount', coalesce((v_record.wallet_credit->>'amount')::numeric, 0)
    ),
    'allocations', v_record.allocations,
    'wallet_credit', v_record.wallet_credit
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 5. RPC: my receipt. Side-effect free — reads the existing receipt_number,
--    never generates a new one. Same not-found behavior as detail.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_receipt(p_group_id uuid, p_payment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_record record;
begin
  v_membership_id := public.member_payment_membership_id(p_group_id);

  if p_payment_id is null then
    raise exception 'p_payment_id is required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.payments p
    where p.id = p_payment_id and p.group_id = p_group_id and p.membership_id = v_membership_id
  ) then
    raise exception 'Payment not found' using errcode = '22023';
  end if;

  select * into v_record from public.member_payment_record(p_payment_id);

  return jsonb_build_object(
    'receipt_number', v_record.receipt_number,
    'effective_at', v_record.effective_at,
    'amount', v_record.amount,
    'payment_method', v_record.payment_method,
    'external_reference', v_record.external_reference,
    'status', v_record.status,
    'reversal_reason', v_record.reversal_reason,
    'member_display_name', v_record.member_display_name,
    'member_number', v_record.member_number,
    'group_name', v_record.group_name,
    'allocations', v_record.allocations,
    'wallet_credit', v_record.wallet_credit
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Grants. RPCs: authenticated only. Internal helpers: not client-
--    executable (they run as the definer from within the RPCs above). No
--    direct table grant is added for payments/payment_allocations/
--    member_wallet_entries.
-- ---------------------------------------------------------------------------

revoke all on function public.member_payment_membership_id(uuid) from public, anon, authenticated;
revoke all on function public.member_payment_record(uuid) from public, anon, authenticated;

revoke all on function public.rpc_get_my_payments(uuid, public.payment_status, date, date, integer, integer) from public;
revoke all on function public.rpc_get_my_payment_detail(uuid, uuid) from public;
revoke all on function public.rpc_get_my_receipt(uuid, uuid) from public;

revoke execute on function public.rpc_get_my_payments(uuid, public.payment_status, date, date, integer, integer) from anon;
revoke execute on function public.rpc_get_my_payment_detail(uuid, uuid) from anon;
revoke execute on function public.rpc_get_my_receipt(uuid, uuid) from anon;

grant execute on function public.rpc_get_my_payments(uuid, public.payment_status, date, date, integer, integer) to authenticated;
grant execute on function public.rpc_get_my_payment_detail(uuid, uuid) to authenticated;
grant execute on function public.rpc_get_my_receipt(uuid, uuid) to authenticated;

comment on function public.rpc_get_my_payments(uuid, public.payment_status, date, date, integer, integer) is
  'Caller-owned external payments in the selected group (09G-B6-B). Ownership via '
  'current_membership_id() + payment.self_view only. Wallet-funded allocations have '
  'no payments row and never appear here.';
comment on function public.rpc_get_my_payment_detail(uuid, uuid) is
  'One caller-owned payment (09G-B6-B): allocation breakdown and any wallet credit '
  'that same payment created. Not-found and not-owned are indistinguishable.';
comment on function public.rpc_get_my_receipt(uuid, uuid) is
  'The caller''s own receipt for one owned payment (09G-B6-B). Reads the existing '
  'payments.receipt_number; never generates a new one. A reversed payment''s receipt '
  'still reports status = REVERSED.';
