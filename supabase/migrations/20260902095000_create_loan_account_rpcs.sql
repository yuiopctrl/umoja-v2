-- Prompt 09A: Loan Account mutation RPCs — draft creation/editing only
-- (section G/Q). No approval/rejection/disbursement transition exists
-- yet; those belong to Phase 09B.

-- ---------------------------------------------------------------------
-- rpc_preview_loan_schedule — section W step 4: computed BEFORE a
-- loan account exists, so a member/product/terms combination can be
-- reviewed before "Save Draft". Read-only; persists nothing. Uses the
-- exact same loan_schedule_compute() the persisted path uses, so a
-- preview a user saw is guaranteed to match what actually gets saved.
-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_loan_schedule(
  p_group_id uuid,
  p_loan_product_id uuid,
  p_principal_amount numeric,
  p_term integer,
  p_first_repayment_date date
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product record;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.create') then
    raise exception 'Not authorized to create loans in this group' using errcode = '42501';
  end if;

  select * into v_product from public.loan_products where id = p_loan_product_id;
  if v_product.group_id is null or v_product.group_id <> p_group_id then
    raise exception 'Loan product not found in group' using errcode = '22023';
  end if;
  if not v_product.is_active then
    raise exception 'LOAN_PRODUCT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_principal_amount is null or p_principal_amount <= 0 then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if p_principal_amount < v_product.minimum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM' using errcode = '22023';
  end if;
  if v_product.maximum_principal is not null and p_principal_amount > v_product.maximum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM' using errcode = '22023';
  end if;
  if p_term is null or p_term < v_product.minimum_term or p_term > v_product.maximum_term then
    raise exception 'LOAN_ACCOUNT_TERM_OUT_OF_PRODUCT_RANGE' using errcode = '22023';
  end if;
  if p_first_repayment_date is null then
    raise exception 'First repayment date is required' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(to_jsonb(s) order by s.installment_number), '[]'::jsonb) into v_items
  from public.loan_schedule_compute(
    p_principal_amount, v_product.interest_rate, v_product.interest_rate_basis,
    v_product.interest_method, p_term, p_first_repayment_date
  ) s;

  return jsonb_build_object(
    'principal_amount', p_principal_amount,
    'interest_rate', v_product.interest_rate,
    'interest_rate_basis', v_product.interest_rate_basis,
    'interest_method', v_product.interest_method,
    'term', p_term,
    'first_repayment_date', p_first_repayment_date,
    'installments', v_items
  );
end;
$$;

