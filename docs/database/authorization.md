# Authorization

This document describes how identity, tenancy, and authorization work
for the tables/functions introduced for the identity + group tenancy
foundation. It does not cover any business/financial module.

## Identity chain

```
auth.users
    ↓
profiles
    ↓
group_memberships
    ↓
groups
```

- `auth.users` is Supabase Auth's own table. `auth.uid()` — resolved
  from the caller's JWT by PostgREST/Postgres — is the only source of
  identity every policy and function in this schema trusts. Nothing
  ever accepts a client-supplied `user_id` as authorization input.
- `public.profiles` is 1:1 with `auth.users` (`profiles.id =
  auth.users.id`), created automatically by an `AFTER INSERT ON
  auth.users` trigger. It holds application-facing metadata only, never
  authentication secrets.
- `public.group_memberships` links a person to a group. `user_id` is
  nullable — see
  [docs/product/member-identity-model.md](../product/member-identity-model.md)
  for why. A user's access to a group is always mediated through their
  own `group_memberships` row(s), never through a field stored directly
  on `auth.users` or `profiles` — a user may belong to more than one
  group.
- `public.groups` is the tenant. There is no direct
  `auth.users → groups` relationship.

## Roles and permissions

- `public.roles`: system-defined roles (`MEMBER`, `TREASURER`,
  `SECRETARY`, `CHAIRPERSON`, `ADMIN`), seeded by migration.
- `public.permissions`: fine-grained capabilities (e.g. `member.create`,
  `role.assign`), seeded by migration.
- `public.role_permissions`: data-driven mapping of which permissions
  each role grants. Changing what a role can do is a data change, not a
  schema/policy change.
- `public.group_membership_roles`: which role(s) a specific membership
  holds. A membership may hold more than one role.

A user's effective permissions in a group are the union of the
permissions granted by every role assigned to their ACTIVE membership
in that group.

## Row Level Security (RLS)

RLS is enabled on every table above. Policies are written to be
tenant-safe:

- No policy on a tenant-owned table uses `USING (true)`.
- `roles`/`permissions`/`role_permissions` are **not** tenant-owned
  (they are system-wide reference data), so a read-only
  `USING (true)` policy restricted `TO authenticated` is used there —
  this is intentional, not an oversight. There are no
  insert/update/delete policies on those three tables: ordinary users
  can never mutate role/permission definitions, only migrations can.
- `group_membership_roles` is tenant-scoped indirectly, through the
  `group_memberships` row it points at; its policies join through that
  table rather than trusting a `group_id` on itself.

Table-level `GRANT`s are also set explicitly and narrowly (e.g.
`profiles` has no `INSERT`/`DELETE` grant for `authenticated` at all —
profile rows are only ever created by the signup trigger) rather than
relying on default privileges, so RLS is a second layer of defense, not
the only one.

## SECURITY DEFINER functions

`is_group_member`, `get_my_membership`, `has_group_permission`, and the
`rpc_*` functions are `SECURITY DEFINER`. This is deliberate, not an
oversight to be "fixed" later:

- The three helper functions are called **from inside RLS policies**
  on `groups`/`group_memberships`/`group_membership_roles`. If they
  were `SECURITY INVOKER`, evaluating their internal query against
  `group_memberships` would re-trigger that table's own RLS policies,
  which can recurse or silently return incomplete results. Running them
  as the definer (bypassing RLS for their own internal lookup) avoids
  that trap.
- Every one of these functions is hard-scoped to `auth.uid()` inside
  the function body — never to a parameter. That is what keeps a
  `SECURITY DEFINER` function safe: it cannot be asked to check or act
  on someone else's identity.
- Each function sets an explicit `search_path` (`public, pg_temp`) to
  prevent search-path hijacking, uses fully-qualified table names, and
  has `EXECUTE` revoked from `PUBLIC` and granted only to
  `authenticated`.
