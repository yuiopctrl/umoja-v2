-- Prompt 09E-CLOSEOUT-BLOCKER-02: append-only corrective migration.
--
-- LOCKED MIGRATION-DISCIPLINE RULE: every migration through
-- 20260914090000 is already applied to the cloud project and is
-- immutable. This migration touches nothing else — it is strictly
-- append-only, later than every existing 09E migration.
--
-- Fixes two data-integrity blockers found by the 09E final closeout
-- audit:
--
-- BLOCKER 1 (rpc_restructure_loan / rpc_preview_loan_restructure):
-- the schedule-replacement queries had no `due_date > v_effective_date`
-- boundary, unlike every other 09E schedule-replacing action
-- (rpc_prepay_loan_principal, rpc_settle_loan_early both already use
-- exactly this boundary). Concretely:
--   * the cancellation `update loan_installments set cancelled_at = ...
--     where loan_account_id = ... and cancelled_at is null` cancelled
--     EVERY still-uncancelled row regardless of due date — including
--     already-paid historical installments (a paid installment is
--     never cancelled by the payment engine, so it stays reachable by
--     this unscoped predicate). A loan restructured after making 3
--     on-time payments would silently flip those 3 PAID installments
--     to CANCELLED, corrupting historical audit state and
--     rpc_get_financial_position's scheduled_unearned_interest (a
--     cancelled installment's interest drops out of the "scheduled"
--     side while its already-recognized amount remains on the
--     "recognized" side, understating or negating the figure).
--   * the `v_old_remaining` audit-snapshot query had the identical
--     missing boundary, so `loan_restructure_events` would also
--     misrecord already-paid installments as part of the "old
--     remaining" (i.e. to-be-replaced future) schedule.
-- Fix: add `and due_date > v_effective_date` to both the cancellation
-- UPDATE and the `v_old_remaining` snapshot query, in both the preview
-- and write RPCs — the exact boundary already used by prepayment/
-- settlement. Nothing else changes: the overdue-balance guard already
-- correctly used this same boundary (it just never propagated to the
-- two statements above), so restructure now only ever modifies/
-- replaces the future schedule, exactly as designed. This also
-- structurally prevents any duplicate/overlapping active schedule: an
-- already-paid installment past the boundary is left exactly as it
-- was, and only the genuinely-future rows are cancelled-and-replaced.
--
-- BLOCKER 2 (rpc_reverse_payment): the guard blocking reversal of a
-- principal prepayment when its replacement schedule has "subsequent
-- activity" only checked payment_allocations. A replacement schedule
-- can also be superseded WITHOUT ever receiving an allocation — a
-- later prepayment or a restructure cancels it outright (own
-- cancelled_at, no allocation involved), and an early settlement
-- cancels every live installment on the loan the same way. In each of
-- those cases the guard's old payment_allocations-only check passed,
-- so reversing the original prepayment would un-cancel the original
-- (now doubly-stale) schedule while the later action's replacement
-- schedule remained live too — two active, overlapping future
-- schedules on the same loan, double-counting outstanding principal.
-- Fix: the guard now also checks whether any of this payment's
-- replacement installments (`created_by_payment_id = p_payment_id`)
-- has itself been cancelled (`cancelled_at is not null`) by ANYTHING
-- since — not just whether it received an allocation. This is
-- deliberately structural rather than an enumeration of "later event
-- types": every 09E schedule-superseding action (a second prepayment,
-- a restructure, an early settlement) is required to mark the row it
-- supersedes as cancelled before creating its own replacement, so
-- "was this row cancelled by something else" is the single
-- authoritative signal for "has later activity superseded this
-- schedule" — no new column or event-table join needed, and no
-- reliance on payment_allocations alone.
--
-- Signatures, SECURITY DEFINER, search_path='', authenticated-only
-- execution, permission checks (loan.restructure / payment.reverse),
-- and tenant/group isolation are all byte-for-byte unchanged from the
-- originals — CREATE OR REPLACE FUNCTION with an identical signature
-- preserves existing GRANT/REVOKE state, so none is re-issued here.

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

  -- BLOCKER 1 fix: only the genuinely-future schedule is "old
  -- remaining" (about to be replaced) — already-paid/historical rows
  -- at or before the effective date are never part of what restructure
  -- touches, so they must never appear in this replacement snapshot.
  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb)
  into v_old_remaining
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
    and li.due_date > v_effective_date;

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

  -- BLOCKER 1 fix: snapshot only the future schedule about to be
  -- replaced — never already-paid/historical rows.
  select coalesce(jsonb_agg(jsonb_build_object(
    'installment_number', li.installment_number, 'due_date', li.due_date,
    'principal_due', li.principal_due, 'interest_due', li.interest_due
  ) order by li.installment_number), '[]'::jsonb)
  into v_old_remaining
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
    and li.due_date > v_effective_date;

  select coalesce(max(installment_number), 0) into v_next_installment_number
  from public.loan_installments
  where loan_account_id = p_loan_account_id;

  -- BLOCKER 1 fix: cancel ONLY the future schedule (due_date strictly
  -- after the effective date) — the exact same boundary the overdue-
  -- balance guard above already enforces, and the same boundary
  -- rpc_prepay_loan_principal/rpc_settle_loan_early already use for
  -- their own schedule replacement. Already-paid/historical/overdue
  -- installments are never touched.
  update public.loan_installments
  set cancelled_at = now(), cancellation_reason = 'RESTRUCTURE'
  where loan_account_id = p_loan_account_id and cancelled_at is null
    and due_date > v_effective_date;

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

