-- Prompt 09E: Controlled Reschedule / Restructure Foundation.
--
-- Deliberately kept simple (section 6 — "This keeps 09E safe and
-- simple"): restructure never forgives debt or edits a balance
-- directly. It replaces the future contractual schedule only, and only
-- when the loan currently has ZERO overdue/currently-payable balance
-- across every component (penalty, interest, AND principal — stricter
-- than prepayment's penalty+interest-only gate, per section 6's own
-- v1 lock). The new schedule reuses the exact same
-- loan_schedule_compute engine already locked for original loan
-- issuance and REDUCE_INSTALLMENT prepayment — no new interest
-- methodology.

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

  if p_effective_date is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  if p_new_term is null or p_new_term <= 0 then
    raise exception 'LOAN_RESTRUCTURE_TERM_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_new_first_installment_date is null or p_new_first_installment_date <= p_effective_date then
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
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date <= p_effective_date;

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
    'effective_date', p_effective_date,
    'remaining_principal_outstanding', v_remaining_principal,
    'new_interest_rate', v_new_rate,
    'new_term', p_new_term,
    'new_first_installment_date', p_new_first_installment_date,
    'old_remaining_installments', v_old_remaining,
    'new_installments', v_new_schedule
  );
end;
$$;

revoke all on function public.rpc_preview_loan_restructure(
  uuid, uuid, integer, date, numeric, date
) from public;
grant execute on function public.rpc_preview_loan_restructure(
  uuid, uuid, integer, date, numeric, date
) to authenticated;
revoke execute on function public.rpc_preview_loan_restructure(
  uuid, uuid, integer, date, numeric, date
) from anon;

-- ---------------------------------------------------------------------
-- rpc_restructure_loan — re-validates everything the preview did, then
-- atomically replaces the future schedule and records the immutable
-- audit event (section 6/12). No cash/payment is involved.
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

  if p_effective_date is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  if p_new_term is null or p_new_term <= 0 then
    raise exception 'LOAN_RESTRUCTURE_TERM_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_new_first_installment_date is null or p_new_first_installment_date <= p_effective_date then
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
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null and li.due_date <= p_effective_date;

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
    p_group_id, p_loan_account_id, p_effective_date, p_reason, v_new_rate, p_new_term,
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

revoke all on function public.rpc_restructure_loan(
  uuid, uuid, text, integer, date, numeric, date
) from public;
grant execute on function public.rpc_restructure_loan(
  uuid, uuid, text, integer, date, numeric, date
) to authenticated;
revoke execute on function public.rpc_restructure_loan(
  uuid, uuid, text, integer, date, numeric, date
) from anon;
