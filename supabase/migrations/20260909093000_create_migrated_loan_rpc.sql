-- Prompt 09D-UAT-BLOCKER-01: rpc_create_migrated_loan — the single
-- authoritative, atomic RPC that onboards a loan already funded before
-- the group started using Umoja (section 25). It creates a MIGRATED
-- loan account, its opening position, its (optional) arrears
-- installment, its remaining future schedule, sets the loan ACTIVE
-- directly, and writes exactly one MIGRATED lifecycle event — never a
-- fake SUBMITTED/APPROVED/DISBURSED sequence, never a cashbook entry,
-- never a loan_disbursements row. Any failure rolls back everything
-- (a single Postgres function body is already one transaction) — there
-- is no partially-imported loan.
--
-- Design note (why zero Payment Engine code changes were needed,
-- section 28): an arrears installment is just an ordinary
-- loan_installments row (due_date = arrears_due_date, which may be
-- before opening_as_of_date) and an opening penalty is just an
-- ordinary loan_penalty_charges row (origin = OPENING, sequence 0).
-- Every existing combined-allocation-plan/component-states/closure/
-- Financial-Position derivation already operates generically over
-- loan_installments + loan_penalty_charges regardless of how they were
-- created — so payment, wallet, receipt, reversal, and closure/
-- reopening all work for a migrated loan with NO code changes at all.
-- The ONE genuine exception is Financial Position's disbursed-principal
-- sum, fixed separately (20260909094000).

