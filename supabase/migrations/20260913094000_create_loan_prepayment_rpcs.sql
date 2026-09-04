-- Prompt 09E: Partial Principal Prepayment + REDUCE_TERM/
-- REDUCE_INSTALLMENT schedule recalculation.
--
-- loan_schedule_compute_fixed_principal below is REDUCE_TERM's engine:
-- unlike loan_schedule_compute (which freshly re-splits principal
-- equally across a GIVEN term), REDUCE_TERM preserves the loan's
-- existing regular per-installment PRINCIPAL amount (section 4A —
-- "preserve regular installment amount as much as possible") and
-- derives however many installments that takes, with the final
-- installment absorbing the exact remainder — the same
-- reconciliation-on-the-final-installment pattern already locked
-- everywhere else in this codebase (loan_schedule_compute itself,
-- compute_simple_migrated_loan_reconstruction). The interest formulas
-- (FLAT total-then-split; REDUCING_BALANCE per opening balance) are
-- copied byte-for-byte from loan_schedule_compute — no new interest
-- methodology is invented (section 5); an unsupported method is
-- explicitly blocked, never approximated.
--
-- REDUCE_INSTALLMENT needs no new engine at all: it preserves the
-- existing remaining term/due dates and lets principal split fresh
-- across that (unchanged) count — exactly what loan_schedule_compute
-- already does, called directly with the new (reduced) principal.

create or replace function public.loan_schedule_compute_fixed_principal(
  p_new_principal numeric,
  p_installment_principal_amount numeric,
  p_interest_rate numeric,
  p_interest_rate_basis public.loan_interest_rate_basis,
  p_interest_method public.loan_interest_method,
  p_first_installment_date date
)
returns table (
  installment_number integer,
  due_date date,
  principal_due numeric,
  interest_due numeric
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_effective_monthly_rate numeric;
  v_new_term integer;
  v_remainder_principal numeric(14, 2);
  v_total_interest numeric(14, 2);
  v_base_interest numeric(14, 2);
  v_remainder_interest numeric(14, 2);
  v_opening_balance numeric(14, 2);
  i integer;
begin
  if p_installment_principal_amount <= 0 then
    raise exception 'Installment principal amount must be positive' using errcode = '22023';
  end if;

  v_new_term := ceil(p_new_principal / p_installment_principal_amount)::integer;
  if v_new_term <= 0 then
    return;
  end if;

  v_remainder_principal := p_new_principal - (p_installment_principal_amount * (v_new_term - 1));

  v_effective_monthly_rate := case p_interest_rate_basis
    when 'MONTHLY' then p_interest_rate / 100
    when 'ANNUAL' then (p_interest_rate / 100) / 12
  end;

  if p_interest_method = 'FLAT' then
    v_total_interest := round(p_new_principal * v_effective_monthly_rate * v_new_term, 2);
    v_base_interest := trunc(v_total_interest / v_new_term, 2);
    v_remainder_interest := v_total_interest - (v_base_interest * v_new_term);

    for i in 1..v_new_term loop
      installment_number := i;
      due_date := p_first_installment_date + ((i - 1) || ' months')::interval;
      principal_due := case when i = v_new_term then v_remainder_principal else p_installment_principal_amount end;
      interest_due := v_base_interest + (case when i = v_new_term then v_remainder_interest else 0 end);
      return next;
    end loop;

  elsif p_interest_method = 'REDUCING_BALANCE' then
    v_opening_balance := p_new_principal;

    for i in 1..v_new_term loop
      installment_number := i;
      due_date := p_first_installment_date + ((i - 1) || ' months')::interval;
      principal_due := case when i = v_new_term then v_remainder_principal else p_installment_principal_amount end;
      interest_due := round(v_opening_balance * v_effective_monthly_rate, 2);
      return next;

      v_opening_balance := v_opening_balance - principal_due;
    end loop;
  else
    raise exception 'Unsupported interest method for reschedule' using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function public.loan_schedule_compute_fixed_principal(
  numeric, numeric, numeric, public.loan_interest_rate_basis, public.loan_interest_method, date
) from public, anon, authenticated;

comment on function public.loan_schedule_compute_fixed_principal(
  numeric, numeric, numeric, public.loan_interest_rate_basis, public.loan_interest_method, date
) is
  'Locked-down internal helper — REDUCE_TERM''s engine (Prompt 09E
  section 4A). Preserves the given per-installment principal amount,
  shortens the term to fit the new balance, final installment absorbs
  the exact remainder. Same interest formulas as loan_schedule_compute;
  no new methodology.';

