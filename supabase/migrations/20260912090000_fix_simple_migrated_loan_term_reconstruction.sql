-- Prompt 09D-UAT-BLOCKER-04: fixes a blocking accounting/schedule bug
-- found in physical UAT. BLOCKER-03's Simple Import had NO concept of
-- an ORIGINAL LOAN TERM — it silently assumed "historical arrears" +
-- "remaining future installments" accounted for the loan's ENTIRE
-- principal and contracted interest, so whenever some installments had
-- already been paid off before the group started using Umoja (the
-- common case), it redistributed the FULL original principal/interest
-- across only the few remaining future installments — e.g. dividing
-- 20,000,000 principal by 7 remaining installments instead of
-- recognizing that 5 of the original 12 installments were already
-- settled and only the last 7 installments' principal remains
-- outstanding.
--
-- Fix: Simple Import now REQUIRES the original loan term (total
-- contractual installment count). The server reconstructs the FULL
-- original contractual schedule (all `original_term` installments,
-- each carrying the regular contractual installment amount split
-- principal/interest proportionally, except the term's own FINAL
-- installment, which absorbs the exact reconciliation difference
-- against the true original_principal/contracted_interest — never
-- redistributed across every installment), then classifies it
-- oldest-first into PAID_BEFORE_UMOJA / HISTORICAL_OVERDUE / FUTURE:
--
--   paid_before_umoja_count = original_term - historical_unpaid_count
--                             - remaining_future_count
--
-- PAID_BEFORE_UMOJA installments are historical contract context
-- only — never persisted as loan_installments rows, never a fake
-- payment/receipt/cashbook entry/income. Only HISTORICAL_OVERDUE and
-- FUTURE installments become real operational rows, and the opening
-- funded principal receivable is the sum of ONLY their principal
-- portions — never the full original principal.
--
-- Same-signature-extension is NOT possible for
-- compute_simple_migrated_loan_reconstruction (new required
-- parameters change its argument list) or for rpc_create_migrated_loan/
-- rpc_preview_migrated_loan (one new trailing parameter each) — the
-- prior BLOCKER-03 signatures are dropped first, per this project's
-- established convention whenever a signature genuinely changes.

drop function if exists public.compute_simple_migrated_loan_reconstruction(
  numeric, numeric, numeric, integer, numeric, date
);

