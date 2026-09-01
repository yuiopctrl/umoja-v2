-- Prompt 09C: read-model extensions for loan repayment. Every
-- installment/loan-level "paid"/"outstanding" figure below is derived
-- fresh from loan_installment_component_states on every read — never a
-- stored counter (section 23 — "read-model derived from allocations,
-- not stored counters").

-- ---------------------------------------------------------------------
-- loan_account_summary — the aggregated member-loan-summary figures
-- (section 22), shared by rpc_get_loan_account and rpc_list_loan_accounts
-- so the two can never disagree.
-- ---------------------------------------------------------------------

create or replace function public.loan_account_summary(p_loan_account_id uuid)
returns table (
  principal_repaid numeric,
  principal_outstanding numeric,
  interest_recognized numeric,
  interest_outstanding numeric,
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
    coalesce(sum(ic.outstanding), 0),
    (select min(it.due_date) from installment_totals it where it.installment_outstanding > 0),
    coalesce((select sum(it.installment_outstanding) from installment_totals it where it.due_date < current_date), 0)
  from installment_components ic;
$$;

revoke all on function public.loan_account_summary(uuid) from public, anon, authenticated;

comment on function public.loan_account_summary(uuid) is
  'Locked-down internal helper. Member-facing loan summary figures
  (Prompt 09C section 22) — always derived from
  loan_installment_component_states, never a stored counter.';

-- ---------------------------------------------------------------------
-- rpc_get_loan_account — installments now carry principal_paid/
-- principal_outstanding/interest_paid/interest_outstanding/
-- total_outstanding/status (section 21/23); the loan itself carries the
-- aggregated summary (section 22).
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
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0),
    'status', (
      case
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) > 0 then 'PARTIALLY_PAID'
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
    'created_at', la.created_at, 'updated_at', la.updated_at,
    'installments', v_installments,
    'events', v_events,
    'disbursement', v_disbursement,
    'principal_repaid', v_summary.principal_repaid,
    'principal_outstanding', v_summary.principal_outstanding,
    'interest_recognized', v_summary.interest_recognized,
    'interest_outstanding', v_summary.interest_outstanding,
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

revoke all on function public.rpc_get_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_account(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_loan_accounts — same summary fields per row, doubling as the
-- member loan summary list (section 22 — "use server-side aggregation",
-- already reachable via p_membership_id, no new RPC needed).
-- ---------------------------------------------------------------------

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
      la.status, la.created_at, la.updated_at,
      sm.principal_repaid, sm.principal_outstanding,
      sm.interest_recognized, sm.interest_outstanding,
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

revoke all on function public.rpc_list_loan_accounts(
  uuid, uuid, uuid, public.loan_account_status, integer, integer
) from public;
grant execute on function public.rpc_list_loan_accounts(
  uuid, uuid, uuid, public.loan_account_status, integer, integer
) to authenticated;
revoke execute on function public.rpc_list_loan_accounts(
  uuid, uuid, uuid, public.loan_account_status, integer, integer
) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_loan_installments — same per-installment fields as
-- rpc_get_loan_account's embedded schedule.
-- ---------------------------------------------------------------------

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
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0),
    'status', (
      case
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) > 0 then 'PARTIALLY_PAID'
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
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  return jsonb_build_object('loan_account_id', p_loan_account_id, 'installments', v_items);
end;
$$;

revoke all on function public.rpc_list_loan_installments(uuid, uuid) from public;
grant execute on function public.rpc_list_loan_installments(uuid, uuid) to authenticated;
revoke execute on function public.rpc_list_loan_installments(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_financial_position — funded_loan_principal_receivable and
-- scheduled_unearned_interest become derived (disbursed minus active
-- allocations, section 13/15) instead of a static sum; a new
-- recognized_loan_interest_income figure is added and folded into
-- group_income (section 14 — "recognize interest as GROUP_INCOME only
-- when an active allocation settles LOAN_INTEREST"). Both the period-
-- bound recognized-income figure and the point-in-time receivable/
-- unearned-interest figures share the same "active allocation" test:
-- wallet-sourced always counts, payment-sourced counts only while its
-- parent payment is still POSTED — identical to every other allocation
-- derivation in this codebase.
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
  -- settled within the requested period — payment-sourced counts only
  -- while POSTED, wallet-sourced always counts (not reversible).
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

  v_group_income := v_group_income + v_manual_income + v_recognized_loan_interest_income;

  v_wallet_liability := public.member_wallet_balance_as_of(p_group_id, v_as_of);

  select coalesce(sum(s.outstanding), 0) into v_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.group_id = p_group_id;

  -- Funded principal receivable (09C): disbursed principal minus every
  -- ACTIVE principal allocation to date — never a static sum of
  -- original principals (section 13). Point-in-time, not date-filtered,
  -- consistent with every other point-in-time figure on this report.
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

  -- Scheduled/unearned interest (09C): scheduled contractual interest
  -- across every funded loan, minus interest actually recognized to
  -- date — never double-counted against recognized_loan_interest_income
  -- above (section 15).
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
    'recognized_loan_interest_income', v_recognized_loan_interest_income
  );
end;
$$;

comment on function public.rpc_get_financial_position(uuid, date, date) is
  'Financial Position / Hali ya Fedha (Prompt 08B, extended 09B/09C).
  group_income now includes recognized_loan_interest_income (period-
  bound) alongside contribution GROUP_INCOME allocations and manual
  income. funded_loan_principal_receivable and scheduled_unearned_interest
  are both derived, point-in-time figures: disbursed principal / total
  scheduled interest minus active allocations to date — never a static
  sum, never double-counting recognized income inside the unearned
  figure.';

revoke all on function public.rpc_get_financial_position(uuid, date, date) from public;
grant execute on function public.rpc_get_financial_position(uuid, date, date) to authenticated;
revoke execute on function public.rpc_get_financial_position(uuid, date, date) from anon;
