# Architecture

## Data flow

```
Flutter
    ↓
Supabase API/Auth
    ↓
PostgreSQL
    ↓
Controlled financial commands / RPCs
    ↓
Authoritative ledgers
```

One Flutter codebase (`app/`) is the client for every platform: Android,
iOS, Web, Linux, Windows, macOS. Supabase (PostgreSQL + Auth + API) is the
backend. There is no separate web frontend, mobile app, or desktop
frontend stack — see
[docs/decisions/0001-single-flutter-codebase.md](../decisions/0001-single-flutter-codebase.md).

## Responsibility split

### Flutter (`app/`)

- Presentation and layout, responsive across form factors
- User interaction
- Input validation for UX (not authoritative validation)
- Invoking Supabase APIs / RPCs
- Displaying server-derived financial state

### Backend / PostgreSQL (`supabase/`)

- Authoritative validation
- Money calculations
- Accounting rules and invariants (see
  [docs/accounting/invariants.md](../accounting/invariants.md))
- Payment/contribution allocation
- Transaction posting
- Concurrency control
- Idempotency of financial commands
- Ledger consistency and auditability

Flutter never computes authoritative financial balances itself, and never
mutates posted financial records directly — it always goes through
controlled backend commands. See
[docs/database/conventions.md](../database/conventions.md) for the
concrete rules this implies for schema and query design.

## Identity and group tenancy

Umoja is multi-group: a single authenticated user may belong to more
than one group (vikundi) over time. Tenancy is therefore never a
permanent field on the auth user — it is resolved through membership:

```
auth.users
    ↓
profiles
    ↓
group_memberships
    ↓
groups
```

- `auth.users` (Supabase Auth) is the authenticated identity;
  `auth.uid()` is the only identity every backend check trusts.
- `public.profiles` is 1:1 application-facing metadata for that user.
- `public.group_memberships` is how a person relates to a group. Its
  `user_id` is nullable — a group member can exist before they ever
  have (or without ever having) an app account. See
  [docs/product/member-identity-model.md](member-identity-model.md).
- `public.groups` is the tenant.

Role/permission resolution: a membership is assigned one or more
`public.roles` (via `public.group_membership_roles`); each role grants
a set of `public.permissions` (via `public.role_permissions`). A user's
effective permissions in a group are the union of their assigned
roles' permissions. See
[docs/database/authorization.md](../database/authorization.md) for how
this is enforced (RLS, `SECURITY DEFINER` helper functions,
`rpc_get_my_context()`).

Flutter fetches this whole shape in one call
(`rpc_get_my_context()`) and never asks the backend to trust a
client-supplied user id or group id for authorization decisions.
