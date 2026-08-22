-- Prompt 05D: closes the last gap in the server-generated member-number
-- invariant introduced by 20260821100000 and hardened by 20260821110000
-- (both already applied to Cloud and NOT edited here).
--
-- Root cause this migration fixes: ROLE and MEMBERSHIP are separate
-- concepts in this schema — an ADMIN role assignment
-- (group_membership_roles) does not replace a group_membership row.
-- rpc_create_group has always inserted the founder's own
-- group_membership directly (never through rpc_create_group_member,
-- which is the only place member-number generation was ever wired up),
-- so every group's founding ADMIN membership has had
-- member_number = null since 20260821100000 shipped. This migration:
--
--   1. Hardens generate_member_number() against legacy/foreign
--      collisions (section 4 below) — needed before backfilling, since
--      the per-group/per-year counter has no idea what numbers already
--      exist in already-populated groups.
--   2. Backfills every existing group_memberships row with
--      member_number is null, in a stable, deterministic order.
--   3. Confirms no null rows remain, then enforces
--      group_memberships.member_number NOT NULL at the database level
--      — the actual product invariant, not just an RPC-level
--      convention. No DEFAULT is added; creation stays exclusively
--      server-controlled through the RPC generation logic.
--   4. Re-creates rpc_create_group so the founder's membership gets a
--      member_number at creation time, same as every other member —
--      now structurally required by step 3's constraint too.
--   5. Re-creates rpc_update_group_member so member_number is
--      immutable through the normal edit path (the gap flagged in
--      20260821110000's own test-file comment).
--
-- All three re-created functions move to the hardened
-- `set search_path = ''` convention, fully schema-qualified.

-- ---------------------------------------------------------------------
-- 1. generate_member_number: collision-safe against pre-existing
-- member numbers. The per-group/per-year counter
-- (group_member_number_counters) only knows about numbers *it* has
-- issued — it has no idea a group might already contain a legacy or
-- manually-entered number that happens to match a future candidate
-- (e.g. a pre-migration row literally named "UMOJ-2026-0001"). Rather
-- than trust the counter blindly, each candidate is checked against
-- the group's actual data and, if occupied, the counter is advanced
-- again and retried. The counter itself remains the sole source of
-- sequencing (still atomic INSERT ... ON CONFLICT ... DO UPDATE, never
-- MAX()+1) — this only adds a check-and-retry loop around it, so
-- concurrency safety is unchanged: two concurrent callers still each
-- get their own distinct, ever-increasing counter value per attempt,
-- and a collision on one caller's candidate simply costs that caller
-- one extra atomic increment, never a duplicate.
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
  v_candidate text;
begin
  select code into v_code from public.groups where id = p_group_id;
  if v_code is null then
    raise exception 'Group has no code configured' using errcode = 'P0001';
  end if;

  loop
    v_seq := public.next_group_member_number(p_group_id, p_year);
    v_candidate := v_code || '-' || p_year::text || '-' || lpad(v_seq::text, 4, '0');

    exit when not exists (
      select 1 from public.group_memberships
      where group_id = p_group_id and member_number = v_candidate
    );
  end loop;

  return v_candidate;
end;
$$;

-- ---------------------------------------------------------------------
-- 2. Backfill. Every pre-existing group_memberships row with no
-- member_number (in practice: every founding ADMIN membership created
-- by rpc_create_group before this migration) receives one, generated
-- with the hardened function above so it cannot collide with anything
-- already present. Processed in a stable, deterministic order
-- (group_id, joined_at, created_at, id) so a re-run against the same
-- data would assign identical numbers in identical order. A row's own
-- joined_at year is used when present (matching how every other member
-- number is dated); a legacy row with no joined_at at all falls back
-- to its created_at year. Only rows with member_number is null are
-- touched — no existing non-null number is ever read for a decision
-- other than the collision check inside generate_member_number, and
-- none is ever overwritten.
do $$
declare
  v_row record;
  v_year integer;
begin
  for v_row in
    select id, group_id, joined_at, created_at
    from public.group_memberships
    where member_number is null
    order by group_id, joined_at nulls last, created_at, id
  loop
    v_year := extract(year from coalesce(v_row.joined_at, v_row.created_at::date))::integer;

    update public.group_memberships
    set member_number = public.generate_member_number(v_row.group_id, v_year)
    where id = v_row.id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Enforce the invariant at the database level. There is no
-- legitimate product case that needs a null member_number going
-- forward — every reachable client path that can create a
-- group_memberships row goes through rpc_create_group or
-- rpc_create_group_member (both always generate one, confirmed by the
-- redefinitions below), and INSERT on this table is already revoked
-- from `authenticated` (20260819083321). The pgTAP fixtures that used
-- to construct membership rows directly without a member_number (for
-- tests unrelated to member numbers — tenant isolation, authorization,
-- admin continuity, ...) were updated alongside this migration to
-- supply deterministic test-only values instead of being a reason to
-- leave the column nullable.
--
-- Ordered deliberately: the backfill above must complete, and be
-- confirmed complete, before this constraint is added — never the
-- other way around. No DEFAULT is added: member_number stays
-- exclusively server-controlled through the RPC generation logic
-- (generate_member_number()), never a column-default side effect of a
-- plain INSERT.
do $$
declare
  v_remaining bigint;
begin
  select count(*) into v_remaining
  from public.group_memberships
  where member_number is null;

  if v_remaining > 0 then
    raise exception
      'Refusing to enforce member_number NOT NULL: % row(s) still have a null member_number after backfill',
      v_remaining;
  end if;
end;
$$;

alter table public.group_memberships
  alter column member_number set not null;

-- The existing partial unique index (group_memberships_member_number_unique,
-- from 20260819080632) already enforces per-group uniqueness and is
-- untouched — no duplicate index is created.

-- ---------------------------------------------------------------------
-- 4. rpc_create_group: the founder's own group_memberships row now
-- gets a member_number, generated the same way as every other member's
-- (group's code + the founding year + the next per-group/per-year
-- sequence) — no separate "admin identifier" concept. ADMIN remains
-- purely a group_membership_roles assignment on top of an otherwise
-- ordinary membership. Everything else (guards, the display-name
-- fallback, the returned rpc_get_my_context() shape) is unchanged from
-- 20260821110000's version.
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
  v_member_number text;
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

  -- The founder's membership is joined_at = current_date (below), so
  -- its member number is dated to the current year, same as any other
  -- member created without an explicit backdated joined_at.
  v_member_number := public.generate_member_number(v_group_id, extract(year from current_date)::integer);

  insert into public.group_memberships (
    group_id, user_id, display_name, member_number, status, joined_at, created_by
  )
  values (
    v_group_id,
    v_uid,
    coalesce(
      nullif(btrim((select full_name from public.profiles where id = v_uid)), ''),
      'Group admin'
    ),
    v_member_number,
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
-- 5. rpc_update_group_member: member_number becomes immutable through
-- this RPC. Compatibility behavior:
--   - p_member_number is null: ignored (unchanged, as before).
--   - p_member_number equals the membership's current number: a
--     tolerated no-op, for any older client that still echoes the
--     value back.
--   - p_member_number is anything else (including a real value passed
--     for a membership whose number happens to be null): rejected with
--     MEMBER_NUMBER_IMMUTABLE, SQLSTATE 22023. Assigning a number is
--     exclusively generate_member_number()'s job via the create RPCs,
--     never this one's, regardless of the row's current state.
-- Every other guard/behavior (member.edit gate, group-scoping,
-- display_name/phone/joined_at handling) is unchanged.
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
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_current_member_number text;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.edit') then
    raise exception 'Not authorized to edit members in this group' using errcode = '42501';
  end if;

  select group_id, member_number into v_target_group_id, v_current_member_number
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if p_display_name is not null and btrim(p_display_name) = '' then
    raise exception 'Member display name cannot be blank' using errcode = '22023';
  end if;

  if p_member_number is not null and p_member_number is distinct from v_current_member_number then
    raise exception 'MEMBER_NUMBER_IMMUTABLE' using errcode = '22023';
  end if;

  update public.group_memberships
  set
    display_name = coalesce(nullif(btrim(p_display_name), ''), display_name),
    phone = coalesce(p_phone, phone),
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