- `rpc_create_group` and `rpc_create_group_member` additionally need
  `SECURITY DEFINER` because they perform multi-table writes (group +
  membership + role assignment; a new member row) that must happen
  atomically as one controlled command — see
  [docs/database/conventions.md](conventions.md) on controlled
  transactional commands. Flutter must never perform these as separate
  client-side inserts.

## Tenant isolation

A request is scoped to a group only through an explicit, checked
membership row:

- `is_group_member(group_id)` / `has_group_permission(group_id, code)`
  both require `group_memberships.user_id = auth.uid() AND status =
  'ACTIVE' AND group_memberships.group_id = <the group in question>`.
  There is no way to pass a group_id you don't have a membership in and
  get a `true` result.
- `rpc_get_my_context()` takes **no parameters** — it cannot be pointed
  at another user's id. It returns every membership for the caller
  across all their groups.
- `rpc_create_group_member` and any future permission-gated write
  re-check `has_group_permission(p_group_id, ...)` inside the function
  body — it is not enough that the caller is authenticated, they must
  hold the permission in the specific target group.

## Inactive-profile enforcement

`profiles.is_active = false` must not retain effective group mutation
privileges through an existing (still-valid) Supabase session — see
[docs/product/authentication.md](../product/authentication.md) for the
Flutter-side "account disabled" UX this backs. Enforced by migration
`20260819085905_enforce_active_profile_on_mutations.sql`:

- `is_group_member()` and `has_group_permission()` now also require
  `caller_profile_is_active()` (a small internal helper: a missing
  profile is treated as inactive, failing closed). Because these two
  functions are the permission gate inside every member/role RPC
  (`rpc_create_group_member`, `rpc_update_group_member`,
  `rpc_change_group_member_status`, `rpc_assign_group_role`,
  `rpc_remove_group_role`) *and* the predicate behind the
  `groups`/`group_memberships`/`group_membership_roles` RLS `SELECT`
  policies, an inactive profile loses both effective permission and
  read visibility everywhere these are used — one change, one place.
- `rpc_create_group()` has no other permission gate (any authenticated
  user may create a group), so it — and every other mutation RPC —
  additionally calls `assert_active_profile()` immediately after its
  "not authenticated" check, raising `ACCOUNT_DISABLED` (`P0001`)
  explicitly. This is a deliberate second layer: `has_group_permission`
  cascading covers the permission-gated RPCs already, but
  `assert_active_profile()` gives every mutation RPC (including
  `rpc_create_group`, which nothing else gates) the same explicit,
  stable error, and keeps the rule from depending on remembering to
  wire each new RPC through `has_group_permission`.
- `rpc_get_my_context()` deliberately does **not** call
  `assert_active_profile()` — it must always succeed for an
  authenticated user so Flutter can *discover* `profile.is_active =
  false` and route to `/access/account-disabled` in the first place.
