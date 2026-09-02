-- Prompt 09D: read-model extensions for loan penalty visibility
-- (section 20/21/31/33/34). Every penalty-paid/outstanding figure
-- below is derived fresh from loan_installment_component_states /
-- loan_penalty_charge_states on every read — never a stored counter.

-- ---------------------------------------------------------------------
-- loan_account_summary — gains penalty_paid/penalty_outstanding.
-- total_outstanding already automatically includes penalty (it already
-- summed ACROSS every component_type returned by
-- loan_installment_component_states, which now includes PENALTY —
-- section 31: "Total Outstanding = principal + interest + penalty").
-- Return-shape change requires dropping the old-signature function.
-- ---------------------------------------------------------------------

drop function if exists public.loan_account_summary(uuid);

create function public.loan_account_summary(p_loan_account_id uuid)
returns table (
  principal_repaid numeric,
  principal_outstanding numeric,
  interest_recognized numeric,
  interest_outstanding numeric,
  penalty_paid numeric,
  penalty_outstanding numeric,
  total_outstanding numeric,
  next_due_date date,
  overdue_amount numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with installment_components as (
    select li.id as installment_id, li.due_date, s.component_type, s.allocated, s.outstanding
    from public.loan_installments li
    cross join lateral public.loan_installment_component_states(li.id) s
    where li.loan_account_id = p_loan_account_id
  ),
  installment_totals as (
    select installment_id, due_date, sum(outstanding) as installment_outstanding
    from installment_components
    group by installment_id, due_date
  )
  select
    coalesce(sum(ic.allocated) filter (where ic.component_type = 'PRINCIPAL'), 0),
    coalesce(sum(ic.outstanding) filter (where ic.component_type = 'PRINCIPAL'), 0),
    coalesce(sum(ic.allocated) filter (where ic.component_type = 'INTEREST'), 0),
    coalesce(sum(ic.outstanding) filter (where ic.component_type = 'INTEREST'), 0),
    coalesce(sum(ic.allocated) filter (where ic.component_type = 'PENALTY'), 0),
    coalesce(sum(ic.outstanding) filter (where ic.component_type = 'PENALTY'), 0),
    coalesce(sum(ic.outstanding), 0),
    (select min(it.due_date) from installment_totals it where it.installment_outstanding > 0),
    coalesce((select sum(it.installment_outstanding) from installment_totals it where it.due_date < current_date), 0)
  from installment_components ic;
$$;

revoke all on function public.loan_account_summary(uuid) from public, anon, authenticated;

comment on function public.loan_account_summary(uuid) is
  'Locked-down internal helper. Member-facing loan summary figures
  (Prompt 09C, extended 09D with penalty_paid/penalty_outstanding) —
  always derived from loan_installment_component_states, never a
  stored counter. total_outstanding = principal + interest + penalty
  outstanding (section 31).';

-- ---------------------------------------------------------------------
-- rpc_get_loan_account / rpc_list_loan_installments — installments now
-- also carry penalty_paid/penalty_outstanding; total_outstanding
-- includes penalty; PAID status requires penalty outstanding = 0 too
-- (section 33 — "do not render as fully PAID while an assessed penalty
-- remains unpaid").
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_loan_account(
  p_group_id uuid,
  p_loan_account_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_installments jsonb;
  v_events jsonb;
  v_disbursement jsonb;
  v_summary record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id,
    'group_id', i.group_id,
    'loan_account_id', i.loan_account_id,
    'installment_number', i.installment_number,
    'due_date', i.due_date,
    'principal_due', i.principal_due,
    'interest_due', i.interest_due,
    'total_due', i.total_due,
    'created_at', i.created_at,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', coalesce(pc.outstanding, 0),
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', coalesce(ic.outstanding, 0),
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', coalesce(penc.outstanding, 0),
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0),
    'status', (
      case
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) + coalesce(penc.allocated, 0) > 0 then 'PARTIALLY_PAID'
        when i.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end
    )
  ) order by i.installment_number), '[]'::jsonb)
  into v_installments
  from public.loan_installments i
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PRINCIPAL'
  ) pc on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'INTEREST'
  ) ic on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PENALTY'
  ) penc on true
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
  into v_events
  from public.loan_account_events e
  where e.loan_account_id = p_loan_account_id and e.group_id = p_group_id;

  select jsonb_build_object(
    'id', d.id, 'financial_account_id', d.financial_account_id,
    'financial_account_name', fa.name,
    'amount', d.amount, 'effective_at', d.effective_at,
    'reference', d.reference, 'notes', d.notes, 'created_at', d.created_at
  )
  into v_disbursement
  from public.loan_disbursements d
  join public.financial_accounts fa on fa.id = d.financial_account_id
  where d.loan_account_id = p_loan_account_id and d.group_id = p_group_id;

  select * into v_summary from public.loan_account_summary(p_loan_account_id);

  select jsonb_build_object(
    'id', la.id, 'group_id', la.group_id, 'membership_id', la.membership_id,
    'borrower_display_name', gm.display_name, 'borrower_member_number', gm.member_number,
    'loan_product_id', la.loan_product_id, 'loan_product_name', lp.name, 'loan_product_code', lp.code,
    'loan_number', la.loan_number,
    'principal_amount', la.principal_amount, 'interest_rate', la.interest_rate,
    'interest_rate_basis', la.interest_rate_basis, 'interest_method', la.interest_method,
    'term', la.term, 'term_unit', la.term_unit, 'repayment_frequency', la.repayment_frequency,
    'application_date', la.application_date,
    'proposed_disbursement_date', la.proposed_disbursement_date,
    'first_repayment_date', la.first_repayment_date,
    'status', la.status,
    'penalty_enabled', la.penalty_enabled, 'penalty_type', la.penalty_type,
    'penalty_frequency', la.penalty_frequency, 'penalty_grace_days', la.penalty_grace_days,
    'penalty_fixed_amount', la.penalty_fixed_amount, 'penalty_rate', la.penalty_rate,
    'penalty_basis', la.penalty_basis,
    'created_at', la.created_at, 'updated_at', la.updated_at,
    'installments', v_installments,
    'events', v_events,
    'disbursement', v_disbursement,
    'principal_repaid', v_summary.principal_repaid,
    'principal_outstanding', v_summary.principal_outstanding,
    'interest_recognized', v_summary.interest_recognized,
    'interest_outstanding', v_summary.interest_outstanding,
    'penalty_paid', v_summary.penalty_paid,
    'penalty_outstanding', v_summary.penalty_outstanding,
    'total_outstanding', v_summary.total_outstanding,
    'next_due_date', v_summary.next_due_date,
    'overdue_amount', v_summary.overdue_amount
  )
  into v_result
  from public.loan_accounts la
  join public.group_memberships gm on gm.id = la.membership_id
  join public.loan_products lp on lp.id = la.loan_product_id
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  if v_result is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$$;