revoke all on function public.rpc_preview_loan_schedule(uuid, uuid, numeric, integer, date) from public;
grant execute on function public.rpc_preview_loan_schedule(uuid, uuid, numeric, integer, date) to authenticated;
revoke execute on function public.rpc_preview_loan_schedule(uuid, uuid, numeric, integer, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_create_draft_loan_account — section F/H/I: snapshots the
-- product's financial terms, validates the borrower's membership,
-- generates a server-authoritative loan number, and generates the
-- initial PLANNED schedule — all in one transaction.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_draft_loan_account(
  p_group_id uuid,
  p_membership_id uuid,
  p_loan_product_id uuid,
  p_principal_amount numeric,
  p_term integer,
  p_first_repayment_date date,
  p_proposed_disbursement_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product record;
  v_membership record;
  v_loan_number text;
  v_loan_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.create') then
    raise exception 'Not authorized to create loans in this group' using errcode = '42501';
  end if;

  -- Borrower rule (section H): membership, never user_id directly;
  -- must belong to this same group and be an ACTIVE member.
  select id, group_id, status into v_membership
  from public.group_memberships
  where id = p_membership_id;

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

  if p_principal_amount is null or p_principal_amount <= 0 then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if p_principal_amount < v_product.minimum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM' using errcode = '22023';
  end if;
  if v_product.maximum_principal is not null and p_principal_amount > v_product.maximum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM' using errcode = '22023';
  end if;
  if p_term is null or p_term < v_product.minimum_term or p_term > v_product.maximum_term then
    raise exception 'LOAN_ACCOUNT_TERM_OUT_OF_PRODUCT_RANGE' using errcode = '22023';
  end if;
  if p_first_repayment_date is null then
    raise exception 'First repayment date is required' using errcode = '22023';
  end if;

  v_loan_number := public.generate_loan_number(p_group_id, extract(year from current_date)::integer);

  insert into public.loan_accounts (
    group_id, membership_id, loan_product_id, loan_number,
    principal_amount, interest_rate, interest_rate_basis, interest_method,
    term, term_unit, repayment_frequency,
    proposed_disbursement_date, first_repayment_date,
    created_by, updated_by
  ) values (
    p_group_id, p_membership_id, p_loan_product_id, v_loan_number,
    p_principal_amount, v_product.interest_rate, v_product.interest_rate_basis, v_product.interest_method,
    p_term, v_product.term_unit, v_product.repayment_frequency,
    p_proposed_disbursement_date, p_first_repayment_date,
    v_uid, v_uid
  )
  returning id into v_loan_id;

  perform public.loan_schedule_generate(v_loan_id);

  select public.rpc_get_loan_account(p_group_id, v_loan_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_create_draft_loan_account(
  uuid, uuid, uuid, numeric, integer, date, date
) from public;
grant execute on function public.rpc_create_draft_loan_account(
  uuid, uuid, uuid, numeric, integer, date, date
) to authenticated;
revoke execute on function public.rpc_create_draft_loan_account(
  uuid, uuid, uuid, numeric, integer, date, date
) from anon;

-- ---------------------------------------------------------------------
-- rpc_update_draft_loan_terms — DRAFT only (section P/U). Re-validates
-- against the loan's own linked product's current min/max bounds
-- (a boundary check, not a re-snapshot: the product's rate/method are
-- never re-copied here, only used to bound principal/term), then
-- regenerates the schedule atomically.
-- ---------------------------------------------------------------------

create or replace function public.rpc_update_draft_loan_terms(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_principal_amount numeric default null,
  p_term integer default null,
  p_first_repayment_date date default null,
  p_proposed_disbursement_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_product record;
  v_new_principal numeric;
  v_new_term integer;
  v_new_first_repayment_date date;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.edit') then
    raise exception 'Not authorized to edit loans in this group' using errcode = '42501';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;
  if v_loan.status <> 'DRAFT' then
    raise exception 'LOAN_ACCOUNT_NOT_DRAFT' using errcode = 'P0001';
  end if;

  select * into v_product from public.loan_products where id = v_loan.loan_product_id;

  v_new_principal := coalesce(p_principal_amount, v_loan.principal_amount);
  v_new_term := coalesce(p_term, v_loan.term);
  v_new_first_repayment_date := coalesce(p_first_repayment_date, v_loan.first_repayment_date);

  if v_new_principal <= 0 then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if v_new_principal < v_product.minimum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM' using errcode = '22023';
  end if;
  if v_product.maximum_principal is not null and v_new_principal > v_product.maximum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM' using errcode = '22023';
  end if;
  if v_new_term < v_product.minimum_term or v_new_term > v_product.maximum_term then
    raise exception 'LOAN_ACCOUNT_TERM_OUT_OF_PRODUCT_RANGE' using errcode = '22023';
  end if;

  update public.loan_accounts set
    principal_amount = v_new_principal,
    term = v_new_term,
    first_repayment_date = v_new_first_repayment_date,
    proposed_disbursement_date = coalesce(p_proposed_disbursement_date, proposed_disbursement_date),
    updated_by = v_uid
  where id = p_loan_account_id;

  perform public.loan_schedule_generate(p_loan_account_id);

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_update_draft_loan_terms(
  uuid, uuid, numeric, integer, date, date
) from public;
grant execute on function public.rpc_update_draft_loan_terms(
  uuid, uuid, numeric, integer, date, date
) to authenticated;
revoke execute on function public.rpc_update_draft_loan_terms(
  uuid, uuid, numeric, integer, date, date
) from anon;

-- ---------------------------------------------------------------------
-- rpc_regenerate_loan_schedule — explicit "regenerate" action (section
-- Q) for when only the schedule needs recomputing (terms unchanged).
-- DRAFT only, same atomic replace as the update path.
-- ---------------------------------------------------------------------

create or replace function public.rpc_regenerate_loan_schedule(
  p_group_id uuid,
  p_loan_account_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_schedule.generate') then
    raise exception 'Not authorized to generate loan schedules in this group' using errcode = '42501';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;
  if v_loan.status <> 'DRAFT' then
    raise exception 'LOAN_ACCOUNT_NOT_DRAFT' using errcode = 'P0001';
  end if;

  perform public.loan_schedule_generate(p_loan_account_id);

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_regenerate_loan_schedule(uuid, uuid) from public;
grant execute on function public.rpc_regenerate_loan_schedule(uuid, uuid) to authenticated;
revoke execute on function public.rpc_regenerate_loan_schedule(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_cancel_draft_loan_account — DRAFT only, terminal. Installment
-- rows are left in place as historical record (they were never
-- collectible debt regardless — section K), never deleted.
-- ---------------------------------------------------------------------

create or replace function public.rpc_cancel_draft_loan_account(
  p_group_id uuid,
  p_loan_account_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.edit') then
    raise exception 'Not authorized to edit loans in this group' using errcode = '42501';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;
  if v_loan.status <> 'DRAFT' then
    raise exception 'LOAN_ACCOUNT_NOT_DRAFT' using errcode = 'P0001';
  end if;

  update public.loan_accounts set status = 'CANCELLED', updated_by = v_uid
  where id = p_loan_account_id;

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_cancel_draft_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_cancel_draft_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_cancel_draft_loan_account(uuid, uuid) from anon;