create function public.compute_simple_migrated_loan_reconstruction(
  p_original_principal numeric,
  p_contracted_interest_amount numeric,
  p_monthly_installment_amount numeric,
  p_original_term integer,
  p_historical_unpaid_count integer,
  p_remaining_future_count integer,
  p_total_historical_arrears numeric,
  p_next_due_date date
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_paid_before_umoja_count integer;
  v_principal_fraction numeric;
  v_regular_principal numeric;
  v_regular_interest numeric;
  v_final_principal numeric;
  v_final_interest numeric;
  v_principal_i numeric;
  v_interest_i numeric;
  v_historical_arr jsonb := '[]'::jsonb;
  v_future_arr jsonb := '[]'::jsonb;
  v_hist_principal_total numeric := 0;
  v_hist_interest_total numeric := 0;
  v_future_principal_total numeric := 0;
  v_future_interest_total numeric := 0;
  v_contractual_historical_arrears numeric := 0;
  v_legacy_penalty_total numeric;
  v_base_penalty numeric;
  v_remainder_penalty numeric;
  v_due_date date;
  v_hist_index integer := 0;
  i integer;
begin
  if p_original_principal is null or p_original_principal <= 0 then
    raise exception 'LOAN_OPENING_ORIGINAL_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if coalesce(p_contracted_interest_amount, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_CONTRACTED_INTEREST_INVALID' using errcode = '22023';
  end if;
  if p_monthly_installment_amount is null or p_monthly_installment_amount <= 0 then
    raise exception 'LOAN_OPENING_SIMPLE_INSTALLMENT_AMOUNT_INVALID' using errcode = '22023';
  end if;
  -- Section B/C: the original loan term is now REQUIRED for Simple
  -- Import — without it the server cannot distinguish installments
  -- already settled before Umoja from genuinely outstanding ones.
  if p_original_term is null or p_original_term <= 0 then
    raise exception 'LOAN_OPENING_SIMPLE_ORIGINAL_TERM_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_historical_unpaid_count, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_HISTORICAL_COUNT_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_remaining_future_count, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_REMAINING_COUNT_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_total_historical_arrears, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_TOTAL_ARREARS_INVALID' using errcode = '22023';
  end if;

  -- Section D: the core derivation and its guard.
  v_paid_before_umoja_count := p_original_term - p_historical_unpaid_count - p_remaining_future_count;
  if v_paid_before_umoja_count < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_COUNTS_EXCEED_TERM' using errcode = '22023';
  end if;

  if (p_historical_unpaid_count > 0 or p_remaining_future_count > 0) and p_next_due_date is null then
    raise exception 'LOAN_OPENING_NEXT_DUE_DATE_REQUIRED' using errcode = '22023';
  end if;

  if (p_original_principal + p_contracted_interest_amount) <= 0 then
    raise exception 'LOAN_OPENING_SIMPLE_CONTRACTED_INTEREST_INVALID' using errcode = '22023';
  end if;
  v_principal_fraction := p_original_principal / (p_original_principal + p_contracted_interest_amount);

  -- Section F/Q: reconstruct the ORIGINAL full contractual schedule —
  -- every installment carries the regular contractual amount
  -- (principal/interest split proportionally, rounded once) EXCEPT the
  -- term's own final installment, which absorbs the EXACT
  -- reconciliation difference against the true original_principal/
  -- contracted_interest totals. This is computed ONCE up front,
  -- independently of which installments turn out to be paid/historical/
  -- future — classification never changes an installment's amount.
  v_regular_principal := round(p_monthly_installment_amount * v_principal_fraction, 2);
  v_regular_interest := p_monthly_installment_amount - v_regular_principal;
  v_final_principal := p_original_principal - v_regular_principal * (p_original_term - 1);
  v_final_interest := p_contracted_interest_amount - v_regular_interest * (p_original_term - 1);

  -- Section G: classify oldest-first — paid_before_umoja_count first,
  -- then historical_unpaid_count, then remaining_future_count.
  for i in 1..p_original_term loop
    if i = p_original_term then
      v_principal_i := v_final_principal;
      v_interest_i := v_final_interest;
    else
      v_principal_i := v_regular_principal;
      v_interest_i := v_regular_interest;
    end if;

    if i <= v_paid_before_umoja_count then
      -- Section H: PAID_BEFORE_UMOJA — historical contract context
      -- only. Never persisted, never a fake payment/receipt/cashbook
      -- row.
      continue;
    elsif i <= v_paid_before_umoja_count + p_historical_unpaid_count then
      v_hist_index := v_hist_index + 1;
      v_due_date := (p_next_due_date - make_interval(months => p_historical_unpaid_count - v_hist_index + 1))::date;
      v_hist_principal_total := v_hist_principal_total + v_principal_i;
      v_hist_interest_total := v_hist_interest_total + v_interest_i;
      v_contractual_historical_arrears := v_contractual_historical_arrears + v_principal_i + v_interest_i;
      v_historical_arr := v_historical_arr || jsonb_build_object(
        'due_date', v_due_date,
        'principal_outstanding', v_principal_i,
        'interest_outstanding', v_interest_i
      );
    else
      v_due_date := (p_next_due_date + make_interval(
        months => i - (v_paid_before_umoja_count + p_historical_unpaid_count) - 1
      ))::date;
      v_future_principal_total := v_future_principal_total + v_principal_i;
      v_future_interest_total := v_future_interest_total + v_interest_i;
      v_future_arr := v_future_arr || jsonb_build_object(
        'due_date', v_due_date,
        'principal_outstanding', v_principal_i,
        'interest_outstanding', v_interest_i
      );
    end if;
  end loop;

  -- Section D/E: reject rather than silently create a negative
  -- penalty. Uses the ACTUAL reconstructed historical total (never a
  -- naive historical_unpaid_count x monthly_installment_amount
  -- multiplication), so the rare case where the historical range
  -- itself includes the term's adjusted final installment still
  -- reconciles exactly.
  if p_total_historical_arrears < v_contractual_historical_arrears then
    raise exception 'LOAN_OPENING_SIMPLE_ARREARS_BELOW_CONTRACTUAL' using errcode = '22023';
  end if;
  v_legacy_penalty_total := p_total_historical_arrears - v_contractual_historical_arrears;

  -- Section H (BLOCKER-03, unchanged rule): equal split of the legacy
  -- penalty across the historical installments, remainder on the most
  -- recent one — an import allocation only, never a reconstruction of
  -- actual historical penalty assessment history.
  if p_historical_unpaid_count > 0 and v_legacy_penalty_total > 0 then
    v_base_penalty := trunc(v_legacy_penalty_total / p_historical_unpaid_count, 2);
    v_remainder_penalty := v_legacy_penalty_total - v_base_penalty * p_historical_unpaid_count;
    v_historical_arr := (
      select coalesce(jsonb_agg(
        case when t.ord = jsonb_array_length(v_historical_arr)
          then t.elem || jsonb_build_object('opening_penalty_outstanding', v_base_penalty + v_remainder_penalty)
          else t.elem || jsonb_build_object('opening_penalty_outstanding', v_base_penalty)
        end
        order by t.ord
      ), '[]'::jsonb)
      from jsonb_array_elements(v_historical_arr) with ordinality as t(elem, ord)
    );
  else
    v_historical_arr := (
      select coalesce(jsonb_agg(t.elem || jsonb_build_object('opening_penalty_outstanding', 0) order by t.ord), '[]'::jsonb)
      from jsonb_array_elements(v_historical_arr) with ordinality as t(elem, ord)
    );
  end if;

  return jsonb_build_object(
    'paid_before_umoja_count', v_paid_before_umoja_count,
    'contractual_historical_arrears', v_contractual_historical_arrears,
    'legacy_penalty_total', v_legacy_penalty_total,
    'historical_installments', v_historical_arr,
    'future_installments', v_future_arr,
    -- Section I: NEVER original_principal automatically — only the
    -- principal portions of the installments that remain outstanding
    -- (historical overdue + future), excluding whatever was already
    -- settled before Umoja.
    'opening_principal_outstanding', v_hist_principal_total + v_future_principal_total,
    'future_scheduled_principal', v_future_principal_total,
    'future_scheduled_interest', v_future_interest_total
  );
end;
$$;

revoke all on function public.compute_simple_migrated_loan_reconstruction(
  numeric, numeric, numeric, integer, integer, integer, numeric, date
) from public, anon, authenticated;

comment on function public.compute_simple_migrated_loan_reconstruction is
  'Prompt 09D-UAT-BLOCKER-04: reconstructs the FULL original contractual
  schedule (original_term installments) and classifies it oldest-first
  into PAID_BEFORE_UMOJA / HISTORICAL_OVERDUE / FUTURE before deriving
  any opening figures. Fixes the BLOCKER-03 bug that redistributed the
  entire original principal/interest across only the remaining future
  installments whenever some installments had already been settled
  before Umoja. Shared by rpc_preview_migrated_loan and
  rpc_create_migrated_loan (SIMPLE mode).';

-- ---------------------------------------------------------------------
-- rpc_create_migrated_loan — adds p_original_term; in SIMPLE mode the
-- future installments are now taken DIRECTLY from the reconstruction's
-- own future_installments array (each with its correct, individually
-- reconstructed principal/interest split) instead of re-splitting an
-- aggregate future total evenly across p_remaining_installment_count —
-- the second half of this blocker's fix (section Q: a regular
-- contractual installment must never be redistributed into a different
-- repeated value). DETAILED mode's future-generation loop is completely
-- unchanged (it has no per-installment contractual-amount concept to
-- reconstruct from).
-- ---------------------------------------------------------------------

