-- Prompt 09E: read-model extensions for loan servicing.
--
-- IMPORTANT: rpc_get_loan_account/rpc_list_loan_installments/
-- rpc_get_financial_position each already carry 09D/BLOCKER-01
-- extensions (penalty fields, loan_origin, opening_position,
-- origin-aware funded-principal, loan_penalties_outstanding) from
-- 20260908097000/20260909094000/20260909095000 — this migration is
-- rebased on those exact latest bodies (not the earlier 09C versions)
-- and adds ONLY the 09E deltas on top, never regressing them.
--
-- loan_installment_component_states — a CANCELLED installment's
-- INTEREST and PRINCIPAL gross both collapse to zero (section 7):
--   * early-settlement-cancelled rows already had their principal paid
--     in full before cancellation (outstanding was already zero), so
--     this changes nothing for them;
--   * prepayment/restructure-cancelled rows never received any
--     allocation at all (they are being replaced, not settled) — left
--     unchanged they would still show a fully-outstanding balance,
--     wrongly inflating loan_account_summary/Financial Position and
--     blocking closure.
-- Neither branch ever recognizes this as paid/income — it simply stops
-- being counted, exactly like future interest was never recognized in
-- the first place (section 5 — never a fake reversal of income that
-- was never booked). PENALTY is untouched: a cancelled installment
-- (always not-yet-due at the moment of cancellation) never has one.

