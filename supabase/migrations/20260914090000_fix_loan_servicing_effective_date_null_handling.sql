-- Prompt 09E-UAT-BLOCKER-01A: append-only corrective migration.
--
-- Physical-device UAT found that Early Settlement and Principal
-- Prepayment previews always failed. Root cause: all six 09E loan-
-- servicing RPCs declared `p_effective_date date default current_date`
-- but ALSO raised 'Effective date is required' whenever it was null.
-- PostgREST (what the Supabase/Flutter client actually calls, unlike a
-- raw SQL call) always sends every declared parameter explicitly — a
-- JSON `null` when the Flutter caller never set one — so the SQL
-- DEFAULT never applied (a DEFAULT only ever fires when an argument is
-- OMITTED, never when it is explicitly NULL). Every real app call hit
-- the raise instead of silently defaulting to today.
--
-- LOCKED MIGRATION-DISCIPLINE RULE: any migration version already
-- applied to the cloud project is immutable. The three original 09E
-- migration files that define these six RPCs
-- (20260913093000/094000/095000) were mistakenly edited in place during
-- the first attempt at this fix and have since been RESTORED to their
-- exact original, already-applied content — see the corresponding
-- closeout report. This migration is the ONLY correction: strictly
-- append-only, later than every existing 09E migration, touching
-- nothing else.
--
-- Fix: normalize into a genuinely new local variable, v_effective_date
-- := coalesce(p_effective_date, current_date), immediately after the
-- permission check in every affected function, and use v_effective_date
-- (never the raw p_effective_date parameter) everywhere from that point
-- on. Signatures, permissions, SECURITY DEFINER, search_path, tenant
-- validation, and all accounting behavior are otherwise byte-for-byte
-- unchanged from the original 09E migrations.

-- ---------------------------------------------------------------------
-- rpc_preview_loan_early_settlement
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
  v_effective_date date;
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

  -- PostgREST always sends this parameter explicitly (JSON null when
  -- the Flutter caller omits it) — normalize here instead of relying on
  -- the SQL DEFAULT, which never applies over that path.
  v_effective_date := coalesce(p_effective_date, current_date);

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
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PENALTY' and p.due_date < v_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'INTEREST' and p.due_date < v_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PRINCIPAL' and p.due_date < v_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PENALTY' and p.due_date = v_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'INTEREST' and p.due_date = v_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PRINCIPAL' and p.due_date = v_effective_date), 0),
    coalesce(sum(p.allocate_amount) filter (where p.component_type = 'PRINCIPAL' and p.due_date > v_effective_date), 0),
    coalesce(sum(p.allocate_amount), 0)
  into
    v_overdue_penalty, v_overdue_interest, v_overdue_principal,
    v_current_penalty, v_current_interest, v_current_principal,
    v_future_principal, v_total
  from public.loan_compute_early_settlement_plan(p_loan_account_id, v_effective_date) p;

  -- Informational only (section 1) — never charged, never included in
  -- v_total.
  select coalesce(sum(s.outstanding), 0)
  into v_future_unearned_interest
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id
    and li.cancelled_at is null
    and li.due_date > v_effective_date
    and s.component_type = 'INTEREST';

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'effective_date', v_effective_date,
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

-- ---------------------------------------------------------------------
-- rpc_settle_loan_early
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
  v_effective_date date;
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

  v_effective_date := coalesce(p_effective_date, current_date);

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
  from public.loan_compute_early_settlement_plan(p_loan_account_id, v_effective_date) p;

  if v_total_allocated <= 0 then
    raise exception 'LOAN_ALREADY_FULLY_SETTLED' using errcode = 'P0001';
  end if;

  v_receipt_number := public.payment_generate_receipt_number(v_effective_date);

  insert into public.payments (
    group_id, membership_id, financial_account_id, amount, effective_at,
    payment_method, external_reference, notes, receipt_number, idempotency_key, created_by
  ) values (
    p_group_id, v_loan.membership_id, p_financial_account_id, v_total_allocated, v_effective_date,
    p_payment_method, p_external_reference, p_notes, v_receipt_number, p_idempotency_key, v_uid
  )
  returning id into v_payment_id;

  for v_plan in
    select * from public.loan_compute_early_settlement_plan(p_loan_account_id, v_effective_date)
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
    and due_date > v_effective_date;

  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'INFLOW',
    p_amount => v_total_allocated,
    p_effective_at => v_effective_date,
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
    jsonb_build_object('payment_id', v_payment_id, 'amount', v_total_allocated, 'effective_date', v_effective_date),
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

