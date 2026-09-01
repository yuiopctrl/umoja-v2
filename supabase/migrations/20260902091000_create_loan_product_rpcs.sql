-- Prompt 09A: Loan Product RPCs — create/update/list/detail. Mirrors
-- the rpc_create_financial_category/rpc_update_financial_category/
-- rpc_list_financial_categories pattern exactly: one update RPC toggles
-- is_active (no separate activate/deactivate RPC needed), and a
-- product is never hard-deleted, only deactivated.

create or replace function public.rpc_create_loan_product(
  p_group_id uuid,
  p_code text,
  p_name text,
  p_minimum_principal numeric,
  p_minimum_term integer,
  p_maximum_term integer,
  p_interest_rate numeric,
  p_interest_rate_basis public.loan_interest_rate_basis,
  p_interest_method public.loan_interest_method,
  p_maximum_principal numeric default null,
  p_description text default null,
  p_term_unit public.loan_term_unit default 'MONTH',
  p_repayment_frequency public.loan_repayment_frequency default 'MONTHLY'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_product.manage') then
    raise exception 'Not authorized to manage loan products in this group' using errcode = '42501';
  end if;

  if p_code is null or btrim(p_code) = '' then
    raise exception 'Loan product code is required' using errcode = '22023';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'Loan product name is required' using errcode = '22023';
  end if;
  if p_minimum_principal is null or p_minimum_principal <= 0 then
    raise exception 'LOAN_PRODUCT_MINIMUM_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if p_maximum_principal is not null and p_maximum_principal < p_minimum_principal then
    raise exception 'LOAN_PRODUCT_MAXIMUM_PRINCIPAL_BELOW_MINIMUM' using errcode = '22023';
  end if;
  if p_minimum_term is null or p_minimum_term <= 0 then
    raise exception 'LOAN_PRODUCT_MINIMUM_TERM_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if p_maximum_term is null or p_maximum_term < p_minimum_term then
    raise exception 'LOAN_PRODUCT_MAXIMUM_TERM_BELOW_MINIMUM' using errcode = '22023';
  end if;
  if p_interest_rate is null or p_interest_rate < 0 then
    raise exception 'LOAN_PRODUCT_INTEREST_RATE_INVALID' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.loan_products
    where group_id = p_group_id and lower(code) = lower(btrim(p_code))
  ) then
    raise exception 'Loan product code already exists in this group' using errcode = '23505';
  end if;

  insert into public.loan_products (
    group_id, code, name, description,
    minimum_principal, maximum_principal,
    minimum_term, maximum_term, term_unit,
    interest_rate, interest_rate_basis, interest_method,
    repayment_frequency, created_by, updated_by
  ) values (
    p_group_id, btrim(p_code), btrim(p_name), p_description,
    p_minimum_principal, p_maximum_principal,
    p_minimum_term, p_maximum_term, p_term_unit,
    p_interest_rate, p_interest_rate_basis, p_interest_method,
    p_repayment_frequency, v_uid, v_uid
  )
  returning id into v_id;

  select public.rpc_get_loan_product(p_group_id, v_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency
) from public;
grant execute on function public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency
) to authenticated;
revoke execute on function public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency
) from anon;

-- ---------------------------------------------------------------------
-- rpc_update_loan_product — partial update, every field optional;
-- also the sole path to deactivate/reactivate (p_is_active). Section E:
-- this NEVER touches any loan_accounts row — existing loans keep their
-- own frozen snapshot regardless of what changes here.
-- ---------------------------------------------------------------------

