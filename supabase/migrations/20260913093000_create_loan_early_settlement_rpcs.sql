-- Prompt 09E: Early Settlement Quote + Full Early Settlement.
--
-- Locked v1 formula (section 1): total settlement amount = every
-- outstanding assessed/opening penalty (any due date) + every
-- currently earned/payable interest (due_date <= effective date only —
-- section 1: "Do NOT charge future unearned interest merely because it
-- exists in the original schedule") + every outstanding principal
-- (every installment, regardless of due date — the whole point of an
-- EARLY settlement is paying off principal that is not yet due). This
-- is why loan_compute_early_settlement_plan below is NOT a "remaining
-- amount" walk like payment_compute_combined_allocation_plan — it is
-- always a full payoff, so every outstanding component simply IS its
-- own allocate_amount.

create or replace function public.loan_compute_early_settlement_plan(
  p_loan_account_id uuid,
  p_effective_date date
)
returns table (
  loan_installment_id uuid,
  installment_number integer,
  due_date date,
  component_type text,
  loan_penalty_charge_id uuid,
  allocate_amount numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_installment record;
  v_penalty record;
  v_interest_outstanding numeric;
  v_principal_outstanding numeric;
begin
  for v_installment in
    select li.id, li.installment_number, li.due_date
    from public.loan_installments li
    where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
    order by li.due_date asc, li.installment_number asc
  loop
    for v_penalty in
      select * from public.loan_penalty_charge_states(v_installment.id) where outstanding > 0
    loop
      loan_installment_id := v_installment.id;
      installment_number := v_installment.installment_number;
      due_date := v_installment.due_date;
      component_type := 'PENALTY';
      loan_penalty_charge_id := v_penalty.charge_id;
      allocate_amount := v_penalty.outstanding;
      return next;
    end loop;

    select
      coalesce(sum(s.outstanding) filter (where s.component_type = 'INTEREST'), 0),
      coalesce(sum(s.outstanding) filter (where s.component_type = 'PRINCIPAL'), 0)
    into v_interest_outstanding, v_principal_outstanding
    from public.loan_installment_component_states(v_installment.id) s;

    if v_installment.due_date <= p_effective_date and v_interest_outstanding > 0 then
      loan_installment_id := v_installment.id;
      installment_number := v_installment.installment_number;
      due_date := v_installment.due_date;
      component_type := 'INTEREST';
      loan_penalty_charge_id := null;
      allocate_amount := v_interest_outstanding;
      return next;
    end if;

    if v_principal_outstanding > 0 then
      loan_installment_id := v_installment.id;
      installment_number := v_installment.installment_number;
      due_date := v_installment.due_date;
      component_type := 'PRINCIPAL';
      loan_penalty_charge_id := null;
      allocate_amount := v_principal_outstanding;
      return next;
    end if;
  end loop;
end;
$$;

revoke all on function public.loan_compute_early_settlement_plan(uuid, date)
  from public, anon, authenticated;

comment on function public.loan_compute_early_settlement_plan(uuid, date) is
  'Locked-down internal helper — a FULL payoff plan (never a partial
  "remaining amount" walk): every outstanding penalty (any due date),
  every currently-payable interest (due_date <= p_effective_date only),
  and every outstanding principal (any due date). Shared by
  rpc_preview_loan_early_settlement and rpc_settle_loan_early so preview
  and posting can never diverge.';

-- ---------------------------------------------------------------------
-- rpc_preview_loan_early_settlement — read-only quote (section 1). No
-- writes; posting always independently recomputes from this same plan
-- function, never trusting a client-held quote.
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_loan_early_settlement(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_effective_date date default current_date
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_overdue_penalty numeric;
  v_overdue_interest numeric;
  v_overdue_principal numeric;
  v_current_penalty numeric;
  v_current_interest numeric;
  v_current_principal numeric;
  v_future_principal numeric;
  v_future_unearned_interest numeric;
  v_total numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.settle_early') then
    raise exception 'Not authorized to settle loans early in this group' using errcode = '42501';
  end if;

  if p_effective_date is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select * into v_loan
  from public.loan_accounts
  where id = p_loan_account_id and group_id = p_group_id;

  if v_loan.id is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  if v_loan.status <> 'ACTIVE' then
    raise exception 'LOAN_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PENALTY' and p.due_date < p_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'INTEREST' and p.due_date < p_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PRINCIPAL' and p.due_date < p_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PENALTY' and p.due_date = p_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'INTEREST' and p.due_date = p_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PRINCIPAL' and p.due_date = p_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PRINCIPAL' and p.due_date > p_effective_date), 0),
    coalesce(sum(p.allocate_amount), 0)
  into
    v_overdue_penalty, v_overdue_interest, v_overdue_principal,
    v_current_penalty, v_current_interest, v_current_principal,
    v_future_principal, v_total
  from public.loan_compute_early_settlement_plan(p_loan_account_id, p_effective_date) p;

  -- Informational only (section 1) — never charged, never included in
  -- v_total.
  select coalesce(sum(s.outstanding), 0)
  into v_future_unearned_interest
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id
    and li.cancelled_at is null
    and li.due_date > p_effective_date
    and s.component_type = 'INTEREST';

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'effective_date', p_effective_date,
    'overdue_penalty_outstanding', v_overdue_penalty,
    'overdue_interest_outstanding', v_overdue_interest,
    'overdue_principal_outstanding', v_overdue_principal,
    'current_payable_penalty', v_current_penalty,
    'current_payable_interest', v_current_interest,
    'current_payable_principal', v_current_principal,
    'future_principal_outstanding', v_future_principal,
    'future_unearned_interest', v_future_unearned_interest,
    'settlement_adjustment_amount', 0,
    'total_settlement_amount', v_total,
    'resulting_principal_balance', 0,
    'resulting_earned_interest_balance', 0,
    'resulting_penalty_balance', 0
  );
