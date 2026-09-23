-- Prompt 09F-A: adjustment reversal (section 17), modelled directly on
-- rpc_reverse_payment's own dependency-guard philosophy (09E,
-- 20260915090000): a per-row STRUCTURAL check ("has anything happened
-- to this exact target since"), never a broad "has the loan seen any
-- activity" scan. At minimum: (a) a later adjustment on the same
-- target, (b) a later payment allocation against the same target, (c)
-- the target installment having been cancelled/superseded (prepayment/
-- restructure/early settlement) since this adjustment was posted.
--
-- Reversal is itself just another append-only row (amount = -1 * the
-- original) — the original adjustment is never edited. A reversal of a
-- reversal is not required in 09F-A and is rejected outright
-- (LOAN_ADJUSTMENT_REVERSAL_NOT_SUPPORTED); an already-reversed
-- adjustment is rejected (LOAN_ADJUSTMENT_ALREADY_REVERSED), backed by
-- the structural
-- loan_obligation_adjustments_reverses_adjustment_id_unique index.

create or replace function public.rpc_reverse_loan_obligation_adjustment(
  p_group_id uuid,
  p_adjustment_id uuid,
  p_reversal_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_adjustment record;
  v_loan record;
  v_blocked boolean;
  v_reversal_id uuid;
  v_target record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if p_reversal_reason is null or btrim(p_reversal_reason) = '' then
    raise exception 'LOAN_ADJUSTMENT_REASON_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_adjustment
  from public.loan_obligation_adjustments
  where id = p_adjustment_id and group_id = p_group_id;

  if v_adjustment.id is null then
    raise exception 'Adjustment not found in group' using errcode = '22023';
  end if;

  if v_adjustment.adjustment_type = 'REVERSAL' then
    raise exception 'LOAN_ADJUSTMENT_REVERSAL_NOT_SUPPORTED' using errcode = 'P0001';
  end if;

  if v_adjustment.adjustment_type = 'WAIVER' then
    if not public.has_group_permission(p_group_id, 'loan.waive') then
      raise exception 'Not authorized to reverse loan waivers in this group' using errcode = '42501';
    end if;
  elsif v_adjustment.adjustment_type = 'CORRECTION_INCREASE' then
    if not public.has_group_permission(p_group_id, 'loan.correct')
      or not public.has_group_permission(p_group_id, 'loan.correct_increase') then
      raise exception 'Not authorized to reverse loan corrections in this group' using errcode = '42501';
    end if;
  else
    if not public.has_group_permission(p_group_id, 'loan.correct') then
      raise exception 'Not authorized to reverse loan corrections in this group' using errcode = '42501';
    end if;
  end if;

  select * into v_loan from public.loan_accounts where id = v_adjustment.loan_account_id for update;

  if exists (
    select 1 from public.loan_obligation_adjustments
    where reverses_adjustment_id = v_adjustment.id
  ) then
    raise exception 'LOAN_ADJUSTMENT_ALREADY_REVERSED' using errcode = 'P0001';
  end if;

  if v_adjustment.target_type = 'LOAN_PENALTY' then
    perform 1 from public.loan_penalty_charges where id = v_adjustment.loan_penalty_charge_id for update;
  else
    perform 1 from public.loan_installments where id = v_adjustment.loan_installment_id for update;
  end if;

  -- Structural dependency guard (section 17) — target-specific, never a
  -- broad "loan has later activity" scan.
  select
    exists (
      select 1 from public.loan_obligation_adjustments oa2
      where oa2.id <> v_adjustment.id
        and oa2.entry_no > v_adjustment.entry_no
        and (
          (v_adjustment.target_type = 'LOAN_PENALTY' and oa2.loan_penalty_charge_id = v_adjustment.loan_penalty_charge_id)
          or
          (v_adjustment.target_type = 'LOAN_INTEREST' and oa2.target_type = 'LOAN_INTEREST'
            and oa2.loan_installment_id = v_adjustment.loan_installment_id)
        )
    )
    or exists (
      select 1 from public.payment_allocations pa
      left join public.payments p on p.id = pa.payment_id
      where pa.created_at > v_adjustment.created_at
        and (pa.wallet_entry_id is not null or p.status = 'POSTED')
        and (
          (v_adjustment.target_type = 'LOAN_PENALTY' and pa.loan_penalty_charge_id = v_adjustment.loan_penalty_charge_id)
          or
          (v_adjustment.target_type = 'LOAN_INTEREST' and pa.allocation_target_type = 'LOAN_INTEREST'
            and pa.loan_installment_id = v_adjustment.loan_installment_id)
        )
    )
    or exists (
      select 1 from public.loan_installments li
      where li.id = v_adjustment.loan_installment_id
        and li.cancelled_at is not null
        and li.cancelled_at > v_adjustment.created_at
    )
  into v_blocked;

  if v_blocked then
    raise exception 'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY' using errcode = 'P0001';
  end if;

  insert into public.loan_obligation_adjustments (
    group_id, loan_account_id, target_type, loan_penalty_charge_id, loan_installment_id,
    adjustment_type, amount, reason_code, note, effective_date, reverses_adjustment_id, created_by
  ) values (
    p_group_id, v_adjustment.loan_account_id, v_adjustment.target_type,
    v_adjustment.loan_penalty_charge_id, v_adjustment.loan_installment_id,
    'REVERSAL', -v_adjustment.amount, p_reversal_reason, null, current_date, v_adjustment.id, v_uid
  )
  returning id into v_reversal_id;

  perform public.loan_account_recheck_closure(p_group_id, v_adjustment.loan_account_id, v_uid);

  select * into v_target
  from public.loan_obligation_adjustment_target_state(
    p_group_id, v_adjustment.loan_account_id, v_adjustment.target_type,
    coalesce(v_adjustment.loan_penalty_charge_id, v_adjustment.loan_installment_id)
  );

  return jsonb_build_object(
    'reversal_id', v_reversal_id,
    'reversed_adjustment_id', v_adjustment.id,
    'loan_account_id', v_adjustment.loan_account_id,
    'target_type', v_adjustment.target_type,
    'loan_installment_id', v_adjustment.loan_installment_id,
    'loan_penalty_charge_id', v_adjustment.loan_penalty_charge_id,
    'reversed_amount', v_adjustment.amount,
    'reversal_reason', p_reversal_reason,
    'outstanding_after', v_target.outstanding,
    'loan_status', (select status from public.loan_accounts where id = v_adjustment.loan_account_id)
  );
end;
$$;

revoke all on function public.rpc_reverse_loan_obligation_adjustment(uuid, uuid, text) from public;
grant execute on function public.rpc_reverse_loan_obligation_adjustment(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reverse_loan_obligation_adjustment(uuid, uuid, text) from anon;

comment on function public.rpc_reverse_loan_obligation_adjustment(uuid, uuid, text) is
  'Prompt 09F-A: append-only reversal. Original adjustment is never
  edited. Blocked (LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY)
  if a later adjustment or payment allocation touched the same target, or
  the target installment was cancelled/superseded since — mirrors
  rpc_reverse_payment''s structural dependency-guard pattern (09E).';