create or replace function public.rpc_list_loan_accounts(
  p_group_id uuid,
  p_membership_id uuid default null,
  p_loan_product_id uuid default null,
  p_status public.loan_account_status default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb;
  v_total integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.loan_accounts la
  where la.group_id = p_group_id
    and (p_membership_id is null or la.membership_id = p_membership_id)
    and (p_loan_product_id is null or la.loan_product_id = p_loan_product_id)
    and (p_status is null or la.status = p_status);

  select coalesce(jsonb_agg(to_jsonb(row) order by row.created_at desc), '[]'::jsonb) into v_items
  from (
    select
      la.id, la.group_id, la.membership_id,
      gm.display_name as borrower_display_name, gm.member_number as borrower_member_number,
      la.loan_product_id, lp.name as loan_product_name, lp.code as loan_product_code,
      la.loan_number, la.principal_amount, la.interest_rate, la.interest_rate_basis,
      la.interest_method, la.term, la.term_unit, la.repayment_frequency,
      la.application_date, la.proposed_disbursement_date, la.first_repayment_date,
      la.status,
      la.penalty_enabled, la.penalty_type, la.penalty_frequency, la.penalty_grace_days,
      la.penalty_fixed_amount, la.penalty_rate, la.penalty_basis,
      la.created_at, la.updated_at,
      sm.principal_repaid, sm.principal_outstanding,
      sm.interest_recognized, sm.interest_outstanding,
      sm.penalty_paid, sm.penalty_outstanding,
      sm.total_outstanding, sm.next_due_date, sm.overdue_amount
    from public.loan_accounts la
    join public.group_memberships gm on gm.id = la.membership_id
    join public.loan_products lp on lp.id = la.loan_product_id
    cross join lateral public.loan_account_summary(la.id) sm
    where la.group_id = p_group_id
      and (p_membership_id is null or la.membership_id = p_membership_id)
      and (p_loan_product_id is null or la.loan_product_id = p_loan_product_id)
      and (p_status is null or la.status = p_status)
    order by la.created_at desc
    limit p_limit offset p_offset
  ) row;

  return jsonb_build_object(
    'items', v_items, 'total_count', v_total, 'limit', p_limit, 'offset', p_offset
  );
end;
$$;

create or replace function public.rpc_list_loan_installments(
  p_group_id uuid,
  p_loan_account_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_schedule.view') then
    raise exception 'Not authorized to view loan schedules in this group' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.loan_accounts where id = p_loan_account_id and group_id = p_group_id
  ) then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id,
    'group_id', i.group_id,
    'loan_account_id', i.loan_account_id,
    'installment_number', i.installment_number,
    'due_date', i.due_date,
    'principal_due', i.principal_due,
    'interest_due', i.interest_due,
    'total_due', i.total_due,
    'created_at', i.created_at,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', coalesce(pc.outstanding, 0),
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', coalesce(ic.outstanding, 0),
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', coalesce(penc.outstanding, 0),
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0),
    'status', (
      case
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) + coalesce(penc.allocated, 0) > 0 then 'PARTIALLY_PAID'
        when i.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end
    )
  ) order by i.installment_number), '[]'::jsonb) into v_items
  from public.loan_installments i
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PRINCIPAL'
  ) pc on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'INTEREST'
  ) ic on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PENALTY'
  ) penc on true
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  return jsonb_build_object('loan_account_id', p_loan_account_id, 'installments', v_items);
end;
$$;

