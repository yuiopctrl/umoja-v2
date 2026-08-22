-- Server-generated, concurrency-safe member numbers
-- (<GROUP_CODE>-<YYYY>-<SEQUENCE>, e.g. UMJ-2026-0001) — prompt 05B
-- §30-36.
--
-- Prefix source: public.groups.code. Inspected before this migration —
-- `code` was a bare nullable text column, never populated by
-- rpc_create_group, not unique, not immutable, and not read anywhere
-- in the Flutter app (confirmed by grep). Repurposing it (rather than
-- adding a second competing prefix column) was confirmed as the
-- preferred approach. It becomes NOT NULL + UNIQUE + format-checked +
-- immutable below, and is removed from the client-editable column
-- grant (a group's code must never change once assigned, since
-- existing member numbers already embed it and must never appear to
-- reference a different group after a rename).

-- ---------------------------------------------------------------------
-- generate_group_code(): derives a short, unique, uppercase
-- alphanumeric code from a group name, disambiguating collisions with
-- a numeric suffix. Internal only — not part of the public API
-- surface; called from rpc_create_group and this migration's backfill.
-- ---------------------------------------------------------------------
create or replace function public.generate_group_code(p_name text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_base text;
  v_candidate text;
  v_suffix integer := 0;
begin
  v_base := upper(regexp_replace(coalesce(p_name, ''), '[^a-zA-Z0-9]', '', 'g'));
  v_base := left(v_base, 4);
  if v_base = '' then
    v_base := 'GRP';
  end if;

  v_candidate := v_base;
  while exists (select 1 from public.groups where code = v_candidate) loop
    v_suffix := v_suffix + 1;
    v_candidate := v_base || v_suffix::text;
  end loop;

  return v_candidate;
end;
$$;

revoke all on function public.generate_group_code(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Backfill existing groups (code is currently NULL for all of them —
-- rpc_create_group never set it), one at a time in a stable order so
-- name collisions disambiguate deterministically via the suffix loop
-- above, before the column becomes NOT NULL/UNIQUE.
-- ---------------------------------------------------------------------
do $$
declare
  v_group record;
begin
  for v_group in select id, name from public.groups where code is null order by created_at loop
    update public.groups
    set code = public.generate_group_code(v_group.name)
    where id = v_group.id;
  end loop;
end;
$$;

alter table public.groups
  add constraint groups_code_format check (code ~ '^[A-Z0-9]{2,10}$');

alter table public.groups
  alter column code set not null;

create unique index groups_code_unique on public.groups (code);

-- code is immutable once set — existing member numbers already embed
-- it, and a renamed/edited group must never appear to relabel numbers
-- that were generated under its old code (prompt 05B §30: "Renaming a
-- group must never change existing member numbers").
create or replace function public.prevent_group_code_change()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.code is distinct from old.code then
    raise exception 'groups.code cannot be changed by update' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger groups_prevent_code_change
  before update on public.groups
  for each row
  execute function public.prevent_group_code_change();

-- Remove code from the client-editable column grant — it is now
-- system-managed only (the trigger above is defense in depth; this is
-- the primary guard, matching this codebase's "least privilege at the
-- grant level" convention).
revoke update on public.groups from authenticated;
grant update (name, description, currency, timezone) on public.groups to authenticated;

-- ---------------------------------------------------------------------
-- rpc_create_group: minimal diff against the actual current definition
-- (20260819085905_enforce_active_profile_on_mutations.sql, which added
-- the assert_active_profile() call on top of the original
-- 20260819080638 version) — the *only* change here is populating the
-- now-required `code` column on insert. Every other statement, the
-- active-profile/admin-role-missing guards, the display-name fallback,
-- and the `return public.rpc_get_my_context()` result shape are
-- reproduced exactly unchanged.
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

-- ---------------------------------------------------------------------
-- Concurrency-safe per-group, per-year member number sequence.
-- ---------------------------------------------------------------------
create table public.group_member_number_counters (
  group_id uuid not null references public.groups (id),
  year integer not null,
  last_number integer not null default 0,
  primary key (group_id, year)
);

comment on table public.group_member_number_counters is
  'Backing counter for server-generated member numbers '
  '(<groups.code>-<year>-<sequence>). Never read/written directly by '
  'clients — only via next_group_member_number(), itself only called '
  'from rpc_create_group_member.';

alter table public.group_member_number_counters enable row level security;
revoke all on public.group_member_number_counters from anon, authenticated;

-- next_group_member_number(): atomic increment via INSERT ... ON
-- CONFLICT ... DO UPDATE ... RETURNING — the standard Postgres-safe
-- counter pattern, immune to the lost-update race a bare
-- "select max(...)+1" would have. Internal only.
create or replace function public.next_group_member_number(
  p_group_id uuid,
  p_year integer
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
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

revoke all on function public.next_group_member_number(uuid, integer) from public, anon, authenticated;

-- generate_member_number(): <code>-<year>-<sequence, >=4 digits,
-- widening beyond 9999 rather than overflowing/failing (prompt 05B
-- §34). Internal only.
create or replace function public.generate_member_number(
  p_group_id uuid,
  p_year integer
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
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

revoke all on function public.generate_member_number(uuid, integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_create_group_member: auto-generate member_number when the caller
-- does not explicitly supply one (the normal app create-member flow —
-- see MemberFormController — never does). An explicitly-supplied
-- number (a future controlled admin/import workflow, per prompt 05B
-- §28) is still honored as an override, subject to the same
-- uniqueness check as before. Existing rows/behavior for explicit
-- numbers are otherwise unchanged.
-- ---------------------------------------------------------------------
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
    if exists (
      select 1
      from public.group_memberships
      where group_id = p_group_id and member_number = p_member_number
    ) then
      raise exception 'member_number already exists in this group' using errcode = '23505';
    end if;
    v_member_number := p_member_number;
  else
    v_member_number := public.generate_member_number(
      p_group_id,
      extract(year from coalesce(p_joined_at, current_date))::integer
    );
  end if;

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
