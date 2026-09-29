-- Prompt 09G-B1-E1: officer-initiated member invitation — backend
-- foundation only (no Flutter, no delivery provider).
--
-- Schema facts confirmed from source before designing (not assumed):
--   * group_memberships.user_id is immutable except through the one
--     controlled trigger exception added by 20260921091000
--     (prevent_membership_user_id_change, redefined again below to add
--     a second, equally narrow, marker-gated exception).
--   * Roles are assigned per-membership via group_membership_roles
--     (many-to-many: a membership may hold more than one role),
--     resolved from a small, fixed vocabulary of ROLE CODES
--     (rpc_assign_group_role/rpc_remove_group_role,
--     20260819083320/20260819085905) — never from a client-supplied
--     role_id. This migration follows that exact convention
--     (p_role_codes text[]), not the illustrative p_role_ids from the
--     prompt's own pseudo-signature — using real project conventions
--     takes precedence over the prompt's placeholder naming.
--   * Assigning/removing the ADMIN role specifically requires the
--     caller to already hold ADMIN in the group (privilege-escalation
--     guard) — replicated here for invitation creation: an inviter who
--     is not themselves ADMIN cannot invite someone AS ADMIN.
--   * No "platform-only, non-group-assignable" role concept exists in
--     this schema — is_system merely means "seeded by migration", not
--     "cannot be assigned to a membership". All five seeded roles are
--     group-assignable today, so no additional filtering beyond the
--     existing role-code vocabulary lookup is needed.
--   * pgcrypto is already installed (schema `extensions`,
--     `extra_search_path = ["public", "extensions"]` in
--     supabase/config.toml) and gen_random_bytes()/digest() both work
--     locally — confirmed by direct query before writing this
--     migration. No weak random()/MD5 token scheme is used.
--   * has_group_permission() already encodes the full operational
--     invariant (active profile AND ACTIVE membership AND ACTIVE
--     group AND permission) — reused as-is for every gate below,
--     exactly like every other mutation RPC in this codebase.
--   * The claim workflow (20260921091000/092000) is the direct
--     precedent for the append-only-in-spirit table shape, the
--     for-update locking discipline, the "re-validate everything
--     against the locked row, never trust the state as read earlier"
--     rule, and the "zero RLS policies + zero direct grants, RPC-only"
--     table lockdown. This migration mirrors all of it.
--
-- Product context: invitation becomes the PRIMARY onboarding path;
-- the existing "Link my membership" claim workflow
-- (20260921091000/092000) is UNCHANGED and remains the fallback/
-- recovery path for members who were not invited or lost the
-- invitation. Both routes converge on the same
-- group_memberships.user_id linkage and must not race into
-- contradictory state — see part F below.

-- =========================================================================
-- A. group_memberships.user_id immutability — the SECOND authorized
-- exception (invitation acceptance), added alongside the existing
-- claim-approval exception. Narrow, additive, never a weakening: every
-- transition this trigger already blocked remains blocked exactly as
-- before; only a NULL -> non-null transition under EITHER
-- transaction-local marker is now allowed. Neither marker is ever
-- client-settable (PostgREST never exposes pg_catalog.set_config()
-- itself), so this can only be reached through
-- rpc_approve_membership_claim or rpc_accept_membership_invitation's
-- own permission/eligibility checks.
-- =========================================================================
create or replace function public.prevent_membership_user_id_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    if old.user_id is null
      and new.user_id is not null
      and (
        coalesce(current_setting('umoja.membership_claim_approval', true), 'false') = 'true'
        or coalesce(current_setting('umoja.membership_invitation_acceptance', true), 'false') = 'true'
      )
    then
      return new;
    end if;
    raise exception 'group_memberships.user_id cannot be changed by update' using errcode = '42501';
  end if;
  return new;
end;
$$;