drop function if exists public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric
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
  p_idempotency_key text default null,
  p_mode text default 'DETAILED',
  p_contracted_interest_amount numeric default null,
  p_monthly_installment_amount numeric default null,
  p_historical_unpaid_count integer default null,
  p_total_historical_arrears numeric default null,
  p_original_term integer default null
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
  v_simple_future_installments jsonb;
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

  if p_mode = 'SIMPLE' then
    v_simple_result := public.compute_simple_migrated_loan_reconstruction(
      p_original_principal, p_contracted_interest_amount, p_monthly_installment_amount,
      p_original_term, p_historical_unpaid_count, p_remaining_installment_count,
      p_total_historical_arrears, p_next_due_date
    );
    p_historical_arrears_installments := v_simple_result->'historical_installments';
    p_opening_principal_outstanding := (v_simple_result->>'opening_principal_outstanding')::numeric;
    p_future_scheduled_interest := (v_simple_result->>'future_scheduled_interest')::numeric;
    v_simple_future_installments := v_simple_result->'future_installments';
  end if;

  if coalesce(p_opening_principal_outstanding, -1) < 0 then
    raise exception 'LOAN_OPENING_PRINCIPAL_OUTSTANDING_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_future_scheduled_interest, -1) < 0 then
    raise exception 'LOAN_OPENING_FUTURE_INTEREST_INVALID' using errcode = '22023';
  end if;

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
    if v_simple_future_installments is not null then
      -- Section F/Q: each future installment comes DIRECTLY from the
      -- full-contract reconstruction — never re-split evenly from an
      -- aggregate total, which is exactly what produced the
      -- BLOCKER-03 bug (dividing 20,000,000/7 instead of using the
      -- true remaining principal per contractual installment).
      for v_row in
        select value from jsonb_array_elements(v_simple_future_installments) order by (value->>'due_date')::date
      loop
        v_installment_number := v_installment_number + 1;
        insert into public.loan_installments (
          group_id, loan_account_id, installment_number, due_date, principal_due, interest_due
        ) values (
          p_group_id, v_loan_id, v_installment_number, (v_row.value->>'due_date')::date,
          (v_row.value->>'principal_outstanding')::numeric, (v_row.value->>'interest_outstanding')::numeric
        );
      end loop;
    else
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
  text, numeric, numeric, integer, numeric, integer
) from public;
grant execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric, integer
) to authenticated;
revoke execute on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric, integer
) from anon;

