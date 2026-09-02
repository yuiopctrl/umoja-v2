-- Prompt 09D: integrates LOAN_PENALTY into the single combined
-- allocation walk and every payment/wallet RPC that consumes it —
-- section 3 ("no second payment engine"), section 17 (locked priority
-- PENALTY -> INTEREST -> PRINCIPAL within an installment, oldest
-- due_date first across obligations, contribution before loan on an
-- exact tie — completely unchanged from 09C/09C-UAT-FIX-01).
--
-- payment_compute_combined_allocation_plan gains a new output column
-- (loan_penalty_charge_id) — a return-shape change requires dropping
-- the old-signature function first (established pattern).

drop function if exists public.payment_compute_combined_allocation_plan(uuid, uuid, numeric, date);

create function public.payment_compute_combined_allocation_plan(
  p_group_id uuid,
  p_membership_id uuid,
  p_amount numeric,
  p_effective_date date default current_date
)
returns table (
  obligation_kind text,
  charge_id uuid,
  component_id uuid,
  component_type text,
  contribution_type_name text,
  period_id uuid,
  period_label text,
  period_purpose text,
  loan_account_id uuid,
  loan_installment_id uuid,
  loan_number text,
  loan_product_name text,
  installment_number integer,
  loan_penalty_charge_id uuid,
  due_date date,
  allocate_amount numeric,
  component_outstanding_before numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_remaining numeric := coalesce(p_amount, 0);
  v_group record;
  v_component record;
  v_penalty_charge record;
  v_take numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  for v_group in
    select * from (
      select
        0 as kind_order,
        'CONTRIBUTION'::text as kind,
        c.charge_id as ref_id,
        c.due_date,
        c.charge_created_at as tie_created_at,
        c.contribution_type_name,
        c.period_id,
        c.period_label,
        c.period_purpose,
        null::uuid as loan_account_id,
        null::text as loan_number,
        null::text as loan_product_name,
        null::integer as installment_number
      from public.contribution_member_allocatable_charges(p_group_id, p_membership_id) c
      union all
      select
        1 as kind_order,
        'LOAN'::text as kind,
        li.installment_id as ref_id,
        li.due_date,
        li.loan_created_at as tie_created_at,
        null::text, null::uuid, null::text, null::text,
        li.loan_account_id,
        li.loan_number,
        li.loan_product_name,
        li.installment_number
      from public.loan_member_allocatable_installments(p_group_id, p_membership_id, p_effective_date) li
    ) combined
    order by combined.due_date asc, combined.kind_order asc, combined.tie_created_at asc, combined.ref_id asc
  loop
    exit when v_remaining <= 0;

    if v_group.kind = 'CONTRIBUTION' then
      for v_component in
        select * from public.contribution_charge_component_states(v_group.ref_id) where outstanding > 0
      loop
        exit when v_remaining <= 0;

        v_take := least(v_remaining, v_component.outstanding);
        if v_take > 0 then
          obligation_kind := 'CONTRIBUTION';
          charge_id := v_group.ref_id;
          component_id := v_component.component_id;
          component_type := v_component.component_type;
          contribution_type_name := v_group.contribution_type_name;
          period_id := v_group.period_id;
          period_label := v_group.period_label;
          period_purpose := v_group.period_purpose;
          loan_account_id := null;
          loan_installment_id := null;
          loan_number := null;
          loan_product_name := null;
          installment_number := null;
          loan_penalty_charge_id := null;
          due_date := v_group.due_date;
          allocate_amount := v_take;
          component_outstanding_before := v_component.outstanding;
          return next;
          v_remaining := v_remaining - v_take;
        end if;
      end loop;
    else
      for v_component in
        select * from public.loan_installment_component_states(v_group.ref_id) where outstanding > 0 order by priority
      loop
        exit when v_remaining <= 0;

        if v_component.component_type = 'PENALTY' then
          -- An installment may carry more than one outstanding penalty
          -- charge (RECURRING_MONTHLY) — attribute FIFO, oldest
          -- assessment_date/sequence first, one plan row per charge
          -- actually touched (section 4/16).
          for v_penalty_charge in
            select * from public.loan_penalty_charge_states(v_group.ref_id)
            where outstanding > 0
            order by assessment_date asc, sequence_number asc
          loop
            exit when v_remaining <= 0;

            v_take := least(v_remaining, v_penalty_charge.outstanding);
            if v_take > 0 then
              obligation_kind := 'LOAN_PENALTY';
              charge_id := null;
              component_id := null;
              component_type := 'PENALTY';
              contribution_type_name := null;
              period_id := null;
              period_label := null;
              period_purpose := null;
              loan_account_id := v_group.loan_account_id;
              loan_installment_id := v_group.ref_id;
              loan_number := v_group.loan_number;
              loan_product_name := v_group.loan_product_name;
              installment_number := v_group.installment_number;
              loan_penalty_charge_id := v_penalty_charge.charge_id;
              due_date := v_group.due_date;
              allocate_amount := v_take;
              component_outstanding_before := v_penalty_charge.outstanding;
              return next;
              v_remaining := v_remaining - v_take;
            end if;
          end loop;
        else
          v_take := least(v_remaining, v_component.outstanding);
          if v_take > 0 then
            obligation_kind := case v_component.component_type when 'INTEREST' then 'LOAN_INTEREST' else 'LOAN_PRINCIPAL' end;
            charge_id := null;
            component_id := null;
            component_type := v_component.component_type;
            contribution_type_name := null;
            period_id := null;
            period_label := null;
            period_purpose := null;
            loan_account_id := v_group.loan_account_id;
            loan_installment_id := v_group.ref_id;
            loan_number := v_group.loan_number;
            loan_product_name := v_group.loan_product_name;
            installment_number := v_group.installment_number;
            loan_penalty_charge_id := null;
            due_date := v_group.due_date;
            allocate_amount := v_take;
            component_outstanding_before := v_component.outstanding;
            return next;
            v_remaining := v_remaining - v_take;
          end if;
        end if;
      end loop;
    end if;
  end loop;
end;
$$;

revoke all on function public.payment_compute_combined_allocation_plan(uuid, uuid, numeric, date)
  from public, anon, authenticated;

comment on function public.payment_compute_combined_allocation_plan(uuid, uuid, numeric, date) is
  'Locked-down internal helper — the single deterministic allocation
  walk shared by rpc_preview_payment_allocation/rpc_post_payment/
  rpc_preview_wallet_allocation/rpc_allocate_member_wallet. Prompt 09D:
  within a loan installment, priority is now PENALTY (attributed FIFO
  across possibly-multiple outstanding charges) -> INTEREST ->
  PRINCIPAL. Cross-obligation ordering (oldest due_date first,
  contribution before loan on an exact tie) is completely unchanged.';

-- ---------------------------------------------------------------------
-- rpc_preview_payment_allocation / rpc_preview_wallet_allocation — same
-- jsonb-returning signatures; each allocation line now also carries
-- loan_penalty_charge_id (null for every non-penalty line).
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

  select coalesce(jsonb_agg(jsonb_build_object(
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
  ) order by plan.due_date, coalesce(plan.component_id, plan.loan_installment_id), plan.component_type), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.payment_compute_combined_allocation_plan(
    p_group_id, p_membership_id, p_amount, coalesce(p_effective_at, current_date)
  ) plan;

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

revoke all on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric, date) from public;
grant execute on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric, date) to authenticated;
revoke execute on function public.rpc_preview_payment_allocation(uuid, uuid, uuid, numeric, date) from anon;

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
  ) order by plan.due_date, coalesce(plan.component_id, plan.loan_installment_id), plan.component_type), '[]'::jsonb),
  coalesce(sum(plan.allocate_amount), 0)
  into v_allocations, v_total_allocated
  from public.payment_compute_combined_allocation_plan(p_group_id, p_membership_id, p_amount, current_date) plan;

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
-- rpc_post_payment — inserts one payment_allocations row per plan row,
-- now setting loan_penalty_charge_id when the plan row is a penalty
-- allocation. Same signature.
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
    if v_plan.obligation_kind = 'CONTRIBUTION' then
      insert into public.payment_allocations (
        group_id, payment_id, membership_id, charge_id, charge_component_id, amount,
        allocation_target_type,
        contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
        created_by
      ) values (
        p_group_id, v_payment_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
        'CONTRIBUTION_COMPONENT',
        v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
        v_uid
      );
    else
      insert into public.payment_allocations (
        group_id, payment_id, membership_id, amount,
        allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id,
        created_by
      ) values (
        p_group_id, v_payment_id, p_membership_id, v_plan.allocate_amount,
        v_plan.obligation_kind::public.payment_allocation_target_type,
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

  -- Exactly one cashbook INFLOW for the FULL payment amount, never
  -- just the allocated portion — invariant B, unchanged.
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

revoke all on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) from public;
grant execute on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) to authenticated;
revoke execute on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) from anon;

