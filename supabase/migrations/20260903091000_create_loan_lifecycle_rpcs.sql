-- Prompt 09B: loan lifecycle RPCs — Submit, Approve, Reject, and
-- Cancel (SUBMITTED/APPROVED). DRAFT-only cancellation is unchanged
-- and stays on 09A's `rpc_cancel_draft_loan_account`.
--
-- Every RPC below: locks the loan row first (`for update`), is
-- idempotent when retried against a loan already in the target status
-- (returns the current state rather than erroring — section 5/7/8's
-- "retry-safe" requirement), and records exactly one
-- `loan_account_events` row per successful transition. None of them
-- ever touches `financial_account_entries`, `financial_manual_entries`,
-- `payments`, `member_wallet_entries`, or any other cash/income table
-- — Submit/Approve/Reject/Cancel are authorization-only state changes
-- (section 2): zero cashbook movement, zero funded receivable, zero
-- income, at every one of these statuses.

-- ---------------------------------------------------------------------
-- rpc_create_draft_loan_account — extended (same signature, CREATE OR
-- REPLACE) to also record the loan's very first lifecycle event
-- (section 6/24 — "who created" must be recoverable from
-- loan_account_events like every other transition). Every other line
-- is unchanged from 09A.
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

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, created_by
  ) values (
    p_group_id, v_loan_id, 'CREATED', null, 'DRAFT', v_uid
  );

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
-- rpc_submit_loan_account — DRAFT -> SUBMITTED (section 5). Freezes
-- the loan's terms from further ordinary edit/regenerate (enforced by
-- `rpc_update_draft_loan_terms`/`rpc_regenerate_loan_schedule` both
-- still requiring status = DRAFT, unchanged from 09A — submission
-- itself needs no separate "freeze" mechanism beyond the status change
-- those RPCs already gate on).
-- ---------------------------------------------------------------------

