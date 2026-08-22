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
`EXITED → ACTIVE` transition through it, and Prompt 05B does not
weaken that rule. A membership is never hard-deleted; `EXITED` is the
closest thing to "removed" and preserves history.

The Flutter UI exposes only the actions valid for the member's current
status:

| Current status | Available actions |
|---|---|
| `ACTIVE` | Sitisha (Suspend), Weka Ametoka (Mark as Exited) |
| `SUSPENDED` | Rudisha (Reactivate), Weka Ametoka (Mark as Exited) |
| `EXITED` | Rudisha kwenye Kikundi (Rejoin) — see below |

Every status change requires an explicit confirmation dialog before
the RPC is called. On success, a `SnackBar` confirms the outcome (e.g.
"Mwanachama amesitishwa.") — the mutation result and any *subsequent*
provider-refresh problem are reported separately, so a background
refresh issue is never mistaken for the mutation itself having failed
(see "Suspend false-error bug" below).

### Explicit rejoin (Prompt 05B)

Reactivating a genuinely-EXITED member is a **separate, explicit
workflow** — `rpc_rejoin_group_member` (introduced in
`20260821090000_add_member_rejoin_workflow.sql`, hardened in place by
the append-only correction migration
`20260821110000_harden_rejoin_and_member_number_functions.sql` — see
"Effective-date validation" below), never a relaxation of
`rpc_change_group_member_status`'s EXITED-terminal rule (pgTAP test
`10_admin_continuity_and_status_transitions` still asserts
`EXITED -> ACTIVE` is rejected through the generic RPC; a dedicated
`15_member_rejoin_workflow` suite covers the new RPC).

- Gated by the same `member.change_status` permission (not a new
  permission code — no `role_permissions` seeding was needed).
- Requires the target membership's current status to be `EXITED`
  (`MEMBERSHIP_NOT_EXITED` otherwise) and the same `p_group_id` (cross-
  group isolation, like every other RPC here).
- If the membership has a linked `user_id` that already holds a
  *different* `ACTIVE` membership in the same group, the rejoin is
  rejected (`USER_ALREADY_HAS_ACTIVE_MEMBERSHIP`) rather than silently
  creating two active memberships for one user in one group.
- Sets `status = 'ACTIVE'` and clears `exited_at` — but the fact that
  the member *had* exited is not lost: a narrowly-scoped, immutable
  `group_membership_status_history` table (append-only, no client
  grants at all — not even `authenticated` SELECT) records
  `from_status/to_status/previous_exited_at/effective_at/changed_by`
  for this transition. This is intentionally the *only* transition
  that writes to that table — it is not a general audit log, and
  `rpc_change_group_member_status` is not retrofitted to also write to
  it.
- **Effective-date validation (hardening correction):** the effective
  rejoin date is resolved as `coalesce(p_rejoined_at, current_date)`
  and must fall within the exited/rejoined interval —
  `previous_exited_at <= effective_rejoin_date <= current_date`. A
  date before the member's own `previous_exited_at`
  (`REJOIN_DATE_BEFORE_EXIT`) or in the future
  (`REJOIN_DATE_IN_FUTURE`) is rejected with SQLSTATE `22023` and a
  stable message. An `EXITED` membership somehow missing a
  `previous_exited_at` is also rejected
  (`EXITED_MEMBERSHIP_MISSING_EXITED_AT`) rather than treated as
  eligible for any date — defense in depth, since every path that sets
  `status = 'EXITED'` already sets `exited_at`. `joined_at` is never
  read or written by this RPC; the preserved
  `previous_exited_at`/`effective_at` pair in
  `group_membership_status_history` remains the sole authoritative
  record of the exited/rejoined interval.
- **Contribution Engine note** (no such module exists yet to hold
  this): a rejoin must never cause automatic back-charging for periods
  opened while the member was `EXITED`. Future contribution-eligibility
  logic should treat the member as ineligible between `exited_at` and
  the rejoin's `effective_at` (from the history table), never inferring
  eligibility purely from `status = 'ACTIVE'` today.
- Flutter: `MemberRepository.rejoinMember` / `MemberStatusController.
  rejoin()` — a dedicated method, never routed through `changeStatus`.
  The button ("Rudisha kwenye Kikundi") only renders for `EXITED`
  members when the caller has `member.change_status`.

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
  the RPC's own default is 25, but Flutter always sends `p_limit`
  explicitly and defaults to **10** (`MembersQuery`, Prompt 05B §18) —
  "Onyesha Zaidi" grows it by 10 each tap; search/filter changes reset
  back to the first 10. Switching the selected group also resets it
  (`SelectedGroupNotifier.selectGroup` invalidates
  `membersQueryProvider`, prompt 05C §11) so a page count/search/filter
  from the previous group is never carried into the newly-selected one.