-- ---------------------------------------------------------------------
-- rpc_preview_loan_prepayment
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_loan_prepayment(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_amount numeric,
  p_treatment public.loan_reschedule_treatment,
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
  v_effective_date date;
  v_loan record;
  v_eligibility record;
  v_new_future_principal numeric;
  v_old_future jsonb;
  v_new_future jsonb;
  v_first_future_due_date date;
  v_future_term integer;
  v_installment_principal numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.prepay_principal') then
    raise exception 'Not authorized to prepay loan principal in this group' using errcode = '42501';
  end if;

  v_effective_date := coalesce(p_effective_date, current_date);

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_PREPAYMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
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

  select * into v_eligibility
  from public.loan_prepayment_eligibility(p_loan_account_id, v_effective_date);

  if v_eligibility.payable_penalty_outstanding > 0 then
    raise exception 'LOAN_PREPAYMENT_BLOCKED_OVERDUE_PENALTY' using errcode = 'P0001';
  end if;

  if v_eligibility.payable_interest_outstanding > 0 then
    raise exception 'LOAN_PREPAYMENT_BLOCKED_OVERDUE_INTEREST' using errcode = 'P0001';
  end if;

  if p_amount > v_eligibility.future_principal_outstanding then
    raise exception 'LOAN_PREPAYMENT_EXCEEDS_FUTURE_PRINCIPAL' using errcode = '22023';
  end if;

  v_new_future_principal := v_eligibility.future_principal_outstanding - p_amount;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb),
  min(li.due_date), count(*)
  into v_old_future, v_first_future_due_date, v_future_term
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date > v_effective_date;

  if v_new_future_principal = 0 then
    v_new_future := '[]'::jsonb;
  elsif p_treatment = 'REDUCE_INSTALLMENT' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'installment_number', s.installment_number, 'due_date', s.due_date,
      'principal_due', s.principal_due, 'interest_due', s.interest_due
    ) order by s.installment_number), '[]'::jsonb)
    into v_new_future
    from public.loan_schedule_compute(
      v_new_future_principal, v_loan.interest_rate, v_loan.interest_rate_basis,
      v_loan.interest_method, v_future_term, v_first_future_due_date
    ) s;
  else
    select li.principal_due into v_installment_principal
    from public.loan_installments li
    where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date > v_effective_date
    order by li.due_date asc, li.installment_number asc
    limit 1;

    select coalesce(jsonb_agg(jsonb_build_object(
      'installment_number', s.installment_number, 'due_date', s.due_date,
      'principal_due', s.principal_due, 'interest_due', s.interest_due
    ) order by s.installment_number), '[]'::jsonb)
    into v_new_future
    from public.loan_schedule_compute_fixed_principal(
      v_new_future_principal, v_installment_principal, v_loan.interest_rate, v_loan.interest_rate_basis,
      v_loan.interest_method, v_first_future_due_date
    ) s;
  end if;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'effective_date', v_effective_date,
    'amount', p_amount,
    'treatment', p_treatment,
    'future_principal_outstanding_before', v_eligibility.future_principal_outstanding,
    'future_principal_outstanding_after', v_new_future_principal,
    'old_future_installments', v_old_future,
    'new_future_installments', v_new_future
  );
end;
$$;

-- ---------------------------------------------------------------------
-- rpc_prepay_loan_principal
-- ---------------------------------------------------------------------