create or replace function public.rpc_create_migrated_loan(
  p_group_id uuid,
  p_membership_id uuid,
  p_loan_product_id uuid,
  p_original_principal numeric,
  p_original_disbursement_date date,
  p_opening_as_of_date date,
  p_opening_principal_outstanding numeric,
  p_opening_principal_arrears numeric,
  p_opening_interest_arrears numeric,
  p_opening_penalty_arrears numeric,
  p_future_scheduled_interest numeric,
  p_remaining_installment_count integer,
  p_arrears_due_date date default null,
  p_next_due_date date default null,
  p_original_loan_number text default null,
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
  v_product record;
  v_existing_position record;
  v_loan_id uuid;
  v_loan_number text;
  v_future_scheduled_principal numeric;
  v_has_arrears boolean;
  v_has_future boolean;
  v_arrears_installment_id uuid;
  v_installment_number integer;
  v_base_principal numeric;
  v_base_interest numeric;
  v_remainder_principal numeric;
  v_remainder_interest numeric;
  v_due_date date;
  i integer;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_opening.create') then
    raise exception 'Not authorized to add existing loans in this group' using errcode = '42501';
  end if;

  -- Idempotency (section 26): a retried post with the same key returns
  -- the already-created loan rather than creating a second one.
  if p_idempotency_key is not null then
    select * into v_existing_position
    from public.loan_opening_positions
    where group_id = p_group_id and idempotency_key = p_idempotency_key;

    if v_existing_position.id is not null then
      select public.rpc_get_loan_account(p_group_id, v_existing_position.loan_account_id) into v_result;
      return v_result;
    end if;
  end if;

  select id, group_id, status into v_membership
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;
  if v_membership.status <> 'ACTIVE' then
    raise exception 'LOAN_ACCOUNT_BORROWER_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select * into v_product from public.loan_products where id = p_loan_product_id;
  if v_product.group_id is null or v_product.group_id <> p_group_id then
    raise exception 'Loan product not found in group' using errcode = '22023';
  end if;
  if not v_product.is_active then
    raise exception 'LOAN_PRODUCT_INACTIVE' using errcode = 'P0001';
  end if;

  -- Section 47 validation — server-authoritative, never trusted from
  -- Flutter alone.
  if p_original_principal is null or p_original_principal <= 0 then
    raise exception 'LOAN_OPENING_ORIGINAL_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if p_original_principal < v_product.minimum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM' using errcode = '22023';
  end if;
  if v_product.maximum_principal is not null and p_original_principal > v_product.maximum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM' using errcode = '22023';
  end if;
  if p_opening_as_of_date is null then
    raise exception 'Opening as-of date is required' using errcode = '22023';
  end if;
  if p_original_disbursement_date is null then
    raise exception 'Original disbursement date is required' using errcode = '22023';
  end if;
  if coalesce(p_opening_principal_outstanding, -1) < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_OUTSTANDING_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_opening_principal_arrears, -1) < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_ARREARS_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_opening_interest_arrears, -1) < 0 then
    raise exception 'LOAN_OPENING_INTEREST_ARREARS_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_opening_penalty_arrears, -1) < 0 then
    raise exception 'LOAN_OPENING_PENALTY_ARREARS_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_future_scheduled_interest, -1) < 0 then
    raise exception 'LOAN_OPENING_FUTURE_INTEREST_INVALID' using errcode = '22023';
  end if;
  if p_opening_principal_arrears > p_opening_principal_outstanding then
    raise exception 'LOAN_OPENING_PRINCIPAL_ARREARS_EXCEEDS_OUTSTANDING' using errcode = '22023';
  end if;

  v_future_scheduled_principal := p_opening_principal_outstanding - p_opening_principal_arrears;
  v_has_arrears := p_opening_principal_arrears > 0 or p_opening_interest_arrears > 0 or p_opening_penalty_arrears > 0;
  v_has_future := v_future_scheduled_principal > 0 or p_future_scheduled_interest > 0;

  -- Section 48: reject a fully-settled historical loan.
  if not v_has_arrears and not v_has_future then
    raise exception 'LOAN_OPENING_NO_OUTSTANDING_POSITION' using errcode = 'P0001';
  end if;

  if v_has_arrears and p_arrears_due_date is null then
    raise exception 'LOAN_OPENING_ARREARS_DUE_DATE_REQUIRED' using errcode = '22023';
  end if;
  if v_has_arrears and p_arrears_due_date > p_opening_as_of_date then
    raise exception 'LOAN_OPENING_ARREARS_DUE_DATE_AFTER_AS_OF' using errcode = '22023';
  end if;

  if v_has_future then
    if coalesce(p_remaining_installment_count, 0) <= 0 then
      raise exception 'LOAN_OPENING_REMAINING_SCHEDULE_INCONSISTENT' using errcode = '22023';
    end if;
    if p_next_due_date is null then
      raise exception 'LOAN_OPENING_NEXT_DUE_DATE_REQUIRED' using errcode = '22023';
    end if;
  else
    if coalesce(p_remaining_installment_count, 0) <> 0 then
      raise exception 'LOAN_OPENING_REMAINING_SCHEDULE_INCONSISTENT' using errcode = '22023';
    end if;
  end if;

  v_loan_number := public.generate_loan_number(p_group_id, extract(year from current_date)::integer);

  insert into public.loan_accounts (
    group_id, membership_id, loan_product_id, loan_number,
    principal_amount, interest_rate, interest_rate_basis, interest_method,
    term, term_unit, repayment_frequency,
    application_date, proposed_disbursement_date,
    first_repayment_date,
    status, loan_origin,
    penalty_enabled, penalty_type, penalty_frequency, penalty_grace_days,
    penalty_fixed_amount, penalty_rate, penalty_basis,
    created_by, updated_by
  ) values (
    p_group_id, p_membership_id, p_loan_product_id, v_loan_number,
    p_original_principal, v_product.interest_rate, v_product.interest_rate_basis, v_product.interest_method,
    (case when v_has_arrears then 1 else 0 end) + coalesce(p_remaining_installment_count, 0),
    v_product.term_unit, v_product.repayment_frequency,
    p_opening_as_of_date, null,
    coalesce(p_arrears_due_date, p_next_due_date),
    'ACTIVE', 'MIGRATED',
    v_product.penalty_enabled, v_product.penalty_type, v_product.penalty_frequency, v_product.penalty_grace_days,
    v_product.penalty_fixed_amount, v_product.penalty_rate, v_product.penalty_basis,
    v_uid, v_uid
  )
  returning id into v_loan_id;

  insert into public.loan_opening_positions (
    group_id, loan_account_id, opening_as_of_date, original_disbursement_date, original_loan_number,
    original_principal, opening_principal_outstanding, opening_principal_arrears,
    opening_interest_arrears, opening_penalty_arrears,
    future_scheduled_principal, future_scheduled_interest,
    arrears_due_date, remaining_installment_count, next_due_date,
    notes, idempotency_key, created_by
  ) values (
    p_group_id, v_loan_id, p_opening_as_of_date, p_original_disbursement_date, p_original_loan_number,
    p_original_principal, p_opening_principal_outstanding, p_opening_principal_arrears,
    p_opening_interest_arrears, p_opening_penalty_arrears,
    v_future_scheduled_principal, p_future_scheduled_interest,
    p_arrears_due_date, coalesce(p_remaining_installment_count, 0), p_next_due_date,
    p_notes, p_idempotency_key, v_uid
  );

  v_installment_number := 1;

  if v_has_arrears then
    insert into public.loan_installments (
      group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
    ) values (
      p_group_id, v_loan_id, v_installment_number, p_arrears_due_date,
      p_opening_principal_arrears, p_opening_interest_arrears
    )
    returning id into v_arrears_installment_id;

    if p_opening_penalty_arrears > 0 then
      insert into public.loan_penalty_charges (
        group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
        origin, penalty_amount, created_by
      ) values (
        p_group_id, v_loan_id, v_arrears_installment_id, p_arrears_due_date, 0,
        'OPENING', p_opening_penalty_arrears, v_uid
      );
    end if;

    v_installment_number := 2;
  end if;

  if v_has_future then
    -- Same trunc-with-remainder-on-last-installment rounding policy
    -- already locked for the ordinary loan schedule engine (section
    -- "Rounding / exact-money policy") — sum(installments) always
    -- reconstructs the total exactly.
    v_base_principal := trunc(v_future_scheduled_principal / p_remaining_installment_count, 2);
    v_remainder_principal := v_future_scheduled_principal - v_base_principal * p_remaining_installment_count;
    v_base_interest := trunc(p_future_scheduled_interest / p_remaining_installment_count, 2);
    v_remainder_interest := p_future_scheduled_interest - v_base_interest * p_remaining_installment_count;

    for i in 1..p_remaining_installment_count loop
      -- Anchored to next_due_date (never cumulative), the same
      -- month-safe discipline used everywhere else in this project.
      v_due_date := (p_next_due_date + make_interval(months => i - 1))::date;

      insert into public.loan_installments (
        group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
      ) values (
        p_group_id, v_loan_id, v_installment_number + i - 1, v_due_date,
        v_base_principal + (case when i = p_remaining_installment_count then v_remainder_principal else 0 end),
        v_base_interest + (case when i = p_remaining_installment_count then v_remainder_interest else 0 end)
      );
    end loop;
  end if;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
  ) values (
    p_group_id, v_loan_id, 'MIGRATED', null, 'ACTIVE',
    coalesce(p_notes, 'Opening loan position imported'), v_uid
  );

  select public.rpc_get_loan_account(p_group_id, v_loan_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, numeric, numeric, numeric, numeric, integer,
  date, date, text, text, text
) from public;
grant execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, numeric, numeric, numeric, numeric, integer,
  date, date, text, text, text
) to authenticated;
revoke execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, numeric, numeric, numeric, numeric, integer,
  date, date, text, text, text
) from anon;

comment on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, numeric, numeric, numeric, numeric, integer,
  date, date, text, text, text
) is
  'Prompt 09D-UAT-BLOCKER-01: the sole, atomic way to onboard a loan
  already funded before Umoja. Creates a MIGRATED loan account (status
  ACTIVE directly, no fake SUBMITTED/APPROVED/DISBURSED events), its
  immutable opening position, an optional arrears installment (+
  opening penalty charge), and the remaining future schedule — zero
  cashbook movement, zero income/expense, zero payment/receipt, zero
  loan_disbursements row. Idempotent via p_idempotency_key.';
