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

## Flutter never decides authorization alone

Flutter reads roles/permissions returned by `rpc_get_my_context()` to
decide what UI to show (e.g. hide a "create member" button for a plain
MEMBER), but that is a UX convenience, not the security boundary. The
actual enforcement is RLS policies and the permission checks inside
`SECURITY DEFINER` functions — a client that ignored the UI and sent a
raw request would still be blocked at the database. Flutter must not
introduce a parallel, client-only authorization model.
