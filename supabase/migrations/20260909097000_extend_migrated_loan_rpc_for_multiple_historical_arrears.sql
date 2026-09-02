-- Prompt 09D-UAT-BLOCKER-02: a migrated loan may have MULTIPLE separate
-- historical overdue installments (section 1, locked) — never one
-- synthetic arrears row combining them. Replaces
-- rpc_create_migrated_loan's three scalar arrears amounts + single
-- p_arrears_due_date with a repeatable p_historical_arrears_installments
-- JSONB array, each element carrying its OWN due_date, principal/
-- interest outstanding, and opening penalty outstanding.
--
-- Design note (why almost nothing else needed to change): exactly like
-- BLOCKER-01's single arrears row, each historical installment is just
-- an ordinary loan_installments row, and each historical penalty is
-- just an ordinary loan_penalty_charges row (origin = OPENING, sequence
-- 0 — already unique per installment via the existing
-- loan_penalty_charges_installment_sequence_unique index, so schema is
-- untouched). The entire Payment Engine, rpc_assess_loan_penalties
-- (which already loops "for v_installment in ... order by
-- installment_number" — independently per installment), Financial
-- Position, and every read RPC already operate generically over
-- loan_installments/loan_penalty_charges regardless of how many of them
-- a migrated loan has — so this migration touches ONLY the posting RPC.
--
-- loan_opening_positions keeps its existing aggregate columns
-- (opening_principal_arrears/opening_interest_arrears/
-- opening_penalty_arrears/arrears_due_date) for audit/reporting
-- compatibility — they are now DERIVED (SUM/MIN) from the historical
-- array in the same transaction that creates the underlying rows, so
-- they can never drift from the authoritative per-installment detail.
-- Table/column definitions are unchanged — append-only, per project
-- convention; only their comments are refreshed below.

comment on column public.loan_opening_positions.opening_principal_arrears is
  'Prompt 09D-UAT-BLOCKER-02: DERIVED — the sum of principal_outstanding
  across every historical overdue loan_installments row for this loan
  (due_date <= opening_as_of_date). Never an independent input; kept for
  audit/reporting only. The per-installment loan_installments rows are
  authoritative.';
comment on column public.loan_opening_positions.opening_interest_arrears is
  'Prompt 09D-UAT-BLOCKER-02: DERIVED — the sum of interest_outstanding
  across every historical overdue loan_installments row. See
  opening_principal_arrears.';
comment on column public.loan_opening_positions.opening_penalty_arrears is
  'Prompt 09D-UAT-BLOCKER-02: DERIVED — the sum of every OPENING-origin
  loan_penalty_charges row tied to a historical installment of this
  loan. See opening_principal_arrears.';
comment on column public.loan_opening_positions.arrears_due_date is
  'Prompt 09D-UAT-BLOCKER-02: DERIVED — the EARLIEST due date among this
  loan''s historical overdue installments (null when there are none).
  Retained for audit/reporting only; each historical installment keeps
  its own real due date on loan_installments, never collapsed into
  this single column.';

-- ---------------------------------------------------------------------
-- Drop the BLOCKER-01 signature (three scalar arrears amounts + one
-- arrears due date) — a genuine signature change, not a same-signature
-- create-or-replace.
-- ---------------------------------------------------------------------

drop function if exists public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, numeric, numeric, numeric, numeric, integer,
  date, date, text, text, text
);

