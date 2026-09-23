-- Prompt 09F-A-09 (UAT Blocker-02, Defect C): future/unearned interest
-- must never be CORRECTION_DECREASE-able.
--
-- Root cause (09F-A-08 investigation): rpc_preview_loan_obligation_
-- correction / rpc_post_loan_obligation_correction never checked
-- `due_date <= effective_date` for LOAN_INTEREST targets — only the
-- WAIVER RPCs (20260916093000) carried that gate. This let a
-- CORRECTION_DECREASE succeed against a not-yet-due installment's
-- interest, violating the locked policy that only earned/payable
-- interest is 09F-A-adjustable (interest CORRECTION_INCREASE remains
-- prohibited outright, unaffected by this migration).
--
-- Fix: mirror the exact same gate already used by
-- rpc_preview_loan_obligation_waiver / rpc_post_loan_obligation_waiver
-- (20260916093000, section 10) — `p_target_type = 'LOAN_INTEREST' and
-- v_target.due_date > p_effective_date` — placed immediately after
-- target resolution, in BOTH preview and post, so a direct authenticated
-- caller cannot bypass the rule by invoking post directly (preview never
-- protects post). A dedicated, correction-specific stable code is used
-- rather than reusing LOAN_FUTURE_INTEREST_NOT_WAIVABLE, whose name is
-- specific to waiver semantics.
--
-- No other behavior changes: penalty CORRECTION_INCREASE's Blocker-01
-- frozen-policy bound, the MIGRATED/OPENING
-- LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE path, and interest
-- CORRECTION_INCREASE's outright prohibition are all untouched below —
-- every other line is byte-identical to 20260916094000.

create or replace function public.rpc_preview_loan_obligation_correction(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_adjustment_type text,
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
  v_expected_amount numeric;
  v_signed_amount numeric;
  v_current_corrected_net numeric;
  v_current_corrected_gross numeric;
  v_new_corrected_gross numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.correct') then
    raise exception 'Not authorized to correct loan obligations in this group' using errcode = '42501';
  end if;

  if p_target_type = 'LOAN_PRINCIPAL' then
    raise exception 'LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED' using errcode = 'P0001';
  end if;

  if p_target_type not in ('LOAN_PENALTY', 'LOAN_INTEREST') then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if p_adjustment_type not in ('CORRECTION_DECREASE', 'CORRECTION_INCREASE') then
    raise exception 'Invalid adjustment type' using errcode = '22023';
  end if;

  if p_target_type = 'LOAN_INTEREST' and p_adjustment_type = 'CORRECTION_INCREASE' then
    raise exception 'LOAN_CORRECTION_INCREASE_NOT_ALLOWED' using errcode = 'P0001';
  end if;

  if p_adjustment_type = 'CORRECTION_INCREASE'
    and not public.has_group_permission(p_group_id, 'loan.correct_increase') then
    raise exception 'Not authorized to increase loan obligations in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_reason_code is null or btrim(p_reason_code) = ''
    or p_reason_code not in ('ASSESSMENT_ERROR', 'DATA_ENTRY_ERROR', 'MIGRATION_ERROR', 'OTHER') then
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

  -- Defect C fix: only earned/payable interest (due_date <= effective
  -- date) may be CORRECTION_DECREASE-d — mirrors the waiver RPCs'
  -- identical gate exactly. By this point CORRECTION_INCREASE on
  -- LOAN_INTEREST has already been rejected above, so this always means
  -- CORRECTION_DECREASE here.
  if p_target_type = 'LOAN_INTEREST' and v_target.due_date > p_effective_date then
    raise exception 'LOAN_FUTURE_INTEREST_NOT_CORRECTABLE' using errcode = 'P0001';
  end if;

  -- Corrected-gross-so-far (section "PRIOR ADJUSTMENTS"): original
  -- assessment + every prior NON-REVERSED correction, WAIVER excluded
  -- entirely — used for both the increase bound and the preview's
  -- informational fields, so what the user reviews is exactly what the
  -- server will re-validate against at Confirm.
  select coalesce(sum(oa.amount), 0) into v_current_corrected_net
  from public.loan_obligation_adjustments oa
  where oa.target_type = p_target_type
    and (
      (p_target_type = 'LOAN_PENALTY' and oa.loan_penalty_charge_id = v_target.loan_penalty_charge_id)
      or
      (p_target_type = 'LOAN_INTEREST' and oa.loan_installment_id = v_target.loan_installment_id)
    )
    and oa.adjustment_type in ('CORRECTION_INCREASE', 'CORRECTION_DECREASE')
    and not exists (
      select 1 from public.loan_obligation_adjustments r
      where r.reverses_adjustment_id = oa.id
    );

  v_current_corrected_gross := v_target.gross + v_current_corrected_net;

  if p_adjustment_type = 'CORRECTION_DECREASE' then
    v_signed_amount := -p_amount;
    if p_amount > v_target.outstanding then
      raise exception 'LOAN_CORRECTION_DECREASE_EXCEEDS_OUTSTANDING' using errcode = 'P0001';
    end if;
  else
    v_signed_amount := p_amount;

    if v_target.penalty_type is null then
      raise exception 'LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE' using errcode = 'P0001';
    end if;

    v_expected_amount := case v_target.penalty_type
      when 'FIXED' then v_target.fixed_amount
      when 'PERCENTAGE' then round(v_target.basis_amount * v_target.rate / 100, 2)
    end;

    v_new_corrected_gross := v_current_corrected_gross + p_amount;

    if v_new_corrected_gross > v_expected_amount then
      raise exception 'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND' using errcode = 'P0001';
    end if;
  end if;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'target_type', p_target_type,
    'target_id', p_target_id,
    'loan_installment_id', v_target.loan_installment_id,
    'loan_penalty_charge_id', v_target.loan_penalty_charge_id,
    'adjustment_type', p_adjustment_type,
    'reason_code', p_reason_code,
    'note', p_note,
    'effective_date', p_effective_date,
    'source_original_amount', v_target.gross,
    'prior_net_corrections', v_current_corrected_net,
    'current_effective_amount', v_current_corrected_gross,
    'proposed_correction', v_signed_amount,
    'new_effective_amount', v_current_corrected_gross + v_signed_amount,
    'outstanding_before', v_target.outstanding,
    'outstanding_after', v_target.outstanding + v_signed_amount,
    'cash_impact', 0,
    'payment_created', false,
    'receipt_created', false
  );