-- ---------------------------------------------------------------------
-- rpc_reverse_payment
-- ---------------------------------------------------------------------

create or replace function public.rpc_reverse_payment(
  p_group_id uuid,
  p_payment_id uuid,
  p_reversal_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership_id uuid;
  v_payment record;
  v_credit_entry record;
  v_wallet_balance numeric;
  v_original_entry_id uuid;
  v_loan_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.reverse') then
    raise exception 'Not authorized to reverse payments in this group' using errcode = '42501';
  end if;

  if p_reversal_reason is null or btrim(p_reversal_reason) = '' then
    raise exception 'PAYMENT_REVERSAL_REASON_REQUIRED' using errcode = '22023';
  end if;

  select membership_id into v_membership_id from public.payments where id = p_payment_id;
  if v_membership_id is null then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  perform 1 from public.group_memberships where id = v_membership_id for update;

  select * into v_payment from public.payments where id = p_payment_id for update;
  if v_payment.group_id is null or v_payment.group_id <> p_group_id then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  if v_payment.status <> 'POSTED' then
    raise exception 'PAYMENT_ALREADY_REVERSED' using errcode = 'P0001';
  end if;

  -- BLOCKER 2 fix (09E-CLOSEOUT-BLOCKER-02 section D): block BEFORE any
  -- mutation if a prepayment's replacement schedule has been either (a)
  -- allocated against (the original check) OR (b) itself cancelled by
  -- ANY later schedule-superseding action — a second prepayment, a
  -- restructure, or an early settlement all cancel the row they
  -- supersede before creating their own replacement, so "was this row
  -- cancelled by something else" is the authoritative signal that this
  -- schedule is no longer current and reversing the payment that
  -- created it would resurrect a stale, overlapping schedule.
  if exists (
    select 1 from public.loan_installments li
    where li.created_by_payment_id = p_payment_id
      and (
        li.cancelled_at is not null
        or exists (
          select 1 from public.payment_allocations pa2
          where pa2.loan_installment_id = li.id
        )
      )
  ) then
    raise exception 'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY' using errcode = 'P0001';
  end if;

  select * into v_credit_entry
  from public.member_wallet_entries
  where source_type = 'PAYMENT' and source_id = p_payment_id and entry_type = 'PAYMENT_CREDIT';

  if v_credit_entry.id is not null then
    v_wallet_balance := public.member_wallet_balance(v_payment.membership_id);
    if v_wallet_balance - v_credit_entry.amount < 0 then
      raise exception 'PAYMENT_REVERSAL_BLOCKED_WALLET_CREDIT_CONSUMED' using errcode = 'P0001';
    end if;

    insert into public.member_wallet_entries (
      group_id, membership_id, entry_type, amount, effective_at,
      source_type, source_id, reverses_entry_id, created_by
    ) values (
      p_group_id, v_payment.membership_id, 'REVERSAL', v_credit_entry.amount, current_date,
      'PAYMENT_REVERSAL', p_payment_id, v_credit_entry.id, v_uid
    );
  end if;

  select id into v_original_entry_id
  from public.financial_account_entries
  where source_type = 'PAYMENT' and source_id = p_payment_id and entry_type = 'INFLOW';

  perform public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => v_payment.financial_account_id,
    p_entry_type => 'OUTFLOW',
    p_amount => v_payment.amount,
    p_effective_at => current_date,
    p_uid => v_uid,
    p_description => 'Reversal of ' || v_payment.receipt_number,
    p_source_type => 'PAYMENT_REVERSAL',
    p_source_id => p_payment_id,
    p_reverses_entry_id => v_original_entry_id
  );

  update public.payments
  set status = 'REVERSED', reversed_at = now(), reversed_by = v_uid, reversal_reason = p_reversal_reason
  where id = p_payment_id;

  -- Prompt 09E cleanup: undo exactly what THIS payment did to the
  -- schedule, and nothing more.
  update public.loan_installments
  set cancelled_at = null, cancellation_reason = null, cancelled_by_payment_id = null
  where cancelled_by_payment_id = p_payment_id;

  delete from public.loan_installments
  where created_by_payment_id = p_payment_id;

  -- The status flip above already makes every one of this payment's
  -- allocations (contribution AND loan) inactive for outstanding
  -- purposes, with zero rows touched. Reopen any loan this payment had
  -- fully settled.
  for v_loan_id in
    select distinct loan_account_id from public.payment_allocations
    where payment_id = p_payment_id and loan_account_id is not null
  loop
    perform public.loan_account_recheck_closure(
      p_group_id, v_loan_id, v_uid,
      'Reversal of payment ' || v_payment.receipt_number || ' restored an outstanding balance'
    );
  end loop;

  return jsonb_build_object(
    'payment_id', p_payment_id,
    'status', 'REVERSED',
    'reversal_reason', p_reversal_reason,
    'financial_account_balance', public.financial_account_balance(v_payment.financial_account_id),
    'wallet_balance', public.member_wallet_balance(v_payment.membership_id)
  );
end;
$$;