-- ---------------------------------------------------------------------
-- rpc_get_payment_detail / rpc_get_receipt — allocation lines now carry
-- loan_penalty_charge_id (section 21). component_type already falls
-- back to pa.allocation_target_type::text ('LOAN_PENALTY') for any row
-- with no contribution_charge_components join, exactly as it already
-- did for LOAN_PRINCIPAL/LOAN_INTEREST — no change needed there.
-- ---------------------------------------------------------------------

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
    'loan_product_name', lp.name,
    'loan_installment_id', pa.loan_installment_id,
    'installment_number', li.installment_number,
    'loan_penalty_charge_id', pa.loan_penalty_charge_id
  ) order by coalesce(c.due_date, li.due_date), pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  left join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.member_contribution_charges c on c.id = pa.charge_id
  left join public.loan_installments li on li.id = pa.loan_installment_id
  left join public.loan_accounts la on la.id = pa.loan_account_id
  left join public.loan_products lp on lp.id = la.loan_product_id
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
    'loan_product_name', lp.name,
    'installment_number', li.installment_number,
    'loan_penalty_charge_id', pa.loan_penalty_charge_id
  ) order by coalesce(c.due_date, li.due_date), pa.created_at), '[]'::jsonb)
  into v_allocations
  from public.payment_allocations pa
  left join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.member_contribution_charges c on c.id = pa.charge_id
  left join public.loan_installments li on li.id = pa.loan_installment_id
  left join public.loan_accounts la on la.id = pa.loan_account_id
  left join public.loan_products lp on lp.id = la.loan_product_id
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