comment on function public.prevent_membership_user_id_change() is
  'Blocks every change to group_memberships.user_id via UPDATE, with '
  'exactly two narrow exceptions: a NULL -> non-null transition when '
  'either the umoja.membership_claim_approval marker (set only by '
  'rpc_approve_membership_claim) or the '
  'umoja.membership_invitation_acceptance marker (set only by '
  'rpc_accept_membership_invitation) is ''true'' for the current '
  'transaction. Neither marker is ever settable by a client. Every '
  'other transition remains unconditionally rejected.';

-- =========================================================================
-- B. membership_invitations / membership_invitation_roles.
-- =========================================================================

create type public.membership_invitation_status as enum ('PENDING', 'ACCEPTED', 'CANCELLED', 'EXPIRED');

create table public.membership_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  token_hash text not null,
  status public.membership_invitation_status not null default 'PENDING',
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint membership_invitations_accepted_fields_consistent
    check (
      (status = 'ACCEPTED' and accepted_at is not null and accepted_by is not null)
      or (status <> 'ACCEPTED' and accepted_at is null and accepted_by is null)
    ),
  constraint membership_invitations_cancelled_fields_consistent
    check (
      (status = 'CANCELLED' and cancelled_at is not null and cancelled_by is not null)
      or (status <> 'CANCELLED' and cancelled_at is null and cancelled_by is null)
    )
);

comment on table public.membership_invitations is
  'Officer-initiated invitation to link an authenticated user to an '
  'existing roster-only (user_id IS NULL) membership and assign it '
  'role(s). Stores only a SHA-256 hash of the bearer token, never the '
  'plaintext — see rpc_create_membership_invitation(). Never stores a '
  'password/OTP/PIN or any authentication secret. Rows are never '
  'hard-deleted or edited outside the RPCs in this migration; '
  'resolved rows (ACCEPTED/CANCELLED) are permanent history, exactly '
  'like membership_claim_requests.';

comment on column public.membership_invitations.token_hash is
  'sha256(plaintext token), hex-encoded. The plaintext token is '
  'returned to the inviting officer exactly once, on successful '
  'creation, and never persisted anywhere.';

create trigger membership_invitations_set_updated_at
  before update on public.membership_invitations
  for each row
  execute function public.set_updated_at();

-- Bearer-token lookups must be exact-match only; no partial/prefix
-- lookup path exists anywhere in this migration.
create unique index membership_invitations_token_hash_unique
  on public.membership_invitations (token_hash);

-- Idempotency (Section J, option A: reject while a live PENDING
-- invitation exists — simpler and safer, and the exact same shape as
-- membership_claim_requests_one_pending_per_membership already chosen
-- for the claim workflow): a membership can never have more than one
-- PENDING invitation at a time.
create unique index membership_invitations_one_pending_per_membership
  on public.membership_invitations (membership_id)
  where status = 'PENDING';

create index membership_invitations_group_idx on public.membership_invitations (group_id);
create index membership_invitations_membership_idx on public.membership_invitations (membership_id);

alter table public.membership_invitations enable row level security;

-- Same lockdown precedent as membership_claim_requests: zero RLS
-- policies, zero direct grants to anon/authenticated. Every read and
-- write goes exclusively through the SECURITY DEFINER RPCs below.
revoke all on public.membership_invitations from anon, authenticated;

create table public.membership_invitation_roles (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null references public.membership_invitations (id) on delete cascade,
  role_id uuid not null references public.roles (id),
  unique (invitation_id, role_id)
);

comment on table public.membership_invitation_roles is
  'The exact role(s) selected at invitation-creation time, recorded '
  'server-side. Never overwritten on acceptance — acceptance reads '
  'and assigns exactly these rows, never client-supplied role input. '
  'Immutable historical evidence of what was actually offered.';

create index membership_invitation_roles_invitation_idx
  on public.membership_invitation_roles (invitation_id);

alter table public.membership_invitation_roles enable row level security;

revoke all on public.membership_invitation_roles from anon, authenticated;