- `rpc_get_group_member(p_group_id, p_membership_id)` — single member
  detail. A `membership_id` that exists but belongs to a different
  group is treated as "not found" — it never leaks existence across
  groups.

Mutations:

- `rpc_create_group_member` — never creates an `auth.users` row, sends
  an OTP, creates a `profiles` row, or assigns an elevated role.
  `user_id = null` on the resulting membership is the normal case.
  **Member numbers are server-generated and server-authoritative**
  (Prompt 05B §30-36 — see "Server-generated member numbers" below);
  the normal create-member screen never sends `p_member_number`,
  letting the RPC generate one. A non-null `p_member_number` is
  rejected outright (`MANUAL_MEMBER_NUMBER_NOT_ALLOWED`, SQLSTATE
  `22023`) — the correction migration
  `20260821110000_harden_rejoin_and_member_number_functions.sql`
  removed the override this RPC originally accepted. There is no
  manual/Flutter override on this path; a separate, privileged import
  RPC is the intended future home for supplying a pre-existing number,
  if that need materializes.
- `rpc_update_group_member` — identity/contact fields only. It has no
  `status` parameter at all, so it is structurally incapable of
  mutating status — status changes always go through
  `rpc_change_group_member_status`. The Flutter form no longer offers a
  member-number field at all — once assigned, a member number is
  treated as a stable, read-only identifier. Since the Prompt 05D
  correction migration
  (`20260821120000_enforce_membership_member_numbers.sql`), the RPC
  itself enforces this server-side too: `p_member_number` is ignored
  when `null`, tolerated as a no-op when it equals the membership's
  current number (old-client compatibility), and rejected
  (`MEMBER_NUMBER_IMMUTABLE`, SQLSTATE `22023`) for any other value —
  including assigning a number to a membership that happens to have
  none, which remains exclusively the generator's job.
- `rpc_change_group_member_status` — unchanged; still EXITED-terminal.
- `rpc_rejoin_group_member` — see "Explicit rejoin" above.
- `rpc_assign_group_role` / `rpc_remove_group_role`

### Server-generated member numbers (Prompt 05B)

Format: `<groups.code>-<YYYY>-<sequence, >=4 digits>`, e.g.
`UMJT-2026-0001`. Migration
`20260821100000_add_server_generated_member_numbers.sql`:

- **Prefix**: `groups.code`, repurposed (confirmed appropriate before
  this migration — it was a dormant, nullable, non-unique,
  never-populated, never-read-by-Flutter column) rather than adding a
  competing prefix column. It is now `NOT NULL`, `UNIQUE`, format-
  checked (`^[A-Z0-9]{2,10}$`), and **immutable** once set — enforced
  both by removing it from `authenticated`'s column-level UPDATE grant
  (the primary guard) and by a `prevent_group_code_change` trigger
  (defense in depth). Existing groups were backfilled once, at
  migration time, from their name (`generate_group_code`); `rpc_create_group`
  now populates it for every new group the same way. Renaming a group
  never changes its code, so existing member numbers never appear to
  reference a different prefix after a rename.
  - **Hardening correction**
    (`20260821110000_harden_rejoin_and_member_number_functions.sql`):
    `generate_group_code` now takes a transaction-scoped
    `pg_advisory_xact_lock`, keyed on the derived base, before checking
    candidate availability — two concurrent group-creation requests
    deriving the same base can no longer race the same candidate onto
    the unique index; one serializes behind the other and gets the next
    free suffix instead of failing. A sanitized base shorter than 2
    characters (including empty) is padded/replaced to a deterministic
    ≥2-character base *before* the availability check, so a very
    short/punctuation-only group name can never reach
    `groups_code_format`'s `^[A-Z0-9]{2,10}$` check as a raw constraint
    violation. A numeric disambiguation suffix can never push the
    result past 10 characters.
- **Sequence**: `group_member_number_counters (group_id, year,
  last_number)`, incremented atomically via `INSERT ... ON CONFLICT
  (group_id, year) DO UPDATE ... RETURNING` — immune to the lost-update
  race a bare `select max(member_number)+1` would have. Never granted
  to any client role; only reachable via the internal
  `next_group_member_number()`/`generate_member_number()` helpers,
  themselves only called from `rpc_create_group_member`. Per-group,
  per-year — two groups (or two years) never share a sequence, and a
  9999+ member/year group simply grows the digit count rather than
  failing.