-- ---------------------------------------------------------------------
-- rpc_get_financial_position — loan_penalties_outstanding (point-in-
-- time) and recognized_loan_penalty_income (period-bound), folded into
-- group_income exactly once alongside recognized_loan_interest_income
-- (section 20).
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_financial_position(
  p_group_id uuid,
  p_date_from date default null,
  p_date_to date default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_as_of date := coalesce(p_date_to, current_date);
  v_accounts jsonb;
  v_total_balance numeric;
  v_group_income numeric;
  v_pass_through numeric;
  v_share_capital numeric;
  v_manual_income numeric;
  v_expenses numeric;
  v_wallet_liability numeric;
  v_outstanding numeric;
  v_disbursed_principal numeric;
  v_principal_allocated numeric;
  v_scheduled_interest_total numeric;
  v_recognized_interest_alltime numeric;
  v_recognized_loan_interest_income numeric;
  v_recognized_loan_penalty_income numeric;
  v_loan_penalties_outstanding numeric;
  v_funded_loan_principal_receivable numeric;
  v_scheduled_unearned_interest numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_report.view') then
    raise exception 'Not authorized to view financial reports in this group' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.account_type, rows.name), '[]'::jsonb)
  into v_accounts
  from (
    select
      a.id, a.name, a.account_type, a.is_active,
      public.financial_account_balance_as_of(a.id, v_as_of) as balance
    from public.financial_accounts a
    where a.group_id = p_group_id
  ) rows;

  select coalesce(sum(public.financial_account_balance_as_of(a.id, v_as_of)), 0)
  into v_total_balance
  from public.financial_accounts a
  where a.group_id = p_group_id;

  select
    coalesce(sum(pa.amount) filter (where ct.accounting_treatment = 'GROUP_INCOME'), 0),
    coalesce(sum(pa.amount) filter (where ct.accounting_treatment = 'PASS_THROUGH'), 0),
    coalesce(sum(pa.amount) filter (where ct.accounting_treatment = 'SHARE_CAPITAL'), 0)
  into v_group_income, v_pass_through, v_share_capital
  from public.payment_allocations pa
  join public.payments p on p.id = pa.payment_id
  join public.member_contribution_charges c on c.id = pa.charge_id
  join public.contribution_setups cs on cs.id = c.contribution_setup_id
  join public.contribution_types ct on ct.id = cs.contribution_type_id
  where pa.group_id = p_group_id
    and pa.payment_id is not null
    and pa.allocation_target_type = 'CONTRIBUTION_COMPONENT'
    and p.status = 'POSTED'
    and (p_date_from is null or p.effective_at >= p_date_from)
    and (p_date_to is null or p.effective_at <= p_date_to);

  select coalesce(sum(amount), 0) into v_manual_income
  from public.financial_manual_entries
  where group_id = p_group_id and entry_kind = 'INCOME' and status = 'POSTED'
    and (p_date_from is null or effective_at >= p_date_from)
    and (p_date_to is null or effective_at <= p_date_to);

  select coalesce(sum(amount), 0) into v_expenses
  from public.financial_manual_entries
  where group_id = p_group_id and entry_kind = 'EXPENSE' and status = 'POSTED'
    and (p_date_from is null or effective_at >= p_date_from)
    and (p_date_to is null or effective_at <= p_date_to);

  -- Interest income (09C): recognized only for allocations actually
  -- settled within the requested period.
  select coalesce(sum(pa.amount), 0)
  into v_recognized_loan_interest_income
  from public.payment_allocations pa
  left join public.payments p on p.id = pa.payment_id
  left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
  where pa.group_id = p_group_id
    and pa.allocation_target_type = 'LOAN_INTEREST'
    and (
      (pa.payment_id is not null and p.status = 'POSTED'
        and (p_date_from is null or p.effective_at >= p_date_from)
        and (p_date_to is null or p.effective_at <= p_date_to))
      or
      (pa.wallet_entry_id is not null
        and (p_date_from is null or we.effective_at >= p_date_from)
        and (p_date_to is null or we.effective_at <= p_date_to))
    );

  -- Penalty income (09D): identical "active allocation, period-bound"
  -- derivation — recognized ONLY when an active allocation has
  -- actually settled LOAN_PENALTY, never merely because a penalty was
  -- assessed (section 18).
  select coalesce(sum(pa.amount), 0)
  into v_recognized_loan_penalty_income
  from public.payment_allocations pa
  left join public.payments p on p.id = pa.payment_id
  left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
  where pa.group_id = p_group_id
    and pa.allocation_target_type = 'LOAN_PENALTY'
    and (
      (pa.payment_id is not null and p.status = 'POSTED'
        and (p_date_from is null or p.effective_at >= p_date_from)
        and (p_date_to is null or p.effective_at <= p_date_to))
      or
      (pa.wallet_entry_id is not null
        and (p_date_from is null or we.effective_at >= p_date_from)
        and (p_date_to is null or we.effective_at <= p_date_to))
    );

  v_group_income := v_group_income + v_manual_income + v_recognized_loan_interest_income + v_recognized_loan_penalty_income;

  v_wallet_liability := public.member_wallet_balance_as_of(p_group_id, v_as_of);

  select coalesce(sum(s.outstanding), 0) into v_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.group_id = p_group_id;

  select coalesce(sum(la.principal_amount), 0)
  into v_disbursed_principal
  from public.loan_accounts la
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE', 'CLOSED');

  select coalesce(sum(pa.amount), 0)
  into v_principal_allocated
  from public.payment_allocations pa
  left join public.payments p on p.id = pa.payment_id
  join public.loan_accounts la on la.id = pa.loan_account_id
  where la.group_id = p_group_id
    and pa.allocation_target_type = 'LOAN_PRINCIPAL'
    and (pa.wallet_entry_id is not null or p.status = 'POSTED');

  v_funded_loan_principal_receivable := v_disbursed_principal - v_principal_allocated;

  select coalesce(sum(li.interest_due), 0)
  into v_scheduled_interest_total
  from public.loan_installments li
  join public.loan_accounts la on la.id = li.loan_account_id
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE', 'CLOSED');

  select coalesce(sum(pa.amount), 0)
  into v_recognized_interest_alltime
  from public.payment_allocations pa
  left join public.payments p on p.id = pa.payment_id
  join public.loan_accounts la on la.id = pa.loan_account_id
  where la.group_id = p_group_id
    and pa.allocation_target_type = 'LOAN_INTEREST'
    and (pa.wallet_entry_id is not null or p.status = 'POSTED');

  v_scheduled_unearned_interest := v_scheduled_interest_total - v_recognized_interest_alltime;

  -- Loan penalties outstanding (09D, point-in-time — never
  -- date-filtered, consistent with every other point-in-time figure
  -- here): every assessed penalty charge across this group's funded
  -- loans, minus every ACTIVE LOAN_PENALTY allocation to date. Unpaid
  -- penalties are never classified as physical funds or as funded
  -- principal receivable (section 20).
  select coalesce(sum(c.penalty_amount), 0)
  into v_loan_penalties_outstanding
  from public.loan_penalty_charges c
  join public.loan_accounts la on la.id = c.loan_account_id
  where la.group_id = p_group_id;

  v_loan_penalties_outstanding := v_loan_penalties_outstanding - (
    select coalesce(sum(pa.amount), 0)
    from public.payment_allocations pa
    left join public.payments p on p.id = pa.payment_id
    join public.loan_accounts la on la.id = pa.loan_account_id
    where la.group_id = p_group_id
      and pa.allocation_target_type = 'LOAN_PENALTY'
      and (pa.wallet_entry_id is not null or p.status = 'POSTED')
  );

  return jsonb_build_object(
    'as_of', v_as_of,
    'period_from', p_date_from,
    'period_to', p_date_to,
    'accounts', v_accounts,
    'total_financial_account_balance', v_total_balance,
    'group_income', v_group_income,
    'expenses', v_expenses,
    'net_operating_result', v_group_income - v_expenses,
    'pass_through_received', v_pass_through,
    'share_capital_received', v_share_capital,
    'member_wallet_liability', v_wallet_liability,
    'total_outstanding_member_obligations', v_outstanding,
    'funded_loan_principal_receivable', v_funded_loan_principal_receivable,
    'scheduled_unearned_interest', v_scheduled_unearned_interest,
    'recognized_loan_interest_income', v_recognized_loan_interest_income,
    'loan_penalties_outstanding', v_loan_penalties_outstanding,
    'recognized_loan_penalty_income', v_recognized_loan_penalty_income
  );
end;
$$;

comment on function public.rpc_get_financial_position(uuid, date, date) is
  'Financial Position / Hali ya Fedha (Prompt 08B, extended 09B/09C/
  09D). group_income now also includes recognized_loan_penalty_income
  (period-bound, recognized only when an active allocation settles
  LOAN_PENALTY — never merely because a penalty was assessed).
  loan_penalties_outstanding is a point-in-time figure, never classified
  as physical funds or funded principal receivable.';
