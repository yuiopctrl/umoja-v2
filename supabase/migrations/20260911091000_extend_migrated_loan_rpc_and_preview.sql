-- Prompt 09D-UAT-BLOCKER-03: wires SIMPLE-mode reconstruction into
-- rpc_create_migrated_loan (section D-H) and adds
-- rpc_preview_migrated_loan — a server-authoritative, non-persisting
-- preview step required before any migrated loan can be posted
-- (section J/K/O). New trailing parameters only, all with defaults —
-- but a Postgres function's identity is its ordered ARGUMENT TYPE list
-- regardless of defaults, so adding 5 new parameters is a genuine
-- signature change (a `create or replace` here would silently create a
-- SECOND overloaded function instead of replacing BLOCKER-02's, leaving
-- calls that could match either ambiguous — "is not unique"). The old
-- 14-arg signature is dropped first.

drop function if exists public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text
);

-- ---------------------------------------------------------------------
-- rpc_create_migrated_loan — adds p_mode ('DETAILED' default, unchanged
-- behavior, or 'SIMPLE') plus the four SIMPLE-mode contract inputs. In
-- SIMPLE mode, p_historical_arrears_installments,
-- p_opening_principal_outstanding, and p_future_scheduled_interest are
-- IGNORED and overwritten with the server-authoritative reconstruction
-- (section P: Flutter never submits a computed total as truth in
-- SIMPLE mode — only the raw contract figures are accepted). Every
-- other line of the function — validation, the historical-installment
-- insert loop, the future-schedule insert loop, the opening-position
-- row, the MIGRATED event — is completely unchanged from BLOCKER-02.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_migrated_loan(
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
  p_idempotency_key text default null,
  p_mode text default 'DETAILED',
  p_contracted_interest_amount numeric default null,
  p_monthly_installment_amount numeric default null,
  p_historical_unpaid_count integer default null,
  p_total_historical_arrears numeric default null
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
  v_simple_result jsonb;
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

  if p_mode not in ('SIMPLE', 'DETAILED') then
    raise exception 'LOAN_OPENING_MODE_INVALID' using errcode = '22023';
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

  -- ---------------------------------------------------------------
  -- Section D-H: in SIMPLE mode, the historical array, opening
  -- principal outstanding, and future scheduled interest are NEVER
  -- taken from the caller — they are entirely recomputed here from the
  -- raw contract inputs via the SAME function rpc_preview_migrated_loan
  -- uses, so a stale/tampered preview payload can never become
  -- authoritative (section P).
  -- ---------------------------------------------------------------

  if p_mode = 'SIMPLE' then
    v_simple_result := public.compute_simple_migrated_loan_reconstruction(
      p_original_principal, p_contracted_interest_amount, p_monthly_installment_amount,
      p_historical_unpaid_count, p_total_historical_arrears, p_next_due_date
    );
    p_historical_arrears_installments := v_simple_result->'historical_installments';
    p_opening_principal_outstanding := (v_simple_result->>'opening_principal_outstanding')::numeric;
    p_future_scheduled_interest := (v_simple_result->>'future_scheduled_interest')::numeric;
  end if;

  if coalesce(p_opening_principal_outstanding, -1) < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_OUTSTANDING_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_future_scheduled_interest, -1) < 0 then
    raise exception 'LOAN_OPENING_FUTURE_INTEREST_INVALID' using errcode = '22023';
  end if;

  -- ---------------------------------------------------------------
  -- Section 3/26 (BLOCKER-02, unchanged): validate the repeatable
  -- historical arrears collection. Zero rows is valid. No fixed
  -- maximum.
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

  v_future_scheduled_principal := p_opening_principal_outstanding - v_arrears_principal_total;
  if v_future_scheduled_principal < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_ARREARS_EXCEEDS_OUTSTANDING' using errcode = '22023';
  end if;

  v_has_future := v_future_scheduled_principal > 0 or p_future_scheduled_interest > 0;

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
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric
) from public;
grant execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric
) to authenticated;
revoke execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric
) from anon;

comment on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric
) is
  'Prompt 09D-UAT-BLOCKER-01/02/03: the sole, atomic way to onboard a
  loan already funded before Umoja. p_mode = DETAILED (default) accepts
  p_historical_arrears_installments directly, exactly as BLOCKER-02.
  p_mode = SIMPLE instead accepts p_contracted_interest_amount/
  p_monthly_installment_amount/p_historical_unpaid_count/
  p_total_historical_arrears and recomputes the historical array,
  opening principal outstanding, and future scheduled interest itself
  via compute_simple_migrated_loan_reconstruction — any value the
  caller passes for those three in SIMPLE mode is ignored/overwritten,
  so the same schedule is authoritatively recomputed at posting
  regardless of what rpc_preview_migrated_loan previously returned.';

