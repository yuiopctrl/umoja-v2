-- Prompt 09F-A section 21: rpc_get_financial_position independently
-- duplicates the gross-minus-allocated arithmetic (it does not call
-- loan_installment_component_states/loan_penalty_charge_states), so it
-- would NOT automatically pick up 09F-A adjustments — this is a
-- correctness patch only, not a broader financial-position refactor.
--
-- loan_penalties_outstanding and scheduled_unearned_interest both gain a
-- net_adjustment term, mirroring exactly how each already nets its own
-- "allocated" term. funded_loan_principal_receivable is intentionally
-- untouched — principal is not adjustable in 09F-A (section 21 "do not
-- invent principal adjustment logic").
--
-- Rebased on the exact latest body (20260913096000) — every other field
-- is byte-for-byte unchanged.

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
  v_net_interest_adjustment numeric;
  v_recognized_interest_alltime numeric;
  v_recognized_loan_interest_income numeric;
  v_recognized_loan_penalty_income numeric;
  v_loan_penalties_outstanding numeric;
  v_net_penalty_adjustment numeric;
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

  select coalesce(sum(
    case
      when la.loan_origin = 'MIGRATED' then lop.opening_principal_outstanding
      else la.principal_amount
    end
  ), 0)
  into v_disbursed_principal
  from public.loan_accounts la
  left join public.loan_opening_positions lop on lop.loan_account_id = la.id
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE', 'CLOSED');

  select coalesce(sum(pa.amount), 0)
  into v_principal_allocated
  from public.payment_allocations pa
  left join public.payments p on p.id = pa.payment_id
  join public.loan_accounts la on la.id = pa.loan_account_id
  where la.group_id = p_group_id
    and pa.allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT')
    and (pa.wallet_entry_id is not null or p.status = 'POSTED');

  -- Principal is not adjustable in 09F-A — untouched.
  v_funded_loan_principal_receivable := v_disbursed_principal - v_principal_allocated;

  select coalesce(sum(li.interest_due), 0)
  into v_scheduled_interest_total
  from public.loan_installments li
  join public.loan_accounts la on la.id = li.loan_account_id
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE', 'CLOSED')
    and li.cancelled_at is null;

  select coalesce(sum(oa.amount), 0)
  into v_net_interest_adjustment
  from public.loan_obligation_adjustments oa
  join public.loan_installments li on li.id = oa.loan_installment_id
  join public.loan_accounts la on la.id = li.loan_account_id
  where la.group_id = p_group_id and oa.target_type = 'LOAN_INTEREST' and li.cancelled_at is null;

  select coalesce(sum(pa.amount), 0)
  into v_recognized_interest_alltime
  from public.payment_allocations pa
  left join public.payments p on p.id = pa.payment_id
  join public.loan_accounts la on la.id = pa.loan_account_id
  where la.group_id = p_group_id
    and pa.allocation_target_type = 'LOAN_INTEREST'
    and (pa.wallet_entry_id is not null or p.status = 'POSTED');

  v_scheduled_unearned_interest := v_scheduled_interest_total + v_net_interest_adjustment - v_recognized_interest_alltime;

  select coalesce(sum(c.penalty_amount), 0)
  into v_loan_penalties_outstanding
  from public.loan_penalty_charges c
  join public.loan_accounts la on la.id = c.loan_account_id
  where la.group_id = p_group_id;

  select coalesce(sum(oa.amount), 0)
  into v_net_penalty_adjustment
  from public.loan_obligation_adjustments oa
  join public.loan_accounts la on la.id = oa.loan_account_id
  where la.group_id = p_group_id and oa.target_type = 'LOAN_PENALTY';

  v_loan_penalties_outstanding := v_loan_penalties_outstanding + v_net_penalty_adjustment - (
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

revoke all on function public.rpc_get_financial_position(uuid, date, date) from public;
grant execute on function public.rpc_get_financial_position(uuid, date, date) to authenticated;
revoke execute on function public.rpc_get_financial_position(uuid, date, date) from anon;