- **Year**: the business-effective `joined_at` year (defaults to
  `current_date`), not the wall-clock year at the moment of the RPC
  call — a backdated join gets that year's sequence.
- **Existing rows are untouched**: nothing in this migration updates
  `group_memberships.member_number` for any pre-existing row —
  auto-generation only applies to members created *after* this
  migration.

### Every membership has a member number (Prompt 05D)

ROLE and MEMBERSHIP are separate concepts: a group's founder/ADMIN is
still represented by an ordinary `group_memberships` row, and that row
was the one gap left by 20260821100000 — `rpc_create_group` inserted it
directly (never through `rpc_create_group_member`, the only place
number generation was wired up), so every founding ADMIN membership had
`member_number = null`. `20260821120000_enforce_membership_member_numbers.sql`
closes this:

- `rpc_create_group` now generates the founder's member number the same
  way any other member's is generated (the new group's own code, the
  founding year — the founder's `joined_at` is always `current_date` —
  and the next per-group/per-year sequence). ADMIN is not exempt, and
  there is no separate "admin identifier" concept.
- **Backfill**: every pre-existing `group_memberships` row with
  `member_number is null` was backfilled once, at migration time, in a
  stable order (`group_id`, `joined_at`, `created_at`, `id`), using each
  row's own `joined_at` year (falling back to `created_at`'s year for a
  row with neither). No existing non-null `member_number` was read for
  a decision beyond the collision check below, and none was
  overwritten.
- **Collision safety**: `generate_member_number()` no longer trusts the
  per-group/per-year counter blindly — a candidate is checked against
  the group's actual data after each atomic counter increment, and the
  counter is advanced again (never `MAX()+1`) if that candidate already
  exists (e.g. a legacy or manually-entered number the counter has no
  idea about). This protects both the backfill above and normal
  ongoing generation, and does not change the counter's own
  concurrency-safety.
- `group_memberships.member_number` is now **`NOT NULL` at the database
  level** — the actual product invariant, not just an RPC-level
  convention. Added only after the backfill above completed and a
  guard confirmed zero remaining null rows (the migration raises rather
  than adds the constraint if that guard ever finds one). No `DEFAULT`
  was added — a member number is never a column-default side effect of
  a plain `INSERT`, only ever `generate_member_number()`'s output via
  the create RPCs. The 13 pgTAP fixture files that used to construct
  membership rows directly without one (for tests unrelated to member
  numbers — tenant isolation, authorization, admin continuity, ...)
  were updated alongside this migration to supply deterministic,
  obviously-test-only values (e.g. `TESTA-2026-0001`, or the fixture's
  own already-declared group code where no real generation happens in
  the same test). The existing per-group unique partial index
  (`group_memberships_member_number_unique`, from 20260819080632) is
  unchanged and not duplicated.

All of the above already enforce (unchanged by this module): caller is
authenticated, `assert_active_profile()`, an `ACTIVE` membership in an
`ACTIVE` group, and the specific permission required. Every query is
scoped to `p_group_id` — no RPC in this module trusts a client-supplied
group id beyond using it as an explicit filter checked against the
caller's own membership.

## Suspend false-error bug (fixed, Prompt 05B)

A real production bug: tapping "Sitisha" (or any status change) could
succeed on the backend but still show "Something went wrong" to the
user. Root cause: `rpc_change_group_member_status`'s jsonb result
omits `display_name`/`created_at` (it only returns
`membership_id/group_id/status/exited_at/updated_at` — a lightweight
confirmation, not a full member row), and `MemberRepository.
changeStatus` used to parse that result via `GroupMember.fromJson`,
which threw on those missing required fields — on *every* successful
call. `rpc_update_group_member`'s result has the same shape gap
(missing `created_at`), so `updateMember` had the identical latent
bug.

Fix: `changeStatus`/`updateMember`/`rejoinMember` all return `void` now
— nothing parses these RPCs' partial results as a `GroupMember` at
all, so the mutation's success/failure is reported purely from whether
the RPC call itself threw, never from a secondary parsing step.
Screens re-read via the existing provider-invalidation pattern instead
of trusting a mutation call's return value. See
`group_member_model_test.dart`'s dedicated regression test (documents
the exact partial shape) and `member_status_controller_test.dart`.

## Member edit discoverability (Prompt 05B)

"Hariri" remains a clear, separate action on Member Detail. The
Members list also offers it per-row via a restrained overflow menu
(⋮) — shown only when the caller has `member.edit` — rather than a
second always-visible button on every row. The edit form itself is
unchanged in scope: display name, phone, and (read-only) member
number; status and roles remain entirely outside it.

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