create function public.rpc_create_migrated_loan(
  p_group_id uuid,
  p_membership_id uuid,
  p_loan_product_id uuid,
  p_original_principal numeric,
  p_original_disbursement_date date,
  p_opening_as_of_date date,
  p_opening_principal_outstanding numeric,
  p_historical_arrears_installments jsonb default '[]'::jsonb,
  p_future_scheduled_interest numeric default 0,
  p_remaining_installment_count integer default 0,
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
  v_arrears jsonb;
  v_arrears_count integer;
  v_distinct_due_dates integer;
  v_row record;
  v_due_date date;
  v_principal_outstanding numeric;
  v_interest_outstanding numeric;
  v_opening_penalty_outstanding numeric;
  v_arrears_principal_total numeric := 0;
  v_arrears_interest_total numeric := 0;
  v_arrears_penalty_total numeric := 0;
  v_earliest_arrears_due_date date;
  v_installment_number integer;
  v_installment_id uuid;
  v_future_scheduled_principal numeric;
  v_has_arrears boolean;
  v_has_future boolean;
  v_base_principal numeric;
  v_base_interest numeric;
  v_remainder_principal numeric;
  v_remainder_interest numeric;
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

  -- Idempotency (unchanged from BLOCKER-01): a retried post with the
  -- same key returns the already-created loan rather than creating a
  -- second one.
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
  if coalesce(p_future_scheduled_interest, -1) < 0 then
    raise exception 'LOAN_OPENING_FUTURE_INTEREST_INVALID' using errcode = '22023';
  end if;

  -- ---------------------------------------------------------------
  -- Section 3/26: validate the repeatable historical arrears
  -- collection. Zero rows is valid (section 27). No fixed maximum.
  -- ---------------------------------------------------------------

  v_arrears := coalesce(p_historical_arrears_installments, '[]'::jsonb);
  if jsonb_typeof(v_arrears) <> 'array' then
    raise exception 'LOAN_OPENING_ARREARS_INSTALLMENTS_INVALID' using errcode = '22023';
  end if;

  for v_row in select value from jsonb_array_elements(v_arrears) loop
    if v_row.value->>'due_date' is null then
      raise exception 'LOAN_OPENING_ARREARS_DUE_DATE_REQUIRED' using errcode = '22023';
    end if;

    v_due_date := (v_row.value->>'due_date')::date;
    v_principal_outstanding := coalesce((v_row.value->>'principal_outstanding')::numeric, 0);
    v_interest_outstanding := coalesce((v_row.value->>'interest_outstanding')::numeric, 0);
    v_opening_penalty_outstanding := coalesce((v_row.value->>'opening_penalty_outstanding')::numeric, 0);

    if v_due_date > p_opening_as_of_date then
      raise exception 'LOAN_OPENING_ARREARS_DUE_DATE_AFTER_AS_OF' using errcode = '22023';
    end if;
    if v_principal_outstanding < 0 or v_interest_outstanding < 0 or v_opening_penalty_outstanding < 0 then
      raise exception 'LOAN_OPENING_ARREARS_COMPONENT_NEGATIVE' using errcode = '22023';
    end if;
    if v_principal_outstanding = 0 and v_interest_outstanding = 0 and v_opening_penalty_outstanding = 0 then
      raise exception 'LOAN_OPENING_ARREARS_ROW_EMPTY' using errcode = '22023';
    end if;

    v_arrears_principal_total := v_arrears_principal_total + v_principal_outstanding;
    v_arrears_interest_total := v_arrears_interest_total + v_interest_outstanding;
    v_arrears_penalty_total := v_arrears_penalty_total + v_opening_penalty_outstanding;
    v_earliest_arrears_due_date := least(coalesce(v_earliest_arrears_due_date, v_due_date), v_due_date);
  end loop;

  select count(*), count(distinct (value->>'due_date'))
  into v_arrears_count, v_distinct_due_dates
  from jsonb_array_elements(v_arrears);

  if v_arrears_count <> v_distinct_due_dates then
    raise exception 'LOAN_OPENING_ARREARS_DUPLICATE_DUE_DATE' using errcode = '22023';
  end if;

  v_has_arrears := v_arrears_count > 0;

  -- Section 6: principal reconciliation is structural — future is
  -- DERIVED, never an independent input that could drift.
  v_future_scheduled_principal := p_opening_principal_outstanding - v_arrears_principal_total;
  if v_future_scheduled_principal < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_ARREARS_EXCEEDS_OUTSTANDING' using errcode = '22023';
  end if;

  v_has_future := v_future_scheduled_principal > 0 or p_future_scheduled_interest > 0;

  -- Section 27/28/48: either half may be empty, but not both.
  if not v_has_arrears and not v_has_future then
    raise exception 'LOAN_OPENING_NO_OUTSTANDING_POSITION' using errcode = 'P0001';
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
    v_arrears_count + coalesce(p_remaining_installment_count, 0),
    v_product.term_unit, v_product.repayment_frequency,
    p_opening_as_of_date, null,
    coalesce(v_earliest_arrears_due_date, p_next_due_date),
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
    p_original_principal, p_opening_principal_outstanding, v_arrears_principal_total,
    v_arrears_interest_total, v_arrears_penalty_total,
    v_future_scheduled_principal, p_future_scheduled_interest,
    v_earliest_arrears_due_date, coalesce(p_remaining_installment_count, 0), p_next_due_date,
    p_notes, p_idempotency_key, v_uid
  );

  -- ---------------------------------------------------------------
  -- Section 1/2/10: one ordinary loan_installments row PER historical
  -- overdue installment, each keeping its own real due date — oldest
  -- first, numbered 1..N. Never collapsed into one synthetic row.
  -- ---------------------------------------------------------------

  v_installment_number := 0;

  for v_row in
    select value from jsonb_array_elements(v_arrears) order by (value->>'due_date')::date
  loop
    v_installment_number := v_installment_number + 1;
    v_due_date := (v_row.value->>'due_date')::date;
    v_principal_outstanding := coalesce((v_row.value->>'principal_outstanding')::numeric, 0);
    v_interest_outstanding := coalesce((v_row.value->>'interest_outstanding')::numeric, 0);
    v_opening_penalty_outstanding := coalesce((v_row.value->>'opening_penalty_outstanding')::numeric, 0);

    insert into public.loan_installments (
      group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
    ) values (
      p_group_id, v_loan_id, v_installment_number, v_due_date,
      v_principal_outstanding, v_interest_outstanding
    )
    returning id into v_installment_id;

    if v_opening_penalty_outstanding > 0 then
      insert into public.loan_penalty_charges (
        group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
        origin, penalty_amount, created_by
      ) values (
        p_group_id, v_loan_id, v_installment_id, v_due_date, 0,
        'OPENING', v_opening_penalty_outstanding, v_uid
      );
    end if;
  end loop;

  if v_has_future then
    v_base_principal := trunc(v_future_scheduled_principal / p_remaining_installment_count, 2);
    v_remainder_principal := v_future_scheduled_principal - v_base_principal * p_remaining_installment_count;
    v_base_interest := trunc(p_future_scheduled_interest / p_remaining_installment_count, 2);
    v_remainder_interest := p_future_scheduled_interest - v_base_interest * p_remaining_installment_count;

    for i in 1..p_remaining_installment_count loop
      v_due_date := (p_next_due_date + make_interval(months => i - 1))::date;

      insert into public.loan_installments (
        group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
      ) values (
        p_group_id, v_loan_id, v_installment_number + i, v_due_date,
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
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text
) from public;
grant execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text
) to authenticated;
revoke execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text
) from anon;

comment on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text
) is
  'Prompt 09D-UAT-BLOCKER-01, extended 09D-UAT-BLOCKER-02: the sole,
  atomic way to onboard a loan already funded before Umoja.
  p_historical_arrears_installments is a JSONB array (each element:
  due_date, principal_outstanding, interest_outstanding,
  opening_penalty_outstanding) — zero or more historical overdue
  installments, each preserved as its OWN loan_installments row (never
  collapsed into one synthetic arrears row) plus an optional OPENING
  loan_penalty_charges row. Creates the immutable opening position, the
  remaining future schedule, sets the loan ACTIVE directly — zero
  cashbook movement, zero income/expense, zero payment/receipt, zero
  loan_disbursements row. Idempotent via p_idempotency_key.';
