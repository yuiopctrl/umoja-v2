-- Prompt 09C: rpc_get_payment_detail / rpc_get_receipt now render a
-- loan allocation line with semantic context (section 16 — "Loan
-- Installment 1 Interest", "Loan Installment 1 Principal") alongside
-- unchanged contribution lines. Still exactly one payment, one receipt
-- — no separate loan receipt is introduced. The joins that used to be
-- INNER (every allocation was a contribution) become LEFT, since a
-- loan-targeted row has null charge_id/charge_component_id.

create or replace function public.rpc_get_payment_detail(
  p_group_id uuid,
  p_payment_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_payment record;
  v_allocations jsonb;
  v_wallet_credit jsonb;
  v_cashbook_entry jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.view') then
    raise exception 'Not authorized to view payments in this group' using errcode = '42501';
  end if;

  select p.*, gm.display_name as member_display_name, gm.member_number, fa.name as financial_account_name
  into v_payment
  from public.payments p
  join public.group_memberships gm on gm.id = p.membership_id
  join public.financial_accounts fa on fa.id = p.financial_account_id
  where p.id = p_payment_id;

  if v_payment.group_id is null or v_payment.group_id <> p_group_id then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'allocation_id', pa.id,
    'allocation_target_type', pa.allocation_target_type,
    'charge_id', pa.charge_id,
    'component_id', pa.charge_component_id,
    'component_type', coalesce(cc.component_type::text, pa.allocation_target_type::text),
    'due_date', coalesce(c.due_date, li.due_date),
    'amount', pa.amount,
    'contribution_type_name', pa.contribution_type_name_snapshot,
    'period_label', pa.period_label_snapshot,
    'period_purpose', pa.period_purpose_snapshot,
    'loan_account_id', pa.loan_account_id,
    'loan_number', la.loan_number,
    'loan_installment_id', pa.loan_installment_id,
    'installment_number', li.installment_number
  ) order by coalesce(c.due_date, li.due_date), pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  left join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.member_contribution_charges c on c.id = pa.charge_id
  left join public.loan_installments li on li.id = pa.loan_installment_id
  left join public.loan_accounts la on la.id = pa.loan_account_id
  where pa.payment_id = p_payment_id;

  select jsonb_build_object('amount', we.amount, 'created_at', we.created_at)
  into v_wallet_credit
  from public.member_wallet_entries we
  where we.source_type = 'PAYMENT' and we.source_id = p_payment_id and we.entry_type = 'PAYMENT_CREDIT';

  select jsonb_build_object('entry_id', fae.id, 'entry_type', fae.entry_type, 'amount', fae.amount)
  into v_cashbook_entry
  from public.financial_account_entries fae
  where fae.source_type = 'PAYMENT' and fae.source_id = p_payment_id and fae.entry_type = 'INFLOW';

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'membership_id', v_payment.membership_id,
    'member_display_name', v_payment.member_display_name,
    'member_number', v_payment.member_number,
    'financial_account_id', v_payment.financial_account_id,
    'financial_account_name', v_payment.financial_account_name,
    'amount', v_payment.amount,
    'effective_at', v_payment.effective_at,
    'payment_method', v_payment.payment_method,
    'external_reference', v_payment.external_reference,
    'notes', v_payment.notes,
    'receipt_number', v_payment.receipt_number,
    'status', v_payment.status,
    'created_at', v_payment.created_at,
    'reversed_at', v_payment.reversed_at,
    'reversed_by', v_payment.reversed_by,
    'reversal_reason', v_payment.reversal_reason,
    'allocations', v_allocations,
    'wallet_credit', v_wallet_credit,
    'cashbook_entry', v_cashbook_entry
  );
end;
$$;

revoke all on function public.rpc_get_payment_detail(uuid, uuid) from public;
grant execute on function public.rpc_get_payment_detail(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_payment_detail(uuid, uuid) from anon;

create or replace function public.rpc_get_receipt(
  p_group_id uuid,
  p_payment_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_payment record;
  v_allocations jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'payment.receipt.view') then
    raise exception 'Not authorized to view receipts in this group' using errcode = '42501';
  end if;

  select p.*, gm.display_name as member_display_name, gm.member_number, fa.name as financial_account_name
  into v_payment
  from public.payments p
  join public.group_memberships gm on gm.id = p.membership_id
  join public.financial_accounts fa on fa.id = p.financial_account_id
  where p.id = p_payment_id;

  if v_payment.group_id is null or v_payment.group_id <> p_group_id then
    raise exception 'Payment not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'allocation_target_type', pa.allocation_target_type,
    'component_type', coalesce(cc.component_type::text, pa.allocation_target_type::text),
    'due_date', coalesce(c.due_date, li.due_date),
    'amount', pa.amount,
    'contribution_type_name', pa.contribution_type_name_snapshot,
    'period_label', pa.period_label_snapshot,
    'period_purpose', pa.period_purpose_snapshot,
    'loan_number', la.loan_number,
    'installment_number', li.installment_number
  ) order by coalesce(c.due_date, li.due_date), pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  left join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.member_contribution_charges c on c.id = pa.charge_id
  left join public.loan_installments li on li.id = pa.loan_installment_id
  left join public.loan_accounts la on la.id = pa.loan_account_id
  where pa.payment_id = p_payment_id;

  return jsonb_build_object(
    'receipt_number', v_payment.receipt_number,
    'payment_id', v_payment.id,
    'member_display_name', v_payment.member_display_name,
    'member_number', v_payment.member_number,
    'financial_account_name', v_payment.financial_account_name,
    'amount', v_payment.amount,
    'effective_at', v_payment.effective_at,
    'payment_method', v_payment.payment_method,
    'status', v_payment.status,
    'allocations', v_allocations
  );
end;
$$;

revoke all on function public.rpc_get_receipt(uuid, uuid) from public;
grant execute on function public.rpc_get_receipt(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_receipt(uuid, uuid) from anon;

comment on function public.rpc_get_payment_detail(uuid, uuid) is
  'Full payment detail (Prompt 07, extended 09C). allocation_target_type
  discriminates a CONTRIBUTION_COMPONENT row (charge_id/component_id/
  contribution snapshot populated) from a LOAN_PRINCIPAL/LOAN_INTEREST
  row (loan_account_id/loan_installment_id/loan_number/
  installment_number populated instead). Still one payment, one receipt
  — a loan allocation is a line on the SAME receipt, never a second
  document.';
