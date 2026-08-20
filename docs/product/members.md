# Members Management

This document describes the Members Management module: viewing,
searching, creating, editing group members, changing their status, and
managing their roles. It does not cover any financial module — members
in this module carry no balance, arrears, contribution, loan, or wallet
data, because none of that exists yet.

## Domain member vs auth user

See
[docs/product/member-identity-model.md](member-identity-model.md) for
the full rationale. In short: a `group_memberships` row is a
first-class record of a person a group tracks, independent of whether
that person has ever signed in to the app. `group_memberships.user_id`
is nullable, and a membership with `user_id = null` is fully valid and
expected — most members registered from a physical register will never
have one.

The UI reflects this as **"Account access: Linked / Not linked"** on
the member detail screen. `user_id` itself is never surfaced as a UI
concept, and there is no invitation/linking flow in this module (see
"Future requirement: linking" in the identity-model doc).

## Statuses and transitions

A membership has one of three statuses:

- `ACTIVE`
- `SUSPENDED`
- `EXITED`

Allowed transitions through `rpc_change_group_member_status`:

- `ACTIVE → SUSPENDED`
- `SUSPENDED → ACTIVE`
- `ACTIVE → EXITED`
- `SUSPENDED → EXITED`

`EXITED` is **terminal** for this generic RPC — there is no
`EXITED → ACTIVE` transition through it. A membership is never
hard-deleted; `EXITED` is the closest thing to "removed" and preserves
history. Reactivating a genuinely-exited member (if ever needed) is a
deliberately separate, not-yet-designed workflow, not a status flip.

The Flutter UI exposes only the actions valid for the member's current
status:

| Current status | Available actions |
|---|---|
| `ACTIVE` | Suspend, Mark as Exited |
| `SUSPENDED` | Reactivate, Mark as Exited |
| `EXITED` | none |

Every status change requires an explicit confirmation dialog before
the RPC is called.

### Last-active-admin protection

Removing the group's last active `ADMIN` (via status change or role
removal) is rejected by the backend
(`LAST_ADMIN_REQUIRED`/`assert_last_active_admin_remains`, unchanged
from prior prompts). The Flutter error mapping surfaces this as:

> Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.

Never a raw Postgres error.

## Permissions

Six permissions gate this module, and none of them imply another:

- `member.view` — list/see members
- `member.create` — add a member
- `member.edit` — edit a member's identity/contact fields
- `member.change_status` — suspend/reactivate/mark exited
- `role.view` — see a member's assigned roles
- `role.assign` — assign/remove roles

Notably, `role.view` is a **strict subset** of `member.view` under
seeded permissions (e.g. SECRETARY/TREASURER hold `member.view` but not
`role.view`). When the caller lacks `role.view`, both
`rpc_list_group_members` and `rpc_get_group_member` return `roles:
null` (not `[]`) — `null` means "hidden from you", `[]` means "this
member genuinely has no roles assigned". The Flutter model
(`GroupMember.roleCodes`, `canViewRoles`) and the detail screen's Roles
section (hidden entirely when `null`) preserve this distinction.

The backend is authoritative for every permission check. Flutter-side
gating (`MembershipContext.hasPermission`) is UX only — it hides
actions a user isn't allowed to take, but every mutation is re-checked
server-side regardless of what the client sends.

Assigning or removing the `ADMIN` role still requires the caller to
already hold `ADMIN` (unchanged protection from prior prompts) — this
module does not weaken it, and does not add custom role/permission
creation.

## RPCs

Read (new, added in this module):

- `rpc_list_group_members(p_group_id, p_search, p_status, p_limit, p_offset)`
  — paginated, searchable (name/member number/phone), status-filtered,
  deterministically sorted (`display_name`, then `id`) list. Page size
  is capped at 100 server-side regardless of what the client requests;
  default 25.
- `rpc_get_group_member(p_group_id, p_membership_id)` — single member
  detail. A `membership_id` that exists but belongs to a different
  group is treated as "not found" — it never leaks existence across
  groups.

Mutations (all pre-existing, reused unchanged):

- `rpc_create_group_member` — never creates an `auth.users` row, sends
  an OTP, creates a `profiles` row, or assigns an elevated role.
  `user_id = null` on the resulting membership is the normal case.
- `rpc_update_group_member` — identity/contact fields only. It has no
  `status` parameter at all, so it is structurally incapable of
  mutating status — status changes always go through
  `rpc_change_group_member_status`.
- `rpc_change_group_member_status`
- `rpc_assign_group_role` / `rpc_remove_group_role`

All of the above already enforce (unchanged by this module): caller is
authenticated, `assert_active_profile()`, an `ACTIVE` membership in an
`ACTIVE` group, and the specific permission required. Every query is
scoped to `p_group_id` — no RPC in this module trusts a client-supplied
group id beyond using it as an explicit filter checked against the
caller's own membership.

## What this module does not do

Deferred, and explicitly out of scope for this prompt:

- Contributions, payments, wallet, Hisa, loans, financial accounts,
  cashbook, reports, statements — no financial module exists yet, so
  no balance/arrears/loan-balance placeholders appear anywhere in this
  module's UI.
- SMS campaigns.
- Auth-user-to-member linking/invitations (see "Future requirement" in
  the identity-model doc).
- Custom roles or custom permissions — only the seeded roles/
  permissions are usable.
- Member photos.
- Member deletion — members are never hard-deleted, only moved to
  `EXITED`.
- Subscriptions, platform admin.
- A full audit-log subsystem. `created_at`/`updated_at`/`created_by`
  are maintained per existing conventions; richer change history is a
  future module.
