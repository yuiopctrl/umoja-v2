-- Correction migration for two already-applied migrations:
--   20260821090000_add_member_rejoin_workflow.sql
--   20260821100000_add_server_generated_member_numbers.sql
--
-- Both are already applied to linked Supabase Cloud and are NOT edited
-- here — this migration only CREATE OR REPLACEs the functions they
-- introduced, correcting them in place. No table/column/constraint/
-- grant from those two migrations is touched except where a fix below
-- explicitly requires it (it does not).
--
-- Fixes, one per section:
--
-- 1. search_path hardening. Every function these two migrations
--    introduced used `set search_path = public, pg_temp` — safe only
--    because every reference inside them already happened to be
--    schema-qualified, but not the codebase's current best practice
--    (20260820180821_create_member_read_rpcs.sql already established
--    `set search_path = ''`, the strictest setting: nothing implicit
--    resolves, not even pg_temp for a same-session temp table). All six
--    functions below move to `search_path = ''`; every custom
--    table/type/function reference is (and already was) schema-
--    qualified, so this is a hardening-only change with no behavior
--    difference by itself.
--
-- 2. rpc_rejoin_group_member: the previously-applied version accepted
--    any p_rejoined_at, including dates before the member's own
--    previous exit or in the future, and (defensively) did not
--    verify an EXITED membership actually carried a previous
--    exited_at. Both are now validated before the history row is
--    written. joined_at is still never read or written by this
--    function — the preserved previous_exited_at/effective_at pair in
--    group_membership_status_history remains the sole authoritative
--    record of the exited/rejoined interval.
--
-- 3. rpc_create_group_member: the previously-applied version silently
--    honored a caller-supplied p_member_number. Server-generated
--    numbers are meant to be authoritative for the normal
--    member.create flow (which the Flutter client already never
--    populates), so a non-null p_member_number is now rejected
--    outright rather than accepted as an undocumented override. A
--    privileged import RPC, should one be built later, is a separate
--    function — not a reason to keep this override live on the normal
--    path today. The function signature is unchanged for
--    compatibility. Existing member_number values are untouched.
--
-- 4 & 5. generate_group_code: the previously-applied version checked
--    candidate availability and let the caller's later INSERT enforce
--    uniqueness — two concurrent transactions deriving the same base
--    could both observe the same candidate as free and race on the
--    unique index, so one would fail outright instead of getting a
--    disambiguated suffix. It also had no floor on the derived base
--    length, so a name that sanitizes to a single character (or to
--    nothing, before the existing 'GRP' fallback) could produce a
--    one-character code, which groups_code_format's
--    `^[A-Z0-9]{2,10}$` check would then reject as a raw constraint
--    violation rather than a clean, intentional outcome. Both are
--    fixed below.
create or replace function public.generate_group_code(p_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base text;
  v_candidate text;
  v_suffix integer := 0;
  v_suffix_text text;
begin
  v_base := upper(regexp_replace(coalesce(p_name, ''), '[^a-zA-Z0-9]', '', 'g'));
  v_base := left(v_base, 4);

  if v_base = '' then
    v_base := 'GRP';
  elsif char_length(v_base) < 2 then
    -- Deterministic floor to 2 characters (groups_code_format requires
    -- at least 2) rather than letting a 1-character base ever reach the
    -- uniqueness check/CHECK constraint below.
    v_base := rpad(v_base, 2, 'X');
  end if;

  -- Serialize concurrent allocation attempts that derive the same base
  -- from similar/duplicate group names. Transaction-scoped: released
  -- automatically at commit or rollback, never held beyond this call's
  -- own transaction (the caller's single RPC invocation). A second
  -- concurrent transaction with the same base blocks here until the
  -- first commits (so it then sees the first's code in the exists-check
  -- below and picks the next free suffix) or rolls back (so it sees
  -- nothing changed) — either way no duplicate code is ever produced,
  -- and neither request fails merely for having raced the other.
  -- Namespaced with hashtext('group_code') as the first key so this
  -- lock space never collides with an unrelated advisory lock use
  -- elsewhere in the schema.
  perform pg_advisory_xact_lock(hashtext('group_code'), hashtext(v_base));

  v_candidate := v_base;
  while exists (select 1 from public.groups where code = v_candidate) loop
    v_suffix := v_suffix + 1;
    v_suffix_text := v_suffix::text;
    v_candidate := v_base || v_suffix_text;
    -- Defensive ceiling: v_base is already capped at 4 characters, so
    -- this only matters in pathological collision counts, but the
    -- constraint (`^[A-Z0-9]{2,10}$`) must never be the thing that
    -- catches an oversized suffix.
    if char_length(v_candidate) > 10 then
      v_candidate := left(v_base, 10 - char_length(v_suffix_text)) || v_suffix_text;
    end if;
  end loop;

  return v_candidate;
end;
$$;

-- rpc_create_group: search_path hardening only. Every statement,
-- guard, and the returned rpc_get_my_context() shape are reproduced
-- unchanged from 20260821100000's version.
create or replace function public.rpc_create_group(
  p_name text,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
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

  insert into public.groups (name, description, status, created_by, code)
  values (btrim(p_name), p_description, 'ACTIVE', v_uid, public.generate_group_code(p_name))
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

-- next_group_member_number: search_path hardening only. Already
-- concurrency-safe via INSERT ... ON CONFLICT ... DO UPDATE.
create or replace function public.next_group_member_number(
  p_group_id uuid,
  p_year integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next integer;
begin
  insert into public.group_member_number_counters (group_id, year, last_number)
  values (p_group_id, p_year, 1)
  on conflict (group_id, year)
  do update set last_number = public.group_member_number_counters.last_number + 1
  returning last_number into v_next;

  return v_next;
end;
$$;

-- generate_member_number: search_path hardening only.
create or replace function public.generate_member_number(
  p_group_id uuid,
  p_year integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_seq integer;
begin
  select code into v_code from public.groups where id = p_group_id;
  if v_code is null then
    raise exception 'Group has no code configured' using errcode = 'P0001';
  end if;

  v_seq := public.next_group_member_number(p_group_id, p_year);

  return v_code || '-' || p_year::text || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

-- rpc_create_group_member: search_path hardening, plus the manual-
-- override removal from section 3 above. p_member_number stays in the
-- signature for compatibility, but a non-null value is now always
-- rejected rather than honored — normal creation is unconditionally
-- server-authoritative for member numbers. The old per-group
-- uniqueness check for an explicit number is now dead code (nothing
-- can reach it with a non-null value) and is removed along with it.
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
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership_id uuid;
  v_member_number text;
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

  if p_member_number is not null then
    raise exception 'MANUAL_MEMBER_NUMBER_NOT_ALLOWED' using errcode = '22023';
  end if;

  v_member_number := public.generate_member_number(
    p_group_id,
    extract(year from coalesce(p_joined_at, current_date))::integer
  );

  insert into public.group_memberships (
    group_id, user_id, display_name, phone, member_number, status, joined_at, created_by
  )
  values (
    p_group_id, null, btrim(p_display_name), p_phone, v_member_number, 'ACTIVE', p_joined_at, v_uid
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

-- rpc_rejoin_group_member: search_path hardening, plus section 2's
-- effective-date validation. The EXITED-only guard, the
-- USER_ALREADY_HAS_ACTIVE_MEMBERSHIP guard, and the history-row shape
-- are otherwise unchanged.
create or replace function public.rpc_rejoin_group_member(
  p_group_id uuid,
  p_membership_id uuid,
  p_rejoined_at date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_current_status public.membership_status;
  v_user_id uuid;
  v_previous_exited_at date;
  v_effective_rejoin_date date;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.change_status') then
    raise exception 'Not authorized to change member status in this group' using errcode = '42501';
  end if;

  select group_id, status, user_id, exited_at
  into v_target_group_id, v_current_status, v_user_id, v_previous_exited_at
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if v_current_status <> 'EXITED' then
    raise exception 'MEMBERSHIP_NOT_EXITED' using errcode = 'P0001';
  end if;

  -- Defense in depth: every path that sets status = 'EXITED'
  -- (rpc_change_group_member_status) also sets exited_at, so this
  -- should be unreachable in practice, but the effective-date checks
  -- below need a real previous_exited_at to compare against, and
  -- history/eligibility logic (see 20260821090000's Contribution
  -- Engine note) depends on it being present.
  if v_previous_exited_at is null then
    raise exception 'EXITED_MEMBERSHIP_MISSING_EXITED_AT' using errcode = '22023';
  end if;

  v_effective_rejoin_date := coalesce(p_rejoined_at, current_date);

  if v_effective_rejoin_date < v_previous_exited_at then
    raise exception 'REJOIN_DATE_BEFORE_EXIT' using errcode = '22023';
  end if;

  if v_effective_rejoin_date > current_date then
    raise exception 'REJOIN_DATE_IN_FUTURE' using errcode = '22023';
  end if;

  -- Mirrors group_memberships_user_active_unique: a linked auth user
  -- must not end up with two ACTIVE memberships in the same group.
  if v_user_id is not null and exists (
    select 1
    from public.group_memberships
    where group_id = p_group_id
      and user_id = v_user_id
      and status = 'ACTIVE'
      and id <> p_membership_id
  ) then
    raise exception 'USER_ALREADY_HAS_ACTIVE_MEMBERSHIP' using errcode = 'P0001';
  end if;

  update public.group_memberships
  set status = 'ACTIVE', exited_at = null
  where id = p_membership_id;

  insert into public.group_membership_status_history (
    group_membership_id, group_id, from_status, to_status,
    previous_exited_at, effective_at, changed_by, action
  ) values (
    p_membership_id, p_group_id, 'EXITED', 'ACTIVE',
    v_previous_exited_at, v_effective_rejoin_date, v_uid, 'REJOIN'
  );

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
end;
$$;
