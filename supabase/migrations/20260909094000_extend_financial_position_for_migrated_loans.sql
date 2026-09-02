-- Prompt 09D-UAT-BLOCKER-01: Financial Position's disbursed-principal
-- sum must use each loan's ACTUAL funded contribution — for a NEW loan
-- that is still `principal_amount` (the full disbursed amount); for a
-- MIGRATED loan it is `opening_principal_outstanding` from
-- loan_opening_positions, NEVER `principal_amount` (the historical
-- ORIGINAL principal, most of which may have already been repaid
-- before Umoja). Using principal_amount for a migrated loan would
-- permanently overstate the receivable by exactly the
-- already-historically-repaid portion, with no installment ever able
-- to pay it off (section 9/10/35). scheduled_unearned_interest needs
-- NO change — it already sums `interest_due` across every installment
-- (arrears + future, for a migrated loan) generically, regardless of
-- origin. Same signature — plain create or replace.

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

  -- Prompt 09D-UAT-BLOCKER-01: origin-aware funded-principal
  -- contribution — NEW uses principal_amount (the disbursed amount);
  -- MIGRATED uses opening_principal_outstanding (what Umoja actually
  -- took responsibility for, never the historical original principal).
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
  09D/09D-UAT-BLOCKER-01). funded_loan_principal_receivable is
  origin-aware: a NEW loan contributes its disbursed principal_amount;
  a MIGRATED loan contributes its opening_principal_outstanding (never
  principal_amount, which is the historical original — most of it may
  already have been repaid before Umoja). Every other figure derives
  generically from loan_installments/loan_penalty_charges regardless of
  origin.';
