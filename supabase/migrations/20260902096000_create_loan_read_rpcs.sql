-- Prompt 09A: Loan read RPCs (section R). Every read is server-side
-- paginated/filtered — never a full-tenant fetch filtered client-side.
-- "Member loan list" (section R item 5) is `rpc_list_loan_accounts`
-- parameterized by p_membership_id, not a separate RPC — the shapes
-- are identical, so a second RPC would only duplicate this one.

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
    'installments', v_installments
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
      la.status, la.created_at, la.updated_at
    from public.loan_accounts la
    join public.group_memberships gm on gm.id = la.membership_id
    join public.loan_products lp on lp.id = la.loan_product_id
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

  select coalesce(jsonb_agg(to_jsonb(i) order by i.installment_number), '[]'::jsonb) into v_items
  from public.loan_installments i
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  return jsonb_build_object('loan_account_id', p_loan_account_id, 'installments', v_items);
end;
$$;

revoke all on function public.rpc_list_loan_installments(uuid, uuid) from public;
grant execute on function public.rpc_list_loan_installments(uuid, uuid) to authenticated;
revoke execute on function public.rpc_list_loan_installments(uuid, uuid) from anon;
