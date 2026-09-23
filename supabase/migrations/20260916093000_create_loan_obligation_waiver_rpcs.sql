-- Prompt 09F-A: Loan Waivers — preview/post RPC pair (section 9/10/15).
--
-- Maximum waiver is always CURRENT EFFECTIVE UNPAID OUTSTANDING on the
-- selected target (never the original gross assessment) — for interest,
-- additionally gated to due_date <= effective_date (never future/
-- unearned interest, section 10). Posting never trusts the preview: it
-- re-resolves the target and recomputes outstanding after locking,
-- exactly like rpc_prepay_loan_principal/rpc_settle_loan_early already
-- do for principal/interest/penalty payoff amounts.

create or replace function public.rpc_preview_loan_obligation_waiver(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_amount numeric,
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
  v_target record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.waive') then
    raise exception 'Not authorized to waive loan obligations in this group' using errcode = '42501';
  end if;

  if p_target_type = 'LOAN_PRINCIPAL' then
    raise exception 'LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED' using errcode = 'P0001';
  end if;

  if p_target_type not in ('LOAN_PENALTY', 'LOAN_INTEREST') then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_reason_code is null or btrim(p_reason_code) = ''
    or p_reason_code not in ('HARDSHIP', 'COMMITTEE_DECISION', 'GOODWILL', 'SETTLEMENT_CONCESSION', 'OTHER') then
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

  if v_loan.status not in ('ACTIVE', 'CLOSED') then
    raise exception 'LOAN_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select * into v_target
  from public.loan_obligation_adjustment_target_state(p_group_id, p_loan_account_id, p_target_type, p_target_id);

  if v_target.due_date is null or v_target.installment_cancelled then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if p_target_type = 'LOAN_INTEREST' and v_target.due_date > p_effective_date then
    raise exception 'LOAN_FUTURE_INTEREST_NOT_WAIVABLE' using errcode = 'P0001';
  end if;

  if p_amount > v_target.outstanding then
    raise exception 'LOAN_WAIVER_EXCEEDS_OUTSTANDING' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'target_type', p_target_type,
    'target_id', p_target_id,
    'loan_installment_id', v_target.loan_installment_id,
    'loan_penalty_charge_id', v_target.loan_penalty_charge_id,
    'reason_code', p_reason_code,
    'note', p_note,
    'effective_date', p_effective_date,
    'current_outstanding', v_target.outstanding,
    'waiver_amount', p_amount,
    'remaining_outstanding', v_target.outstanding - p_amount,
    'cash_impact', 0,
    'payment_created', false,
    'receipt_created', false
  );
end;
$$;

revoke all on function public.rpc_preview_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date) from public;
grant execute on function public.rpc_preview_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date) to authenticated;
revoke execute on function public.rpc_preview_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date) from anon;

create or replace function public.rpc_post_loan_obligation_waiver(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_amount numeric,
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
  v_target record;
  v_adjustment_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.waive') then
    raise exception 'Not authorized to waive loan obligations in this group' using errcode = '42501';
  end if;

  if p_target_type = 'LOAN_PRINCIPAL' then
    raise exception 'LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED' using errcode = 'P0001';
  end if;

  if p_target_type not in ('LOAN_PENALTY', 'LOAN_INTEREST') then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_reason_code is null or btrim(p_reason_code) = ''
    or p_reason_code not in ('HARDSHIP', 'COMMITTEE_DECISION', 'GOODWILL', 'SETTLEMENT_CONCESSION', 'OTHER') then
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

  if v_loan.status not in ('ACTIVE', 'CLOSED') then
    raise exception 'LOAN_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.loan_obligation_adjustments
    where group_id = p_group_id and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      return jsonb_build_object(
        'adjustment_id', v_existing.id,
        'loan_account_id', v_existing.loan_account_id,
        'target_type', v_existing.target_type,
        'loan_installment_id', v_existing.loan_installment_id,
        'loan_penalty_charge_id', v_existing.loan_penalty_charge_id,
        'adjustment_type', v_existing.adjustment_type,
        'amount', v_existing.amount,
        'reason_code', v_existing.reason_code,
        'note', v_existing.note,
        'effective_date', v_existing.effective_date,
        'cash_impact', 0,
        'payment_created', false,
        'receipt_created', false,
        'already_posted', true,
        'loan_status', v_loan.status
      );
    end if;
  end if;

  -- Lock the exact target row before recomputing outstanding — this is
  -- what serializes two concurrent waiver requests against the same
  -- charge/installment so neither can over-waive (section 14).
  if p_target_type = 'LOAN_PENALTY' then
    perform 1 from public.loan_penalty_charges where id = p_target_id for update;
  else
    perform 1 from public.loan_installments where id = p_target_id for update;
  end if;

  select * into v_target
  from public.loan_obligation_adjustment_target_state(p_group_id, p_loan_account_id, p_target_type, p_target_id);

  if v_target.due_date is null or v_target.installment_cancelled then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if p_target_type = 'LOAN_INTEREST' and v_target.due_date > p_effective_date then
    raise exception 'LOAN_FUTURE_INTEREST_NOT_WAIVABLE' using errcode = 'P0001';
  end if;

  if p_amount > v_target.outstanding then
    raise exception 'LOAN_WAIVER_EXCEEDS_OUTSTANDING' using errcode = 'P0001';
  end if;

  insert into public.loan_obligation_adjustments (
    group_id, loan_account_id, target_type, loan_penalty_charge_id, loan_installment_id,
    adjustment_type, amount, reason_code, note, effective_date, idempotency_key, created_by
  ) values (
    p_group_id, p_loan_account_id, p_target_type, v_target.loan_penalty_charge_id,
    case when p_target_type = 'LOAN_PENALTY' then null else v_target.loan_installment_id end,
    'WAIVER', -p_amount, p_reason_code, p_note, p_effective_date, p_idempotency_key, v_uid
  )
  returning id into v_adjustment_id;

  perform public.loan_account_recheck_closure(p_group_id, p_loan_account_id, v_uid);

  return jsonb_build_object(
    'adjustment_id', v_adjustment_id,
    'loan_account_id', p_loan_account_id,
    'target_type', p_target_type,
    'loan_installment_id', v_target.loan_installment_id,
    'loan_penalty_charge_id', v_target.loan_penalty_charge_id,
    'adjustment_type', 'WAIVER',
    'amount', -p_amount,
    'reason_code', p_reason_code,
    'note', p_note,
    'effective_date', p_effective_date,
    'outstanding_before', v_target.outstanding,
    'outstanding_after', v_target.outstanding - p_amount,
    'cash_impact', 0,
    'payment_created', false,
    'receipt_created', false,
    'already_posted', false,
    'loan_status', (select status from public.loan_accounts where id = p_loan_account_id)
  );
end;
$$;

revoke all on function public.rpc_post_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date, text) from public;
grant execute on function public.rpc_post_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date, text) to authenticated;
revoke execute on function public.rpc_post_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date, text) from anon;

comment on function public.rpc_post_loan_obligation_waiver(uuid, uuid, text, uuid, numeric, text, text, date, text) is
  'Prompt 09F-A: posts exactly one immutable WAIVER row. Zero payment,
  zero receipt, zero wallet/cashbook movement, zero income. Maximum
  waiver is always the CURRENT effective outstanding, recomputed after
  locking the target row (never the client-held preview figure).';