-- ---------------------------------------------------------------------
-- loan_prepayment_eligibility — shared gating for both preview and
-- write (section 3 v1 lock): overdue/currently-payable PENALTY and
-- INTEREST must both be zero before any principal prepayment.
-- ---------------------------------------------------------------------

create or replace function public.loan_prepayment_eligibility(
  p_loan_account_id uuid,
  p_effective_date date
)
returns table (
  payable_penalty_outstanding numeric,
  payable_interest_outstanding numeric,
  future_principal_outstanding numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PENALTY' and li.due_date <= p_effective_date), 0),
    coalesce(sum(s.outstanding) filter (where s.component_type = 'INTEREST' and li.due_date <= p_effective_date), 0),
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PRINCIPAL' and li.due_date > p_effective_date), 0)
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null;
$$;

revoke all on function public.loan_prepayment_eligibility(uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_preview_loan_prepayment — read-only (section 3/4). No writes.
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

  if p_effective_date is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

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
  from public.loan_prepayment_eligibility(p_loan_account_id, p_effective_date);

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
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date > p_effective_date;

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
    where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date > p_effective_date
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
    'effective_date', p_effective_date,
    'amount', p_amount,
    'treatment', p_treatment,
    'future_principal_outstanding_before', v_eligibility.future_principal_outstanding,
    'future_principal_outstanding_after', v_new_future_principal,
    'old_future_installments', v_old_future,
    'new_future_installments', v_new_future
  );
end;
$$;

revoke all on function public.rpc_preview_loan_prepayment(
  uuid, uuid, numeric, public.loan_reschedule_treatment, date
) from public;
grant execute on function public.rpc_preview_loan_prepayment(
  uuid, uuid, numeric, public.loan_reschedule_treatment, date
) to authenticated;
revoke execute on function public.rpc_preview_loan_prepayment(
  uuid, uuid, numeric, public.loan_reschedule_treatment, date
) from anon;

-- ---------------------------------------------------------------------
-- rpc_prepay_loan_principal — re-validates everything the preview did
-- (never trusts a client-held preview), then atomically: one payment/
-- cashbook INFLOW, one LOAN_PRINCIPAL_PREPAYMENT allocation (not tied
-- to any installment — section 3), cancels the old future installments
-- (never deletes — section 7) and inserts the recomputed future
-- schedule, continuing the installment_number sequence so the
-- cancelled originals and their replacements never collide.
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

  if p_effective_date is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

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
  from public.loan_prepayment_eligibility(p_loan_account_id, p_effective_date);

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
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date > p_effective_date;

  -- Numbering continues from the highest installment_number EVER
  -- assigned to this loan (including already-cancelled rows), so a
  -- replacement schedule can never collide with the
  -- (loan_account_id, installment_number) unique index.
  select coalesce(max(installment_number), 0) into v_next_installment_number
  from public.loan_installments
  where loan_account_id = p_loan_account_id;

  v_receipt_number := public.payment_generate_receipt_number(p_effective_date);

  insert into public.payments (
    group_id, membership_id, financial_account_id, amount, effective_at,
    payment_method, external_reference, notes, receipt_number, idempotency_key, created_by
  ) values (
    p_group_id, v_loan.membership_id, p_financial_account_id, p_amount, p_effective_date,
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
  where loan_account_id = p_loan_account_id and cancelled_at is null and due_date > p_effective_date;

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
    p_effective_at => p_effective_date,
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
    p_group_id, p_loan_account_id, v_loan.membership_id, v_payment_id, p_effective_date, p_amount, p_treatment,
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

revoke all on function public.rpc_prepay_loan_principal(
  uuid, uuid, numeric, public.loan_reschedule_treatment, uuid, public.payment_method, date, text, text, text
) from public;
grant execute on function public.rpc_prepay_loan_principal(
  uuid, uuid, numeric, public.loan_reschedule_treatment, uuid, public.payment_method, date, text, text, text
) to authenticated;
revoke execute on function public.rpc_prepay_loan_principal(
  uuid, uuid, numeric, public.loan_reschedule_treatment, uuid, public.payment_method, date, text, text, text
) from anon;