create or replace function public.rpc_submit_loan_account(
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
  v_membership record;
  v_schedule_count integer;
  v_schedule_principal numeric;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.submit') then
    raise exception 'Not authorized to submit loans in this group' using errcode = '42501';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  -- Idempotent retry: already submitted is a safe no-op, not an error.
  if v_loan.status = 'SUBMITTED' then
    select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
    return v_result;
  end if;

  if v_loan.status <> 'DRAFT' then
    raise exception 'LOAN_ACCOUNT_NOT_DRAFT' using errcode = 'P0001';
  end if;

  select id, status into v_membership
  from public.group_memberships
  where id = v_loan.membership_id;
  if v_membership.status <> 'ACTIVE' then
    raise exception 'LOAN_ACCOUNT_BORROWER_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select count(*), coalesce(sum(principal_due), 0)
  into v_schedule_count, v_schedule_principal
  from public.loan_installments
  where loan_account_id = p_loan_account_id;

  if v_schedule_count = 0 then
    raise exception 'LOAN_ACCOUNT_SCHEDULE_MISSING' using errcode = 'P0001';
  end if;
  if v_schedule_principal <> v_loan.principal_amount then
    raise exception 'LOAN_ACCOUNT_SCHEDULE_MISMATCH' using errcode = 'P0001';
  end if;

  update public.loan_accounts
  set status = 'SUBMITTED', updated_by = v_uid
  where id = p_loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, created_by
  ) values (
    p_group_id, p_loan_account_id, 'SUBMITTED', v_loan.status, 'SUBMITTED', v_uid
  );

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_submit_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_submit_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_submit_loan_account(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_approve_loan_account — SUBMITTED -> APPROVED (section 7).
-- Authorization only: no financial_account_entry, no payment, no
-- allocation, no wallet entry, no income recognition of any kind.
-- ---------------------------------------------------------------------

create or replace function public.rpc_approve_loan_account(
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
  v_membership record;
  v_schedule_count integer;
  v_schedule_principal numeric;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.approve') then
    raise exception 'Not authorized to approve loans in this group' using errcode = '42501';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  if v_loan.status = 'APPROVED' then
    select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
    return v_result;
  end if;

  if v_loan.status <> 'SUBMITTED' then
    raise exception 'LOAN_ACCOUNT_NOT_SUBMITTED' using errcode = 'P0001';
  end if;

  select id, status into v_membership
  from public.group_memberships
  where id = v_loan.membership_id;
  if v_membership.status <> 'ACTIVE' then
    raise exception 'LOAN_ACCOUNT_BORROWER_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select count(*), coalesce(sum(principal_due), 0)
  into v_schedule_count, v_schedule_principal
  from public.loan_installments
  where loan_account_id = p_loan_account_id;

  if v_schedule_count = 0 or v_schedule_principal <> v_loan.principal_amount then
    raise exception 'LOAN_ACCOUNT_SCHEDULE_MISMATCH' using errcode = 'P0001';
  end if;

  update public.loan_accounts
  set status = 'APPROVED', updated_by = v_uid
  where id = p_loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, created_by
  ) values (
    p_group_id, p_loan_account_id, 'APPROVED', v_loan.status, 'APPROVED', v_uid
  );

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_approve_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_approve_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_approve_loan_account(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_reject_loan_account — SUBMITTED -> REJECTED (section 8).
-- Terminal: a rejected loan can never be disbursed, approved, or
-- resubmitted in 09B. Historical rows (loan account + schedule) are
-- never deleted.
-- ---------------------------------------------------------------------

create or replace function public.rpc_reject_loan_account(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.reject') then
    raise exception 'Not authorized to reject loans in this group' using errcode = '42501';
  end if;

  if v_reason = '' then
    raise exception 'LOAN_ACCOUNT_REJECTION_REASON_REQUIRED' using errcode = '22023';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  if v_loan.status <> 'SUBMITTED' then
    raise exception 'LOAN_ACCOUNT_NOT_SUBMITTED' using errcode = 'P0001';
  end if;

  update public.loan_accounts
  set status = 'REJECTED', updated_by = v_uid
  where id = p_loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
  ) values (
    p_group_id, p_loan_account_id, 'REJECTED', v_loan.status, 'REJECTED', v_reason, v_uid
  );

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_reject_loan_account(uuid, uuid, text) from public;
grant execute on function public.rpc_reject_loan_account(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reject_loan_account(uuid, uuid, text) from anon;

-- ---------------------------------------------------------------------
-- rpc_cancel_loan_account — SUBMITTED/APPROVED -> CANCELLED (section
-- 9). DRAFT cancellation is unchanged and stays on 09A's
-- `rpc_cancel_draft_loan_account`; this is the pre-disbursement-only
-- extension for the two later pre-disbursement statuses. A reason is
-- mandatory here (unlike the DRAFT path) since withdrawing a loan that
-- has already been submitted/approved is a more consequential action.
-- Terminal, and structurally cannot ever reach a loan that has already
-- been disbursed (status is checked, not merely a UI hint) — a
-- disbursed loan's financial correction is deferred to a future
-- controlled reversal workflow (section 32), never ordinary cancel.
-- ---------------------------------------------------------------------

create or replace function public.rpc_cancel_loan_account(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.cancel') then
    raise exception 'Not authorized to cancel loans in this group' using errcode = '42501';
  end if;

  if v_reason = '' then
    raise exception 'LOAN_ACCOUNT_CANCELLATION_REASON_REQUIRED' using errcode = '22023';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  if v_loan.status not in ('SUBMITTED', 'APPROVED') then
    raise exception 'LOAN_ACCOUNT_NOT_CANCELLABLE' using errcode = 'P0001';
  end if;

  update public.loan_accounts
  set status = 'CANCELLED', updated_by = v_uid
  where id = p_loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
  ) values (
    p_group_id, p_loan_account_id, 'CANCELLED', v_loan.status, 'CANCELLED', v_reason, v_uid
  );

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_cancel_loan_account(uuid, uuid, text) from public;
grant execute on function public.rpc_cancel_loan_account(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_cancel_loan_account(uuid, uuid, text) from anon;
