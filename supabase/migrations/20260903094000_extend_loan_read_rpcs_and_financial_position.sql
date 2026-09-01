-- Prompt 09B: extends three existing read RPCs (same signatures,
-- CREATE OR REPLACE — every existing caller keeps working unchanged),
-- following the exact precedent already set by
-- 20260901096000_extend_cashbook_read_rpc.sql for 08B.

-- ---------------------------------------------------------------------
-- rpc_get_loan_account — adds `events` (the lifecycle timeline,
-- section 25/26) and `disbursement` (non-null only once a disbursement
-- exists, section 25's "disbursement detail"/"funded loan detail").
-- Embedded directly rather than as separate RPCs: a single loan's
-- event history and disbursement are always small/bounded, so a
-- second round-trip would only add latency, never scalability.
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
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.installment_number), '[]'::jsonb)
  into v_installments
  from public.loan_installments i
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
    'created_at', la.created_at, 'updated_at', la.updated_at,
    'installments', v_installments,
    'events', v_events,
    'disbursement', v_disbursement
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

revoke all on function public.rpc_get_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_account(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_financial_position — adds `funded_loan_principal_receivable`
-- and `scheduled_unearned_interest` (section 15/16/21). Principal on
-- every DISBURSED/ACTIVE loan is a funded receivable the instant
-- disbursement happens; its scheduled future interest is deliberately
-- kept OUT of group_income here — 09B recognizes no interest income at
-- all (that policy is 09C's job) — so it is surfaced separately,
-- clearly labelled "scheduled/unearned", never folded into income.
-- group_income/expenses themselves need no change: they are already
-- computed purely from financial_manual_entries and payment
-- allocations, never by classifying financial_account_entries.source_type,
-- so a LOAN_DISBURSEMENT cashbook OUTFLOW was never at risk of being
-- counted as an operating expense in the first place.
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

  v_group_income := v_group_income + v_manual_income;

  v_wallet_liability := public.member_wallet_balance_as_of(p_group_id, v_as_of);

  select coalesce(sum(s.outstanding), 0) into v_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.group_id = p_group_id;

  -- Funded principal: the full frozen principal of every loan that has
  -- actually been disbursed (DISBURSED is transactional and never
  -- observed at rest — see rpc_disburse_loan_account — so ACTIVE alone
  -- covers every funded loan; DISBURSED is still checked defensively).
  -- No repayment exists yet in 09B, so nothing reduces this figure.
  select coalesce(sum(la.principal_amount), 0)
  into v_funded_loan_principal_receivable
  from public.loan_accounts la
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE');

  -- Scheduled/unearned interest across every funded loan's own
  -- installments — contractual, never recognized income (09C's job).
  select coalesce(sum(li.interest_due), 0)
  into v_scheduled_unearned_interest
  from public.loan_installments li
  join public.loan_accounts la on la.id = li.loan_account_id
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE');

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
    'scheduled_unearned_interest', v_scheduled_unearned_interest
  );
end;
$$;

comment on function public.rpc_get_financial_position(uuid, date, date) is
  'Financial Position / Hali ya Fedha (Prompt 08B, extended 09B) — NOT
  a full accounting balance sheet. group_income already nets in manual
  INCOME entries; pass_through_received/share_capital_received are
  shown separately and never included in group_income;
  member_wallet_liability is a member advance/liability, never
  deducted from total_financial_account_balance.
  funded_loan_principal_receivable is the sum of frozen principal
  across every DISBURSED/ACTIVE loan (09B); scheduled_unearned_interest
  is that same set''s contractual future interest, deliberately never
  added to group_income — interest recognition is a 09C policy
  decision, not a 09B one. total_outstanding_member_obligations is
  always current, never date-filtered.';

revoke all on function public.rpc_get_financial_position(uuid, date, date) from public;
grant execute on function public.rpc_get_financial_position(uuid, date, date) to authenticated;
revoke execute on function public.rpc_get_financial_position(uuid, date, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_financial_account_entries — resolves loan_number/borrower
-- name for LOAN_DISBURSEMENT rows (section 22), the same way PAYMENT/
-- MANUAL_INCOME/FINANCIAL_ADJUSTMENT rows already resolve their own
-- context. Same 9-argument signature as the 08B extension — no new
-- parameters needed, since p_source_type already exists as a filter.
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_financial_account_entries(
  p_group_id uuid,
  p_account_id uuid,
  p_limit integer default 10,
  p_offset integer default 0,
  p_date_from date default null,
  p_date_to date default null,
  p_entry_type public.financial_account_entry_type default null,
  p_source_type text default null,
  p_category_id uuid default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_account_group_id uuid;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.view') then
    raise exception 'Not authorized to view financial accounts in this group' using errcode = '42501';
  end if;

  select group_id into v_account_group_id from public.financial_accounts where id = p_account_id;
  if v_account_group_id is null or v_account_group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  select count(*) into v_total
  from public.financial_account_entries e
  where e.financial_account_id = p_account_id
    and (p_date_from is null or e.effective_at >= p_date_from)
    and (p_date_to is null or e.effective_at <= p_date_to)
    and (p_entry_type is null or e.entry_type = p_entry_type)
    and (p_source_type is null or e.source_type = p_source_type)
    and (
      p_category_id is null
      or exists (
        select 1 from public.financial_manual_entries me
        where me.id = e.source_id and me.category_id = p_category_id
      )
    );

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.effective_at desc, rows.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select
      e.id as entry_id, e.entry_type, e.amount, e.effective_at, e.description,
      e.reference, e.transfer_reference, e.source_type, e.source_id,
      e.reverses_entry_id, e.created_at, e.created_by,
      counterparty.id as counterparty_account_id,
      counterparty.name as counterparty_account_name,
      pay.receipt_number as payment_receipt_number,
      me.category_id as manual_entry_category_id,
      cat.name as manual_entry_category_name,
      me.status::text as manual_entry_status,
      adj.reason as adjustment_reason,
      ld.loan_account_id as loan_disbursement_loan_account_id,
      la.loan_number as loan_disbursement_loan_number,
      gm.display_name as loan_disbursement_borrower_display_name
    from public.financial_account_entries e
    left join public.financial_account_entries pair
      on pair.transfer_reference = e.transfer_reference
      and pair.financial_account_id <> e.financial_account_id
      and e.transfer_reference is not null
    left join public.financial_accounts counterparty
      on counterparty.id = pair.financial_account_id
    left join public.payments pay
      on e.source_type in ('PAYMENT', 'PAYMENT_REVERSAL') and pay.id = e.source_id
    left join public.financial_manual_entries me
      on e.source_type in ('MANUAL_INCOME', 'EXPENSE', 'MANUAL_INCOME_REVERSAL', 'EXPENSE_REVERSAL')
      and me.id = e.source_id
    left join public.financial_categories cat on cat.id = me.category_id
    left join public.financial_adjustments adj
      on e.source_type = 'FINANCIAL_ADJUSTMENT' and adj.id = e.source_id
    left join public.loan_disbursements ld
      on e.source_type = 'LOAN_DISBURSEMENT' and ld.id = e.source_id
    left join public.loan_accounts la on la.id = ld.loan_account_id
    left join public.group_memberships gm on gm.id = la.membership_id
    where e.financial_account_id = p_account_id
      and (p_date_from is null or e.effective_at >= p_date_from)
      and (p_date_to is null or e.effective_at <= p_date_to)
      and (p_entry_type is null or e.entry_type = p_entry_type)
      and (p_source_type is null or e.source_type = p_source_type)
      and (p_category_id is null or me.category_id = p_category_id)
    order by e.effective_at desc, e.created_at desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

comment on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) is
  'Paginated, filterable cashbook for one account (Prompt 08A, extended
  08B/09B). source_type is the authoritative economic classification —
  LOAN_DISBURSEMENT (09B) resolves loan_number/borrower_display_name
  the same way PAYMENT resolves its receipt_number. A LOAN_DISBURSEMENT
  row is an OUTFLOW but is never classified as an expense — expenses
  are computed elsewhere purely from financial_manual_entries, never
  by scanning this table''s source_type.';

revoke all on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) from public;
grant execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) to authenticated;
revoke execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) from anon;
