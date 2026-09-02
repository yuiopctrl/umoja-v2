-- Prompt 09D: Loan Penalty Engine — product-level policy configuration
-- and per-loan snapshot, following the exact same "product defines,
-- account freezes at creation time" separation already locked for
-- every other loan term (principal_amount/interest_rate/interest_method/
-- etc — see 20260902092000_create_loan_accounts_schema.sql section E).
--
-- Basis rule (section 5/10, locked for this phase — no repository doc
-- defines an alternative loan-penalty basis, so this is the newly
-- documented policy): penalty_basis is a closed one-value enum,
-- OUTSTANDING_INSTALLMENT, meaning "this installment's current
-- principal outstanding + interest outstanding, excluding any existing
-- penalty outstanding" (no penalty-on-penalty compounding — section
-- 10/12). Defined as an enum (rather than a bare text/boolean) so a
-- later phase can widen it deliberately instead of ambiguously.

create type public.loan_penalty_type as enum (
  'FIXED',
  'PERCENTAGE'
);

create type public.loan_penalty_frequency as enum (
  'ONCE',
  'RECURRING_MONTHLY'
);

create type public.loan_penalty_basis as enum (
  'OUTSTANDING_INSTALLMENT'
);

-- ---------------------------------------------------------------------
-- Permissions: loan_penalty.view / loan_penalty.assess. Mapped like
-- every other money-affecting loan permission (09A/09C precedent):
-- ADMIN + TREASURER get both; CHAIRPERSON + SECRETARY view-only;
-- MEMBER gets neither in the staff module. loan_penalty.waive is
-- deliberately NOT added — section 27 forbids it unless this phase
-- implements waiver, which it does not (section 8: correction/waiver
-- deferred).
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('loan_penalty.view', 'View loan penalties', 'View assessed loan penalty charges and outstanding penalty amounts.'),
  ('loan_penalty.assess', 'Assess loan penalties', 'Run loan penalty assessment for overdue loan installments.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in ('loan_penalty.view', 'loan_penalty.assess')
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('loan_penalty.view', 'loan_penalty.assess')
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'loan_penalty.view'
where r.code in ('CHAIRPERSON', 'SECRETARY');

-- MEMBER intentionally gets neither — same posture as every other
-- staff-facing loan permission.

-- ---------------------------------------------------------------------
-- loan_products — penalty policy configuration (section 5). All
-- columns are nullable/default-disabled so every pre-09D product row
-- backfills to "no penalty policy" with zero behavior change.
-- ---------------------------------------------------------------------

alter table public.loan_products
  add column penalty_enabled boolean not null default false,
  add column penalty_type public.loan_penalty_type,
  add column penalty_frequency public.loan_penalty_frequency,
  add column penalty_grace_days integer,
  add column penalty_fixed_amount numeric(14, 2),
  add column penalty_rate numeric(7, 4),
  add column penalty_basis public.loan_penalty_basis;

alter table public.loan_products
  add constraint loan_products_penalty_grace_days_non_negative
    check (penalty_grace_days is null or penalty_grace_days >= 0),
  add constraint loan_products_penalty_fixed_amount_positive
    check (penalty_fixed_amount is null or penalty_fixed_amount > 0),
  add constraint loan_products_penalty_rate_positive
    check (penalty_rate is null or penalty_rate > 0),
  add constraint loan_products_penalty_config_consistency check (
    (
      -- Disabled: every dependent field must be null — a disabled
      -- policy can never silently retain a stale FIXED/PERCENTAGE
      -- configuration (section 40 item 1).
      penalty_enabled = false
      and penalty_type is null
      and penalty_frequency is null
      and penalty_grace_days is null
      and penalty_fixed_amount is null
      and penalty_rate is null
      and penalty_basis is null
    )
    or
    (
      penalty_enabled = true
      and penalty_type is not null
      and penalty_frequency is not null
      and penalty_grace_days is not null
      and penalty_basis is not null
      and (
        (penalty_type = 'FIXED' and penalty_fixed_amount is not null and penalty_rate is null)
        or
        (penalty_type = 'PERCENTAGE' and penalty_rate is not null and penalty_fixed_amount is null)
      )
    )
  );

comment on column public.loan_products.penalty_enabled is
  'Prompt 09D. When false, every other penalty_* column must be null
  (loan_products_penalty_config_consistency) — a disabled policy never
  carries stale FIXED/PERCENTAGE configuration.';
comment on column public.loan_products.penalty_basis is
  'Locked to OUTSTANDING_INSTALLMENT for this phase (section 5/10):
  the installment''s current principal outstanding + interest
  outstanding at assessment time, excluding any existing penalty
  outstanding (no penalty-on-penalty compounding).';

-- ---------------------------------------------------------------------
-- loan_accounts — frozen penalty snapshot (section 6/7), taken at the
-- exact same DRAFT-creation instant every other term is already frozen
-- (see rpc_create_draft_loan_account) — never re-read live from
-- loan_products for an existing loan.
-- ---------------------------------------------------------------------

alter table public.loan_accounts
  add column penalty_enabled boolean not null default false,
  add column penalty_type public.loan_penalty_type,
  add column penalty_frequency public.loan_penalty_frequency,
  add column penalty_grace_days integer,
  add column penalty_fixed_amount numeric(14, 2),
  add column penalty_rate numeric(7, 4),
  add column penalty_basis public.loan_penalty_basis;

comment on column public.loan_accounts.penalty_enabled is
  'Prompt 09D. Frozen snapshot taken from loan_products at DRAFT
  creation time, exactly like principal_amount/interest_rate/etc
  (section E precedent) — editing the product afterwards never alters
  an already-created loan''s penalty economics (section 6).';

-- ---------------------------------------------------------------------
-- rpc_create_loan_product / rpc_update_loan_product — extended with
-- penalty policy parameters. `create or replace function` only
-- replaces a function with the EXACT SAME argument-type list; adding
-- trailing parameters (even with defaults) creates a SEPARATE overload
-- instead, leaving every existing exact-arity call site ambiguous.
-- Drop the old-signature overloads first (established pattern — see
-- 20260906090000_restrict_loan_auto_allocation_to_currently_due.sql).
-- ---------------------------------------------------------------------

drop function if exists public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency
);
drop function if exists public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean
);

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
  p_repayment_frequency public.loan_repayment_frequency default 'MONTHLY',
  p_penalty_enabled boolean default false,
  p_penalty_type public.loan_penalty_type default null,
  p_penalty_frequency public.loan_penalty_frequency default null,
  p_penalty_grace_days integer default null,
  p_penalty_fixed_amount numeric default null,
  p_penalty_rate numeric default null,
  p_penalty_basis public.loan_penalty_basis default 'OUTSTANDING_INSTALLMENT'
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

  -- Penalty policy validation (section 40 items 2-5) — mirrors the
  -- table-level check constraint so a caller gets a clear error code
  -- rather than a bare constraint-violation.
  if p_penalty_enabled then
    if p_penalty_type is null then
      raise exception 'LOAN_PRODUCT_PENALTY_TYPE_REQUIRED' using errcode = '22023';
    end if;
    if p_penalty_frequency is null then
      raise exception 'LOAN_PRODUCT_PENALTY_FREQUENCY_REQUIRED' using errcode = '22023';
    end if;
    if p_penalty_grace_days is null or p_penalty_grace_days < 0 then
      raise exception 'LOAN_PRODUCT_PENALTY_GRACE_DAYS_INVALID' using errcode = '22023';
    end if;
    if p_penalty_type = 'FIXED' and (p_penalty_fixed_amount is null or p_penalty_fixed_amount <= 0) then
      raise exception 'LOAN_PRODUCT_PENALTY_FIXED_AMOUNT_REQUIRED' using errcode = '22023';
    end if;
    if p_penalty_type = 'PERCENTAGE' and (p_penalty_rate is null or p_penalty_rate <= 0) then
      raise exception 'LOAN_PRODUCT_PENALTY_RATE_REQUIRED' using errcode = '22023';
    end if;
  end if;

  insert into public.loan_products (
    group_id, code, name, description,
    minimum_principal, maximum_principal,
    minimum_term, maximum_term, term_unit,
    interest_rate, interest_rate_basis, interest_method,
    repayment_frequency,
    penalty_enabled, penalty_type, penalty_frequency, penalty_grace_days,
    penalty_fixed_amount,
    penalty_rate,
    penalty_basis,
    created_by, updated_by
  ) values (
    p_group_id, btrim(p_code), btrim(p_name), p_description,
    p_minimum_principal, p_maximum_principal,
    p_minimum_term, p_maximum_term, p_term_unit,
    p_interest_rate, p_interest_rate_basis, p_interest_method,
    p_repayment_frequency,
    p_penalty_enabled,
    case when p_penalty_enabled then p_penalty_type else null end,
    case when p_penalty_enabled then p_penalty_frequency else null end,
    case when p_penalty_enabled then p_penalty_grace_days else null end,
    case when p_penalty_enabled and p_penalty_type = 'FIXED' then p_penalty_fixed_amount else null end,
    case when p_penalty_enabled and p_penalty_type = 'PERCENTAGE' then p_penalty_rate else null end,
    case when p_penalty_enabled then p_penalty_basis else null end,
    v_uid, v_uid
  )
  returning id into v_id;

  select public.rpc_get_loan_product(p_group_id, v_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency,
  boolean, public.loan_penalty_type, public.loan_penalty_frequency, integer, numeric, numeric,
  public.loan_penalty_basis
) from public;
grant execute on function public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency,
  boolean, public.loan_penalty_type, public.loan_penalty_frequency, integer, numeric, numeric,
  public.loan_penalty_basis
) to authenticated;
revoke execute on function public.rpc_create_loan_product(
  uuid, text, text, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method,
  numeric, text, public.loan_term_unit, public.loan_repayment_frequency,
  boolean, public.loan_penalty_type, public.loan_penalty_frequency, integer, numeric, numeric,
  public.loan_penalty_basis
) from anon;