comment on function public.rpc_create_migrated_loan(
  uuid, uuid, uuid, numeric, date, date, numeric, jsonb, numeric, integer, date, text, text, text,
  text, numeric, numeric, integer, numeric, integer
) is
  'Prompt 09D-UAT-BLOCKER-01/02/03/04: the sole, atomic way to onboard a
  loan already funded before Umoja. SIMPLE mode now requires
  p_original_term and recomputes the historical AND future installment
  arrays via compute_simple_migrated_loan_reconstruction, which
  correctly excludes installments already paid off before Umoja from
  the opening funded principal receivable.';

-- ---------------------------------------------------------------------
-- rpc_preview_migrated_loan — same fix, plus returns
-- paid_before_umoja_count for the Simple Import live summary/Schedule
-- Preview (section N/O).
-- ---------------------------------------------------------------------

drop function if exists public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric
);

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
  p_total_historical_arrears numeric default null,
  p_original_term integer default null
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
  v_simple_future_installments jsonb;
  v_paid_before_umoja_count integer;
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
      p_original_term, p_historical_unpaid_count, p_remaining_installment_count,
      p_total_historical_arrears, p_next_due_date
    );
    v_arrears := v_simple_result->'historical_installments';
    v_simple_future_installments := v_simple_result->'future_installments';
    v_paid_before_umoja_count := (v_simple_result->>'paid_before_umoja_count')::integer;
    v_opening_principal_outstanding := (v_simple_result->>'opening_principal_outstanding')::numeric;
    v_future_scheduled_interest := (v_simple_result->>'future_scheduled_interest')::numeric;
    v_contractual_historical_arrears := (v_simple_result->>'contractual_historical_arrears')::numeric;
    v_legacy_penalty_total := (v_simple_result->>'legacy_penalty_total')::numeric;
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

    if v_simple_future_installments is not null then
      for v_row in
        select value from jsonb_array_elements(v_simple_future_installments) order by (value->>'due_date')::date
      loop
        v_principal := (v_row.value->>'principal_outstanding')::numeric;
        v_interest := (v_row.value->>'interest_outstanding')::numeric;
        v_future_preview := v_future_preview || jsonb_build_object(
          'due_date', (v_row.value->>'due_date')::date,
          'principal_outstanding', v_principal,
          'interest_outstanding', v_interest,
          'opening_penalty_outstanding', 0,
          'total_contractual_amount', v_principal + v_interest,
          'status', 'UPCOMING'
        );
      end loop;
    else
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
  end if;

  return jsonb_build_object(
    'mode', p_mode,
    'paid_before_umoja_count', v_paid_before_umoja_count,
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
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric, integer
) from public;
grant execute on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric, integer
) to authenticated;
revoke execute on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric, integer
) from anon;

comment on function public.rpc_preview_migrated_loan(
  uuid, uuid, uuid, numeric, date, numeric, jsonb, numeric, integer, date, text, numeric, numeric, integer, numeric, integer
) is
  'Prompt 09D-UAT-BLOCKER-04: adds p_original_term and
  paid_before_umoja_count to the SIMPLE-mode preview; future
  installments now come directly from
  compute_simple_migrated_loan_reconstruction, never re-split from an
  aggregate total.';
