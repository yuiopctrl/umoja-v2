-- Prompt 09D-UAT-BLOCKER-01 bug fix: allocation lines for the SAME due
-- date/installment were displayed out of priority order.
--
-- Root cause: `rpc_preview_payment_allocation`/`rpc_preview_wallet_
-- allocation` re-sorted their jsonb_agg output by
-- `(due_date, loan_installment_id, component_type)` — a tiebreaker
-- added back in 09C when only INTEREST/PRINCIPAL existed (where
-- alphabetical order happened to match priority order by
-- coincidence). Prompt 09D's PENALTY sorts alphabetically BETWEEN
-- INTEREST and PRINCIPAL ('INTEREST' < 'PENALTY' < 'PRINCIPAL'),
-- silently breaking the locked PENALTY -> INTEREST -> PRINCIPAL
-- priority display order the instant all three apply to one
-- installment in the same payment — exactly the scenario this
-- blocker's migrated-arrears worked example (section 30) exercises for
-- the first time. `rpc_get_payment_detail`/`rpc_get_receipt` had the
-- same latent defect for POSTED allocations: their tiebreaker,
-- `pa.created_at`, is `now()` — identical for every row inserted
-- within one `rpc_post_payment`/`rpc_allocate_member_wallet`
-- transaction — so their relative order was never actually guaranteed
-- by anything.
--
-- Fix: `payment_allocations` gains an explicit `line_number`,
-- populated in insertion (= priority-walk) order by
-- `rpc_post_payment`/`rpc_allocate_member_wallet`; every read RPC now
-- orders by it directly instead of re-deriving order from
-- component_type or relying on a same-instant timestamp.

alter table public.payment_allocations
  add column line_number integer;

update public.payment_allocations pa
set line_number = sub.rn
from (
  select id, row_number() over (partition by coalesce(payment_id, wallet_entry_id) order by created_at, id) as rn
  from public.payment_allocations
) sub
where pa.id = sub.id;

alter table public.payment_allocations
  alter column line_number set not null,
  add constraint payment_allocations_line_number_positive check (line_number > 0);

comment on column public.payment_allocations.line_number is
  'Prompt 09D-UAT-BLOCKER-01: 1-based position within its payment/
  wallet-entry''s allocation walk, in the exact order
  payment_compute_combined_allocation_plan emitted it — the
  authoritative display order (never re-derived from component_type or
  created_at, which is identical for every row in one posting
  transaction).';