- `caller_profile_is_active()` and `assert_active_profile()` are
  internal-only: `EXECUTE` is revoked from `public`, `anon`, **and**
  `authenticated` — they are reachable only as nested calls from other
  `SECURITY DEFINER` functions (which run as the function owner
  regardless of the original caller's grants), never directly by a
  client. See "Internal helper functions should expose the minimum
  required surface" below.
- Group-level status (`groups.status` SUSPENDED/CLOSED) was **not**
  wired into `has_group_permission()` as of this migration — that was a
  real gap, closed by Prompt 03A below.

## Operational group-status enforcement (Prompt 03A)

Prompt 03 added Flutter-side eligibility filtering (only an ACTIVE
membership in an ACTIVE group is a normal operational context), but
left the backend gap noted above: `has_group_permission()` did not
check `groups.status`, so a modified/malicious client could still call
protected mutation RPCs directly against a SUSPENDED or CLOSED group.
Fixed in migration
`20260819094605_enforce_group_operational_status_on_permissions.sql`:

- `has_group_permission(group_id, permission_code)` now additionally
  requires `groups.status = 'ACTIVE'` for the target group, alongside
  the existing `caller_profile_is_active()` and `membership.status =
  'ACTIVE'` conditions. The full operational invariant it now expresses
  in one place: `authenticated AND profile.is_active AND
  membership.status = 'ACTIVE' AND group.status = 'ACTIVE' AND
  permission granted`. Because every mutation RPC already gates on this
  one function, the fix cascades to all of them (including the
  `group.manage`-gated group-metadata update path) without touching
  each RPC body individually.
- **Deliberate semantic split**: `is_group_member()` is unchanged and
  remains a *relationship/read* predicate — "does this profile have an
  ACTIVE membership row?", independent of the group's own status. It
  backs the `groups` RLS `SELECT` policy, and a SUSPENDED/CLOSED group
  must stay readable so `rpc_get_my_context()` keeps working and
  Flutter can render the correct restricted screen.
  `has_group_permission()` is the *operational* gate, and is the one
  that was tightened. Do not read this asymmetry as an oversight — it
  is what keeps historical/restricted context inspectable while still
  blocking operational mutations, per the "don't erase historical rows
  just because they're not operational" principle.
- `has_group_role()`, `get_my_membership()`, and
  `assert_last_active_admin_remains()` were deliberately left
  unchanged: the first two are only ever consulted after a
  `has_group_permission()` check has already gated the caller as
  operational in every current RPC, and the last-active-ADMIN
  continuity invariant is a structural property of the group's admin
  roster, not itself conditioned on the group's current operational
  status — changing it would have weakened Prompt 02A/02B.
- No separate `has_operational_group_access()` function was
  introduced; folding the rule into the existing single choke-point
  (`has_group_permission()`) was judged simpler and less
  duplication-prone than adding a second helper every RPC would also
  need to remember to call.
- `groups.status` (and `accounting_cutover_date`, which is
  accounting-relevant and has no designed behavior yet) were removed
  from the authenticated-role column-level `UPDATE` grant on
  `public.groups` — an ADMIN could otherwise flip a group's own
  lifecycle status with no controlled reactivation workflow to reverse
  it, especially now that group.status gates operational access. Group
  lifecycle (suspend/close/reactivate) remains an explicit future
  workflow, not a plain column edit.
- Error contract: mutation RPCs keep their existing generic
  `42501`/"Not authorized..." message regardless of *why*
  `has_group_permission()` returned false (missing permission, inactive
  profile, non-ACTIVE membership, or non-ACTIVE group) — this was a
  deliberate choice (permitted explicitly by the Prompt 03A brief:
  "simply PERMISSION_DENIED if centralized permission checking
  naturally produces that result") rather than inventing distinct
  `GROUP_NOT_OPERATIONAL`/`MEMBERSHIP_NOT_ACTIVE` codes, so the error
  itself does not leak *which* condition failed to an unauthorized
  caller.

## A note on `EXECUTE` grants and `anon`

`REVOKE ALL ... FROM PUBLIC` does **not** revoke `anon`'s `EXECUTE`
privilege — Supabase's own bootstrap sets `ALTER DEFAULT PRIVILEGES ...
GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role`, which
grants `anon` `EXECUTE` on every newly created function independently of
`PUBLIC`. This was a real gap found during a Prompt 02A review (every
function was reachable by an unauthenticated `anon`-key client, though
still safely rejected internally by the `auth.uid() IS NULL` check) and
fixed by explicit `REVOKE EXECUTE ... FROM anon` statements — see
migration `20260819083819_revoke_anon_execute_on_functions.sql`. Every
function added since explicitly revokes from `anon` as well as `public`,
not just `public`.

## Flutter never decides authorization alone

Flutter reads roles/permissions returned by `rpc_get_my_context()` to
decide what UI to show (e.g. hide a "create member" button for a plain
MEMBER), but that is a UX convenience, not the security boundary. The
actual enforcement is RLS policies and the permission checks inside
`SECURITY DEFINER` functions — a client that ignored the UI and sent a
raw request would still be blocked at the database. Flutter must not
introduce a parallel, client-only authorization model.