-- ---------------------------------------------------------------------
-- rpc_update_loan_product — extended the same way. p_penalty_enabled
-- stays nullable/default-null so "not mentioned" genuinely means
-- "leave the current penalty policy untouched", distinct from an
-- explicit false (disable). When any penalty_* param is passed, the
-- full new policy is validated and replaces the old one atomically —
-- never a partial/inconsistent penalty state.
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
  p_is_active boolean default null,
  p_penalty_enabled boolean default null,
  p_penalty_type public.loan_penalty_type default null,
  p_penalty_frequency public.loan_penalty_frequency default null,
  p_penalty_grace_days integer default null,
  p_penalty_fixed_amount numeric default null,
  p_penalty_rate numeric default null,
  p_penalty_basis public.loan_penalty_basis default null
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
  v_new_penalty_enabled boolean;
  v_new_penalty_type public.loan_penalty_type;
  v_new_penalty_frequency public.loan_penalty_frequency;
  v_new_penalty_grace_days integer;
  v_new_penalty_fixed_amount numeric;
  v_new_penalty_rate numeric;
  v_new_penalty_basis public.loan_penalty_basis;
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

  -- Penalty policy: recompute the FULL new policy state (never a
  -- partial merge that could leave FIXED with a stale PERCENTAGE rate
  -- or vice versa) whenever the caller touches ANY penalty_* param.
  if p_penalty_enabled is not null or p_penalty_type is not null or p_penalty_frequency is not null
    or p_penalty_grace_days is not null or p_penalty_fixed_amount is not null or p_penalty_rate is not null
    or p_penalty_basis is not null then
    v_new_penalty_enabled := coalesce(p_penalty_enabled, v_product.penalty_enabled);
    v_new_penalty_type := coalesce(p_penalty_type, v_product.penalty_type);
    v_new_penalty_frequency := coalesce(p_penalty_frequency, v_product.penalty_frequency);
    v_new_penalty_grace_days := coalesce(p_penalty_grace_days, v_product.penalty_grace_days);
    v_new_penalty_basis := coalesce(p_penalty_basis, v_product.penalty_basis, 'OUTSTANDING_INSTALLMENT');

    if v_new_penalty_enabled then
      if v_new_penalty_type is null then
        raise exception 'LOAN_PRODUCT_PENALTY_TYPE_REQUIRED' using errcode = '22023';
      end if;
      if v_new_penalty_frequency is null then
        raise exception 'LOAN_PRODUCT_PENALTY_FREQUENCY_REQUIRED' using errcode = '22023';
      end if;
      if v_new_penalty_grace_days is null or v_new_penalty_grace_days < 0 then
        raise exception 'LOAN_PRODUCT_PENALTY_GRACE_DAYS_INVALID' using errcode = '22023';
      end if;

      if v_new_penalty_type = 'FIXED' then
        v_new_penalty_fixed_amount := coalesce(
          p_penalty_fixed_amount,
          case when v_product.penalty_type = 'FIXED' then v_product.penalty_fixed_amount else null end
        );
        v_new_penalty_rate := null;
        if v_new_penalty_fixed_amount is null or v_new_penalty_fixed_amount <= 0 then
          raise exception 'LOAN_PRODUCT_PENALTY_FIXED_AMOUNT_REQUIRED' using errcode = '22023';
        end if;
      else
        v_new_penalty_rate := coalesce(
          p_penalty_rate,
          case when v_product.penalty_type = 'PERCENTAGE' then v_product.penalty_rate else null end
        );
        v_new_penalty_fixed_amount := null;
        if v_new_penalty_rate is null or v_new_penalty_rate <= 0 then
          raise exception 'LOAN_PRODUCT_PENALTY_RATE_REQUIRED' using errcode = '22023';
        end if;
      end if;
    else
      v_new_penalty_type := null;
      v_new_penalty_frequency := null;
      v_new_penalty_grace_days := null;
      v_new_penalty_fixed_amount := null;
      v_new_penalty_rate := null;
      v_new_penalty_basis := null;
    end if;
  else
    v_new_penalty_enabled := v_product.penalty_enabled;
    v_new_penalty_type := v_product.penalty_type;
    v_new_penalty_frequency := v_product.penalty_frequency;
    v_new_penalty_grace_days := v_product.penalty_grace_days;
    v_new_penalty_fixed_amount := v_product.penalty_fixed_amount;
    v_new_penalty_rate := v_product.penalty_rate;
    v_new_penalty_basis := v_product.penalty_basis;
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
    penalty_enabled = v_new_penalty_enabled,
    penalty_type = v_new_penalty_type,
    penalty_frequency = v_new_penalty_frequency,
    penalty_grace_days = v_new_penalty_grace_days,
    penalty_fixed_amount = v_new_penalty_fixed_amount,
    penalty_rate = v_new_penalty_rate,
    penalty_basis = v_new_penalty_basis,
    updated_by = v_uid
  where id = p_product_id;

  select public.rpc_get_loan_product(p_group_id, p_product_id) into v_result;
  return v_result;
