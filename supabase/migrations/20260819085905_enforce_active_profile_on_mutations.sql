-- Prompt 03: an inactive profile (public.profiles.is_active = false)
-- must not retain effective group mutation privileges just because a
-- Supabase Auth session/JWT is still valid. Flutter gates the UI on
-- rpc_get_my_context().profile.is_active, but that is UX only — this
-- migration makes the backend authoritative for the same rule.

-- ---------------------------------------------------------------------
-- caller_profile_is_active(): whether auth.uid()'s own profile row is
-- active. A missing profile is treated as inactive (fails closed).
-- Internal-only: not part of the public API surface.
-- ---------------------------------------------------------------------
create or replace function public.caller_profile_is_active()
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select coalesce((select is_active from public.profiles where id = auth.uid()), false);
$$;

comment on function public.caller_profile_is_active() is
  'Whether the caller''s own profile is active. A missing profile is '
  'treated as inactive. Internal helper, not part of the public API.';

revoke all on function public.caller_profile_is_active() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- assert_active_profile(): raises ACCOUNT_DISABLED if the caller's
-- profile is not active. Called at the top of every mutation RPC,
-- immediately after the existing "not authenticated" check. Internal
-- only, same rationale as caller_profile_is_active().
-- ---------------------------------------------------------------------
create or replace function public.assert_active_profile()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.caller_profile_is_active() then
    raise exception 'ACCOUNT_DISABLED' using errcode = 'P0001';
  end if;
end;
$$;

comment on function public.assert_active_profile() is
  'Raises ACCOUNT_DISABLED if the caller''s profile is not active. '
  'Internal helper called from every mutation RPC; not part of the '
  'public API.';

revoke all on function public.assert_active_profile() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- is_group_member() / has_group_permission(): now also require an
-- active profile, so an inactive account loses effective membership
-- and permission everywhere these are used — both as RLS predicates
-- (groups/group_memberships/group_membership_roles SELECT policies)
-- and as the permission gate inside every member/role mutation RPC.
-- Returns false (not an exception) to stay safe as an RLS predicate.
-- ---------------------------------------------------------------------
create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select public.caller_profile_is_active() and exists (
    select 1
    from public.group_memberships gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'ACTIVE'
  );
$$;

create or replace function public.has_group_permission(p_group_id uuid, p_permission_code text)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select public.caller_profile_is_active() and exists (
    select 1
    from public.group_memberships gm
    join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
    join public.role_permissions rp on rp.role_id = gmr.role_id
    join public.permissions p on p.id = rp.permission_id
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'ACTIVE'
      and p.code = p_permission_code
  );
$$;

