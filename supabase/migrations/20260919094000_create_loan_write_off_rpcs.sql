-- Prompt 09F-B: Loan Write-Off — internal helper + preview/post/reverse
-- RPC triplet.
--
-- Amount formula (locked, section A): reuses the exact same
-- loan_installment_component_states helper 09F-A already made
-- adjustment-aware, so a write-off always operates on the true current
-- effective obligation (net of any prior waiver/correction), never a
-- stale gross figure:
--   principal_amount = sum(PRINCIPAL outstanding) across every
--     non-cancelled installment, any due date (principal has no
--     earned/unearned distinction — matches loan_compute_early_
--     settlement_plan's existing treatment exactly).
--   interest_amount  = sum(INTEREST outstanding) across every
--     non-cancelled installment whose due_date <= effective_date only
--     — future/unearned interest is structurally excluded, never
--     written off, mirroring the identical gate already used by 09F-A
--     waiver/correction and 09E early settlement.
--   penalty_amount   = sum(PENALTY outstanding) across every
--     non-cancelled installment, any due date (matches early
--     settlement's existing treatment).
-- No installment/penalty-charge row is ever mutated — only
-- loan_write_off_events gains a row and loan_accounts.status changes.

create or replace function public.loan_write_off_compute_amounts(
  p_loan_account_id uuid,
  p_effective_date date
)
returns table (
  principal_outstanding numeric,
  interest_outstanding numeric,
  penalty_outstanding numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PRINCIPAL'), 0),
    coalesce(sum(s.outstanding) filter (
      where s.component_type = 'INTEREST' and li.due_date <= p_effective_date
    ), 0),
    coalesce(sum(s.outstanding) filter (where s.component_type = 'PENALTY'), 0)
  from public.loan_installments li
  cross join lateral public.loan_installment_component_states(li.id) s
  where li.loan_account_id = p_loan_account_id
    and li.cancelled_at is null;
$$;

revoke all on function public.loan_write_off_compute_amounts(uuid, date) from public, anon, authenticated;

comment on function public.loan_write_off_compute_amounts(uuid, date) is
  'Locked-down internal helper (Prompt 09F-B). Computes the exact
  amount a full write-off would freeze right now — principal and
  penalty in full (any due date), interest only where due_date <=
  p_effective_date (future/unearned interest is never included).';

-- ---------------------------------------------------------------------

create or replace function public.rpc_preview_loan_write_off(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_reason_code text,
  p_note text default null,
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
  v_amounts record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.write_off') then
    raise exception 'Not authorized to write off loans in this group' using errcode = '42501';
  end if;

  if p_reason_code is null or btrim(p_reason_code) = ''
    or p_reason_code not in (
      'PROLONGED_DEFAULT', 'BORROWER_DECEASED', 'BORROWER_UNTRACEABLE',
      'UNCOLLECTIBLE_COST', 'GROUP_DECISION', 'OTHER'
    ) then
    raise exception 'LOAN_ADJUSTMENT_REASON_REQUIRED' using errcode = 'P0001';
  end if;

  if p_reason_code = 'OTHER' and (p_note is null or btrim(p_note) = '') then
    raise exception 'LOAN_ADJUSTMENT_OTHER_NOTE_REQUIRED' using errcode = 'P0001';
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

  if v_loan.status <> 'ACTIVE' then
    raise exception 'LOAN_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select * into v_amounts
  from public.loan_write_off_compute_amounts(p_loan_account_id, p_effective_date);

  if (v_amounts.principal_outstanding + v_amounts.interest_outstanding + v_amounts.penalty_outstanding) <= 0 then
    raise exception 'LOAN_WRITE_OFF_NOTHING_OUTSTANDING' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'reason_code', p_reason_code,
    'note', p_note,
    'effective_date', p_effective_date,
    'principal_amount', v_amounts.principal_outstanding,
    'interest_amount', v_amounts.interest_outstanding,
    'penalty_amount', v_amounts.penalty_outstanding,
    'total_amount', v_amounts.principal_outstanding + v_amounts.interest_outstanding + v_amounts.penalty_outstanding,
    'cash_impact', 0,
    'payment_created', false,
    'receipt_created', false
  );
end;
$$;

revoke all on function public.rpc_preview_loan_write_off(uuid, uuid, text, text, date) from public;
grant execute on function public.rpc_preview_loan_write_off(uuid, uuid, text, text, date) to authenticated;
revoke execute on function public.rpc_preview_loan_write_off(uuid, uuid, text, text, date) from anon;

-- ---------------------------------------------------------------------

create or replace function public.rpc_post_loan_write_off(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_reason_code text,
  p_note text default null,
  p_effective_date date default current_date,
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
  v_existing record;
  v_amounts record;
  v_write_off_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.write_off') then
    raise exception 'Not authorized to write off loans in this group' using errcode = '42501';
  end if;

  if p_reason_code is null or btrim(p_reason_code) = ''
    or p_reason_code not in (
      'PROLONGED_DEFAULT', 'BORROWER_DECEASED', 'BORROWER_UNTRACEABLE',
      'UNCOLLECTIBLE_COST', 'GROUP_DECISION', 'OTHER'
    ) then
    raise exception 'LOAN_ADJUSTMENT_REASON_REQUIRED' using errcode = 'P0001';
  end if;

  if p_reason_code = 'OTHER' and (p_note is null or btrim(p_note) = '') then
    raise exception 'LOAN_ADJUSTMENT_OTHER_NOTE_REQUIRED' using errcode = 'P0001';
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

  if p_idempotency_key is not null then
    select * into v_existing
    from public.loan_write_off_events
    where group_id = p_group_id and loan_account_id = p_loan_account_id
      and event_type = 'WRITE_OFF'
      and created_by = v_uid
    order by entry_no desc
    limit 1;
    -- Idempotency for a locked-per-loan, at-most-one-active event is
    -- simpler than 09F-A's group-wide key: if a non-reversed WRITE_OFF
    -- already exists for this loan (regardless of key match), the
    -- unique index below would reject a second one anyway, so we
    -- short-circuit here on "does one already exist" rather than
    -- requiring an exact key match — but only when a key was supplied,
    -- to remain a true no-op retry rather than silently hiding a
    -- distinct caller's attempt.
    if v_existing.id is not null and v_loan.status = 'WRITTEN_OFF' then
      return jsonb_build_object(
        'write_off_event_id', v_existing.id,
        'loan_account_id', p_loan_account_id,
        'principal_amount', v_existing.principal_amount,
        'interest_amount', v_existing.interest_amount,
        'penalty_amount', v_existing.penalty_amount,
        'total_amount', v_existing.principal_amount + v_existing.interest_amount + v_existing.penalty_amount,
        'cash_impact', 0,
        'payment_created', false,
        'receipt_created', false,
        'already_posted', true,
        'loan_status', v_loan.status
      );
    end if;
  end if;

  if v_loan.status <> 'ACTIVE' then
    raise exception 'LOAN_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select * into v_amounts
  from public.loan_write_off_compute_amounts(p_loan_account_id, p_effective_date);

  if (v_amounts.principal_outstanding + v_amounts.interest_outstanding + v_amounts.penalty_outstanding) <= 0 then
    raise exception 'LOAN_WRITE_OFF_NOTHING_OUTSTANDING' using errcode = 'P0001';
  end if;

  insert into public.loan_write_off_events (
    group_id, loan_account_id, event_type,
    principal_amount, interest_amount, penalty_amount,
    reason_code, note, effective_date, created_by
  ) values (
    p_group_id, p_loan_account_id, 'WRITE_OFF',
    v_amounts.principal_outstanding, v_amounts.interest_outstanding, v_amounts.penalty_outstanding,
    p_reason_code, p_note, p_effective_date, v_uid
  )
  returning id into v_write_off_id;

  update public.loan_accounts
  set status = 'WRITTEN_OFF', updated_at = now(), updated_by = v_uid
  where id = p_loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
  ) values (
    p_group_id, p_loan_account_id, 'WRITTEN_OFF', v_loan.status, 'WRITTEN_OFF', p_reason_code, v_uid
  );

  return jsonb_build_object(
    'write_off_event_id', v_write_off_id,
    'loan_account_id', p_loan_account_id,
    'principal_amount', v_amounts.principal_outstanding,
    'interest_amount', v_amounts.interest_outstanding,
    'penalty_amount', v_amounts.penalty_outstanding,
    'total_amount', v_amounts.principal_outstanding + v_amounts.interest_outstanding + v_amounts.penalty_outstanding,
    'cash_impact', 0,
    'payment_created', false,
    'receipt_created', false,
    'already_posted', false,
    'loan_status', 'WRITTEN_OFF'
  );
end;
$$;

revoke all on function public.rpc_post_loan_write_off(uuid, uuid, text, text, date, text) from public;
grant execute on function public.rpc_post_loan_write_off(uuid, uuid, text, text, date, text) to authenticated;
revoke execute on function public.rpc_post_loan_write_off(uuid, uuid, text, text, date, text) from anon;

comment on function public.rpc_post_loan_write_off(uuid, uuid, text, text, date, text) is
  'Prompt 09F-B: posts exactly one immutable WRITE_OFF row and flips
  loan_accounts.status to WRITTEN_OFF. Zero payment/receipt/wallet/
  cashbook/income. No installment/penalty-charge row is ever mutated.
  Rejects a loan that is not ACTIVE or that has nothing outstanding to
  write off (LOAN_WRITE_OFF_NOTHING_OUTSTANDING).';

-- ---------------------------------------------------------------------
-- rpc_reverse_loan_write_off — allowed only while no dependent recovery
-- activity exists (section C): a non-reversed loan_recovery_events row
-- whose underlying payment is still POSTED. Mirrors the exact
-- structural, per-row dependency philosophy already used by 09E/09F-A
-- reversal guards — never a broad "any later activity" scan.
-- ---------------------------------------------------------------------

create or replace function public.rpc_reverse_loan_write_off(
  p_group_id uuid,
  p_write_off_event_id uuid,
  p_reversal_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_write_off record;
  v_loan record;
  v_reversal_id uuid;
  v_has_dependent_recovery boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.write_off.reverse') then
    raise exception 'Not authorized to reverse loan write-offs in this group' using errcode = '42501';
  end if;

  if p_reversal_reason is null or btrim(p_reversal_reason) = '' then
    raise exception 'LOAN_ADJUSTMENT_REASON_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_write_off
  from public.loan_write_off_events
  where id = p_write_off_event_id and group_id = p_group_id
  for update;

  if v_write_off.id is null then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if v_write_off.event_type <> 'WRITE_OFF' then
    raise exception 'LOAN_ADJUSTMENT_REVERSAL_NOT_SUPPORTED' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.loan_write_off_events r
    where r.reverses_write_off_id = v_write_off.id
  ) then
    raise exception 'LOAN_ADJUSTMENT_ALREADY_REVERSED' using errcode = 'P0001';
  end if;

  select exists (
    select 1
    from public.loan_recovery_events re
    join public.payments p on p.id = re.payment_id
    where re.write_off_event_id = v_write_off.id
      and p.status = 'POSTED'
  ) into v_has_dependent_recovery;

  if v_has_dependent_recovery then
    raise exception 'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY' using errcode = 'P0001';
  end if;

  select * into v_loan
  from public.loan_accounts
  where id = v_write_off.loan_account_id and group_id = p_group_id
  for update;

  if v_loan.status <> 'WRITTEN_OFF' then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  insert into public.loan_write_off_events (
    group_id, loan_account_id, event_type, reverses_write_off_id,
    principal_amount, interest_amount, penalty_amount,
    reason_code, note, effective_date, created_by
  ) values (
    p_group_id, v_write_off.loan_account_id, 'REVERSAL', v_write_off.id,
    -v_write_off.principal_amount, -v_write_off.interest_amount, -v_write_off.penalty_amount,
    p_reversal_reason, null, current_date, v_uid
  )
  returning id into v_reversal_id;

  update public.loan_accounts
  set status = 'ACTIVE', updated_at = now(), updated_by = v_uid
  where id = v_write_off.loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, reason, created_by
  ) values (
    p_group_id, v_write_off.loan_account_id, 'WRITE_OFF_REVERSED', 'WRITTEN_OFF', 'ACTIVE', p_reversal_reason, v_uid
  );

  return jsonb_build_object(
    'reversal_id', v_reversal_id,
    'reversed_write_off_event_id', v_write_off.id,
    'loan_account_id', v_write_off.loan_account_id,
    'loan_status', 'ACTIVE'
  );
end;
$$;

revoke all on function public.rpc_reverse_loan_write_off(uuid, uuid, text) from public;
grant execute on function public.rpc_reverse_loan_write_off(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reverse_loan_write_off(uuid, uuid, text) from anon;

comment on function public.rpc_reverse_loan_write_off(uuid, uuid, text) is
  'Prompt 09F-B: reverses a write-off by posting a new REVERSAL row
  (the original WRITE_OFF row is never edited/deleted) and restoring
  loan_accounts.status to ACTIVE — no installment/penalty-charge row is
  touched, so the loan''s pre-write-off effective obligation state is
  exactly what loan_installment_component_states already shows, with
  zero rewriting. Blocked once any non-reversed recovery exists against
  this write-off (LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY).';
