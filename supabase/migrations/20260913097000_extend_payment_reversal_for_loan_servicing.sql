-- Prompt 09E: rpc_reverse_payment gains loan-servicing cleanup (section
-- 9). An early-settlement/prepayment payment is reversed through the
-- EXISTING, unchanged mechanism (flip payments.status to REVERSED,
-- which already makes every allocation against it inactive again —
-- zero special-casing needed there). What the generic mechanism cannot
-- do on its own is undo the SCHEDULE side effects that same payment
-- caused:
--   * un-cancel any loan_installments row this payment cancelled
--     (cancelled_by_payment_id) — restores its interest/principal
--     obligation exactly as loan_installment_component_states already
--     derives it, with zero new code there;
--   * remove any loan_installments row this payment's prepayment
--     created (created_by_payment_id) — but ONLY when safe: if any
--     allocation has since been posted against that replacement row
--     (e.g. an ordinary payment settled part of the new schedule),
--     reversing the original prepayment is BLOCKED rather than
--     silently orphaning that later activity's basis. This keeps
--     reversal safe and simple, matching the same "block rather than
--     approximate" posture already locked for restructure/prepayment
--     writes.
-- Restructure has no reversal path here — it creates no payment, so
-- section 9's reversal requirement does not apply to it (a correction
-- is a further restructure).

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

  -- Prompt 09E guard (section 9): block BEFORE any mutation if a
  -- prepayment's replacement installment already has activity against
  -- it — reversing would otherwise orphan that later activity's
  -- obligation basis.
  if exists (
    select 1 from public.loan_installments li
    where li.created_by_payment_id = p_payment_id
      and exists (
        select 1 from public.payment_allocations pa2
        where pa2.loan_installment_id = li.id
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

revoke all on function public.rpc_reverse_payment(uuid, uuid, text) from public;
grant execute on function public.rpc_reverse_payment(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reverse_payment(uuid, uuid, text) from anon;

comment on function public.rpc_reverse_payment(uuid, uuid, text) is
  'Prompt 07/09C/09E: reverses one payment and every allocation it
  made, exactly as before, plus (09E) undoes any loan_installments
  cancellation/creation THIS payment caused (early settlement/
  prepayment) — blocked upfront if a prepayment''s replacement
  installment already has its own subsequent activity.';