end;
$$;

revoke all on function public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean,
  boolean, public.loan_penalty_type, public.loan_penalty_frequency, integer, numeric, numeric,
  public.loan_penalty_basis
) from public;
grant execute on function public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean,
  boolean, public.loan_penalty_type, public.loan_penalty_frequency, integer, numeric, numeric,
  public.loan_penalty_basis
) to authenticated;
revoke execute on function public.rpc_update_loan_product(
  uuid, uuid, text, text, numeric, numeric, integer, integer, numeric,
  public.loan_interest_rate_basis, public.loan_interest_method, boolean,
  boolean, public.loan_penalty_type, public.loan_penalty_frequency, integer, numeric, numeric,
  public.loan_penalty_basis
) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_loan_product / rpc_list_loan_products — surface the penalty
-- policy fields. Same signature (jsonb-returning / same params) —
-- plain create or replace.
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
    'penalty_enabled', penalty_enabled, 'penalty_type', penalty_type,
    'penalty_frequency', penalty_frequency, 'penalty_grace_days', penalty_grace_days,
    'penalty_fixed_amount', penalty_fixed_amount, 'penalty_rate', penalty_rate,
    'penalty_basis', penalty_basis,
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
      penalty_enabled, penalty_type, penalty_frequency, penalty_grace_days,
      penalty_fixed_amount, penalty_rate, penalty_basis,
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

