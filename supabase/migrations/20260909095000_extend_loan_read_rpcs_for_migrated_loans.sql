-- Prompt 09D-UAT-BLOCKER-01: surfaces loan_origin and the full opening
-- position (section 38: Loan Detail must clearly show MIGRATED/
-- BROUGHT FORWARD, original disbursement date, opening as-of date,
-- original principal, opening principal/arrears breakdown, remaining
-- schedule terms) and adds `origin` to penalty history rows (section
-- 16: OPENING vs ASSESSED must remain distinguishable in audit/
-- history). Same signatures throughout — plain create or replace.

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
      la.loan_number, la.loan_origin, la.principal_amount, la.interest_rate, la.interest_rate_basis,
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

-- ---------------------------------------------------------------------
-- rpc_list_loan_penalty_charges — surfaces origin (OPENING vs
-- ASSESSED) so Loan Detail's penalty history can distinguish them.
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_loan_penalty_charges(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_loan_installment_id uuid default null
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

  if not public.has_group_permission(p_group_id, 'loan_penalty.view') then
    raise exception 'Not authorized to view loan penalties in this group' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.loan_accounts where id = p_loan_account_id and group_id = p_group_id
  ) then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'loan_account_id', c.loan_account_id,
    'loan_installment_id', c.loan_installment_id,
    'installment_number', li.installment_number,
    'assessment_date', c.assessment_date,
    'sequence_number', c.sequence_number,
    'origin', c.origin,
    'penalty_type', c.penalty_type,
    'penalty_frequency', c.penalty_frequency,
    'basis_amount', c.basis_amount,
    'rate', c.rate,
    'fixed_amount', c.fixed_amount,
    'penalty_amount', c.penalty_amount,
    'paid_amount', s.allocated,
    'outstanding_amount', s.outstanding,
    'created_at', c.created_at
  ) order by c.assessment_date, c.sequence_number), '[]'::jsonb)
  into v_items
  from public.loan_penalty_charges c
  join public.loan_installments li on li.id = c.loan_installment_id
  cross join lateral (
    select * from public.loan_penalty_charge_states(c.loan_installment_id) s2
    where s2.charge_id = c.id
  ) s
  where c.loan_account_id = p_loan_account_id
    and c.group_id = p_group_id
    and (p_loan_installment_id is null or c.loan_installment_id = p_loan_installment_id);

  return jsonb_build_object('loan_account_id', p_loan_account_id, 'items', v_items);
end;
$$;