create or replace function public.rpc_update_loan_product(
  p_group_id uuid,
  p_product_id uuid,
  p_name text default null,
  p_description text default null,
  p_minimum_principal numeric default null,
  p_maximum_principal numeric default null,
  p_minimum_term integer default null,
  p_maximum_term integer default null,
  p_interest_rate numeric default null,
  p_interest_rate_basis public.loan_interest_rate_basis default null,
  p_interest_method public.loan_interest_method default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product record;
  v_new_min_principal numeric;
  v_new_max_principal numeric;
  v_new_min_term integer;
  v_new_max_term integer;
  v_new_rate numeric;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_product.manage') then
    raise exception 'Not authorized to manage loan products in this group' using errcode = '42501';
  end if;

  select * into v_product from public.loan_products where id = p_product_id;
  if v_product.group_id is null or v_product.group_id <> p_group_id then
    raise exception 'Loan product not found in group' using errcode = '22023';
  end if;

  v_new_min_principal := coalesce(p_minimum_principal, v_product.minimum_principal);
  v_new_max_principal := coalesce(p_maximum_principal, v_product.maximum_principal);
  v_new_min_term := coalesce(p_minimum_term, v_product.minimum_term);
  v_new_max_term := coalesce(p_maximum_term, v_product.maximum_term);
  v_new_rate := coalesce(p_interest_rate, v_product.interest_rate);

  if v_new_min_principal <= 0 then
    raise exception 'LOAN_PRODUCT_MINIMUM_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if v_new_max_principal is not null and v_new_max_principal < v_new_min_principal then
    raise exception 'LOAN_PRODUCT_MAXIMUM_PRINCIPAL_BELOW_MINIMUM' using errcode = '22023';
  end if;
  if v_new_min_term <= 0 then
    raise exception 'LOAN_PRODUCT_MINIMUM_TERM_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if v_new_max_term < v_new_min_term then
    raise exception 'LOAN_PRODUCT_MAXIMUM_TERM_BELOW_MINIMUM' using errcode = '22023';
  end if;
  if v_new_rate < 0 then
    raise exception 'LOAN_PRODUCT_INTEREST_RATE_INVALID' using errcode = '22023';
  end if;

  if p_name is not null and btrim(p_name) = '' then
    raise exception 'Loan product name is required' using errcode = '22023';
  end if;

  update public.loan_products set
    name = coalesce(nullif(btrim(p_name), ''), name),
    description = coalesce(p_description, description),
    minimum_principal = v_new_min_principal,
    maximum_principal = v_new_max_principal,
    minimum_term = v_new_min_term,
    maximum_term = v_new_max_term,
    interest_rate = v_new_rate,
    interest_rate_basis = coalesce(p_interest_rate_basis, interest_rate_basis),
    interest_method = coalesce(p_interest_method, interest_method),
    is_active = coalesce(p_is_active, is_active),
    updated_by = v_uid
  where id = p_product_id;

  select public.rpc_get_loan_product(p_group_id, p_product_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean
) from public;
grant execute on function public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean
) to authenticated;
revoke execute on function public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean
) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_loan_product / rpc_list_loan_products
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_loan_product(
  p_group_id uuid,
  p_product_id uuid
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
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_product.view') then
    raise exception 'Not authorized to view loan products in this group' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'code', code, 'name', name,
    'description', description, 'is_active', is_active,
    'minimum_principal', minimum_principal, 'maximum_principal', maximum_principal,
    'minimum_term', minimum_term, 'maximum_term', maximum_term, 'term_unit', term_unit,
    'interest_rate', interest_rate, 'interest_rate_basis', interest_rate_basis,
    'interest_method', interest_method, 'repayment_frequency', repayment_frequency,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.loan_products
  where id = p_product_id and group_id = p_group_id;

  if v_result is null then
    raise exception 'Loan product not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$$;

revoke all on function public.rpc_get_loan_product(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_product(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_product(uuid, uuid) from anon;

create or replace function public.rpc_list_loan_products(
  p_group_id uuid,
  p_is_active boolean default null,
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

  if not public.has_group_permission(p_group_id, 'loan_product.view') then
    raise exception 'Not authorized to view loan products in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.loan_products
  where group_id = p_group_id
    and (p_is_active is null or is_active = p_is_active);

  select coalesce(jsonb_agg(to_jsonb(row) order by row.name), '[]'::jsonb) into v_items
  from (
    select id, group_id, code, name, description, is_active,
      minimum_principal, maximum_principal, minimum_term, maximum_term, term_unit,
      interest_rate, interest_rate_basis, interest_method, repayment_frequency,
      created_at, updated_at
    from public.loan_products
    where group_id = p_group_id
      and (p_is_active is null or is_active = p_is_active)
    order by name
    limit p_limit offset p_offset
  ) row;

  return jsonb_build_object(
    'items', v_items, 'total_count', v_total, 'limit', p_limit, 'offset', p_offset
  );
end;
$$;

revoke all on function public.rpc_list_loan_products(uuid, boolean, integer, integer) from public;
grant execute on function public.rpc_list_loan_products(uuid, boolean, integer, integer) to authenticated;
revoke execute on function public.rpc_list_loan_products(uuid, boolean, integer, integer) from anon;
