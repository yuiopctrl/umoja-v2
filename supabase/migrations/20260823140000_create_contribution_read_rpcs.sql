-- Contribution Engine read RPCs: paginated lists and detail getters
-- for types, setups, periods and period charges. Default page size 10
-- (docs/product/members.md pagination philosophy), max 100. All
-- summary totals are computed server-side — Flutter never sums
-- paginated rows for an authoritative total.

-- ---------------------------------------------------------------------
-- Contribution Types
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_contribution_types(
  p_group_id uuid,
  p_search text default null,
  p_is_active boolean default null,
  p_limit integer default 10,
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
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.contribution_types t
  where t.group_id = p_group_id
    and (p_is_active is null or t.is_active = p_is_active)
    and (p_search is null or btrim(p_search) = '' or t.name ilike '%' || btrim(p_search) || '%');

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.display_order, rows.name), '[]'::jsonb)
  into v_items
  from (
    select id, group_id, name, description, category, accounting_treatment,
           is_active, display_order, created_at, updated_at
    from public.contribution_types t
    where t.group_id = p_group_id
      and (p_is_active is null or t.is_active = p_is_active)
      and (p_search is null or btrim(p_search) = '' or t.name ilike '%' || btrim(p_search) || '%')
    order by display_order, name
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_types(uuid, text, boolean, integer, integer) from public;
grant execute on function public.rpc_list_contribution_types(uuid, text, boolean, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_types(uuid, text, boolean, integer, integer) from anon;

create or replace function public.rpc_get_contribution_type(
  p_group_id uuid,
  p_type_id uuid
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

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'description', description,
    'category', category, 'accounting_treatment', accounting_treatment,
    'is_active', is_active, 'display_order', display_order,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.contribution_types
  where id = p_type_id and group_id = p_group_id;

  if v_result is null then
    raise exception 'Contribution type not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$$;

revoke all on function public.rpc_get_contribution_type(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_type(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_type(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- Contribution Setups
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_contribution_setups(
  p_group_id uuid,
  p_contribution_type_id uuid default null,
  p_is_active boolean default null,
  p_limit integer default 10,
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
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.contribution_setups s
  where s.group_id = p_group_id
    and (p_contribution_type_id is null or s.contribution_type_id = p_contribution_type_id)
    and (p_is_active is null or s.is_active = p_is_active);

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.name), '[]'::jsonb)
  into v_items
  from (
    select id, group_id, contribution_type_id, name, description, schedule_mode, amount_mode,
           fixed_amount, default_due_day, default_due_month_offset,
           penalty_mode, penalty_grace_days, penalty_value, penalty_cap_amount,
           is_active, created_at, updated_at
    from public.contribution_setups s
    where s.group_id = p_group_id
      and (p_contribution_type_id is null or s.contribution_type_id = p_contribution_type_id)
      and (p_is_active is null or s.is_active = p_is_active)
    order by name
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_setups(uuid, uuid, boolean, integer, integer) from public;
grant execute on function public.rpc_list_contribution_setups(uuid, uuid, boolean, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_setups(uuid, uuid, boolean, integer, integer) from anon;

create or replace function public.rpc_get_contribution_setup(
  p_group_id uuid,
  p_setup_id uuid
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

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

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
  where id = p_setup_id and group_id = p_group_id;

  if v_result is null then
    raise exception 'Contribution setup not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$$;

revoke all on function public.rpc_get_contribution_setup(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_setup(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_setup(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- Contribution Periods
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_contribution_periods(
  p_group_id uuid,
  p_contribution_setup_id uuid default null,
  p_status public.contribution_period_status default null,
  p_limit integer default 10,
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
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.contribution_periods p
  where p.group_id = p_group_id
    and (p_contribution_setup_id is null or p.contribution_setup_id = p_contribution_setup_id)
    and (p_status is null or p.status = p_status);

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.period_start desc), '[]'::jsonb)
  into v_items
  from (
    select id, group_id, contribution_setup_id, label, period_start, period_end,
           obligation_date, eligibility_date, due_date, status, scheduled_open_date,
           opened_at, closed_at, cancelled_at, created_at, updated_at
    from public.contribution_periods p
    where p.group_id = p_group_id
      and (p_contribution_setup_id is null or p.contribution_setup_id = p_contribution_setup_id)
      and (p_status is null or p.status = p_status)
    order by period_start desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_periods(uuid, uuid, public.contribution_period_status, integer, integer) from public;
grant execute on function public.rpc_list_contribution_periods(uuid, uuid, public.contribution_period_status, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_periods(uuid, uuid, public.contribution_period_status, integer, integer) from anon;

create or replace function public.rpc_get_contribution_period(
  p_group_id uuid,
  p_period_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
  v_excluded_count integer;
  v_custom_amount_count integer;
  v_total_members_charged integer;
  v_total_base_assessed numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id;
  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  select count(*) into v_excluded_count
  from public.contribution_period_member_exclusions
  where period_id = p_period_id;

  select count(*) into v_custom_amount_count
  from public.contribution_period_member_amounts
  where period_id = p_period_id;

  select count(*), coalesce(sum(cc.assessed_amount), 0)
  into v_total_members_charged, v_total_base_assessed
  from public.member_contribution_charges c
  join public.contribution_charge_components cc
    on cc.charge_id = c.id and cc.component_type = 'BASE'
  where c.period_id = p_period_id;

  return jsonb_build_object(
    'id', v_period.id, 'group_id', v_period.group_id,
    'contribution_setup_id', v_period.contribution_setup_id,
    'label', v_period.label, 'period_start', v_period.period_start, 'period_end', v_period.period_end,
    'obligation_date', v_period.obligation_date, 'eligibility_date', v_period.eligibility_date,
    'due_date', v_period.due_date, 'status', v_period.status,
    'scheduled_open_date', v_period.scheduled_open_date,
    'opened_at', v_period.opened_at, 'opened_by', v_period.opened_by,
    'closed_at', v_period.closed_at, 'closed_by', v_period.closed_by,
    'cancelled_at', v_period.cancelled_at, 'cancelled_by', v_period.cancelled_by,
    'snapshot_type_name', v_period.snapshot_type_name,
    'snapshot_category', v_period.snapshot_category,
    'snapshot_accounting_treatment', v_period.snapshot_accounting_treatment,
    'snapshot_setup_name', v_period.snapshot_setup_name,
    'snapshot_schedule_mode', v_period.snapshot_schedule_mode,
    'snapshot_amount_mode', v_period.snapshot_amount_mode,
    'snapshot_fixed_amount', v_period.snapshot_fixed_amount,
    'snapshot_penalty_mode', v_period.snapshot_penalty_mode,
    'snapshot_penalty_grace_days', v_period.snapshot_penalty_grace_days,
    'snapshot_penalty_value', v_period.snapshot_penalty_value,
    'snapshot_penalty_cap_amount', v_period.snapshot_penalty_cap_amount,
    'created_at', v_period.created_at, 'updated_at', v_period.updated_at,
    'excluded_count', v_excluded_count,
    'custom_amount_count', v_custom_amount_count,
    'total_members_charged', v_total_members_charged,
    'total_base_assessed', v_total_base_assessed
  );
end;
$$;

revoke all on function public.rpc_get_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_period(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- Contribution Period Charges
-- ---------------------------------------------------------------------
--
-- Full visibility requires contribution.view. Otherwise a caller with
-- only contribution.self_view sees exclusively their own charge (via
-- their own membership row in this group).

create or replace function public.rpc_list_contribution_period_charges(
  p_group_id uuid,
  p_period_id uuid,
  p_search text default null,
  p_limit integer default 10,
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
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_period_group_id uuid;
  v_full_view boolean;
  v_self_membership_id uuid;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select group_id into v_period_group_id from public.contribution_periods where id = p_period_id;
  if v_period_group_id is null or v_period_group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  v_full_view := public.has_group_permission(p_group_id, 'contribution.view');

  if not v_full_view then
    if not public.has_group_permission(p_group_id, 'contribution.self_view') then
      raise exception 'Not authorized to view contribution charges in this group' using errcode = '42501';
    end if;

    select id into v_self_membership_id
    from public.group_memberships
    where group_id = p_group_id and user_id = v_uid
    limit 1;
  end if;

  select count(*) into v_total
  from public.member_contribution_charges c
  where c.period_id = p_period_id
    and (v_full_view or c.membership_id = v_self_membership_id)
    and (
      p_search is null or btrim(p_search) = ''
      or c.member_name_snapshot ilike '%' || btrim(p_search) || '%'
      or c.member_number_snapshot ilike '%' || btrim(p_search) || '%'
    );

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.member_name_snapshot), '[]'::jsonb)
  into v_items
  from (
    select
      c.id as charge_id, c.membership_id, c.member_number_snapshot, c.member_name_snapshot,
      c.effective_at, c.due_date, c.created_at,
      (
        select cc.assessed_amount from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'BASE'
      ) as base_amount
    from public.member_contribution_charges c
    where c.period_id = p_period_id
      and (v_full_view or c.membership_id = v_self_membership_id)
      and (
        p_search is null or btrim(p_search) = ''
        or c.member_name_snapshot ilike '%' || btrim(p_search) || '%'
        or c.member_number_snapshot ilike '%' || btrim(p_search) || '%'
      )
    order by c.member_name_snapshot
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_period_charges(uuid, uuid, text, integer, integer) from public;
grant execute on function public.rpc_list_contribution_period_charges(uuid, uuid, text, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_period_charges(uuid, uuid, text, integer, integer) from anon;
