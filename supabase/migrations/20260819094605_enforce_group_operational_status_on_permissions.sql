-- Prompt 03A: backend operational group/membership authorization
-- hardening.
--
-- Prompt 03 added Flutter-side eligibility filtering (only an ACTIVE
-- membership in an ACTIVE group is a normal operational context), but
-- the implementation report explicitly flagged that group.status was
-- NOT enforced by has_group_permission() or any backend check — a
-- modified/malicious client could still call protected mutation RPCs
-- directly against a SUSPENDED or CLOSED group. Flutter routing is UX
-- only; this closes that gap in the database.
--
-- Semantic distinction preserved (see docs/database/authorization.md):
-- is_group_member() stays a *relationship/read* predicate (does this
-- profile have an ACTIVE membership row, regardless of the group's own
-- status?) — it is unchanged, because it backs the `groups` RLS SELECT
-- policy and a SUSPENDED/CLOSED group must remain readable so Flutter
-- can render the correct restricted screen and rpc_get_my_context()
-- keeps working. has_group_permission() is the *operational* gate used
-- by every mutation RPC, and is the one tightened here.

-- ---------------------------------------------------------------------
-- has_group_permission(): now additionally requires the target group's
-- own status to be ACTIVE. Combined with the existing
-- caller_profile_is_active() and gm.status = 'ACTIVE' conditions, this
-- makes the full operational invariant:
--
--   authenticated AND profile.is_active AND membership.status = 'ACTIVE'
--   AND group.status = 'ACTIVE' AND permission granted
--
-- a single centralized check. Every existing mutation RPC
-- (rpc_create_group_member, rpc_update_group_member,
-- rpc_change_group_member_status, rpc_assign_group_role,
-- rpc_remove_group_role, and the group.manage-gated group update path)
-- already gates on has_group_permission(), so this one change cascades
-- to all of them without needing to duplicate status checks in each
-- function body. No new helper function/RPC signature is introduced —
-- see docs/database/authorization.md for why a separate
-- has_operational_group_access() was judged unnecessary here.
--
-- is_group_role(), get_my_membership(), and
-- assert_last_active_admin_remains() are intentionally left
-- unchanged: has_group_role()/assert_last_active_admin_remains() are
-- only ever consulted *after* a has_group_permission() check has
-- already gated the caller as operational in the current RPCs, and
-- the last-active-ADMIN continuity invariant they protect is a
-- structural property of the group's admin roster, not itself gated
-- by the group's current operational status — see Prompt 02A/02B,
-- which this migration must not weaken.
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
    join public.groups g on g.id = gm.group_id
    join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
    join public.role_permissions rp on rp.role_id = gmr.role_id
    join public.permissions p on p.id = rp.permission_id
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'ACTIVE'
      and g.status = 'ACTIVE'
      and p.code = p_permission_code
  );
$$;

comment on function public.has_group_permission(uuid, text) is
  'Whether the caller (auth.uid()) holds the given permission code AND '
  'is currently operational in the group: active profile, ACTIVE '
  'membership, ACTIVE group. Returns false (never raises) for '
  'inactive/missing profile, non-ACTIVE membership, non-ACTIVE group, '
  'or a missing/unassigned permission — it does not distinguish which '
  'reason to the caller. This is the operational gate for every '
  'mutation RPC; is_group_member() remains a relationship/read '
  'predicate unaffected by group status.';

-- Grants unchanged by CREATE OR REPLACE (same signature): already
-- REVOKE ALL FROM PUBLIC, REVOKE EXECUTE FROM anon, GRANT EXECUTE TO
-- authenticated only, from prior migrations.

-- ---------------------------------------------------------------------
-- groups.status direct-update protection.
--
-- Prompt 02A's column-level grant left `status` (and
-- `accounting_cutover_date`) directly editable by any group.manage
-- holder. Two problems: (1) an ADMIN could toggle group lifecycle
-- status with no controlled workflow, and (2) now that operational
-- checks require group.status = 'ACTIVE', an ADMIN could otherwise
-- suspend/close their own group and have no way back without direct
-- database access. No group lifecycle (suspend/close/reactivate) RPC
-- exists yet — that is deferred to a future explicit workflow — so for
-- now `status` is removed from the ordinary client-editable column
-- set entirely. `accounting_cutover_date` is removed too: it is
-- accounting-relevant and no accounting behavior has been designed
-- yet to interpret it safely (see docs/accounting/invariants.md);
-- editing it prematurely is out of scope rather than "safe metadata".
-- Both remain admin/platform-settable directly against the database
-- (e.g. for test/ops fixtures) — only the authenticated-role grant is
-- narrowed.
revoke update on public.groups from authenticated;
grant update (name, code, description, currency, timezone) on public.groups to authenticated;
