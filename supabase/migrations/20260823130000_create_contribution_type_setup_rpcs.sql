-- Contribution Type and Contribution Setup mutation RPCs.

-- ---------------------------------------------------------------------
-- Internal lock-check helpers (not directly callable by clients).
-- ---------------------------------------------------------------------

create or replace function public.contribution_type_has_posted_period(p_type_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.contribution_periods cp
    join public.contribution_setups cs on cs.id = cp.contribution_setup_id
    where cs.contribution_type_id = p_type_id
      and cp.status in ('OPEN', 'CLOSED')
  );
$$;

revoke all on function public.contribution_type_has_posted_period(uuid) from public, anon, authenticated;

create or replace function public.contribution_setup_has_posted_period(p_setup_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.contribution_periods
    where contribution_setup_id = p_setup_id
      and status in ('OPEN', 'CLOSED')
  );
$$;

revoke all on function public.contribution_setup_has_posted_period(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_create_contribution_type
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_contribution_type(
  p_group_id uuid,
  p_name text,
  p_category public.contribution_category,
  p_accounting_treatment public.contribution_accounting_treatment,
  p_description text default null,
  p_display_order integer default 0
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

  if not public.has_group_permission(p_group_id, 'contribution.type.manage') then
    raise exception 'Not authorized to manage contribution types in this group' using errcode = '42501';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Contribution type name is required' using errcode = '22023';
  end if;

  if p_accounting_treatment = 'MEMBER_SAVINGS' then
    raise exception 'MEMBER_SAVINGS_NOT_AVAILABLE' using errcode = 'P0001';
  end if;

  insert into public.contribution_types (
    group_id, name, description, category, accounting_treatment, display_order, created_by
  ) values (
    p_group_id, btrim(p_name), p_description, p_category, p_accounting_treatment,
    coalesce(p_display_order, 0), v_uid
  )
  returning id into v_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'description', description,
    'category', category, 'accounting_treatment', accounting_treatment,
    'is_active', is_active, 'display_order', display_order,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.contribution_types
  where id = v_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_contribution_type(uuid, text, public.contribution_category, public.contribution_accounting_treatment, text, integer) from public;
grant execute on function public.rpc_create_contribution_type(uuid, text, public.contribution_category, public.contribution_accounting_treatment, text, integer) to authenticated;
revoke execute on function public.rpc_create_contribution_type(uuid, text, public.contribution_category, public.contribution_accounting_treatment, text, integer) from anon;

-- ---------------------------------------------------------------------
-- rpc_update_contribution_type
-- ---------------------------------------------------------------------

create or replace function public.rpc_update_contribution_type(
  p_group_id uuid,
  p_type_id uuid,
  p_name text default null,
  p_description text default null,
  p_category public.contribution_category default null,
  p_accounting_treatment public.contribution_accounting_treatment default null,
  p_display_order integer default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_current_category public.contribution_category;
  v_current_treatment public.contribution_accounting_treatment;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.type.manage') then
    raise exception 'Not authorized to manage contribution types in this group' using errcode = '42501';
  end if;

  select group_id, category, accounting_treatment
  into v_target_group_id, v_current_category, v_current_treatment
  from public.contribution_types
  where id = p_type_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Contribution type not found in group' using errcode = '22023';
  end if;

  if p_name is not null and btrim(p_name) = '' then
    raise exception 'Contribution type name cannot be blank' using errcode = '22023';
  end if;

  if p_accounting_treatment = 'MEMBER_SAVINGS' then
    raise exception 'MEMBER_SAVINGS_NOT_AVAILABLE' using errcode = 'P0001';
  end if;

  if (p_category is not null and p_category <> v_current_category)
     or (p_accounting_treatment is not null and p_accounting_treatment <> v_current_treatment) then
    if public.contribution_type_has_posted_period(p_type_id) then
      raise exception 'CONTRIBUTION_TYPE_ACCOUNTING_LOCKED' using errcode = 'P0001';
    end if;
  end if;

  update public.contribution_types
  set
    name = coalesce(nullif(btrim(p_name), ''), name),
    description = coalesce(p_description, description),
    category = coalesce(p_category, category),
    accounting_treatment = coalesce(p_accounting_treatment, accounting_treatment),
    display_order = coalesce(p_display_order, display_order),
    is_active = coalesce(p_is_active, is_active)
  where id = p_type_id
  returning jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'description', description,
    'category', category, 'accounting_treatment', accounting_treatment,
    'is_active', is_active, 'display_order', display_order,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function public.rpc_update_contribution_type(uuid, uuid, text, text, public.contribution_category, public.contribution_accounting_treatment, integer, boolean) from public;
grant execute on function public.rpc_update_contribution_type(uuid, uuid, text, text, public.contribution_category, public.contribution_accounting_treatment, integer, boolean) to authenticated;
revoke execute on function public.rpc_update_contribution_type(uuid, uuid, text, text, public.contribution_category, public.contribution_accounting_treatment, integer, boolean) from anon;

-- ---------------------------------------------------------------------
-- rpc_create_contribution_setup
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_contribution_setup(
  p_group_id uuid,
  p_contribution_type_id uuid,
  p_name text,
  p_schedule_mode public.contribution_schedule_mode,
  p_amount_mode public.contribution_amount_mode,
  p_description text default null,
  p_fixed_amount numeric default null,
  p_default_due_day integer default null,
  p_default_due_month_offset integer default null,
  p_penalty_mode public.contribution_penalty_mode default 'NONE',
  p_penalty_grace_days integer default null,
  p_penalty_value numeric default null,
  p_penalty_cap_amount numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_type_group_id uuid;
  v_type_active boolean;
  v_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.setup.manage') then
    raise exception 'Not authorized to manage contribution setups in this group' using errcode = '42501';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Contribution setup name is required' using errcode = '22023';
  end if;

  select group_id, is_active into v_type_group_id, v_type_active
  from public.contribution_types
  where id = p_contribution_type_id;

  if v_type_group_id is null or v_type_group_id <> p_group_id then
    raise exception 'Contribution type not found in group' using errcode = '22023';
  end if;

  if not v_type_active then
    raise exception 'CONTRIBUTION_TYPE_INACTIVE' using errcode = 'P0001';
  end if;

  insert into public.contribution_setups (
    group_id, contribution_type_id, name, description, schedule_mode, amount_mode,
    fixed_amount, default_due_day, default_due_month_offset,
    penalty_mode, penalty_grace_days, penalty_value, penalty_cap_amount, created_by
  ) values (
    p_group_id, p_contribution_type_id, btrim(p_name), p_description, p_schedule_mode, p_amount_mode,
    p_fixed_amount, p_default_due_day, p_default_due_month_offset,
    coalesce(p_penalty_mode, 'NONE'), p_penalty_grace_days, p_penalty_value, p_penalty_cap_amount, v_uid
  )
  returning id into v_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'contribution_type_id', contribution_type_id,
    'name', name, 'description', description, 'schedule_mode', schedule_mode,
    'amount_mode', amount_mode, 'fixed_amount', fixed_amount,
    'default_due_day', default_due_day, 'default_due_month_offset', default_due_month_offset,
    'penalty_mode', penalty_mode, 'penalty_grace_days', penalty_grace_days,
    'penalty_value', penalty_value, 'penalty_cap_amount', penalty_cap_amount,
    'is_active', is_active, 'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.contribution_setups
  where id = v_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_contribution_setup(uuid, uuid, text, public.contribution_schedule_mode, public.contribution_amount_mode, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric) from public;
grant execute on function public.rpc_create_contribution_setup(uuid, uuid, text, public.contribution_schedule_mode, public.contribution_amount_mode, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric) to authenticated;
revoke execute on function public.rpc_create_contribution_setup(uuid, uuid, text, public.contribution_schedule_mode, public.contribution_amount_mode, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric) from anon;

-- ---------------------------------------------------------------------
-- rpc_update_contribution_setup
-- ---------------------------------------------------------------------

create or replace function public.rpc_update_contribution_setup(
  p_group_id uuid,
  p_setup_id uuid,
  p_name text default null,
  p_description text default null,
  p_fixed_amount numeric default null,
  p_default_due_day integer default null,
  p_default_due_month_offset integer default null,
  p_penalty_mode public.contribution_penalty_mode default null,
  p_penalty_grace_days integer default null,
  p_penalty_value numeric default null,
  p_penalty_cap_amount numeric default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.setup.manage') then
    raise exception 'Not authorized to manage contribution setups in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.contribution_setups
  where id = p_setup_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Contribution setup not found in group' using errcode = '22023';
  end if;

  if p_name is not null and btrim(p_name) = '' then
    raise exception 'Contribution setup name cannot be blank' using errcode = '22023';
  end if;

  if p_fixed_amount is not null or p_default_due_day is not null
     or p_default_due_month_offset is not null or p_penalty_mode is not null
     or p_penalty_grace_days is not null or p_penalty_value is not null
     or p_penalty_cap_amount is not null then
    if public.contribution_setup_has_posted_period(p_setup_id) then
      raise exception 'CONTRIBUTION_SETUP_CONFIG_LOCKED' using errcode = 'P0001';
    end if;
  end if;

  update public.contribution_setups
  set
    name = coalesce(nullif(btrim(p_name), ''), name),
    description = coalesce(p_description, description),
    fixed_amount = coalesce(p_fixed_amount, fixed_amount),
    default_due_day = coalesce(p_default_due_day, default_due_day),
    default_due_month_offset = coalesce(p_default_due_month_offset, default_due_month_offset),
    penalty_mode = coalesce(p_penalty_mode, penalty_mode),
    penalty_grace_days = case when p_penalty_mode = 'NONE' then null else coalesce(p_penalty_grace_days, penalty_grace_days) end,
    penalty_value = case when p_penalty_mode = 'NONE' then null else coalesce(p_penalty_value, penalty_value) end,
    penalty_cap_amount = case when p_penalty_mode = 'NONE' then null else coalesce(p_penalty_cap_amount, penalty_cap_amount) end,
    is_active = coalesce(p_is_active, is_active)
  where id = p_setup_id
  returning jsonb_build_object(
    'id', id, 'group_id', group_id, 'contribution_type_id', contribution_type_id,
    'name', name, 'description', description, 'schedule_mode', schedule_mode,
    'amount_mode', amount_mode, 'fixed_amount', fixed_amount,
    'default_due_day', default_due_day, 'default_due_month_offset', default_due_month_offset,
    'penalty_mode', penalty_mode, 'penalty_grace_days', penalty_grace_days,
    'penalty_value', penalty_value, 'penalty_cap_amount', penalty_cap_amount,
    'is_active', is_active, 'created_at', created_at, 'updated_at', updated_at
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function public.rpc_update_contribution_setup(uuid, uuid, text, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric, boolean) from public;
grant execute on function public.rpc_update_contribution_setup(uuid, uuid, text, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric, boolean) to authenticated;
revoke execute on function public.rpc_update_contribution_setup(uuid, uuid, text, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric, boolean) from anon;