-- ---------------------------------------------------------------------
-- rpc_preview_migrated_loan — section J/K/O: an explicit,
-- server-authoritative preview step required before Post, for BOTH
-- modes. Touches ZERO tables — no loan account, opening position,
-- installment, penalty charge, or cashbook entry is ever created here.
-- Returns the full historical + future schedule (with per-installment
-- status), the aggregate figures, and a zero-cash/zero-income
-- accounting preview. DETAILED-mode preview performs a lighter,
-- structural validation only (array shape, aggregate sums) — the full
-- per-row semantic validation (due date ordering, duplicate detection,
-- non-negative/non-empty components) remains authoritative at
-- rpc_create_migrated_loan exactly as BLOCKER-02 already enforced it;
-- this keeps preview cheap while still surfacing the SIMPLE-mode
-- validation failures (arrears-below-contractual, etc.) that this
-- blocker specifically requires the preview step to catch before Post.
-- ---------------------------------------------------------------------

create function public.rpc_preview_migrated_loan(
  p_group_id uuid,
  p_membership_id uuid,
  p_loan_product_id uuid,
  p_original_principal numeric,
  p_opening_as_of_date date,
  p_opening_principal_outstanding numeric default null,
  p_historical_arrears_installments jsonb default '[]'::jsonb,
  p_future_scheduled_interest numeric default 0,
  p_remaining_installment_count integer default 0,
  p_next_due_date date default null,
  p_mode text default 'DETAILED',
  p_contracted_interest_amount numeric default null,
  p_monthly_installment_amount numeric default null,
  p_historical_unpaid_count integer default null,
  p_total_historical_arrears numeric default null
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
  v_product record;
  v_arrears jsonb;
  v_simple_result jsonb;
  v_opening_principal_outstanding numeric;
  v_future_scheduled_interest numeric;
  v_contractual_historical_arrears numeric;
  v_legacy_penalty_total numeric;
  v_future_contractual_total_informational numeric;
  v_arrears_principal_total numeric := 0;
  v_arrears_interest_total numeric := 0;
  v_arrears_penalty_total numeric := 0;
  v_future_scheduled_principal numeric;
  v_has_future boolean;
  v_historical_preview jsonb := '[]'::jsonb;
  v_future_preview jsonb := '[]'::jsonb;
  v_row record;
  v_due_date date;
  v_principal numeric;
  v_interest numeric;
  v_penalty numeric;
  v_base_principal numeric;
  v_remainder_principal numeric;
  v_base_interest numeric;
  v_remainder_interest numeric;
  i integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_opening.create') then
    raise exception 'Not authorized to add existing loans in this group' using errcode = '42501';
  end if;

  if p_mode not in ('SIMPLE', 'DETAILED') then
    raise exception 'LOAN_OPENING_MODE_INVALID' using errcode = '22023';
  end if;

  select id, group_id into v_membership
  from public.group_memberships
  where id = p_membership_id;
  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id, group_id, is_active into v_product
  from public.loan_products
  where id = p_loan_product_id;
  if v_product.group_id is null or v_product.group_id <> p_group_id then
    raise exception 'Loan product not found in group' using errcode = '22023';
  end if;

  if p_original_principal is null or p_original_principal <= 0 then
    raise exception 'LOAN_OPENING_ORIGINAL_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_mode = 'SIMPLE' then
    v_simple_result := public.compute_simple_migrated_loan_reconstruction(
      p_original_principal, p_contracted_interest_amount, p_monthly_installment_amount,
      p_historical_unpaid_count, p_total_historical_arrears, p_next_due_date
    );
    v_arrears := v_simple_result->'historical_installments';
    v_opening_principal_outstanding := (v_simple_result->>'opening_principal_outstanding')::numeric;
    v_future_scheduled_interest := (v_simple_result->>'future_scheduled_interest')::numeric;
    v_contractual_historical_arrears := (v_simple_result->>'contractual_historical_arrears')::numeric;
    v_legacy_penalty_total := (v_simple_result->>'legacy_penalty_total')::numeric;
    -- Informational only (section G/M): what the OLD ledger would have
    -- collected per the flat monthly installment figure — distinct from
    -- future_scheduled_principal/interest below, which is the EXACT
    -- accounting complement of original_principal/contracted_interest
    -- and is what actually gets persisted/reconciled structurally.
    v_future_contractual_total_informational := coalesce(p_remaining_installment_count, 0) * p_monthly_installment_amount;
  else
    v_arrears := coalesce(p_historical_arrears_installments, '[]'::jsonb);
    if jsonb_typeof(v_arrears) <> 'array' then
      raise exception 'LOAN_OPENING_ARREARS_INSTALLMENTS_INVALID' using errcode = '22023';
    end if;
    v_opening_principal_outstanding := coalesce(p_opening_principal_outstanding, 0);
    v_future_scheduled_interest := coalesce(p_future_scheduled_interest, 0);
  end if;

  for v_row in select value from jsonb_array_elements(v_arrears) order by (value->>'due_date')::date loop
    v_due_date := (v_row.value->>'due_date')::date;
    v_principal := coalesce((v_row.value->>'principal_outstanding')::numeric, 0);
    v_interest := coalesce((v_row.value->>'interest_outstanding')::numeric, 0);
    v_penalty := coalesce((v_row.value->>'opening_penalty_outstanding')::numeric, 0);

    v_arrears_principal_total := v_arrears_principal_total + v_principal;
    v_arrears_interest_total := v_arrears_interest_total + v_interest;
    v_arrears_penalty_total := v_arrears_penalty_total + v_penalty;

    v_historical_preview := v_historical_preview || jsonb_build_object(
      'due_date', v_due_date,
      'principal_outstanding', v_principal,
      'interest_outstanding', v_interest,
      'opening_penalty_outstanding', v_penalty,
      'total_contractual_amount', v_principal + v_interest + v_penalty,
      'status', 'OVERDUE'
    );
  end loop;

  v_future_scheduled_principal := v_opening_principal_outstanding - v_arrears_principal_total;
  if v_future_scheduled_principal < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_ARREARS_EXCEEDS_OUTSTANDING' using errcode = '22023';
  end if;
  v_has_future := v_future_scheduled_principal > 0 or v_future_scheduled_interest > 0;

  if v_has_future then
    if coalesce(p_remaining_installment_count, 0) <= 0 then
      raise exception 'LOAN_OPENING_REMAINING_SCHEDULE_INCONSISTENT' using errcode = '22023';
    end if;
    if p_next_due_date is null then
      raise exception 'LOAN_OPENING_NEXT_DUE_DATE_REQUIRED' using errcode = '22023';
    end if;

    v_base_principal := trunc(v_future_scheduled_principal / p_remaining_installment_count, 2);
    v_remainder_principal := v_future_scheduled_principal - v_base_principal * p_remaining_installment_count;
    v_base_interest := trunc(v_future_scheduled_interest / p_remaining_installment_count, 2);
    v_remainder_interest := v_future_scheduled_interest - v_base_interest * p_remaining_installment_count;

    for i in 1..p_remaining_installment_count loop
      v_due_date := (p_next_due_date + make_interval(months => i - 1))::date;
      v_principal := v_base_principal + (case when i = p_remaining_installment_count then v_remainder_principal else 0 end);
      v_interest := v_base_interest + (case when i = p_remaining_installment_count then v_remainder_interest else 0 end);
      v_future_preview := v_future_preview || jsonb_build_object(
        'due_date', v_due_date,
        'principal_outstanding', v_principal,
        'interest_outstanding', v_interest,
        'opening_penalty_outstanding', 0,
        'total_contractual_amount', v_principal + v_interest,
        'status', 'UPCOMING'
      );
    end loop;
  end if;

  return jsonb_build_object(
    'mode', p_mode,
    'historical_installments', v_historical_preview,
    'future_installments', v_future_preview,
    'contractual_historical_arrears', v_contractual_historical_arrears,
    'legacy_penalty_total', v_legacy_penalty_total,
    'historical_principal_total', v_arrears_principal_total,
    'historical_interest_total', v_arrears_interest_total,
    'historical_penalty_total', v_arrears_penalty_total,
    'total_historical_arrears', v_arrears_principal_total + v_arrears_interest_total + v_arrears_penalty_total,
    'opening_principal_outstanding', v_opening_principal_outstanding,
    'future_scheduled_principal', v_future_scheduled_principal,
    'future_scheduled_interest', v_future_scheduled_interest,
    'future_contractual_total', coalesce(v_future_contractual_total_informational, v_future_scheduled_principal + v_future_scheduled_interest),
    'accounting_impact', jsonb_build_object(
      'cashbook_impact', 0,
      'income_recognized_now', 0,
      'expense_recognized_now', 0,
      'financial_account', null,
      'funded_principal_receivable_change', v_opening_principal_outstanding
    )
  );
end;
$$;

revoke all on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric
) from public;
grant execute on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric
) to authenticated;
revoke execute on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric
) from anon;

comment on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric
) is
  'Prompt 09D-UAT-BLOCKER-03: server-authoritative, non-persisting
  preview of a migrated-loan import (SIMPLE or DETAILED mode) — zero
  tables written. Returns the full historical + future schedule and a
  zero-cash/zero-income accounting preview. rpc_create_migrated_loan
  recomputes the same reconstruction independently at posting time and
  never trusts this payload as input.';