-- ---------------------------------------------------------------------
-- handle_new_user(): now also mirrors the authenticated phone (present
-- on auth.users at signup time for phone-OTP sign-ups) into
-- profiles.phone, so profile.phone starts in sync with the
-- authenticated identity without Flutter having to write it. This does
-- not let profiles.phone drift into an authorization field — Supabase
-- Auth's phone identity remains authoritative for authentication;
-- profiles.phone stays application-facing metadata (see
-- docs/product/member-identity-model.md).
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    new.email,
    new.phone
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Every mutation RPC now calls assert_active_profile() immediately
-- after its existing "not authenticated" check. Bodies are otherwise
-- unchanged from their latest established definitions.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_group(
  p_name text,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_group_id uuid;
  v_membership_id uuid;
  v_admin_role_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Group name is required' using errcode = '22023';
  end if;

  select id into v_admin_role_id from public.roles where code = 'ADMIN';
  if v_admin_role_id is null then
    raise exception 'ADMIN role is not defined';
  end if;

  insert into public.groups (name, description, status, created_by)
  values (btrim(p_name), p_description, 'ACTIVE', v_uid)
  returning id into v_group_id;

  insert into public.group_memberships (
    group_id, user_id, display_name, status, joined_at, created_by
  )
  values (
    v_group_id,
    v_uid,
    coalesce(
      nullif(btrim((select full_name from public.profiles where id = v_uid)), ''),
      'Group admin'
    ),
    'ACTIVE',
    current_date,
    v_uid
  )
  returning id into v_membership_id;

  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  values (v_membership_id, v_admin_role_id, v_uid);

  return public.rpc_get_my_context();
end;
$$;

create or replace function public.rpc_create_group_member(
  p_group_id uuid,
  p_display_name text,
  p_phone text default null,
  p_member_number text default null,
  p_joined_at date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_membership_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.create') then
    raise exception 'Not authorized to create members in this group' using errcode = '42501';
  end if;

  if p_display_name is null or btrim(p_display_name) = '' then
    raise exception 'Member display name is required' using errcode = '22023';
  end if;

  if p_member_number is not null and exists (
    select 1
    from public.group_memberships
    where group_id = p_group_id and member_number = p_member_number
  ) then
    raise exception 'member_number already exists in this group' using errcode = '23505';
  end if;

  insert into public.group_memberships (
    group_id, user_id, display_name, phone, member_number, status, joined_at, created_by
  )
  values (
    p_group_id, null, btrim(p_display_name), p_phone, p_member_number, 'ACTIVE', p_joined_at, v_uid
  )
  returning id into v_membership_id;

  select jsonb_build_object(
    'membership_id', gm.id,
    'group_id', gm.group_id,
    'display_name', gm.display_name,
    'phone', gm.phone,
    'member_number', gm.member_number,
    'status', gm.status,
    'joined_at', gm.joined_at,
    'created_at', gm.created_at
  )
  into v_result
  from public.group_memberships gm
  where gm.id = v_membership_id;

  return v_result;
end;
$$;

create or replace function public.rpc_update_group_member(
  p_group_id uuid,
  p_membership_id uuid,
  p_display_name text default null,
  p_phone text default null,
  p_member_number text default null,
  p_joined_at date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
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

  if not public.has_group_permission(p_group_id, 'member.edit') then
    raise exception 'Not authorized to edit members in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if p_display_name is not null and btrim(p_display_name) = '' then
    raise exception 'Member display name cannot be blank' using errcode = '22023';
  end if;

  if p_member_number is not null and exists (
    select 1
    from public.group_memberships
    where group_id = p_group_id
      and member_number = p_member_number
      and id <> p_membership_id
  ) then
    raise exception 'member_number already exists in this group' using errcode = '23505';
  end if;

  update public.group_memberships
  set
    display_name = coalesce(nullif(btrim(p_display_name), ''), display_name),
    phone = coalesce(p_phone, phone),
    member_number = coalesce(p_member_number, member_number),
    joined_at = coalesce(p_joined_at, joined_at)
  where id = p_membership_id
  returning jsonb_build_object(
    'membership_id', id,
    'group_id', group_id,
    'display_name', display_name,
    'phone', phone,
    'member_number', member_number,
    'status', status,
    'joined_at', joined_at,
    'exited_at', exited_at,
    'updated_at', updated_at
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.rpc_change_group_member_status(
  p_group_id uuid,
  p_membership_id uuid,
  p_status public.membership_status,
  p_exited_at date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_current_status public.membership_status;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.change_status') then
    raise exception 'Not authorized to change member status in this group' using errcode = '42501';
  end if;

  select group_id, status into v_target_group_id, v_current_status
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if v_current_status = p_status then
    select jsonb_build_object(
      'membership_id', id,
      'group_id', group_id,
      'status', status,
      'exited_at', exited_at,
      'updated_at', updated_at
    )
    into v_result
    from public.group_memberships
    where id = p_membership_id;

    return v_result;
  end if;

  if v_current_status = 'EXITED' then
    raise exception 'EXITED_MEMBERSHIP_IS_TERMINAL' using errcode = 'P0001';
  end if;

  if v_current_status = 'ACTIVE' and exists (
    select 1
    from public.group_membership_roles gmr
    join public.roles r on r.id = gmr.role_id
    where gmr.group_membership_id = p_membership_id and r.code = 'ADMIN'
  ) then
    perform public.assert_last_active_admin_remains(p_group_id, p_membership_id);
  end if;

  update public.group_memberships
  set
    status = p_status,
    exited_at = case
      when p_status = 'EXITED' then coalesce(p_exited_at, current_date)
      else null
    end
  where id = p_membership_id
  returning jsonb_build_object(
    'membership_id', id,
    'group_id', group_id,
    'status', status,
    'exited_at', exited_at,
    'updated_at', updated_at
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.rpc_assign_group_role(
  p_group_id uuid,
  p_membership_id uuid,
  p_role_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_role_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'role.assign') then
    raise exception 'Not authorized to assign roles in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id into v_role_id from public.roles where code = p_role_code;
  if v_role_id is null then
    raise exception 'Unknown role code: %', p_role_code using errcode = '22023';
  end if;

  if p_role_code = 'ADMIN' and not public.has_group_role(p_group_id, 'ADMIN') then
    raise exception 'Only an existing ADMIN may assign the ADMIN role' using errcode = '42501';
  end if;

  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  values (p_membership_id, v_role_id, v_uid)
  on conflict (group_membership_id, role_id) do nothing;

  select jsonb_build_object(
    'membership_id', gm.id,
    'roles', coalesce((
      select jsonb_agg(distinct r.code)
      from public.group_membership_roles gmr
      join public.roles r on r.id = gmr.role_id
      where gmr.group_membership_id = gm.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.group_memberships gm
  where gm.id = p_membership_id;

  return v_result;
end;
$$;

create or replace function public.rpc_remove_group_role(
  p_group_id uuid,
  p_membership_id uuid,
  p_role_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_role_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'role.assign') then
    raise exception 'Not authorized to remove roles in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id into v_role_id from public.roles where code = p_role_code;
  if v_role_id is null then
    raise exception 'Unknown role code: %', p_role_code using errcode = '22023';
  end if;

  if p_role_code = 'ADMIN' then
    if not public.has_group_role(p_group_id, 'ADMIN') then
      raise exception 'Only an existing ADMIN may remove the ADMIN role' using errcode = '42501';
    end if;

    perform public.assert_last_active_admin_remains(p_group_id, p_membership_id);
  end if;

  delete from public.group_membership_roles
  where group_membership_id = p_membership_id and role_id = v_role_id;

  select jsonb_build_object(
    'membership_id', gm.id,
    'roles', coalesce((
      select jsonb_agg(distinct r.code)
      from public.group_membership_roles gmr
      join public.roles r on r.id = gmr.role_id
      where gmr.group_membership_id = gm.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.group_memberships gm
  where gm.id = p_membership_id;

  return v_result;
end;
$$;