-- ---------------------------------------------------------------------
-- rpc_post_payment / rpc_allocate_member_wallet — set line_number
-- sequentially in their existing allocation-insertion loop. Same
-- signatures throughout — plain create or replace.
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
  v_loan_id uuid;
  v_total_allocated numeric := 0;
  v_wallet_credit_amount numeric;
  v_wallet_entry_id uuid;
  v_already_posted boolean := false;
  v_line_number integer := 0;
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
    select * from public.payment_compute_combined_allocation_plan(
      p_group_id, p_membership_id, p_amount, p_effective_at
    )
  loop
    v_line_number := v_line_number + 1;
    if v_plan.obligation_kind = 'CONTRIBUTION' then
      insert into public.payment_allocations (
        group_id, payment_id, membership_id, charge_id, charge_component_id, amount,
        allocation_target_type, line_number,
        contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
        created_by
      ) values (
        p_group_id, v_payment_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
        'CONTRIBUTION_COMPONENT', v_line_number,
        v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
        v_uid
      );
    else
      insert into public.payment_allocations (
        group_id, payment_id, membership_id, amount,
        allocation_target_type, line_number, loan_account_id, loan_installment_id, loan_penalty_charge_id,
        created_by
      ) values (
        p_group_id, v_payment_id, p_membership_id, v_plan.allocate_amount,
        v_plan.obligation_kind::public.payment_allocation_target_type, v_line_number,
        v_plan.loan_account_id, v_plan.loan_installment_id, v_plan.loan_penalty_charge_id,
        v_uid
      );
    end if;
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

  for v_loan_id in
    select distinct loan_account_id from public.payment_allocations
    where payment_id = v_payment_id and loan_account_id is not null
  loop
    perform public.loan_account_recheck_closure(p_group_id, v_loan_id, v_uid);
  end loop;

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
  v_loan_id uuid;
  v_total_allocated numeric := 0;
  v_line_number integer := 0;
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

  select coalesce(sum(allocate_amount), 0) into v_total_allocated
  from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date);

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
    select * from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date)
  loop
    v_line_number := v_line_number + 1;
    if v_plan.obligation_kind = 'CONTRIBUTION' then
      insert into public.payment_allocations (
        group_id, wallet_entry_id, membership_id, charge_id, charge_component_id, amount,
        allocation_target_type, line_number,
        contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
        created_by
      ) values (
        p_group_id, v_wallet_entry_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
        'CONTRIBUTION_COMPONENT', v_line_number,
        v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
        v_uid
      );
    else
      insert into public.payment_allocations (
        group_id, wallet_entry_id, membership_id, amount,
        allocation_target_type, line_number, loan_account_id, loan_installment_id, loan_penalty_charge_id,
        created_by
      ) values (
        p_group_id, v_wallet_entry_id, p_membership_id, v_plan.allocate_amount,
        v_plan.obligation_kind::public.payment_allocation_target_type, v_line_number,
        v_plan.loan_account_id, v_plan.loan_installment_id, v_plan.loan_penalty_charge_id,
        v_uid
      );
    end if;
  end loop;

  for v_loan_id in
    select distinct loan_account_id from public.payment_allocations
    where wallet_entry_id = v_wallet_entry_id and loan_account_id is not null
  loop
    perform public.loan_account_recheck_closure(p_group_id, v_loan_id, v_uid);
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

-- ---------------------------------------------------------------------
-- rpc_preview_payment_allocation / rpc_preview_wallet_allocation — the
-- preview never persists rows, so there is no line_number to read;
-- instead, number the plan's own emission order (a plpgsql function's
-- `return next` sequence, preserved by a bare `row_number() over ()`
-- with no window ORDER BY applied directly over its FROM-clause scan)
-- and order the jsonb_agg by THAT, never by component_type/due_date.
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

  select coalesce(jsonb_agg(x.line_obj order by x.rn), '[]'::jsonb),
    coalesce(sum(x.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from (
    select
      row_number() over () as rn,
      plan.allocate_amount,
      jsonb_build_object(
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
        'loan_penalty_charge_id', plan.loan_penalty_charge_id,
        'component_outstanding_before', plan.component_outstanding_before
      ) as line_obj
    from public.payment_compute_combined_allocation_plan(
      p_group_id, p_membership_id, p_amount, coalesce(p_effective_at, current_date)
    ) plan
  ) x;

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

  select coalesce(jsonb_agg(x.line_obj order by x.rn), '[]'::jsonb),
    coalesce(sum(x.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from (
    select
      row_number() over () as rn,
      plan.allocate_amount,
      jsonb_build_object(
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
        'loan_penalty_charge_id', plan.loan_penalty_charge_id,
        'component_outstanding_before', plan.component_outstanding_before
      ) as line_obj
    from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date) plan
  ) x;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'wallet_balance', v_balance,
    'amount', p_amount,
    'allocations', v_allocations,
    'total_allocated', v_total_allocated
  );
end;
$$;

-- ---------------------------------------------------------------------
-- rpc_get_payment_detail / rpc_get_receipt — order by pa.line_number
-- instead of pa.created_at (identical for every row in one posting
-- transaction, so it never actually guaranteed anything).
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
    'installment_number', li.installment_number,
    'loan_penalty_charge_id', pa.loan_penalty_charge_id
  ) order by pa.line_number), '[]'::jsonb)
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
    'installment_number', li.installment_number,
    'loan_penalty_charge_id', pa.loan_penalty_charge_id
  ) order by pa.line_number), '[]'::jsonb)
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