end;
$$;

revoke all on function public.rpc_preview_loan_early_settlement(uuid, uuid, date) from public;
grant execute on function public.rpc_preview_loan_early_settlement(uuid, uuid, date) to authenticated;
revoke execute on function public.rpc_preview_loan_early_settlement(uuid, uuid, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_settle_loan_early — the amount is ALWAYS server-computed from
-- loan_compute_early_settlement_plan, never a client-supplied figure
-- (section 2). One payment, one cashbook INFLOW, reusing the existing
-- Payment Engine's payments/financial_account_post_entry/receipt
-- infrastructure exactly as rpc_post_payment does (section 2 — "Do NOT
-- build a parallel cash/payment mechanism").
-- ---------------------------------------------------------------------

create or replace function public.rpc_settle_loan_early(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_financial_account_id uuid,
  p_payment_method public.payment_method,
  p_effective_date date default current_date,
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
  v_loan record;
  v_account record;
  v_existing record;
  v_payment_id uuid;
  v_receipt_number text;
  v_plan record;
  v_total_allocated numeric := 0;
  v_line_number integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.settle_early') then
    raise exception 'Not authorized to settle loans early in this group' using errcode = '42501';
  end if;

  if p_effective_date is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select * into v_loan
  from public.loan_accounts
  where id = p_loan_account_id and group_id = p_group_id
  for update;

  if v_loan.id is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  if v_loan.status <> 'ACTIVE' then
    raise exception 'LOAN_NOT_ACTIVE' using errcode = 'P0001';
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
      select coalesce(sum(amount), 0) into v_total_allocated
      from public.payment_allocations
      where payment_id = v_existing.id;

      return jsonb_build_object(
        'payment_id', v_existing.id,
        'receipt_number', v_existing.receipt_number,
        'loan_account_id', p_loan_account_id,
        'amount', v_existing.amount,
        'total_allocated', v_total_allocated,
        'already_posted', true,
        'financial_account_balance', public.financial_account_balance(v_existing.financial_account_id)
      );
    end if;
  end if;

  select coalesce(sum(p.allocate_amount), 0) into v_total_allocated
  from public.loan_compute_early_settlement_plan(p_loan_account_id, p_effective_date) p;

  if v_total_allocated <= 0 then
    raise exception 'LOAN_ALREADY_FULLY_SETTLED' using errcode = 'P0001';
  end if;

  v_receipt_number := public.payment_generate_receipt_number(p_effective_date);

  insert into public.payments (
    group_id, membership_id, financial_account_id, amount, effective_at,
    payment_method, external_reference, notes, receipt_number, idempotency_key, created_by
  ) values (
    p_group_id, v_loan.membership_id, p_financial_account_id, v_total_allocated, p_effective_date,
    p_payment_method, p_external_reference, p_notes, v_receipt_number, p_idempotency_key, v_uid
  )
  returning id into v_payment_id;

  for v_plan in
    select * from public.loan_compute_early_settlement_plan(p_loan_account_id, p_effective_date)
  loop
    v_line_number := v_line_number + 1;
    insert into public.payment_allocations (
      group_id, payment_id, membership_id, amount,
      allocation_target_type, line_number, loan_account_id, loan_installment_id, loan_penalty_charge_id,
      created_by
    ) values (
      p_group_id, v_payment_id, v_loan.membership_id, v_plan.allocate_amount,
      ('LOAN_' || v_plan.component_type)::public.payment_allocation_target_type, v_line_number,
      p_loan_account_id, v_plan.loan_installment_id, v_plan.loan_penalty_charge_id,
      v_uid
    );
  end loop;

  -- Every not-yet-due installment just had its principal paid off in
  -- full above but never received an interest allocation (section 1) —
  -- its interest is now permanently void, never to be earned or
  -- recognized. Mark it CANCELLED (never delete — section 7) so it
  -- stops appearing as outstanding/unearned forever after.
  update public.loan_installments
  set cancelled_at = now(),
    cancellation_reason = 'EARLY_SETTLEMENT',
    cancelled_by_payment_id = v_payment_id
  where loan_account_id = p_loan_account_id
    and cancelled_at is null
    and due_date > p_effective_date;

  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'INFLOW',
    p_amount => v_total_allocated,
    p_effective_at => p_effective_date,
    p_uid => v_uid,
    p_description => 'Early settlement ' || v_receipt_number,
    p_reference => p_external_reference,
    p_source_type => 'PAYMENT',
    p_source_id => v_payment_id
  );

  perform public.loan_account_recheck_closure(p_group_id, p_loan_account_id, v_uid);

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, metadata, created_by
  ) values (
    p_group_id, p_loan_account_id, 'EARLY_SETTLED', v_loan.status,
    (select status from public.loan_accounts where id = p_loan_account_id),
    jsonb_build_object('payment_id', v_payment_id, 'amount', v_total_allocated, 'effective_date', p_effective_date),
    v_uid
  );

  return jsonb_build_object(
    'payment_id', v_payment_id,
    'receipt_number', v_receipt_number,
    'loan_account_id', p_loan_account_id,
    'amount', v_total_allocated,
    'total_allocated', v_total_allocated,
    'already_posted', false,
    'financial_account_balance', public.financial_account_balance(p_financial_account_id),
    'loan_status', (select status from public.loan_accounts where id = p_loan_account_id)
  );
end;
$$;

revoke all on function public.rpc_settle_loan_early(
  uuid, uuid, uuid, public.payment_method, date, text, text, text
) from public;
grant execute on function public.rpc_settle_loan_early(
  uuid, uuid, uuid, public.payment_method, date, text, text, text
) to authenticated;
revoke execute on function public.rpc_settle_loan_early(
  uuid, uuid, uuid, public.payment_method, date, text, text, text
) from anon;

comment on function public.rpc_settle_loan_early(
  uuid, uuid, uuid, public.payment_method, date, text, text, text
) is
  'Prompt 09E: atomic full early settlement. Amount is always
  server-computed (loan_compute_early_settlement_plan), never a
  client-supplied figure. Creates exactly one payment/cashbook INFLOW
  (reusing the existing Payment Engine), pays every outstanding penalty
  and currently-payable interest plus every outstanding principal
  (including not-yet-due), cancels the voided future interest, and
  closes the loan via the existing loan_account_recheck_closure once
  every component reaches zero.';
