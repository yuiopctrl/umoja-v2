-- Prompt 09G-B1-F1: phone-targeted member invitation — backend
-- foundation only (no Flutter). Adds a SECOND invitation delivery
-- mechanism (PHONE) alongside the existing bearer-TOKEN mechanism from
-- 20260922090000, which remains fully intact for backward
-- compatibility (this migration does not delete/deprecate it).
--
-- Schema/platform facts confirmed from source before designing (not
-- assumed):
--   * auth.users has `phone text` and `phone_confirmed_at timestamptz`
--     (confirmed via `information_schema.columns` locally), with a
--     UNIQUE constraint on `phone` (`users_phone_key`, confirmed via
--     `pg_constraint`) — Supabase Auth itself guarantees at most one
--     auth.users row per confirmed phone. `phone_confirmed_at` is
--     populated by Supabase Auth's own phone-OTP verification
--     (`auth.verifyOTP(... type: sms)`), never client-writable — this
--     is the ONE authoritative, non-spoofable "verified phone" signal
--     available server-side, and is EXACTLY what this project's own
--     `setup-pin` Edge Function (supabase/functions/setup-pin/
--     index.ts) already keys authorization off of
--     (`caller.phone`/`caller.phoneConfirmed = Boolean(data.user.
--     phone_confirmed_at)`) — this migration reuses that same
--     authoritative source, never invents a second one.
--   * `profiles.phone` is explicitly NOT authoritative — confirmed by
--     20260921092000's own header comment: it is mirrored from
--     auth.users.phone ONCE at signup (handle_new_user trigger), but
--     `grant update (full_name, phone, avatar_url) on public.profiles
--     to authenticated` (20260819083322) lets the SAME user overwrite
--     it afterward with no re-verification at all. `group_memberships.
--     phone` is weaker still: free text entered by an officer at
--     `rpc_create_group_member` time (20260819080639), no format
--     check, no uniqueness, never verified against anything. NEITHER
--     is used anywhere in this migration as recipient authority — see
--     Section C below.
--   * Phone normalization: `app/lib/core/utils/tanzania_phone_number.
--     dart` (`TanzaniaPhoneNumber.parse`) and its already-existing
--     server-side TypeScript mirror `supabase/functions/_shared/
--     phone.ts` (`normalizeTanzaniaPhone`, used by setup-pin/pin-login)
--     together establish ONE canonical convention: accepts
--     `0712345678` / `712345678` / `255712345678` / `+255712345678`
--     (Tanzanian mobile only, subscriber prefix 6 or 7), canonical
--     output `+255XXXXXXXXX`. `normalize_tanzania_phone_e164()` below
--     is a byte-for-byte PL/pgSQL reimplementation of that EXACT same
--     algorithm (SQL cannot call Dart/Deno code), not a new/divergent
--     convention. `setup-pin` itself re-normalizes `auth.users.phone`
--     before use — confirming the raw stored value cannot be assumed
--     already canonical, so this migration does the same defensive
--     re-normalization at every read.
--   * `membership_invitations` (20260922090000) already has zero RLS
--     policies, zero direct grants, and the exact "lock row -> re-
--     validate everything against the CURRENT row -> mutate" discipline
--     this migration reuses verbatim for the new RPCs. Reused as-is:
--     the table itself (extended, not duplicated), `membership_
--     invitation_roles` (unchanged), `membership_invitations_one_
--     pending_per_membership` (already membership-scoped and type-
--     agnostic — a PHONE invitation attempt against a membership that
--     already has ANY PENDING invitation, TOKEN or PHONE, is already
--     blocked by this existing unique index with zero changes), the
--     ADMIN-escalation guard, `prevent_membership_user_id_change()`'s
--     existing `umoja.membership_invitation_acceptance` marker (reused
--     as-is — a phone-invitation acceptance is authorized through the
--     exact same sanctioned exception, not a new one), and the
--     existing symmetric claim<->invitation cancellation in
--     `rpc_approve_membership_claim` (already membership-scoped with
--     no TOKEN-specific filter, so it already cancels a competing
--     PENDING PHONE invitation with zero changes needed).
--   * `membership_invitation_status` currently has no value meaning
--     "the recipient declined it" — CANCELLED is already used for TWO
--     distinct officer/system-side outcomes (explicit officer
--     cancellation via rpc_cancel_membership_invitation, AND automatic
--     symmetric cancellation when a competing claim is approved).
--     Reusing CANCELLED for a member's own explicit decline would
--     erase that distinction for officers reviewing history. Per this
--     prompt's own explicit escape clause, DECLINED was added as a new
--     enum value in the SEPARATE, EARLIER migration
--     20260922091000_add_declined_to_membership_invitation_status.sql
--     (see that file's header for why it could not live in this one).
--
-- Sections:
--   A. normalize_tanzania_phone_e164() — internal phone canonicalizer.
--   B. current_verified_auth_phone_e164() — internal authoritative-
--      identity resolver.
--   C. membership_invitations schema extension (invitation_type,
--      target_phone_e164, declined_at/declined_by) and the
--      DECLINED-dependent check constraint.
--   D. rpc_create_membership_phone_invitation.
--   E. rpc_list_my_membership_invitations.
--   F. rpc_accept_membership_phone_invitation.
--   G. rpc_decline_membership_phone_invitation.
--   H. rpc_list_membership_invitations — redefined, additive fields
--      only (invitation_type, target_phone_e164), so PHONE invitations
--      are visible in existing officer history/queue screens.
--      rpc_cancel_membership_invitation needs, and receives, ZERO
--      changes — it already operates purely on id/group_id/status with
--      no TOKEN-specific logic, so it already cancels a PENDING PHONE
--      invitation correctly today.

-- =========================================================================
-- A. normalize_tanzania_phone_e164 — pure, no table access, no
-- elevated privilege needed (security invoker, the default). Internal
-- only: never called directly by a client, only from the SECURITY
-- DEFINER RPCs below.
-- =========================================================================
create or replace function public.normalize_tanzania_phone_e164(p_raw text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_trimmed text;
  v_stripped text;
  v_has_plus boolean;
  v_digits text;
  v_subscriber text;
begin
  if p_raw is null then
    return null;
  end if;

  v_trimmed := btrim(p_raw);
  if v_trimmed = '' then
    return null;
  end if;

  v_stripped := regexp_replace(v_trimmed, '[\s\-()]', '', 'g');
  v_has_plus := left(v_stripped, 1) = '+';
  v_digits := case when v_has_plus then substring(v_stripped from 2) else v_stripped end;

  if v_digits = '' or v_digits !~ '^[0-9]+$' then
    return null;
  end if;

  if v_has_plus then
    if left(v_digits, 3) <> '255' then
      return null;
    end if;
    v_subscriber := substring(v_digits from 4);
  elsif left(v_digits, 3) = '255' and length(v_digits) = 12 then
    v_subscriber := substring(v_digits from 4);
  elsif left(v_digits, 1) = '0' then
    v_subscriber := substring(v_digits from 2);
  else
    v_subscriber := v_digits;
  end if;

  if length(v_subscriber) <> 9 then
    return null;
  end if;

  if left(v_subscriber, 1) not in ('6', '7') then
    return null;
  end if;

  return '+255' || v_subscriber;
end;
$$;

comment on function public.normalize_tanzania_phone_e164(text) is
  'PL/pgSQL mirror of app/lib/core/utils/tanzania_phone_number.dart''s '
  'TanzaniaPhoneNumber.parse and supabase/functions/_shared/phone.ts''s '
  'normalizeTanzaniaPhone — the SAME accepted-input rules and canonical '
  'output (+255XXXXXXXXX), never a second/divergent convention. Returns '
  'NULL for anything unparseable/unsupported (not a Tanzanian mobile '
  'number) rather than raising, so callers can decide the appropriate '
  'error for their own context.';

revoke all on function public.normalize_tanzania_phone_e164(text) from public, anon, authenticated;

-- =========================================================================
-- B. current_verified_auth_phone_e164 — the ONE authoritative
-- identity-resolution primitive every new RPC below uses. Reads
-- auth.users directly (ordinary authenticated/anon roles have no grant
-- on auth.users at all; this is only reachable through this SECURITY
-- DEFINER function, exactly like handle_new_user() already reads
-- auth.users via its trigger NEW record). Always resolves the CALLING
-- user's own row via auth.uid() — never accepts a phone/user id
-- parameter, so it is structurally impossible for a caller to assert
-- "my phone is X".
-- =========================================================================
create or replace function public.current_verified_auth_phone_e164()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_raw_phone text;
  v_confirmed_at timestamptz;
begin
  if v_uid is null then
    return null;
  end if;

  select phone, phone_confirmed_at into v_raw_phone, v_confirmed_at
  from auth.users
  where id = v_uid;

  if v_confirmed_at is null then
    return null;
  end if;

  return public.normalize_tanzania_phone_e164(v_raw_phone);
end;
$$;

comment on function public.current_verified_auth_phone_e164() is
  'Resolves the CALLING user''s (auth.uid()) own authoritative, Supabase '
  'Auth-verified phone (auth.users.phone where phone_confirmed_at is '
  'not null), canonicalized to +255XXXXXXXXX, or NULL if unauthenticated '
  'or the caller has no confirmed phone. This is the ONLY server-side '
  'primitive phone-targeted invitation discovery/acceptance/decline may '
  'use to establish recipient identity — never profiles.phone, never '
  'group_memberships.phone, never a client-supplied phone parameter. '
  'Internal-only; never granted to anon/authenticated directly.';

revoke all on function public.current_verified_auth_phone_e164() from public, anon, authenticated;

-- =========================================================================
-- C. membership_invitations schema extension. Purely additive:
-- existing TOKEN rows already satisfy the new consistency constraint
-- (token_hash NOT NULL, target_phone_e164 NULL) via the column
-- default, verified below. DECLINED (used by the check constraint
-- below) was already committed by the separate, earlier
-- 20260922091000 migration.
-- =========================================================================
create type public.membership_invitation_type as enum ('TOKEN', 'PHONE');

alter table public.membership_invitations
  add column invitation_type public.membership_invitation_type not null default 'TOKEN',
  add column target_phone_e164 text,
  add column declined_at timestamptz,
  add column declined_by uuid references auth.users (id);

-- token_hash is meaningless for a PHONE invitation — no bearer token is
-- ever generated for one (Section F item 8/9 of the prompt).
alter table public.membership_invitations alter column token_hash drop not null;

alter table public.membership_invitations
  add constraint membership_invitations_type_fields_consistent
  check (
    (invitation_type = 'TOKEN' and token_hash is not null and target_phone_e164 is null)
    or
    (invitation_type = 'PHONE' and token_hash is null and target_phone_e164 is not null)
  );

alter table public.membership_invitations
  add constraint membership_invitations_declined_fields_consistent
  check (
    (status = 'DECLINED' and declined_at is not null and declined_by is not null)
    or (status <> 'DECLINED' and declined_at is null and declined_by is null)
  );

comment on column public.membership_invitations.invitation_type is
  'TOKEN (bearer-link, 20260922090000) or PHONE (this migration). '
  'Mutually exclusive with the other type''s own identifying column — '
  'see membership_invitations_type_fields_consistent.';

comment on column public.membership_invitations.target_phone_e164 is
  'PHONE invitations only: the canonical (+255XXXXXXXXX) phone the '
  'invitation targets, normalized server-side at creation time via '
  'normalize_tanzania_phone_e164(). Compared only against the '
  'recipient''s OWN Supabase-Auth-verified phone at discovery/accept/'
  'decline time (current_verified_auth_phone_e164()) — never against '
  'profiles.phone or group_memberships.phone.';

comment on column public.membership_invitations.declined_by is
  'The recipient (auth.uid()) who declined a PHONE invitation. Distinct '
  'from cancelled_by (which always means an officer action or the '
  'symmetric claim-approval side effect) — kept as a separate status/'
  'column pair so officer-facing history never conflates "the officer '
  'cancelled this" with "the recipient said no".';

-- =========================================================================
-- D. rpc_create_membership_phone_invitation — officer creates a PHONE
-- invitation. Same authorization/eligibility engine as
-- rpc_create_membership_invitation (20260922090000 §D), with phone
-- normalization in place of token generation.
-- =========================================================================
create or replace function public.rpc_create_membership_phone_invitation(
  p_group_id uuid,
  p_membership_id uuid,
  p_phone text,
  p_role_codes text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_phone_e164 text;
  v_membership record;
  v_role_codes text[];
  v_role_code text;
  v_role_id uuid;
  v_role_ids uuid[] := '{}';
  v_invitation_id uuid;
  v_expires_at timestamptz;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.invite') then
    raise exception 'Not authorized to invite members in this group' using errcode = '42501';
  end if;

  v_phone_e164 := public.normalize_tanzania_phone_e164(p_phone);
  if v_phone_e164 is null then
    raise exception 'MEMBERSHIP_INVITATION_INVALID_PHONE' using errcode = 'P0001';
  end if;

  if p_role_codes is null or cardinality(p_role_codes) = 0 then
    raise exception 'At least one role must be selected' using errcode = '22023';
  end if;

  select array_agg(distinct upper(btrim(code)))
  into v_role_codes
  from unnest(p_role_codes) as code;

  foreach v_role_code in array v_role_codes loop
    select id into v_role_id from public.roles where code = v_role_code;
    if v_role_id is null then
      raise exception 'Unknown role code: %', v_role_code using errcode = '22023';
    end if;
    v_role_ids := v_role_ids || v_role_id;
  end loop;

  -- Identical ADMIN anti-escalation invariant as the TOKEN flow.
  if 'ADMIN' = any(v_role_codes) and not public.has_group_role(p_group_id, 'ADMIN') then
    raise exception 'Only an existing ADMIN may invite a member with the ADMIN role' using errcode = '42501';
  end if;

  select gm.id, gm.group_id, gm.user_id, gm.status as membership_status, g.status as group_status
  into v_membership
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = p_membership_id
  for update of gm;

  if v_membership.id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if v_membership.user_id is not null then
    raise exception 'MEMBERSHIP_ALREADY_LINKED' using errcode = 'P0001';
  end if;

  if v_membership.membership_status <> 'ACTIVE' then
    raise exception 'MEMBERSHIP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if v_membership.group_status <> 'ACTIVE' then
    raise exception 'GROUP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  -- Type-agnostic: the SAME unique index the TOKEN flow already relies
  -- on (membership_invitations_one_pending_per_membership) blocks a
  -- second PENDING invitation of EITHER type for this membership. This
  -- pre-check is a friendlier error than the unique-violation the index
  -- itself would raise; the index remains the authoritative race guard.
  if exists (
    select 1 from public.membership_invitations
    where membership_id = p_membership_id and status = 'PENDING'
  ) then
    raise exception 'MEMBERSHIP_INVITATION_ALREADY_PENDING' using errcode = 'P0001';
  end if;

  v_expires_at := now() + interval '7 days';

  -- No account-existence check of any kind against auth.users happens
  -- here (Section O/P) — a PHONE invitation is created identically
  -- whether or not the phone already has an account; it simply becomes
  -- visible via rpc_list_my_membership_invitations() once/if a
  -- matching authenticated, verified-phone identity exists.
  insert into public.membership_invitations (
    group_id, membership_id, invitation_type, target_phone_e164, expires_at, created_by
  )
  values (
    p_group_id, p_membership_id, 'PHONE', v_phone_e164, v_expires_at, v_uid
  )
  returning id into v_invitation_id;

  insert into public.membership_invitation_roles (invitation_id, role_id)
  select v_invitation_id, unnest(v_role_ids);

  select jsonb_build_object(
    'invitation_id', mi.id,
    'group_id', mi.group_id,
    'membership_id', mi.membership_id,
    'status', mi.status,
    'target_phone_e164', mi.target_phone_e164,
    'created_at', mi.created_at,
    'expires_at', mi.expires_at,
    'roles', (
      select coalesce(jsonb_agg(distinct r.code), '[]'::jsonb)
      from public.membership_invitation_roles mir
      join public.roles r on r.id = mir.role_id
      where mir.invitation_id = mi.id
    )
  )
  into v_result
  from public.membership_invitations mi
  where mi.id = v_invitation_id;

  return v_result;
end;
$$;

comment on function public.rpc_create_membership_phone_invitation(uuid, uuid, text, text[]) is
  'Creates a PENDING PHONE invitation for an ACTIVE, currently-unlinked '
  'membership in an ACTIVE group, targeting the given phone (normalized '
  'server-side, never trusted as already canonical) and assigning the '
  'given role codes (resolved server-side). No bearer token is ever '
  'generated. Requires member.invite; inviting with the ADMIN role '
  'additionally requires the caller to already hold ADMIN. Rejected '
  'while ANY PENDING invitation (TOKEN or PHONE) already exists for the '
  'same membership. Never checks whether the phone already has an '
  'auth.users account — the same creation path handles both cases.';

revoke all on function public.rpc_create_membership_phone_invitation(uuid, uuid, text, text[]) from public;
grant execute on function public.rpc_create_membership_phone_invitation(uuid, uuid, text, text[]) to authenticated;
revoke execute on function public.rpc_create_membership_phone_invitation(uuid, uuid, text, text[]) from anon;

-- =========================================================================
-- E. rpc_list_my_membership_invitations — the invited user's own queue.
-- Takes NO phone/user parameter; identity is resolved exclusively via
-- current_verified_auth_phone_e164().
-- =========================================================================
create or replace function public.rpc_list_my_membership_invitations(
  p_status public.membership_invitation_status default null,
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
  v_phone text;
  v_items jsonb;
  v_total bigint;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  v_phone := public.current_verified_auth_phone_e164();

  -- Section Q's chosen contract: a caller with no confirmed Auth phone
  -- (unreachable in normal use today — phone-OTP is this app's only
  -- signup path, and assert_active_profile() already requires a
  -- completed profile) sees an empty list rather than an error. This
  -- fails closed on ACTIONABILITY (nothing is ever exposed/acceptable
  -- without a verified phone) while never crashing or alarming a
  -- legitimate caller with a generic technical error for a state that
  -- should not occur.
  if v_phone is null then
    return jsonb_build_object(
      'items', '[]'::jsonb, 'total_count', 0, 'limit', p_limit, 'offset', p_offset
    );
  end if;

  select count(*) into v_total
  from public.membership_invitations mi
  where mi.invitation_type = 'PHONE'
    and mi.target_phone_e164 = v_phone
    and (
      p_status is null
      or mi.status = p_status
      or (p_status = 'EXPIRED' and mi.status = 'PENDING' and mi.expires_at <= now())
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'invitation_id', mi.id,
    'status', case
      when mi.status = 'PENDING' and mi.expires_at <= now() then 'EXPIRED'
      else mi.status::text
    end,
    'can_accept', mi.status = 'PENDING' and mi.expires_at > now(),
    'group_name', g.name,
    'membership_display_name', gm.display_name,
    'membership_member_number', gm.member_number,
    'roles', (
      select coalesce(jsonb_agg(distinct r.name), '[]'::jsonb)
      from public.membership_invitation_roles mir
      join public.roles r on r.id = mir.role_id
      where mir.invitation_id = mi.id
    ),
    'invited_at', mi.created_at,
    'expires_at', mi.expires_at
  ) order by mi.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select *
    from public.membership_invitations mi
    where mi.invitation_type = 'PHONE'
      and mi.target_phone_e164 = v_phone
      and (
        p_status is null
        or mi.status = p_status
        or (p_status = 'EXPIRED' and mi.status = 'PENDING' and mi.expires_at <= now())
      )
    order by mi.created_at desc
    limit p_limit offset p_offset
  ) mi
  join public.group_memberships gm on gm.id = mi.membership_id
  join public.groups g on g.id = mi.group_id;

  return jsonb_build_object(
    'items', v_items, 'total_count', v_total, 'limit', p_limit, 'offset', p_offset
  );
end;
$$;

comment on function public.rpc_list_my_membership_invitations(public.membership_invitation_status, integer, integer) is
  'The invited user''s own PHONE-invitation queue. Takes NO phone/user '
  'parameter — the caller''s identity is resolved exclusively via '
  'current_verified_auth_phone_e164(), so this can only ever return '
  'invitations targeting the CALLER''S OWN Supabase-Auth-verified '
  'phone. Never exposes token_hash, another user''s auth id, or '
  'inviter identity. Effective status computes live EXPIRED exactly '
  'like rpc_preview_membership_invitation, never writing it back.';

revoke all on function public.rpc_list_my_membership_invitations(public.membership_invitation_status, integer, integer) from public;
grant execute on function public.rpc_list_my_membership_invitations(public.membership_invitation_status, integer, integer) to authenticated;
revoke execute on function public.rpc_list_my_membership_invitations(public.membership_invitation_status, integer, integer) from anon;

-- =========================================================================
-- F. rpc_accept_membership_phone_invitation. Anti-enumeration model
-- mirrors rpc_accept_membership_invitation's own (Section 20260922090000
-- §E header): the invitation_id is as unguessable as the TOKEN flow's
-- 256-bit token (a gen_random_uuid() v4 primary key, never listed to
-- anyone but the legitimate matching-phone recipient), so "not found",
-- "wrong type", and "phone does not match" are ALL collapsed into the
-- SAME generic MEMBERSHIP_PHONE_INVITATION_NOT_FOUND outcome — a caller
-- can never learn "this id exists but for a different phone" versus
-- "this id doesn't exist". Only once ownership is proven (phone
-- matches) do further status-specific outcomes become distinguishable,
-- exactly like the TOKEN flow's "once found by secret, status
-- distinctions are safe" boundary.
-- =========================================================================
create or replace function public.rpc_accept_membership_phone_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_phone text;
  v_invitation record;
  v_membership record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  v_phone := public.current_verified_auth_phone_e164();
  if v_phone is null then
    raise exception 'AUTH_PHONE_NOT_VERIFIED' using errcode = 'P0001';
  end if;

  -- Lock first — two simultaneous accepts on the same invitation_id
  -- serialize here, exactly like the TOKEN flow's token-hash lock.
  select mi.id, mi.invitation_type, mi.target_phone_e164, mi.status, mi.expires_at,
         mi.group_id, mi.membership_id, mi.accepted_by
  into v_invitation
  from public.membership_invitations mi
  where mi.id = p_invitation_id
  for update of mi;

  if v_invitation.id is null
    or v_invitation.invitation_type <> 'PHONE'
    or v_invitation.target_phone_e164 <> v_phone
  then
    raise exception 'MEMBERSHIP_PHONE_INVITATION_NOT_FOUND' using errcode = 'P0001';
  end if;

  -- Idempotent retry for the SAME accepting user.
  if v_invitation.status = 'ACCEPTED' and v_invitation.accepted_by = v_uid then
    select jsonb_build_object(
      'invitation_id', id, 'group_id', group_id, 'membership_id', membership_id,
      'status', status, 'accepted_at', accepted_at, 'already_accepted', true
    )
    into v_result
    from public.membership_invitations
    where id = v_invitation.id;
    return v_result;
  end if;

  if v_invitation.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_INVITATION_NOT_PENDING' using errcode = 'P0001';
  end if;

  if v_invitation.expires_at <= now() then
    raise exception 'MEMBERSHIP_INVITATION_EXPIRED' using errcode = 'P0001';
  end if;

  select gm.id, gm.group_id, gm.user_id, gm.status as membership_status, g.status as group_status
  into v_membership
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = v_invitation.membership_id
  for update of gm;

  if v_membership.id is null or v_membership.group_id <> v_invitation.group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if v_membership.user_id is not null then
    raise exception 'MEMBERSHIP_ALREADY_LINKED' using errcode = 'P0001';
  end if;

  if v_membership.membership_status <> 'ACTIVE' then
    raise exception 'MEMBERSHIP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if v_membership.group_status <> 'ACTIVE' then
    raise exception 'GROUP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.group_memberships
    where group_id = v_invitation.group_id and user_id = v_uid and status = 'ACTIVE'
  ) then
    raise exception 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP' using errcode = 'P0001';
  end if;

  -- Reuses the EXISTING sanctioned trigger exception from
  -- 20260922090000 — no new linking pathway is introduced.
  perform set_config('umoja.membership_invitation_acceptance', 'true', true);

  update public.group_memberships
  set user_id = v_uid
  where id = v_invitation.membership_id;

  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  select v_invitation.membership_id, mir.role_id, v_uid
  from public.membership_invitation_roles mir
  where mir.invitation_id = v_invitation.id
  on conflict (group_membership_id, role_id) do nothing;

  update public.membership_invitations
  set status = 'ACCEPTED', accepted_at = now(), accepted_by = v_uid
  where id = v_invitation.id;

  -- Symmetric claim conflict resolution — identical to the TOKEN flow.
  update public.membership_claim_requests
  set status = 'CANCELLED', resolved_at = now(), resolved_by = v_uid
  where membership_id = v_invitation.membership_id and status = 'PENDING';

  select jsonb_build_object(
    'invitation_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'status', status, 'accepted_at', accepted_at, 'already_accepted', false
  )
  into v_result
  from public.membership_invitations
  where id = v_invitation.id;

  return v_result;
end;
$$;

comment on function public.rpc_accept_membership_phone_invitation(uuid) is
  'Accepts a PENDING, non-expired PHONE invitation by id: re-establishes '
  'authority server-side via current_verified_auth_phone_e164() (never '
  'a client-supplied phone/user/membership/group/role), collapsing '
  '"not found", "wrong type", and "phone mismatch" into ONE generic '
  'MEMBERSHIP_PHONE_INVITATION_NOT_FOUND outcome. Re-validates every '
  'eligibility condition against the locked, current membership row, '
  'then atomically links group_memberships.user_id = auth.uid(), '
  'assigns exactly the server-recorded roles, marks the invitation '
  'ACCEPTED, and auto-cancels any competing PENDING claim — all in one '
  'transaction. Idempotent for a retry by the SAME already-accepted '
  'user.';

revoke all on function public.rpc_accept_membership_phone_invitation(uuid) from public;
grant execute on function public.rpc_accept_membership_phone_invitation(uuid) to authenticated;
revoke execute on function public.rpc_accept_membership_phone_invitation(uuid) from anon;

-- =========================================================================
-- G. rpc_decline_membership_phone_invitation. Same ownership-proof gate
-- as accept; never touches group_memberships/group_membership_roles.
-- =========================================================================
create or replace function public.rpc_decline_membership_phone_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_phone text;
  v_invitation record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  v_phone := public.current_verified_auth_phone_e164();
  if v_phone is null then
    raise exception 'AUTH_PHONE_NOT_VERIFIED' using errcode = 'P0001';
  end if;

  select mi.id, mi.invitation_type, mi.target_phone_e164, mi.status,
         mi.group_id, mi.membership_id, mi.declined_by
  into v_invitation
  from public.membership_invitations mi
  where mi.id = p_invitation_id
  for update of mi;

  if v_invitation.id is null
    or v_invitation.invitation_type <> 'PHONE'
    or v_invitation.target_phone_e164 <> v_phone
  then
    raise exception 'MEMBERSHIP_PHONE_INVITATION_NOT_FOUND' using errcode = 'P0001';
  end if;

  -- Idempotent retry for the SAME declining user.
  if v_invitation.status = 'DECLINED' and v_invitation.declined_by = v_uid then
    select jsonb_build_object(
      'invitation_id', id, 'group_id', group_id, 'membership_id', membership_id,
      'status', status, 'declined_at', declined_at, 'already_declined', true
    )
    into v_result
    from public.membership_invitations
    where id = v_invitation.id;
    return v_result;
  end if;

  if v_invitation.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_INVITATION_NOT_PENDING' using errcode = 'P0001';
  end if;

  update public.membership_invitations
  set status = 'DECLINED', declined_at = now(), declined_by = v_uid
  where id = v_invitation.id;

  select jsonb_build_object(
    'invitation_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'status', status, 'declined_at', declined_at, 'already_declined', false
  )
  into v_result
  from public.membership_invitations
  where id = v_invitation.id;

  return v_result;
end;
$$;

comment on function public.rpc_decline_membership_phone_invitation(uuid) is
  'Declines a PENDING PHONE invitation by id, transitioning it to the '
  'terminal DECLINED state (never CANCELLED, which stays officer/'
  'system-only — see this migration''s header). Same ownership-proof '
  'gate as rpc_accept_membership_phone_invitation: id/type/phone-match '
  'failures collapse into MEMBERSHIP_PHONE_INVITATION_NOT_FOUND. Never '
  'touches group_memberships or group_membership_roles. Idempotent for '
  'a retry by the SAME declining user. A technically-expired-but-still-'
  '-stored-PENDING invitation may still be declined (harmless — it was '
  'never going to become acceptable either).';

revoke all on function public.rpc_decline_membership_phone_invitation(uuid) from public;
grant execute on function public.rpc_decline_membership_phone_invitation(uuid) to authenticated;
revoke execute on function public.rpc_decline_membership_phone_invitation(uuid) from anon;

-- =========================================================================
-- H. rpc_list_membership_invitations — redefined ONLY to add two
-- additive fields (invitation_type, target_phone_e164) so officer
-- history/queue screens can show PHONE invitations meaningfully. Every
-- existing field, parameter, and behavior is otherwise byte-for-byte
-- unchanged — this already selected from membership_invitations with
-- no invitation_type filter, so PHONE rows were already included even
-- before this redefinition; only the shape of each item gains fields.
-- rpc_cancel_membership_invitation is NOT redefined here: it already
-- operates purely on id/group_id/status with zero TOKEN-specific logic,
-- so it already cancels a PENDING PHONE invitation correctly today,
-- with no code change needed or made.
-- =========================================================================
create or replace function public.rpc_list_membership_invitations(
  p_group_id uuid,
  p_status public.membership_invitation_status default null,
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
  v_total bigint;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.invite') then
    raise exception 'Not authorized to view membership invitations in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.membership_invitations mi
  where mi.group_id = p_group_id and (p_status is null or mi.status = p_status);

  select coalesce(jsonb_agg(jsonb_build_object(
    'invitation_id', mi.id,
    'invitation_type', mi.invitation_type,
    'target_phone_e164', mi.target_phone_e164,
    'membership_id', mi.membership_id,
    'membership_display_name', gm.display_name,
    'membership_member_number', gm.member_number,
    'status', mi.status,
    'is_expired', mi.status = 'PENDING' and mi.expires_at <= now(),
    'roles', (
      select coalesce(jsonb_agg(distinct r.code), '[]'::jsonb)
      from public.membership_invitation_roles mir
      join public.roles r on r.id = mir.role_id
      where mir.invitation_id = mi.id
    ),
    'created_at', mi.created_at,
    'expires_at', mi.expires_at,
    'created_by_full_name', creator.full_name,
    'accepted_at', mi.accepted_at,
    'accepted_by_full_name', accepter.full_name,
    'cancelled_at', mi.cancelled_at,
    'cancelled_by_full_name', canceller.full_name,
    'declined_at', mi.declined_at
  ) order by mi.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select *
    from public.membership_invitations mi
    where mi.group_id = p_group_id and (p_status is null or mi.status = p_status)
    order by mi.created_at desc
    limit p_limit offset p_offset
  ) mi
  join public.group_memberships gm on gm.id = mi.membership_id
  left join public.profiles creator on creator.id = mi.created_by
  left join public.profiles accepter on accepter.id = mi.accepted_by
  left join public.profiles canceller on canceller.id = mi.cancelled_by;

  return jsonb_build_object(
    'items', v_items, 'total_count', v_total, 'limit', p_limit, 'offset', p_offset
  );
end;
$$;

comment on function public.rpc_list_membership_invitations(uuid, public.membership_invitation_status, integer, integer) is
  'Group-scoped, member.invite-gated officer queue/history — now covers '
  'BOTH TOKEN and PHONE invitations (invitation_type/target_phone_e164 '
  'added; every other field unchanged from 20260922090000). '
  'declined_by is deliberately never joined to a profile/exposed by '
  'name here — declined_at plus status=DECLINED is enough for officer '
  'history without surfacing recipient-identity detail beyond what the '
  'officer already knows (the phone they themselves invited). Never '
  'exposes the token or its hash.';

-- Grants unchanged by CREATE OR REPLACE (same signature): already
-- REVOKE ALL FROM PUBLIC, GRANT EXECUTE TO authenticated, REVOKE
-- EXECUTE FROM anon, from 20260922090000.