comment on function public.rpc_post_payment(
  uuid, uuid, uuid, numeric, date, public.payment_method, text, text, text
) is
  'Prompt 07, extended 09C/09D. LOAN_PRINCIPAL/LOAN_INTEREST/
  LOAN_PENALTY allocations now cast v_plan.obligation_kind directly
  (all three share the exact enum spelling), carrying
  loan_penalty_charge_id only for LOAN_PENALTY rows. Still exactly one
  payment, one cashbook INFLOW, one receipt regardless of how many
  obligation kinds a payment settles (section 3).';

-- ---------------------------------------------------------------------
-- rpc_allocate_member_wallet — same extension for wallet-sourced
-- allocations. Zero cashbook movement, exactly as wallet-to-loan
-- already worked for interest/principal (section 19).
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
  v_loan_id uuid;
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
    if v_plan.obligation_kind = 'CONTRIBUTION' then
      insert into public.payment_allocations (
        group_id, wallet_entry_id, membership_id, charge_id, charge_component_id, amount,
        allocation_target_type,
        contribution_type_name_snapshot, period_label_snapshot, period_purpose_snapshot,
        created_by
      ) values (
        p_group_id, v_wallet_entry_id, p_membership_id, v_plan.charge_id, v_plan.component_id, v_plan.allocate_amount,
        'CONTRIBUTION_COMPONENT',
        v_plan.contribution_type_name, v_plan.period_label, v_plan.period_purpose,
        v_uid
      );
    else
      insert into public.payment_allocations (
        group_id, wallet_entry_id, membership_id, amount,
        allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id,
        created_by
      ) values (
        p_group_id, v_wallet_entry_id, p_membership_id, v_plan.allocate_amount,
        v_plan.obligation_kind::public.payment_allocation_target_type,
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

revoke all on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) from public;
grant execute on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) to authenticated;
revoke execute on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) from anon;

comment on function public.rpc_allocate_member_wallet(uuid, uuid, numeric, text) is
  'Prompt 07, extended 09C/09D. Wallet may now also settle LOAN_PENALTY
  — reduces wallet, reduces penalty outstanding, recognizes penalty
  income, creates ZERO cashbook movement, exactly like wallet-to-loan-
  interest already worked (section 19).';
