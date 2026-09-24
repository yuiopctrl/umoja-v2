-- Prompt 09G-B1-A: Member Self-Service — canonical ownership/
-- authorization foundation.
--
-- Locked identity model (09G-B-01 architecture audit; see
-- docs/product/member-identity-model.md): the self-service ownership
-- unit is ONE group_memberships row (its `id`), never auth.users.id
-- directly, never a role, never phone/member_number/display_name.
-- Ownership is a RELATIONSHIP FACT
-- (group_memberships.user_id = auth.uid() for that specific
-- membership), completely independent of whatever administrative
-- roles/permissions that same membership may also hold — an
-- ADMIN/TREASURER can simultaneously own their own membership.
--
-- These three helpers are pure infrastructure. Nothing in this
-- migration changes the authorization of any existing RPC — a plain
-- MEMBER gains no new data access from this migration alone; that is
-- deliberately deferred to later B4/B5/B6 prompts, each of which will
-- explicitly widen exactly one existing RPC's own authorization check
-- to `has_group_permission(...) OR is_own_membership(...)`.
--
-- current_membership_id() is intentionally NOT built on top of the
-- existing get_my_membership() (20260819080634_create_authorization_
-- functions.sql): that function predates the active-profile/group-
-- status hardening added later (20260819085905/20260819094605) and
-- was deliberately left unchanged by the project's own 20260819094605
-- migration for reasons unrelated to self-service (rpc_get_my_context()
-- and RLS SELECT policies still need its looser, group-status-agnostic
-- behavior — see that migration's own comment). Changing get_my_
-- membership()'s semantics now would be out of scope and risks
-- regressing those existing consumers. current_membership_id() is
-- therefore new, independent SQL that mirrors has_group_permission()'s
-- own full operational invariant (active profile AND ACTIVE membership
-- AND ACTIVE group) minus the permission join — i.e. "is this
-- membership currently a normal operational self-service context",
-- matching this project's own rule (CLAUDE.md) that only an ACTIVE
-- membership in an ACTIVE group is ever a normal selected-group
-- context. A membership belonging to a SUSPENDED/CLOSED group, or
-- itself SUSPENDED/EXITED, or belonging to a caller whose profile is
-- inactive, therefore never resolves as "current" here —
-- is_own_membership() inherits this for free by comparing against
-- current_membership_id(), never duplicating the gating logic.
--
-- Same SECURITY DEFINER / explicit search_path / EXECUTE-restricted-
-- to-authenticated discipline as get_my_membership/is_group_member/
-- has_group_permission (20260819080634_create_authorization_
-- functions.sql) — SECURITY DEFINER avoids RLS self-recursion when
-- used inside RLS policies or other SECURITY DEFINER RPCs; the
-- explicit search_path prevents search-path hijacking. Safe to expose
-- to `authenticated` directly (same reasoning as get_my_membership()
-- already being client-callable): current_membership_id() only ever
-- returns the CALLER's own id, never another member's; is_own_
-- membership() only ever returns a boolean for a caller-supplied pair,
-- disclosing nothing about whether the target id exists at all.

create or replace function public.current_membership_id(p_group_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select gm.id
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.group_id = p_group_id
    and gm.user_id = auth.uid()
    and gm.status = 'ACTIVE'
    and g.status = 'ACTIVE'
    and public.caller_profile_is_active()
  limit 1;
$$;

comment on function public.current_membership_id(uuid) is
  'The caller''s (auth.uid()) own membership_id in the given group, or '
  'NULL unless the caller currently has an ACTIVE membership in an '
  'ACTIVE group with an active profile — the same full operational '
  'invariant has_group_permission() enforces, minus the permission '
  'check. Never accepts a client-supplied user_id. At most one row can '
  'ever match (group_memberships_user_active_unique enforces at most '
  'one ACTIVE membership per (group, user)), so this can never '
  'ambiguously choose between duplicate/historical memberships.';

create or replace function public.is_own_membership(p_group_id uuid, p_membership_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select coalesce(
    p_membership_id is not null
      and p_membership_id = public.current_membership_id(p_group_id),
    false
  );
$$;

comment on function public.is_own_membership(uuid, uuid) is
  'Whether p_membership_id is EXACTLY the caller''s own current '
  'membership in p_group_id (see current_membership_id() for the '
  'operational gate this inherits). False for another member, another '
  'group, an unauthenticated caller, or a roster-only membership with '
  'no linked user_id — never inferred from phone or member_number, '
  'only from the group_memberships.user_id relationship.';

create or replace function public.assert_self_or_permission(
  p_group_id uuid,
  p_membership_id uuid,
  p_permission_code text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (
    public.is_own_membership(p_group_id, p_membership_id)
    or public.has_group_permission(p_group_id, p_permission_code)
  ) then
    raise exception 'Not authorized for this membership in this group' using errcode = '42501';
  end if;
end;
$$;

comment on function public.assert_self_or_permission(uuid, uuid, text) is
  'Raises 42501 unless the caller either owns p_membership_id '
  '(is_own_membership) or holds p_permission_code administratively '
  '(has_group_permission) in p_group_id. Self-ownership is additive to '
  'administrative permission, never a replacement for it — an '
  'officer''s existing permission-gated access to another member''s '
  'data is completely unaffected. Intended to be called by future '
  'self-service-capable RPCs (09G-B4/B5/B6) as their sole authorization '
  'check, in place of a bare has_group_permission() call, wherever a '
  'resource is addressed by membership_id. Not yet called by any '
  'existing RPC as of this migration — see the 09G-B1-A prompt''s '
  'explicit scope boundary.';

revoke all on function public.current_membership_id(uuid) from public;
revoke all on function public.is_own_membership(uuid, uuid) from public;
revoke all on function public.assert_self_or_permission(uuid, uuid, text) from public;

grant execute on function public.current_membership_id(uuid) to authenticated;
grant execute on function public.is_own_membership(uuid, uuid) to authenticated;
grant execute on function public.assert_self_or_permission(uuid, uuid, text) to authenticated;