-- =========================================================================
-- C. member.invite — a dedicated permission, mirroring
-- member.claim.approve's own precedent: inviting someone grants real
-- authenticated account access (plus roles) once accepted, a
-- materially more sensitive action than an ordinary member.create/
-- member.edit record change, so it is not folded into either.
--
-- Granted to ADMIN, CHAIRPERSON, AND SECRETARY — wider than
-- member.claim.approve's ADMIN/CHAIRPERSON-only boundary. This is a
-- deliberate product decision, not an oversight: the flow this prompt
-- describes explicitly names "Officer/Admin/Secretary" as the actors
-- who initiate invitations, and SECRETARY already holds member.create
-- (the "register a member" half of this same job) today. TREASURER is
-- not granted, consistent with its existing minimal (group.view/
-- member.view-only) footprint.
-- =========================================================================
insert into public.permissions (code, name, description) values
  ('member.invite', 'Invite members', 'Create an invitation linking an authenticated account to a roster membership and assigning role(s).');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where r.code = 'ADMIN' and p.code = 'member.invite';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where r.code = 'CHAIRPERSON' and p.code = 'member.invite';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where r.code = 'SECRETARY' and p.code = 'member.invite';

-- =========================================================================
-- D. rpc_create_membership_invitation
-- =========================================================================
create or replace function public.rpc_create_membership_invitation(
  p_group_id uuid,
  p_membership_id uuid,
  p_role_codes text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_role_codes text[];
  v_role_code text;
  v_role_id uuid;
  v_role_ids uuid[] := '{}';
  v_invitation_id uuid;
  v_token text;
  v_token_hash text;
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

  if p_role_codes is null or cardinality(p_role_codes) = 0 then
    raise exception 'At least one role must be selected' using errcode = '22023';
  end if;

  -- Normalize/dedupe (defensive, mirrors group_code uppercase
  -- normalization precedent elsewhere in this codebase).
  select array_agg(distinct upper(btrim(code)))
  into v_role_codes
  from unnest(p_role_codes) as code;

  -- Resolve every code server-side; never trust a client-supplied
  -- role_id. Unknown code -> hard failure (mirrors
  -- rpc_assign_group_role's exact wording/errcode).
  foreach v_role_code in array v_role_codes loop
    select id into v_role_id from public.roles where code = v_role_code;
    if v_role_id is null then
      raise exception 'Unknown role code: %', v_role_code using errcode = '22023';
    end if;
    v_role_ids := v_role_ids || v_role_id;
  end loop;

  -- Privilege-escalation guard: identical boundary to
  -- rpc_assign_group_role — only an existing ADMIN may invite someone
  -- AS ADMIN.
  if 'ADMIN' = any(v_role_codes) and not public.has_group_role(p_group_id, 'ADMIN') then
    raise exception 'Only an existing ADMIN may invite a member with the ADMIN role' using errcode = '42501';
  end if;

  -- Lock the target membership row for the duration of the
  -- eligibility check — serializes concurrent invitation-creation
  -- attempts against the same membership, same discipline as
  -- rpc_request_membership_claim.
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

  if exists (
    select 1 from public.membership_invitations
    where membership_id = p_membership_id and status = 'PENDING'
  ) then
    raise exception 'MEMBERSHIP_INVITATION_ALREADY_PENDING' using errcode = 'P0001';
  end if;

  -- Cryptographically strong, unguessable bearer token: 32 random
  -- bytes (256 bits) from pgcrypto, hex-encoded for URL/UI safety.
  -- Only its sha256 hash is ever persisted.
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  v_token_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');
  v_expires_at := now() + interval '7 days';

  insert into public.membership_invitations (
    group_id, membership_id, token_hash, expires_at, created_by
  )
  values (
    p_group_id, p_membership_id, v_token_hash, v_expires_at, v_uid
  )
  returning id into v_invitation_id;

  insert into public.membership_invitation_roles (invitation_id, role_id)
  select v_invitation_id, unnest(v_role_ids);

  select jsonb_build_object(
    'invitation_id', mi.id,
    'group_id', mi.group_id,
    'membership_id', mi.membership_id,
    'status', mi.status,
    'created_at', mi.created_at,
    'expires_at', mi.expires_at,
    'roles', (
      select coalesce(jsonb_agg(distinct r.code), '[]'::jsonb)
      from public.membership_invitation_roles mir
      join public.roles r on r.id = mir.role_id
      where mir.invitation_id = mi.id
    ),
    'token', v_token
  )
  into v_result
  from public.membership_invitations mi
  where mi.id = v_invitation_id;

  return v_result;
end;
$$;

comment on function public.rpc_create_membership_invitation(uuid, uuid, text[]) is
  'Creates a PENDING invitation for an ACTIVE, currently-unlinked '
  'membership in an ACTIVE group, assigning the given role codes '
  '(resolved server-side, never a client-supplied role_id). Returns '
  'the plaintext bearer token exactly once — only its sha256 hash is '
  'ever stored. Requires member.invite; inviting with the ADMIN role '
  'additionally requires the caller to already hold ADMIN. Rejected '
  'while a PENDING invitation already exists for the same membership.';

revoke all on function public.rpc_create_membership_invitation(uuid, uuid, text[]) from public;
grant execute on function public.rpc_create_membership_invitation(uuid, uuid, text[]) to authenticated;
revoke execute on function public.rpc_create_membership_invitation(uuid, uuid, text[]) from anon;

-- =========================================================================
-- E. rpc_preview_membership_invitation — safe, read-only, anti-
-- enumeration preview for the invited member, BEFORE acceptance.
--
-- Authenticated-only (not anon): consistent with every other function
-- in this codebase (see docs/database/authorization.md's "note on
-- EXECUTE grants and anon") and with rpc_request_membership_claim_by_
-- reference's own precedent of requiring sign-in first. This
-- deliberately defers "show the invite before sign-up" UX polish to a
-- later Flutter phase (out of scope here) rather than introducing this
-- codebase's first-ever anon-reachable RPC.
--
-- Anti-enumeration model: an UNKNOWN token hash (never existed, or a
-- garbage/malformed guess) collapses into ONE generic
-- MEMBERSHIP_INVITATION_NOT_FOUND failure — the brute-force-resistant
-- boundary, since a 256-bit random token cannot be guessed and finding
-- no matching row proves nothing about whether any invitation like it
-- ever existed. Once a row IS found (which requires already possessing
-- the exact secret token — not guessable), distinguishing its status
-- (PENDING/EXPIRED/CANCELLED/ACCEPTED) leaks nothing further and is a
-- genuine, compelling UX necessity (a real invitation flow must be able
-- to tell an invitee "this has expired, ask your officer to resend" —
-- see Section E's own "compelling UX-safe distinction" escape clause).
-- Causes zero mutation, including no lazy status write-back — see this
-- migration's header for why lazy EXPIRED normalization was
-- deliberately not implemented anywhere.
-- =========================================================================
create or replace function public.rpc_preview_membership_invitation(
  p_token text
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_token_hash text;
  v_invitation record;
  v_effective_status text;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if p_token is null or btrim(p_token) = '' then
    raise exception 'MEMBERSHIP_INVITATION_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_token_hash := encode(extensions.digest(btrim(p_token), 'sha256'), 'hex');

  select mi.id, mi.status, mi.expires_at, mi.group_id, mi.membership_id
  into v_invitation
  from public.membership_invitations mi
  where mi.token_hash = v_token_hash;

  if v_invitation.id is null then
    raise exception 'MEMBERSHIP_INVITATION_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_effective_status := case
    when v_invitation.status = 'PENDING' and v_invitation.expires_at <= now() then 'EXPIRED'
    else v_invitation.status::text
  end;

  select jsonb_build_object(
    'status', v_effective_status,
    'expires_at', v_invitation.expires_at,
    'group_name', g.name,
    'membership_display_name', gm.display_name,
    'membership_member_number', gm.member_number,
    'roles', (
      select coalesce(jsonb_agg(distinct r.name), '[]'::jsonb)
      from public.membership_invitation_roles mir
      join public.roles r on r.id = mir.role_id
      where mir.invitation_id = v_invitation.id
    )
  )
  into v_result
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = v_invitation.membership_id;

  return v_result;
end;
$$;

comment on function public.rpc_preview_membership_invitation(text) is
  'Safe, read-only, zero-mutation preview of an invitation by bearer '
  'token, for confirmation before acceptance. An unknown/malformed '
  'token collapses into the single generic '
  'MEMBERSHIP_INVITATION_NOT_FOUND failure; a found invitation reports '
  'its effective status (PENDING/EXPIRED/ACCEPTED/CANCELLED, computing '
  'expiry live without writing it back) plus group/member display '
  'context and invited role display names. Never returns internal '
  'ids, the token hash, other members, or inviter-sensitive metadata.';

revoke all on function public.rpc_preview_membership_invitation(text) from public;
grant execute on function public.rpc_preview_membership_invitation(text) to authenticated;
revoke execute on function public.rpc_preview_membership_invitation(text) from anon;

-- =========================================================================
-- F. rpc_accept_membership_invitation
-- =========================================================================
create or replace function public.rpc_accept_membership_invitation(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_token_hash text;
  v_invitation record;
  v_membership record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if p_token is null or btrim(p_token) = '' then
    raise exception 'MEMBERSHIP_INVITATION_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_token_hash := encode(extensions.digest(btrim(p_token), 'sha256'), 'hex');

  -- Lock the invitation row itself first: two simultaneous accepts on
  -- the exact same token serialize here — the second blocks until the
  -- first transaction commits/rolls back, then re-reads the
  -- now-current (already ACCEPTED) row rather than racing on a stale
  -- read, exactly like rpc_approve_membership_claim's own claim lock.
  select mi.id, mi.status, mi.expires_at, mi.group_id, mi.membership_id, mi.accepted_by
  into v_invitation
  from public.membership_invitations mi
  where mi.token_hash = v_token_hash
  for update of mi;

  if v_invitation.id is null then
    raise exception 'MEMBERSHIP_INVITATION_NOT_FOUND' using errcode = 'P0001';
  end if;

  -- Idempotent retry after success: the SAME accepting user retrying
  -- an invitation they already successfully accepted gets the same
  -- success payload again, never an error and never a second mutation
  -- attempt. Mirrors rpc_request_membership_claim's own
  -- already-requested idempotency idiom.
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

  -- Expiry is enforced from expires_at directly, independent of the
  -- stored status column (see this migration's header for why no
  -- lazy EXPIRED write-back is implemented) — an invitation whose
  -- expires_at has passed is rejected even though its stored status
  -- still says PENDING.
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

  -- Re-check every eligibility condition against the CURRENT,
  -- now-locked row — never trust the state as it was when the
  -- invitation was created. Covers: someone else linked it since
  -- (via claim approval or a race), or the membership/group became
  -- non-operational since.
  if v_membership.user_id is not null then
    raise exception 'MEMBERSHIP_ALREADY_LINKED' using errcode = 'P0001';
  end if;

  if v_membership.membership_status <> 'ACTIVE' then
    raise exception 'MEMBERSHIP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if v_membership.group_status <> 'ACTIVE' then
    raise exception 'GROUP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  -- Mirrors group_memberships_user_active_unique / the identical
  -- guard in rpc_approve_membership_claim: the accepting user must
  -- not end up with two ACTIVE memberships in the same group.
  if exists (
    select 1 from public.group_memberships
    where group_id = v_invitation.group_id and user_id = v_uid and status = 'ACTIVE'
  ) then
    raise exception 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP' using errcode = 'P0001';
  end if;

  perform set_config('umoja.membership_invitation_acceptance', 'true', true);

  update public.group_memberships
  set user_id = v_uid
  where id = v_invitation.membership_id;

  -- Assign exactly the server-recorded roles from creation time —
  -- never client-supplied at acceptance. Idempotent (on conflict do
  -- nothing), matching rpc_assign_group_role's own pattern; harmless
  -- even on the idempotent-retry path above, which returns earlier
  -- and never reaches here a second time regardless.
  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  select v_invitation.membership_id, mir.role_id, v_uid
  from public.membership_invitation_roles mir
  where mir.invitation_id = v_invitation.id
  on conflict (group_membership_id, role_id) do nothing;

  update public.membership_invitations
  set status = 'ACCEPTED', accepted_at = now(), accepted_by = v_uid
  where id = v_invitation.id;

  -- Claim/invitation conflict resolution (Section F): once this
  -- membership is linked, no other pending mechanism may link it to a
  -- different account. rpc_approve_membership_claim's own re-check
  -- already makes that deterministic/safe on its own (it re-validates
  -- user_id IS NULL against the locked row), but a competing PENDING
  -- claim on the same membership is now permanently unapprovable —
  -- auto-cancelling it keeps the claimant's/officer's own queues
  -- accurate instead of showing a claim that can never succeed.
  -- Historical rows are never deleted, only status-transitioned.
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

comment on function public.rpc_accept_membership_invitation(text) is
  'Accepts a PENDING, non-expired invitation by bearer token: '
  're-validates every eligibility condition against the locked, '
  'current membership row, then atomically links '
  'group_memberships.user_id = auth.uid(), assigns exactly the '
  'server-recorded roles, marks the invitation ACCEPTED, and '
  'auto-cancels any competing PENDING claim on the same membership — '
  'all in one transaction; if any part fails, none of it happens. '
  'Idempotent for a retry by the SAME already-accepted user. Never '
  'accepts membership_id, group_id, a user id, or role ids from the '
  'client — the token alone resolves all invitation authority.';

revoke all on function public.rpc_accept_membership_invitation(text) from public;
grant execute on function public.rpc_accept_membership_invitation(text) to authenticated;
revoke execute on function public.rpc_accept_membership_invitation(text) from anon;

-- =========================================================================
-- G. rpc_cancel_membership_invitation — officer cancellation of a
-- still-PENDING invitation. No role/link mutation of any kind.
-- =========================================================================
create or replace function public.rpc_cancel_membership_invitation(
  p_group_id uuid,
  p_invitation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_invitation record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.invite') then
    raise exception 'Not authorized to cancel invitations in this group' using errcode = '42501';
  end if;

  select id, group_id, status into v_invitation
  from public.membership_invitations
  where id = p_invitation_id
  for update;

  if v_invitation.id is null or v_invitation.group_id <> p_group_id then
    raise exception 'Membership invitation not found in group' using errcode = '22023';
  end if;

  if v_invitation.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_INVITATION_NOT_PENDING' using errcode = 'P0001';
  end if;

  update public.membership_invitations
  set status = 'CANCELLED', cancelled_at = now(), cancelled_by = v_uid
  where id = p_invitation_id;

  select jsonb_build_object(
    'invitation_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'status', status, 'cancelled_at', cancelled_at, 'cancelled_by', cancelled_by
  )
  into v_result
  from public.membership_invitations
  where id = p_invitation_id;

  return v_result;
end;
$$;

comment on function public.rpc_cancel_membership_invitation(uuid, uuid) is
  'Cancels a still-PENDING invitation. Requires member.invite. Cannot '
  'cancel an ACCEPTED invitation, and cannot resurrect one already '
  'CANCELLED. Never touches group_memberships or '
  'group_membership_roles.';

revoke all on function public.rpc_cancel_membership_invitation(uuid, uuid) from public;
grant execute on function public.rpc_cancel_membership_invitation(uuid, uuid) to authenticated;
revoke execute on function public.rpc_cancel_membership_invitation(uuid, uuid) from anon;

-- =========================================================================
-- H. rpc_list_membership_invitations — group-scoped, member.invite-
-- gated officer queue/history.
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
    'cancelled_by_full_name', canceller.full_name
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
  'Group-scoped, member.invite-gated officer queue/history. '
  'is_expired is computed live (PENDING and past expires_at), never '
  'written back — see this migration''s header for why no lazy '
  'EXPIRED status normalization is implemented. Never exposes the '
  'token or its hash.';

revoke all on function public.rpc_list_membership_invitations(uuid, public.membership_invitation_status, integer, integer) from public;
grant execute on function public.rpc_list_membership_invitations(uuid, public.membership_invitation_status, integer, integer) to authenticated;
revoke execute on function public.rpc_list_membership_invitations(uuid, public.membership_invitation_status, integer, integer) from anon;

-- =========================================================================
-- I. rpc_approve_membership_claim — redefined ONLY to add the
-- symmetric conflict-resolution side effect (Section F): once a claim
-- approval links a membership, any competing PENDING invitation on
-- the same membership is now permanently unacceptable (accept already
-- re-checks user_id IS NULL against the locked row and would reject
-- it deterministically on its own), so it is auto-cancelled here for
-- the same officer/claimant queue-accuracy reason. Every existing
-- parameter, return shape, and error code from 20260921091000 is
-- otherwise byte-for-byte unchanged — verified by the full pre-
-- existing 102_membership_claim_workflow.test.sql suite passing as-is
-- after this redefinition.
-- =========================================================================
create or replace function public.rpc_approve_membership_claim(
  p_group_id uuid,
  p_claim_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_claim record;
  v_membership record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.claim.approve') then
    raise exception 'Not authorized to approve membership claims in this group' using errcode = '42501';
  end if;

  select id, group_id, membership_id, claimant_user_id, status
  into v_claim
  from public.membership_claim_requests
  where id = p_claim_id
  for update;

  if v_claim.id is null or v_claim.group_id <> p_group_id then
    raise exception 'Membership claim not found in group' using errcode = '22023';
  end if;

  if v_claim.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_CLAIM_NOT_PENDING' using errcode = 'P0001';
  end if;

  select gm.id, gm.group_id, gm.user_id, gm.status as membership_status, g.status as group_status
  into v_membership
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = v_claim.membership_id
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

  if exists (
    select 1 from public.group_memberships
    where group_id = p_group_id and user_id = v_claim.claimant_user_id and status = 'ACTIVE'
  ) then
    raise exception 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP' using errcode = 'P0001';
  end if;

  perform set_config('umoja.membership_claim_approval', 'true', true);

  update public.group_memberships
  set user_id = v_claim.claimant_user_id
  where id = v_claim.membership_id;

  update public.membership_claim_requests
  set status = 'APPROVED', resolved_at = now(), resolved_by = v_uid
  where id = p_claim_id;

  -- Symmetric conflict resolution — see this section's own header.
  update public.membership_invitations
  set status = 'CANCELLED', cancelled_at = now(), cancelled_by = v_uid
  where membership_id = v_claim.membership_id and status = 'PENDING';

  select jsonb_build_object(
    'claim_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'claimant_user_id', claimant_user_id, 'status', status,
    'resolved_at', resolved_at, 'resolved_by', resolved_by
  )
  into v_result
  from public.membership_claim_requests
  where id = p_claim_id;

  return v_result;
end;
$$;

comment on function public.rpc_approve_membership_claim(uuid, uuid) is
  'Approves a PENDING membership claim: re-validates every eligibility '
  'condition against the locked, current row state, then atomically '
  'links group_memberships.user_id = claimant AND marks the claim '
  'APPROVED in the same transaction, auto-cancelling any competing '
  'PENDING invitation on the same membership. Requires '
  'member.claim.approve.';

-- Grants unchanged by CREATE OR REPLACE (same signature): already
-- REVOKE ALL FROM PUBLIC, GRANT EXECUTE TO authenticated, REVOKE
-- EXECUTE FROM anon, from 20260921091000.