create or replace function public.rpc_prepay_loan_principal(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_amount numeric,
  p_treatment public.loan_reschedule_treatment,
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
  v_effective_date date;
  v_loan record;
  v_account record;
  v_existing_payment record;
  v_existing_event record;
  v_eligibility record;
  v_new_future_principal numeric;
  v_old_future jsonb;
  v_new_future jsonb := '[]'::jsonb;
  v_first_future_due_date date;
  v_future_term integer;
  v_installment_principal numeric;
  v_next_installment_number integer;
  v_payment_id uuid;
  v_receipt_number text;
  v_schedule_row record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.prepay_principal') then
    raise exception 'Not authorized to prepay loan principal in this group' using errcode = '42501';
  end if;

  v_effective_date := coalesce(p_effective_date, current_date);

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_PREPAYMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
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
    select * into v_existing_payment
    from public.payments
    where group_id = p_group_id and idempotency_key = p_idempotency_key;

    if v_existing_payment.id is not null then
      select * into v_existing_event
      from public.loan_prepayment_events
      where payment_id = v_existing_payment.id;

      return jsonb_build_object(
        'payment_id', v_existing_payment.id,
        'receipt_number', v_existing_payment.receipt_number,
        'loan_account_id', p_loan_account_id,
        'amount', v_existing_payment.amount,
        'treatment', v_existing_event.treatment,
        'new_future_installments', v_existing_event.new_future_schedule_snapshot,
        'already_posted', true,
        'financial_account_balance', public.financial_account_balance(v_existing_payment.financial_account_id)
      );
    end if;
  end if;

  select * into v_eligibility
  from public.loan_prepayment_eligibility(p_loan_account_id, v_effective_date);

  if v_eligibility.payable_penalty_outstanding > 0 then
    raise exception 'LOAN_PREPAYMENT_BLOCKED_OVERDUE_PENALTY' using errcode = 'P0001';
  end if;

  if v_eligibility.payable_interest_outstanding > 0 then
    raise exception 'LOAN_PREPAYMENT_BLOCKED_OVERDUE_INTEREST' using errcode = 'P0001';
  end if;

  if p_amount > v_eligibility.future_principal_outstanding then
    raise exception 'LOAN_PREPAYMENT_EXCEEDS_FUTURE_PRINCIPAL' using errcode = '22023';
  end if;

  v_new_future_principal := v_eligibility.future_principal_outstanding - p_amount;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb),
  min(li.due_date), count(*)
  into v_old_future, v_first_future_due_date, v_future_term
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date > v_effective_date;

  -- Numbering continues from the highest installment_number EVER
  -- assigned to this loan (including already-cancelled rows), so a
  -- replacement schedule can never collide with the
  -- (loan_account_id, installment_number) unique index.
  select coalesce(max(installment_number), 0) into v_next_installment_number
  from public.loan_installments
  where loan_account_id = p_loan_account_id;

  v_receipt_number := public.payment_generate_receipt_number(v_effective_date);

  insert into public.payments (
    group_id, membership_id, financial_account_id, amount, effective_at,
    payment_method, external_reference, notes, receipt_number, idempotency_key, created_by
  ) values (
    p_group_id, v_loan.membership_id, p_financial_account_id, p_amount, v_effective_date,
    p_payment_method, p_external_reference, p_notes, v_receipt_number, p_idempotency_key, v_uid
  )
  returning id into v_payment_id;

  insert into public.payment_allocations (
    group_id, payment_id, membership_id, amount, allocation_target_type, line_number, loan_account_id, created_by
  ) values (
    p_group_id, v_payment_id, v_loan.membership_id, p_amount, 'LOAN_PRINCIPAL_PREPAYMENT', 1, p_loan_account_id, v_uid
  );

  update public.loan_installments
  set cancelled_at = now(),
    cancellation_reason = 'PRINCIPAL_PREPAYMENT',
    cancelled_by_payment_id = v_payment_id
  where loan_account_id = p_loan_account_id and cancelled_at is null and due_date > v_effective_date;

  if v_new_future_principal > 0 then
    if p_treatment = 'REDUCE_INSTALLMENT' then
      for v_schedule_row in
        select * from public.loan_schedule_compute(
          v_new_future_principal, v_loan.interest_rate, v_loan.interest_rate_basis,
          v_loan.interest_method, v_future_term, v_first_future_due_date
        )
      loop
        v_next_installment_number := v_next_installment_number + 1;
        insert into public.loan_installments (
          group_id, loan_account_id, installment_number, due_date, principal_due, interest_due,
          created_by_payment_id
        ) values (
          p_group_id, p_loan_account_id, v_next_installment_number, v_schedule_row.due_date,
          v_schedule_row.principal_due, v_schedule_row.interest_due, v_payment_id
        );
      end loop;
    else
      select li.principal_due into v_installment_principal
      from public.loan_installments li
      where li.loan_account_id = p_loan_account_id
        and li.cancelled_by_payment_id = v_payment_id
      order by li.due_date asc, li.installment_number asc
      limit 1;

      for v_schedule_row in
        select * from public.loan_schedule_compute_fixed_principal(
          v_new_future_principal, v_installment_principal, v_loan.interest_rate, v_loan.interest_rate_basis,
          v_loan.interest_method, v_first_future_due_date
        )
      loop
        v_next_installment_number := v_next_installment_number + 1;
        insert into public.loan_installments (
          group_id, loan_account_id, installment_number, due_date, principal_due, interest_due,
          created_by_payment_id
        ) values (
          p_group_id, p_loan_account_id, v_next_installment_number, v_schedule_row.due_date,
          v_schedule_row.principal_due, v_schedule_row.interest_due, v_payment_id
        );
      end loop;
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb)
  into v_new_future
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.created_by_payment_id = v_payment_id;

  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'INFLOW',
    p_amount => p_amount,
    p_effective_at => v_effective_date,
    p_uid => v_uid,
    p_description => 'Principal prepayment ' || v_receipt_number,
    p_reference => p_external_reference,
    p_source_type => 'PAYMENT',
    p_source_id => v_payment_id
  );

  insert into public.loan_prepayment_events (
    group_id, loan_account_id, membership_id, payment_id, effective_date, amount, treatment,
    old_future_schedule_snapshot, new_future_schedule_snapshot, created_by
  ) values (
    p_group_id, p_loan_account_id, v_loan.membership_id, v_payment_id, v_effective_date, p_amount, p_treatment,
    v_old_future, v_new_future, v_uid
  );

  perform public.loan_account_recheck_closure(p_group_id, p_loan_account_id, v_uid);

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, metadata, created_by
  ) values (
    p_group_id, p_loan_account_id, 'PRINCIPAL_PREPAID', v_loan.status,
    (select status from public.loan_accounts where id = p_loan_account_id),
    jsonb_build_object('payment_id', v_payment_id, 'amount', p_amount, 'treatment', p_treatment),
    v_uid
  );

  return jsonb_build_object(
    'payment_id', v_payment_id,
    'receipt_number', v_receipt_number,
    'loan_account_id', p_loan_account_id,
    'amount', p_amount,
    'treatment', p_treatment,
    'new_future_installments', v_new_future,
    'already_posted', false,
    'financial_account_balance', public.financial_account_balance(p_financial_account_id),
    'loan_status', (select status from public.loan_accounts where id = p_loan_account_id)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- rpc_preview_loan_restructure
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_loan_restructure(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_new_term integer,
  p_new_first_installment_date date,
  p_new_interest_rate numeric default null,
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
  v_effective_date date;
  v_loan record;
  v_overdue_outstanding numeric;
  v_remaining_principal numeric;
  v_new_rate numeric;
  v_old_remaining jsonb;
  v_new_schedule jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.restructure') then
    raise exception 'Not authorized to restructure loans in this group' using errcode = '42501';
  end if;

  v_effective_date := coalesce(p_effective_date, current_date);

  if p_new_term is null or p_new_term <= 0 then
    raise exception 'LOAN_RESTRUCTURE_TERM_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_new_first_installment_date is null or p_new_first_installment_date <= v_effective_date then
    raise exception 'LOAN_RESTRUCTURE_FIRST_INSTALLMENT_DATE_MUST_BE_AFTER_EFFECTIVE_DATE' using errcode = '22023';
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

  select coalesce(sum(s.outstanding), 0)
  into v_overdue_outstanding
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date <= v_effective_date;

  if v_overdue_outstanding > 0 then
    raise exception 'LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE' using errcode = 'P0001';
  end if;

  select coalesce(sum(s.outstanding), 0)
  into v_remaining_principal
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
    and s.component_type = 'PRINCIPAL';

  if v_remaining_principal <= 0 then
    raise exception 'LOAN_RESTRUCTURE_NOTHING_REMAINING' using errcode = 'P0001';
  end if;

  v_new_rate := coalesce(p_new_interest_rate, v_loan.interest_rate);
  if v_new_rate < 0 then
    raise exception 'LOAN_RESTRUCTURE_INTEREST_RATE_MUST_BE_NON_NEGATIVE' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb)
  into v_old_remaining
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', s.installment_number, 'due_date', s.due_date,
    'principal_due', s.principal_due, 'interest_due', s.interest_due
  ) order by s.installment_number), '[]'::jsonb)
  into v_new_schedule
  from public.loan_schedule_compute(
    v_remaining_principal, v_new_rate, v_loan.interest_rate_basis, v_loan.interest_method,
    p_new_term, p_new_first_installment_date
  ) s;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'effective_date', v_effective_date,
    'remaining_principal_outstanding', v_remaining_principal,
    'new_interest_rate', v_new_rate,
    'new_term', p_new_term,
    'new_first_installment_date', p_new_first_installment_date,
    'old_remaining_installments', v_old_remaining,
    'new_installments', v_new_schedule
  );
