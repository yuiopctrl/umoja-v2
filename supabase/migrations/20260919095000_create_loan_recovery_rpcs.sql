-- Prompt 09F-B section B: Loan Recovery — a real cash event that
-- reuses the existing Payment Engine's own primitives (payments,
-- payment_generate_receipt_number, financial_account_post_entry,
-- payment_allocations) rather than building any parallel cash
-- mechanism. Allocation priority is locked: PENALTY -> INTEREST ->
-- PRINCIPAL, against the remaining recoverable written-off balance —
-- never the normal installment schedule (a written-off loan is no
-- longer 'ACTIVE', so it is already structurally excluded from every
-- ordinary servicing/allocation path). The loan is NEVER automatically
-- reactivated by a recovery — it remains WRITTEN_OFF regardless of how
-- much is recovered.

create or replace function public.loan_recovery_remaining_balance(
  p_write_off_event_id uuid
)
returns table (
  principal_remaining numeric,
  interest_remaining numeric,
  penalty_remaining numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    greatest(0, w.principal_amount - coalesce((
      select sum(re.principal_recovered)
      from public.loan_recovery_events re
      join public.payments p on p.id = re.payment_id
      where re.write_off_event_id = w.id and p.status = 'POSTED'
    ), 0)),
    greatest(0, w.interest_amount - coalesce((
      select sum(re.interest_recovered)
      from public.loan_recovery_events re
      join public.payments p on p.id = re.payment_id
      where re.write_off_event_id = w.id and p.status = 'POSTED'
    ), 0)),
    greatest(0, w.penalty_amount - coalesce((
      select sum(re.penalty_recovered)
      from public.loan_recovery_events re
      join public.payments p on p.id = re.payment_id
      where re.write_off_event_id = w.id and p.status = 'POSTED'
    ), 0))
  from public.loan_write_off_events w
  where w.id = p_write_off_event_id and w.event_type = 'WRITE_OFF';
$$;

revoke all on function public.loan_recovery_remaining_balance(uuid) from public, anon, authenticated;

comment on function public.loan_recovery_remaining_balance(uuid) is
  'Locked-down internal helper (Prompt 09F-B). The write-off''s own
  frozen amounts minus every non-reversed (payment POSTED) recovery
  against it, per component. Never a stored counter.';

-- ---------------------------------------------------------------------

create or replace function public.loan_recovery_compute_allocation(
  p_write_off_event_id uuid,
  p_amount numeric
)
returns table (
  penalty_allocate numeric,
  interest_allocate numeric,
  principal_allocate numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_remaining record;
  v_left numeric := p_amount;
  v_penalty numeric := 0;
  v_interest numeric := 0;
  v_principal numeric := 0;
begin
  select * into v_remaining
  from public.loan_recovery_remaining_balance(p_write_off_event_id);

  v_penalty := least(v_left, coalesce(v_remaining.penalty_remaining, 0));
  v_left := v_left - v_penalty;

  v_interest := least(v_left, coalesce(v_remaining.interest_remaining, 0));
  v_left := v_left - v_interest;

  v_principal := least(v_left, coalesce(v_remaining.principal_remaining, 0));
  v_left := v_left - v_principal;

  if v_left > 0 then
    raise exception 'LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE' using errcode = 'P0001';
  end if;

  return query select v_penalty, v_interest, v_principal;
end;
$$;

revoke all on function public.loan_recovery_compute_allocation(uuid, numeric) from public, anon, authenticated;

comment on function public.loan_recovery_compute_allocation(uuid, numeric) is
  'Locked-down internal helper (Prompt 09F-B). PENALTY -> INTEREST ->
  PRINCIPAL allocation of p_amount against the write-off''s remaining
  recoverable balance. Rejects any amount that would exceed the total
  remaining recoverable balance (LOAN_RECOVERY_EXCEEDS_REMAINING_
  BALANCE) — never a partial silent clamp.';

-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_loan_recovery(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_amount numeric,
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
  v_write_off record;
  v_remaining_before record;
  v_alloc record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.recovery.create') then
    raise exception 'Not authorized to record loan recoveries in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
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

  if v_loan.status <> 'WRITTEN_OFF' then
    raise exception 'LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF' using errcode = 'P0001';
  end if;

  select * into v_write_off
  from public.loan_write_off_events
  where loan_account_id = p_loan_account_id and event_type = 'WRITE_OFF'
  order by entry_no desc
  limit 1;

  if v_write_off.id is null then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  select * into v_remaining_before
  from public.loan_recovery_remaining_balance(v_write_off.id);

  select * into v_alloc
  from public.loan_recovery_compute_allocation(v_write_off.id, p_amount);

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'write_off_event_id', v_write_off.id,
    'write_off_total_amount', v_write_off.principal_amount + v_write_off.interest_amount + v_write_off.penalty_amount,
    'remaining_before', jsonb_build_object(
      'principal', v_remaining_before.principal_remaining,
      'interest', v_remaining_before.interest_remaining,
      'penalty', v_remaining_before.penalty_remaining,
      'total', v_remaining_before.principal_remaining + v_remaining_before.interest_remaining + v_remaining_before.penalty_remaining
    ),
    'recovery_amount', p_amount,
    'allocation', jsonb_build_object(
      'penalty', v_alloc.penalty_allocate,
      'interest', v_alloc.interest_allocate,
      'principal', v_alloc.principal_allocate
    ),
    'remaining_after', jsonb_build_object(
      'principal', v_remaining_before.principal_remaining - v_alloc.principal_allocate,
      'interest', v_remaining_before.interest_remaining - v_alloc.interest_allocate,
      'penalty', v_remaining_before.penalty_remaining - v_alloc.penalty_allocate,
      'total',
        (v_remaining_before.principal_remaining - v_alloc.principal_allocate)
        + (v_remaining_before.interest_remaining - v_alloc.interest_allocate)
        + (v_remaining_before.penalty_remaining - v_alloc.penalty_allocate)
    ),
    'cash_impact', p_amount,
    'payment_created', true,
    'receipt_created', true
  );
end;
$$;

revoke all on function public.rpc_preview_loan_recovery(uuid, uuid, numeric, date) from public;
grant execute on function public.rpc_preview_loan_recovery(uuid, uuid, numeric, date) to authenticated;
revoke execute on function public.rpc_preview_loan_recovery(uuid, uuid, numeric, date) from anon;

-- ---------------------------------------------------------------------

create or replace function public.rpc_post_loan_recovery(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_amount numeric,
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
  v_write_off record;
  v_alloc record;
  v_existing_recovery record;
  v_receipt_number text;
  v_payment_id uuid;
  v_recovery_event_id uuid;
  v_line_number integer := 1;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.recovery.create') then
    raise exception 'Not authorized to record loan recoveries in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
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
      -- Same full shape as the first-post branch below (recovery_event_id/
      -- write_off_event_id/allocation included) — a client must never
      -- have to branch on already_posted to know which fields exist.
      select re.id, re.write_off_event_id, re.penalty_recovered, re.interest_recovered, re.principal_recovered
      into v_existing_recovery
      from public.loan_recovery_events re
      where re.payment_id = v_existing.id;

      return jsonb_build_object(
        'recovery_event_id', v_existing_recovery.id,
        'payment_id', v_existing.id,
        'receipt_number', v_existing.receipt_number,
        'loan_account_id', p_loan_account_id,
        'write_off_event_id', v_existing_recovery.write_off_event_id,
        'amount', v_existing.amount,
        'allocation', jsonb_build_object(
          'penalty', v_existing_recovery.penalty_recovered,
          'interest', v_existing_recovery.interest_recovered,
          'principal', v_existing_recovery.principal_recovered
        ),
        'already_posted', true,
        'loan_status', v_loan.status
      );
    end if;
  end if;

  if v_loan.status <> 'WRITTEN_OFF' then
    raise exception 'LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF' using errcode = 'P0001';
  end if;

  select * into v_write_off
  from public.loan_write_off_events
  where loan_account_id = p_loan_account_id and event_type = 'WRITE_OFF'
  order by entry_no desc
  limit 1
  for update;

  if v_write_off.id is null then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  -- Recomputed AFTER the loan/write-off row locks above — never trusts
  -- the preview's figure (matching 09E/09F-A's posting discipline).
  select * into v_alloc
  from public.loan_recovery_compute_allocation(v_write_off.id, p_amount);

  v_receipt_number := public.payment_generate_receipt_number(p_effective_date);

  insert into public.payments (
    group_id, membership_id, financial_account_id, amount, effective_at,
    payment_method, external_reference, notes, receipt_number, idempotency_key, created_by
  ) values (
    p_group_id, v_loan.membership_id, p_financial_account_id, p_amount, p_effective_date,
    p_payment_method, p_external_reference, p_notes, v_receipt_number, p_idempotency_key, v_uid
  )
  returning id into v_payment_id;

  if v_alloc.penalty_allocate > 0 then
    insert into public.payment_allocations (
      group_id, payment_id, membership_id, loan_account_id,
      allocation_target_type, amount, line_number, created_by
    ) values (
      p_group_id, v_payment_id, v_loan.membership_id, p_loan_account_id,
      'LOAN_RECOVERY_PENALTY', v_alloc.penalty_allocate, v_line_number, v_uid
    );
    v_line_number := v_line_number + 1;
  end if;

  if v_alloc.interest_allocate > 0 then
    insert into public.payment_allocations (
      group_id, payment_id, membership_id, loan_account_id,
      allocation_target_type, amount, line_number, created_by
    ) values (
      p_group_id, v_payment_id, v_loan.membership_id, p_loan_account_id,
      'LOAN_RECOVERY_INTEREST', v_alloc.interest_allocate, v_line_number, v_uid
    );
    v_line_number := v_line_number + 1;
  end if;

  if v_alloc.principal_allocate > 0 then
    insert into public.payment_allocations (
      group_id, payment_id, membership_id, loan_account_id,
      allocation_target_type, amount, line_number, created_by
    ) values (
      p_group_id, v_payment_id, v_loan.membership_id, p_loan_account_id,
      'LOAN_RECOVERY_PRINCIPAL', v_alloc.principal_allocate, v_line_number, v_uid
    );
    v_line_number := v_line_number + 1;
  end if;

  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'INFLOW',
    p_amount => p_amount,
    p_effective_at => p_effective_date,
    p_uid => v_uid,
    p_description => 'Loan recovery — ' || v_loan.loan_number,
    p_reference => p_external_reference,
    p_source_type => 'LOAN_RECOVERY',
    p_source_id => v_payment_id
  );

  insert into public.loan_recovery_events (
    group_id, loan_account_id, write_off_event_id, payment_id,
    principal_recovered, interest_recovered, penalty_recovered, created_by
  ) values (
    p_group_id, p_loan_account_id, v_write_off.id, v_payment_id,
    v_alloc.principal_allocate, v_alloc.interest_allocate, v_alloc.penalty_allocate, v_uid
  )
  returning id into v_recovery_event_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
  ) values (
    p_group_id, p_loan_account_id, 'RECOVERY_RECORDED', 'WRITTEN_OFF', 'WRITTEN_OFF',
    'Recovery of ' || p_amount::text, v_uid
  );

  return jsonb_build_object(
    'recovery_event_id', v_recovery_event_id,
    'payment_id', v_payment_id,
    'receipt_number', v_receipt_number,
    'loan_account_id', p_loan_account_id,
    'write_off_event_id', v_write_off.id,
    'amount', p_amount,
    'allocation', jsonb_build_object(
      'penalty', v_alloc.penalty_allocate,
      'interest', v_alloc.interest_allocate,
      'principal', v_alloc.principal_allocate
    ),
    'already_posted', false,
    'loan_status', v_loan.status
  );
end;
$$;

revoke all on function public.rpc_post_loan_recovery(uuid, uuid, numeric, uuid, public.payment_method, date, text, text, text) from public;
grant execute on function public.rpc_post_loan_recovery(uuid, uuid, numeric, uuid, public.payment_method, date, text, text, text) to authenticated;
revoke execute on function public.rpc_post_loan_recovery(uuid, uuid, numeric, uuid, public.payment_method, date, text, text, text) from anon;

comment on function public.rpc_post_loan_recovery(uuid, uuid, numeric, uuid, public.payment_method, date, text, text, text) is
  'Prompt 09F-B: records a real cash recovery against a WRITTEN_OFF
  loan''s most recent write-off event, reusing the existing Payment
  Engine primitives (payments, financial_account_post_entry,
  payment_allocations) — never a parallel cash mechanism. Allocation is
  PENALTY -> INTEREST -> PRINCIPAL against the remaining recoverable
  balance, recomputed fresh after locking the loan and write-off rows.
  The loan is NEVER automatically reactivated — it remains WRITTEN_OFF
  regardless of recovery amount.';