-- ---------------------------------------------------------------------
-- rpc_create_draft_loan_account — snapshots the penalty policy at the
-- exact same instant every other term is snapshotted (section 6).
-- Same signature — plain create or replace.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_draft_loan_account(
  p_group_id uuid,
  p_membership_id uuid,
  p_loan_product_id uuid,
  p_principal_amount numeric,
  p_term integer,
  p_first_repayment_date date,
  p_proposed_disbursement_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product record;
  v_membership record;
  v_loan_number text;
  v_loan_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.create') then
    raise exception 'Not authorized to create loans in this group' using errcode = '42501';
  end if;

  select id, group_id, status into v_membership
  from public.group_memberships
  where id = p_membership_id;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;
  if v_membership.status <> 'ACTIVE' then
    raise exception 'LOAN_ACCOUNT_BORROWER_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  select * into v_product from public.loan_products where id = p_loan_product_id;
  if v_product.group_id is null or v_product.group_id <> p_group_id then
    raise exception 'Loan product not found in group' using errcode = '22023';
  end if;
  if not v_product.is_active then
    raise exception 'LOAN_PRODUCT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_principal_amount is null or p_principal_amount <= 0 then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if p_principal_amount < v_product.minimum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM' using errcode = '22023';
  end if;
  if v_product.maximum_principal is not null and p_principal_amount > v_product.maximum_principal then
    raise exception 'LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM' using errcode = '22023';
  end if;
  if p_term is null or p_term < v_product.minimum_term or p_term > v_product.maximum_term then
    raise exception 'LOAN_ACCOUNT_TERM_OUT_OF_PRODUCT_RANGE' using errcode = '22023';
  end if;
  if p_first_repayment_date is null then
    raise exception 'First repayment date is required' using errcode = '22023';
  end if;

  v_loan_number := public.generate_loan_number(p_group_id, extract(year from current_date)::integer);

  insert into public.loan_accounts (
    group_id, membership_id, loan_product_id, loan_number,
    principal_amount, interest_rate, interest_rate_basis, interest_method,
    term, term_unit, repayment_frequency,
    proposed_disbursement_date, first_repayment_date,
    penalty_enabled, penalty_type, penalty_frequency, penalty_grace_days,
    penalty_fixed_amount, penalty_rate, penalty_basis,
    created_by, updated_by
  ) values (
    p_group_id, p_membership_id, p_loan_product_id, v_loan_number,
    p_principal_amount, v_product.interest_rate, v_product.interest_rate_basis, v_product.interest_method,
    p_term, v_product.term_unit, v_product.repayment_frequency,
    p_proposed_disbursement_date, p_first_repayment_date,
    v_product.penalty_enabled, v_product.penalty_type, v_product.penalty_frequency, v_product.penalty_grace_days,
    v_product.penalty_fixed_amount, v_product.penalty_rate, v_product.penalty_basis,
    v_uid, v_uid
  )
  returning id into v_loan_id;

  perform public.loan_schedule_generate(v_loan_id);

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, created_by
  ) values (
    p_group_id, v_loan_id, 'CREATED', null, 'DRAFT', v_uid
  );

  select public.rpc_get_loan_account(p_group_id, v_loan_id) into v_result;
  return v_result;
end;
$$;

comment on function public.rpc_create_draft_loan_account(uuid, uuid, uuid, numeric, integer, date, date) is
  'Prompt 09A/09B, extended 09D: also freezes the loan product''s
  penalty policy onto the new loan account at the exact same instant
  every other financial term is frozen (section 6) — a later edit to
  the product''s penalty configuration never alters this loan''s
  penalty economics.';