end;
$$;

-- ---------------------------------------------------------------------
-- rpc_restructure_loan
-- ---------------------------------------------------------------------

create or replace function public.rpc_restructure_loan(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_reason text,
  p_new_term integer,
  p_new_first_installment_date date,
  p_new_interest_rate numeric default null,
  p_effective_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_effective_date date;
  v_loan record;
  v_overdue_outstanding numeric;
  v_remaining_principal numeric;
  v_new_rate numeric;
  v_old_remaining jsonb;
  v_new_schedule jsonb;
  v_next_installment_number integer;
  v_schedule_row record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.restructure') then
    raise exception 'Not authorized to restructure loans in this group' using errcode = '42501';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'LOAN_RESTRUCTURE_REASON_REQUIRED' using errcode = '22023';
  end if;

  v_effective_date := coalesce(p_effective_date, current_date);

  if p_new_term is null or p_new_term <= 0 then
    raise exception 'LOAN_RESTRUCTURE_TERM_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_new_first_installment_date is null or p_new_first_installment_date <= v_effective_date then
    raise exception 'LOAN_RESTRUCTURE_FIRST_INSTALLMENT_DATE_MUST_BE_AFTER_EFFECTIVE_DATE' using errcode = '22023';
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

  select coalesce(sum(s.outstanding), 0)
  into v_overdue_outstanding
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date <= v_effective_date;

  if v_overdue_outstanding > 0 then
    raise exception 'LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE' using errcode = 'P0001';
  end if;

  select coalesce(sum(s.outstanding), 0)
  into v_remaining_principal
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
    and s.component_type = 'PRINCIPAL';

  if v_remaining_principal <= 0 then
    raise exception 'LOAN_RESTRUCTURE_NOTHING_REMAINING' using errcode = 'P0001';
  end if;

  v_new_rate := coalesce(p_new_interest_rate, v_loan.interest_rate);
  if v_new_rate < 0 then
    raise exception 'LOAN_RESTRUCTURE_INTEREST_RATE_MUST_BE_NON_NEGATIVE' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb)
  into v_old_remaining
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null;

  select coalesce(max(installment_number), 0) into v_next_installment_number
  from public.loan_installments
  where loan_account_id = p_loan_account_id;

  update public.loan_installments
  set cancelled_at = now(), cancellation_reason = 'RESTRUCTURE'
  where loan_account_id = p_loan_account_id and cancelled_at is null;

  for v_schedule_row in
    select * from public.loan_schedule_compute(
      v_remaining_principal, v_new_rate, v_loan.interest_rate_basis, v_loan.interest_method,
      p_new_term, p_new_first_installment_date
    )
  loop
    v_next_installment_number := v_next_installment_number + 1;
    insert into public.loan_installments (
      group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
    ) values (
      p_group_id, p_loan_account_id, v_next_installment_number, v_schedule_row.due_date,
      v_schedule_row.principal_due, v_schedule_row.interest_due
    );
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb)
  into v_new_schedule
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.installment_number > (v_next_installment_number - p_new_term);

  insert into public.loan_restructure_events (
    group_id, loan_account_id, effective_date, reason, new_interest_rate, new_term,
    new_first_installment_date, old_remaining_schedule_snapshot, new_remaining_schedule_snapshot, created_by
  ) values (
    p_group_id, p_loan_account_id, v_effective_date, p_reason, v_new_rate, p_new_term,
    p_new_first_installment_date, v_old_remaining, v_new_schedule, v_uid
  );

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, metadata, created_by
  ) values (
    p_group_id, p_loan_account_id, 'RESTRUCTURED', v_loan.status, v_loan.status, p_reason,
    jsonb_build_object('new_interest_rate', v_new_rate, 'new_term', p_new_term),
    v_uid
  );

  -- Return the full, current loan account (matching every other
  -- lifecycle RPC's contract, e.g. rpc_approve_loan_account/
  -- rpc_disburse_loan_account) rather than a bespoke minimal shape —
  -- Flutter re-renders the same full loan detail it already knows how
  -- to display, with the new schedule embedded via the existing
  -- installments array.
  return public.rpc_get_loan_account(p_group_id, p_loan_account_id);
end;
$$;
