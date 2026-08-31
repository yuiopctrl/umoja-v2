-- Prompt 08B: Financial Position read model (sections 23-25).
--
-- Deliberately NOT called a "Balance Sheet" — it does not meet
-- accounting standards for one (no full GL, no assets/liabilities/
-- equity classification beyond what is explicitly listed below). Title
-- is "Financial Position" / "Hali ya Fedha".
--
-- Section 41 stop-condition check (contribution-treatment context):
-- contribution_types.accounting_treatment is permanently locked by
-- rpc_update_contribution_type the moment any of its periods reaches
-- OPEN/CLOSED (contribution_type_has_posted_period(), 06A) — so a live
-- join from payment_allocations -> member_contribution_charges ->
-- contribution_setups -> contribution_types is safe: a contribution
-- type's treatment can never retroactively change once a payment could
-- possibly have been allocated against it. No new snapshot column is
-- needed for this reporting to be historically accurate.
--
-- "Balance AS OF" vs "movement DURING period" (section 25):
-- account/wallet balances use financial_account_balance_as_of() /
-- member_wallet_balance_as_of() (new helpers below, additive — the
-- existing "always current" financial_account_balance()/
-- member_wallet_balance() are untouched and still used everywhere
-- else), cut off at p_date_to (default: current_date). Income/expense/
-- pass-through/share-capital are genuine period movements, filtered by
-- p_date_from/p_date_to with no backend-hardcoded default range (a
-- null bound means unbounded on that side) — any "current month"
-- default belongs in Flutter's date-range picker, never assumed here.
-- Outstanding member obligations is inherently a "right now" figure
-- (an unpaid amount has no historical point-in-time meaning the way a
-- balance does), so it is never date-filtered.

-- ---------------------------------------------------------------------
-- financial_account_balance_as_of / member_wallet_balance_as_of —
-- additive cutoff-aware siblings of the existing always-current
-- helpers. Same locked-down internal-helper posture (no client grant).
-- ---------------------------------------------------------------------

create or replace function public.financial_account_balance_as_of(p_account_id uuid, p_as_of date)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(
    case
      when entry_type in ('INFLOW', 'TRANSFER_IN') then amount
      else -amount
    end
  ), 0)
  from public.financial_account_entries
  where financial_account_id = p_account_id
    and effective_at <= p_as_of;
$$;

revoke all on function public.financial_account_balance_as_of(uuid, date) from public, anon, authenticated;

create or replace function public.member_wallet_balance_as_of(p_group_id uuid, p_as_of date)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(case when entry_type = 'PAYMENT_CREDIT' then amount else -amount end), 0)
  from public.member_wallet_entries
  where group_id = p_group_id
    and effective_at <= p_as_of;
$$;

revoke all on function public.member_wallet_balance_as_of(uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_get_financial_position
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
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_report.view') then
    raise exception 'Not authorized to view financial reports in this group' using errcode = '42501';
  end if;

  -- Physical funds: per-account balance AS OF the cutoff, plus
  -- account_type subtotals (Cash/Bank/Mobile Money) and a grand total.
  -- Every account regardless of is_active — deactivating an account
  -- never makes its historical balance disappear from the group total.
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

  -- Contribution-treatment-classified cash received during the period
  -- — only payment-sourced allocations count (wallet-sourced
  -- allocations never moved cash; see payment_allocations.wallet_entry_id),
  -- and only while the parent payment is still POSTED (a reversed
  -- payment's allocations no longer represent real cash received).
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
    and p.status = 'POSTED'
    and (p_date_from is null or p.effective_at >= p_date_from)
    and (p_date_to is null or p.effective_at <= p_date_to);

  -- Manual income/expense during the period — only still-POSTED
  -- entries (a REVERSED manual entry no longer represents real income/
  -- expense; its compensating cashbook entry is what nets the cash
  -- effect, never a second adjustment to this figure).
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

  v_group_income := v_group_income + v_manual_income;

  v_wallet_liability := public.member_wallet_balance_as_of(p_group_id, v_as_of);

  -- Outstanding member obligations: always "right now" (section 25 —
  -- an unpaid amount is a current-state figure, never a historical
  -- point-in-time one), reusing the same authoritative per-charge
  -- helper the member-centric charges view (UAT-FIX-03) already relies
  -- on rather than re-deriving outstanding logic here.
  select coalesce(sum(s.outstanding), 0) into v_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.group_id = p_group_id;

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
    'total_outstanding_member_obligations', v_outstanding
  );
end;
$$;

comment on function public.rpc_get_financial_position(uuid, date, date) is
  'Financial Position / Hali ya Fedha (Prompt 08B) — NOT a full
  accounting balance sheet. group_income already nets in manual INCOME
  entries; pass_through_received/share_capital_received are shown
  separately and are never included in group_income;
  member_wallet_liability is a member advance/liability, never
  deducted from total_financial_account_balance (cash balance and
  economic ownership are separate concepts, see docs/product/
  financial_operations.md). total_outstanding_member_obligations is
  always current, never date-filtered.';

revoke all on function public.rpc_get_financial_position(uuid, date, date) from public;
grant execute on function public.rpc_get_financial_position(uuid, date, date) to authenticated;
revoke execute on function public.rpc_get_financial_position(uuid, date, date) from anon;