end;
$$;

revoke all on function public.rpc_preview_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date) from public;
grant execute on function public.rpc_preview_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date) to authenticated;
revoke execute on function public.rpc_preview_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date) from anon;

create or replace function public.rpc_post_loan_obligation_correction(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_adjustment_type text,
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
  v_expected_amount numeric;
  v_signed_amount numeric;
  v_current_corrected_net numeric;
  v_current_corrected_gross numeric;
  v_new_corrected_gross numeric;
  v_adjustment_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.correct') then
    raise exception 'Not authorized to correct loan obligations in this group' using errcode = '42501';
  end if;

  if p_target_type = 'LOAN_PRINCIPAL' then
    raise exception 'LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED' using errcode = 'P0001';
  end if;

  if p_target_type not in ('LOAN_PENALTY', 'LOAN_INTEREST') then
    raise exception 'LOAN_ADJUSTMENT_TARGET_INVALID' using errcode = 'P0001';
  end if;

  if p_adjustment_type not in ('CORRECTION_DECREASE', 'CORRECTION_INCREASE') then
    raise exception 'Invalid adjustment type' using errcode = '22023';
  end if;

  if p_target_type = 'LOAN_INTEREST' and p_adjustment_type = 'CORRECTION_INCREASE' then
    raise exception 'LOAN_CORRECTION_INCREASE_NOT_ALLOWED' using errcode = 'P0001';
  end if;

  if p_adjustment_type = 'CORRECTION_INCREASE'
    and not public.has_group_permission(p_group_id, 'loan.correct_increase') then
    raise exception 'Not authorized to increase loan obligations in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_reason_code is null or btrim(p_reason_code) = ''
    or p_reason_code not in ('ASSESSMENT_ERROR', 'DATA_ENTRY_ERROR', 'MIGRATION_ERROR', 'OTHER') then
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

  -- Defect C fix (see preview above for full rationale): enforced again
  -- here, independently, so a direct authenticated post call cannot
  -- bypass the rule by skipping preview.
  if p_target_type = 'LOAN_INTEREST' and v_target.due_date > p_effective_date then
    raise exception 'LOAN_FUTURE_INTEREST_NOT_CORRECTABLE' using errcode = 'P0001';
  end if;

  -- Recomputed AFTER the target row lock above — never trusts the
  -- preview's figure (section 14/10).
  select coalesce(sum(oa.amount), 0) into v_current_corrected_net
  from public.loan_obligation_adjustments oa
  where oa.target_type = p_target_type
    and (
      (p_target_type = 'LOAN_PENALTY' and oa.loan_penalty_charge_id = v_target.loan_penalty_charge_id)
      or
      (p_target_type = 'LOAN_INTEREST' and oa.loan_installment_id = v_target.loan_installment_id)
    )
    and oa.adjustment_type in ('CORRECTION_INCREASE', 'CORRECTION_DECREASE')
    and not exists (
      select 1 from public.loan_obligation_adjustments r
      where r.reverses_adjustment_id = oa.id
    );

  v_current_corrected_gross := v_target.gross + v_current_corrected_net;

  if p_adjustment_type = 'CORRECTION_DECREASE' then
    v_signed_amount := -p_amount;
    if p_amount > v_target.outstanding then
      raise exception 'LOAN_CORRECTION_DECREASE_EXCEEDS_OUTSTANDING' using errcode = 'P0001';
    end if;
  else
    v_signed_amount := p_amount;

    if v_target.penalty_type is null then
      raise exception 'LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE' using errcode = 'P0001';
    end if;

    v_expected_amount := case v_target.penalty_type
      when 'FIXED' then v_target.fixed_amount
      when 'PERCENTAGE' then round(v_target.basis_amount * v_target.rate / 100, 2)
    end;

    v_new_corrected_gross := v_current_corrected_gross + p_amount;

    if v_new_corrected_gross > v_expected_amount then
      raise exception 'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND' using errcode = 'P0001';
    end if;
  end if;

  insert into public.loan_obligation_adjustments (
    group_id, loan_account_id, target_type, loan_penalty_charge_id, loan_installment_id,
    adjustment_type, amount, reason_code, note, effective_date, idempotency_key, created_by
  ) values (
    p_group_id, p_loan_account_id, p_target_type, v_target.loan_penalty_charge_id,
    case when p_target_type = 'LOAN_PENALTY' then null else v_target.loan_installment_id end,
    p_adjustment_type, v_signed_amount, p_reason_code, p_note, p_effective_date, p_idempotency_key, v_uid
  )
  returning id into v_adjustment_id;

  perform public.loan_account_recheck_closure(p_group_id, p_loan_account_id, v_uid);

  return jsonb_build_object(
    'adjustment_id', v_adjustment_id,
    'loan_account_id', p_loan_account_id,
    'target_type', p_target_type,
    'loan_installment_id', v_target.loan_installment_id,
    'loan_penalty_charge_id', v_target.loan_penalty_charge_id,
    'adjustment_type', p_adjustment_type,
    'amount', v_signed_amount,
    'reason_code', p_reason_code,
    'note', p_note,
    'effective_date', p_effective_date,
    'source_original_amount', v_target.gross,
    'prior_net_corrections', v_current_corrected_net,
    'new_effective_amount', v_current_corrected_gross + v_signed_amount,
    'outstanding_before', v_target.outstanding,
    'outstanding_after', v_target.outstanding + v_signed_amount,
    'cash_impact', 0,
    'payment_created', false,
    'receipt_created', false,
    'already_posted', false,
    'loan_status', (select status from public.loan_accounts where id = p_loan_account_id)
  );
end;
$$;

revoke all on function public.rpc_post_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date, text) from public;
grant execute on function public.rpc_post_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date, text) to authenticated;
revoke execute on function public.rpc_post_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date, text) from anon;

comment on function public.rpc_post_loan_obligation_correction(uuid, uuid, text, uuid, text, numeric, text, text, date, text) is
  'Prompt 09F-A (bound corrected by 09F-A-BLOCKER-01; future-interest
  gate added by 09F-A-09 Defect C): posts exactly one immutable
  CORRECTION_DECREASE/CORRECTION_INCREASE row. Original assessment/
  installment row is never edited. Zero payment/receipt/wallet/cashbook/
  income. CORRECTION_INCREASE requires loan.correct_increase
  (ADMIN-only), is only ever reachable for LOAN_PENALTY, and is capped so
  the corrected GROSS obligation (original + non-reversed corrections,
  WAIVER excluded) can never exceed the charge''s own frozen-policy
  expected amount — no multiplier, no override. A target with no
  computable frozen policy (MIGRATED OPENING charges) rejects
  CORRECTION_INCREASE outright via
  LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE. LOAN_INTEREST
  CORRECTION_DECREASE is only reachable for earned/payable interest
  (due_date <= effective_date) — a future/not-yet-due installment
  rejects with LOAN_FUTURE_INTEREST_NOT_CORRECTABLE.';