create or replace function public.loan_installment_component_states(p_loan_installment_id uuid)
returns table (
  component_type text,
  priority integer,
  gross numeric,
  allocated numeric,
  outstanding numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with gross_components as (
    select 'PENALTY'::text as component_type, 0 as priority,
      coalesce((
        select sum(c.penalty_amount) from public.loan_penalty_charges c
        where c.loan_installment_id = p_loan_installment_id
      ), 0) as gross
    union all
    select 'INTEREST'::text, 1,
      case when li.cancelled_at is not null then 0 else li.interest_due end
    from public.loan_installments li
    where li.id = p_loan_installment_id
    union all
    select 'PRINCIPAL'::text, 2,
      case when li.cancelled_at is not null then 0 else li.principal_due end
    from public.loan_installments li
    where li.id = p_loan_installment_id
  ),
  allocated_totals as (
    select
      case pa.allocation_target_type
        when 'LOAN_INTEREST' then 'INTEREST'
        when 'LOAN_PENALTY' then 'PENALTY'
        else 'PRINCIPAL'
      end as component_type,
      sum(pa.amount) as allocated
    from public.payment_allocations pa
    left join public.payments p on p.id = pa.payment_id
    where pa.loan_installment_id = p_loan_installment_id
      and (pa.wallet_entry_id is not null or p.status = 'POSTED')
    group by 1
  )
  select
    g.component_type,
    g.priority,
    g.gross,
    coalesce(a.allocated, 0) as allocated,
    greatest(0, g.gross - coalesce(a.allocated, 0)) as outstanding
  from gross_components g
  left join allocated_totals a on a.component_type = g.component_type
  order by g.priority;
$$;

revoke all on function public.loan_installment_component_states(uuid) from public, anon, authenticated;

comment on function public.loan_installment_component_states(uuid) is
  'Locked-down internal helper. For one loan installment: PENALTY,
  INTEREST, PRINCIPAL (priority order). A CANCELLED installment
  (Prompt 09E) always contributes zero INTEREST/PRINCIPAL gross,
  regardless of what was ever allocated against it — never a stored
  balance, never a fake income reversal.';

-- ---------------------------------------------------------------------
-- rpc_get_loan_account (rebased on 20260909095000) — installments now
-- also surface cancelled_at/cancellation_reason and a CANCELLED status
-- (checked first, before PAID/OVERDUE/etc). Also embeds
-- prepayment_events/restructure_events (append-only audit history,
-- exactly like the existing embedded events array).
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
  v_opening_position jsonb;
  v_prepayment_events jsonb;
  v_restructure_events jsonb;
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
    'cancelled_at', i.cancelled_at,
    'cancellation_reason', i.cancellation_reason,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', coalesce(pc.outstanding, 0),
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', coalesce(ic.outstanding, 0),
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', coalesce(penc.outstanding, 0),
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0),
    'status', (
      case
        when i.cancelled_at is not null then 'CANCELLED'
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

  select coalesce(jsonb_agg(to_jsonb(pe) order by pe.created_at), '[]'::jsonb)
  into v_prepayment_events
  from public.loan_prepayment_events pe
  where pe.loan_account_id = p_loan_account_id and pe.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(re) order by re.created_at), '[]'::jsonb)
  into v_restructure_events
  from public.loan_restructure_events re
  where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id;

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
    'opening_as_of_date', o.opening_as_of_date,
    'original_disbursement_date', o.original_disbursement_date,
    'original_loan_number', o.original_loan_number,
    'original_principal', o.original_principal,
    'opening_principal_outstanding', o.opening_principal_outstanding,
    'opening_principal_arrears', o.opening_principal_arrears,
    'opening_interest_arrears', o.opening_interest_arrears,
    'opening_penalty_arrears', o.opening_penalty_arrears,
    'future_scheduled_principal', o.future_scheduled_principal,
    'future_scheduled_interest', o.future_scheduled_interest,
    'arrears_due_date', o.arrears_due_date,
    'remaining_installment_count', o.remaining_installment_count,
    'next_due_date', o.next_due_date,
    'notes', o.notes,
    'created_at', o.created_at
  )
  into v_opening_position
  from public.loan_opening_positions o
  where o.loan_account_id = p_loan_account_id and o.group_id = p_group_id;

  select * into v_summary from public.loan_account_summary(p_loan_account_id);

  select jsonb_build_object(
    'id', la.id, 'group_id', la.group_id, 'membership_id', la.membership_id,
    'borrower_display_name', gm.display_name, 'borrower_member_number', gm.member_number,
    'loan_product_id', la.loan_product_id, 'loan_product_name', lp.name, 'loan_product_code', lp.code,
    'loan_number', la.loan_number,
    'loan_origin', la.loan_origin,
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
    'prepayment_events', v_prepayment_events,
    'restructure_events', v_restructure_events,
    'disbursement', v_disbursement,
    'opening_position', v_opening_position,
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

revoke all on function public.rpc_get_loan_account(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_account(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_account(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_loan_installments (rebased on 20260908097000) — same
-- cancelled_at/cancellation_reason/CANCELLED-status delta as above.
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
    'cancelled_at', i.cancelled_at,
    'cancellation_reason', i.cancellation_reason,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', coalesce(pc.outstanding, 0),
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', coalesce(ic.outstanding, 0),
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', coalesce(penc.outstanding, 0),
    'total_outstanding', coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0),
    'status', (
      case
        when i.cancelled_at is not null then 'CANCELLED'
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

revoke all on function public.rpc_list_loan_installments(uuid, uuid) from public;
grant execute on function public.rpc_list_loan_installments(uuid, uuid) to authenticated;
revoke execute on function public.rpc_list_loan_installments(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_financial_position (rebased on 20260909094000) —
-- funded_loan_principal_receivable must also subtract
-- LOAN_PRINCIPAL_PREPAYMENT allocations (a prepayment is genuine
-- principal repayment, never income — same treatment as ordinary
-- LOAN_PRINCIPAL). scheduled_unearned_interest must exclude CANCELLED
-- installments' interest_due — that interest will never be earned or
-- recognized, so it must never linger in the report as "unearned"
-- forever after an early settlement/prepayment/restructure (section
-- 5/7 — it was voided, not merely deferred).
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

  v_funded_loan_principal_receivable := v_disbursed_principal - v_principal_allocated;

  select coalesce(sum(li.interest_due), 0)
  into v_scheduled_interest_total
  from public.loan_installments li
  join public.loan_accounts la on la.id = li.loan_account_id
  where la.group_id = p_group_id and la.status in ('DISBURSED', 'ACTIVE', 'CLOSED')
    and li.cancelled_at is null;

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

revoke all on function public.rpc_get_financial_position(uuid, date, date) from public;
grant execute on function public.rpc_get_financial_position(uuid, date, date) to authenticated;
revoke execute on function public.rpc_get_financial_position(uuid, date, date) from anon;
