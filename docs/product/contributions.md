# Contribution Engine — Obligation Foundation (Prompt 06A)

This document describes the Contribution Engine as implemented in
Prompt 06A: the **obligation ledger** only. It covers what a member
owes and how that obligation is created. It does not cover payments,
payment allocation, wallet, or cashbook — those are later modules and
none of their tables exist yet.

Critical rule, repeated everywhere it matters in the schema and code:
**creating an obligation never creates cash movement.**

## The hierarchy

```
Contribution Type
      ↓
Contribution Setup
      ↓
Contribution Period
      ↓
Member Contribution Charge
      ↓ (1 or more)
Contribution Charge Component
```

There is intentionally **no `contribution_series` entity**. A
Contribution Setup already carries the recurring rule; a Contribution
Period is the concrete instance.

- **Contribution Type** (`public.contribution_types`) — business
  classification: "what kind of contribution is this?" (e.g. Ada,
  Michango ya Jamii, Hisa).
- **Contribution Setup** (`public.contribution_setups`) — reusable
  charging rules: "how does it behave?" (schedule, amount mode, due
  date defaults, penalty configuration).
- **Contribution Period** (`public.contribution_periods`) — one
  concrete obligation cycle/event (e.g. "Ada — Januari 2027" or
  "Msiba wa Mama David").
- **Member Contribution Charge** (`public.member_contribution_charges`)
  — the posted obligation for one member for one period.
- **Contribution Charge Component** (`public.contribution_charge_components`)
  — the monetary pieces of a charge. `OPEN`/explicit enrollment always
  posts a `BASE` component; `rpc_assess_contribution_penalties()`
  (Prompt 06B) posts `PENALTY` components — see "Penalty assessment &
  posting" below.

## Accounting treatments

`public.contribution_accounting_treatment`: `GROUP_INCOME`,
`PASS_THROUGH`, `SHARE_CAPITAL`, `MEMBER_SAVINGS`.

- **GROUP_INCOME** — settled contributions ultimately belong to the
  group as income.
- **PASS_THROUGH** — collected for a specific purpose/event (e.g.
  Mzunguko, Rambirambi) and is never ordinary group income merely
  because cash was collected. Prompt 06A preserves this treatment on
  the type/setup/period/charge and displays it correctly, but does not
  implement any payout/settlement logic (`GROUP_ADVANCE_TO_PASS_THROUGH`,
  `UNSETTLED`/`ADVANCE_OUTSTANDING`/`FUNDS_REMAINING`/`SETTLED` states)
  — that is a future financial module.
- **SHARE_CAPITAL** — member-owned/group-equity style contribution
  (Hisa). Not ordinary income. `category = 'SHARE'` requires
  `accounting_treatment = 'SHARE_CAPITAL'` (`contribution_types_share_requires_share_capital`
  check constraint) — this is the one hard-locked pairing.
- **MEMBER_SAVINGS** — reserved/deferred. The schema and enum
  understand the value (so future work doesn't need a schema change),
  but `rpc_create_contribution_type` and `rpc_update_contribution_type`
  both reject it outright (`MEMBER_SAVINGS_NOT_AVAILABLE`, errcode
  `P0001`). There is no product path to create one yet.

## Categories

`public.contribution_category`: `GENERAL`, `SOCIAL`, `SHARE`.
Deliberately does not encode schedule mode (recurring vs one-off) —
that belongs entirely to Contribution Setup, so there's no redundant
"MONTHLY_GENERAL vs ONE_TIME_GENERAL" category proliferation.

## Contribution Setup

Schedule modes (`public.contribution_schedule_mode`): `MONTHLY`,
`ON_DEMAND`, `ONE_TIME`.

Amount modes (`public.contribution_amount_mode`): `FIXED`,
`CUSTOM_PER_MEMBER`.

- `FIXED` requires `fixed_amount > 0`; `CUSTOM_PER_MEMBER` requires
  `fixed_amount is null` (`contribution_setups_fixed_amount_rule`).
  Period opening for `CUSTOM_PER_MEMBER` uses per-member amounts
  configured on the period (see below) — there is no single fake
  default that everyone is assumed to owe.

Due date defaults: `default_due_month_offset` + `default_due_day`
(1–31). `public.contribution_compute_due_date(period_start,
month_offset, day)` derives the due date, capping the day at the last
valid day of the resulting month (e.g. day 31 requested against
February resolves to the 28th, or the 29th in a leap year) — never an
invalid calendar date. Example: Ada period starting 2027-01-01 with
offset 1 / day 5 → due date 2027-02-05.

If a setup has no `default_due_day` configured, period creation
requires an explicit `due_date` from the caller (`DUE_DATE_REQUIRED`)
— this is expected for one-off `ON_DEMAND`/`ONE_TIME` setups, where
the UI is expected to let the user pick the due date directly rather
than relying on a monthly default that doesn't apply.

## Contribution Period lifecycle

```
DRAFT ──────► SCHEDULED ──────► OPEN ──────► CLOSED
  │                │
  └──► CANCELLED ◄─┘
```

Allowed transitions: `DRAFT → SCHEDULED`, `DRAFT → OPEN`,
`SCHEDULED → OPEN`, `DRAFT → CANCELLED`, `SCHEDULED → CANCELLED`,
`OPEN → CLOSED`. `CLOSED` and `CANCELLED` are terminal. `OPEN` cannot
become `CANCELLED` (it already contains posted obligations —
corrections are a future, explicit workflow, not a status hack).

**Locked invariant: DRAFT and SCHEDULED periods create zero member
charges.** Only the transition into `OPEN`
(`rpc_open_contribution_period`) ever inserts into
`member_contribution_charges`. A future month can exist as a
`SCHEDULED` period today without generating any debt for it — debt
only exists once a human explicitly opens that period. Prompt 06A
never auto-generates next month/quarter/year obligations just because
a `MONTHLY` setup exists.

## The three dates (never collapsed into one)

- **`obligation_date`** — when the obligation belongs economically
  (defaults to `period_start`).
- **`eligibility_date`** — the date used to compute automatic member
  eligibility (defaults to `period_start`, stored explicitly rather
  than implicitly reusing `period_start` everywhere).
- **`due_date`** — when payment becomes due (see due-date defaults
  above).

`effective_at`/`created_at` are kept distinct throughout, per
[docs/database/conventions.md](../database/conventions.md): a charge's
`effective_at` is its `obligation_date`; `created_at` is only ever the
audit timestamp of when the row was written (e.g. a committee opening
January's charges on 3 February still has `effective_at = 2027-01-01`,
`created_at = 2027-02-03`).

## Configuration snapshot at OPEN

`rpc_open_contribution_period` freezes the type/setup configuration
that was in effect at open time into explicit columns on
`contribution_periods` (`snapshot_type_name`, `snapshot_category`,
`snapshot_accounting_treatment`, `snapshot_setup_name`,
`snapshot_schedule_mode`, `snapshot_amount_mode`,
`snapshot_fixed_amount`, `snapshot_penalty_mode`,
`snapshot_penalty_grace_days`, `snapshot_penalty_value`,
`snapshot_penalty_cap_amount`) rather than an opaque JSON blob, so the
values stay queryable. A later rename/edit of the Contribution Type or
Setup never rewrites an already-OPEN period's historical meaning.

Two additional immutability locks reinforce this at the type/setup
level, independent of any specific period: once a type/setup has been
used by any `OPEN` or `CLOSED` period, `rpc_update_contribution_type`
refuses to change `category`/`accounting_treatment`
(`CONTRIBUTION_TYPE_ACCOUNTING_LOCKED`), and
`rpc_update_contribution_setup` refuses to change any financially
meaningful field — amount/due/penalty configuration
(`CONTRIBUTION_SETUP_CONFIG_LOCKED`). Name/description/`is_active`
remain editable at any time.

## Editing a DRAFT/SCHEDULED period (Prompt 06A-CLOSEOUT)

`rpc_update_contribution_period` lets a DRAFT/SCHEDULED period's
pre-open configuration be corrected without cancel-and-recreate.
`CONTRIBUTION_PERIOD_NOT_EDITABLE` once the period is `OPEN`/`CLOSED`/
`CANCELLED` — same lifecycle gate and error code as
`rpc_set_contribution_period_member_amounts`/
`rpc_exclude_contribution_period_member`. `contribution_setup_id` has no
parameter at all (matching `rpc_update_contribution_setup`/
`rpc_update_contribution_type`'s precedent of simply omitting an
immutable parent reference), so it can never change. Editable:
`label`, `period_start`, `period_end`, `obligation_date`,
`eligibility_date`, `due_date`, `scheduled_open_date` — a `null`
argument means "leave unchanged", matching every other Contribution
Engine update RPC's coalesce convention (there is no separate "clear
this field" signal). MONTHLY duplicate-month protection is re-checked
against the resulting `period_start` (excluding the period's own row),
and `period_start <= period_end` is re-validated, exactly as at
creation.

No charges exist yet on a DRAFT/SCHEDULED period, so an edit never
touches `member_contribution_charges`/`contribution_charge_components`
— it only ever updates the period row. Changing `eligibility_date`
therefore only changes future preview/open behaviour:
`rpc_preview_contribution_period_open` and
`contribution_period_eligible_memberships` both read the period's
*current* `eligibility_date` live, so the very next preview reflects
the edit immediately.

## Member eligibility

`public.contribution_period_eligible_memberships(period_id)` is the
single server-authoritative eligibility roster, used by both the open
preview and the actual OPEN posting (so preview and posting can never
disagree). A membership is eligible when:

1. `status = 'ACTIVE'`,
2. `joined_at` is null or `joined_at <= eligibility_date`,
3. it has no row in `contribution_period_member_exclusions` for this
   period, and
4. it is not currently inside a "was EXITED, later rejoined" window
   that covers `eligibility_date` (see below).

Domain member identity is always `group_memberships.id`
(`membership_id`), never `auth.users.id` — `user_id` is nullable by
design (see
[docs/product/member-identity-model.md](member-identity-model.md)) and
a membership with no linked account is charged exactly like one that
has an account.

### Rejoin / back-charge protection

Per the Contribution Engine note in
`20260821090000_add_member_rejoin_workflow.sql`: a member who exited
and later rejoined must never be automatically back-charged for a
period whose `eligibility_date` falls inside the window they were
exited, purely because their status reads `ACTIVE` today.

The eligibility function checks `public.group_membership_status_history`
for a `REJOIN` row where `previous_exited_at <= eligibility_date <
effective_at` (the rejoin date) — if one exists, the membership is
excluded from automatic eligibility for that period. This table is
intentionally narrow (only rejoin writes to it — see the table
comment); it is not a general status audit log, so it cannot perfectly
reconstruct every historical suspension window. Per instruction, we do
not invent history to fill that gap. Where automatic eligibility can't
be determined with confidence, the period-open preview and explicit
pre-open exclusion / post-open enrollment are the intended tools for a
human to get the roster right — not silent back-charging.

## Exclusion vs future waiver

**Exclusion** (`contribution_period_member_exclusions`) — a member is
intentionally left out of a period *before* it opens. No obligation is
ever posted for them. Only meaningful while the period is `DRAFT` or
`SCHEDULED`; once `OPEN`, the eligibility roster is historical fact
and cannot be changed by adding/removing exclusions.

**Waiver** — an obligation existed and was later forgiven. **Not
implemented in Prompt 06A.** The UI intentionally avoids the words
"Waive"/"Futa deni" for the pre-open exclusion action, since no charge
exists yet to forgive at that point.

### Excluded, then explicitly enrolled after OPEN (Prompt 06A-CLOSEOUT)

Prompt 06A already permits `rpc_enroll_member_in_contribution_period`
to enroll a member who was explicitly excluded pre-open — nothing in
that RPC checks `contribution_period_member_exclusions`. The exclusion
row is never deleted or rewritten just because a later enrollment
happened; it remains as historical pre-open roster information (why
they weren't part of the original OPEN posting).

What changed in the closeout: `rpc_get_contribution_period`'s
`excluded_count` previously counted every exclusion row for the period,
which would misleadingly still call an enrolled-after-OPEN member
"excluded" even though they now have a charge. The definition is now:

> `excluded_count` = excluded members who do **not** currently have a
> charge for this period.

A member with both an exclusion row and a charge (the
excluded-then-enrolled case) is no longer counted in `excluded_count`,
even though their exclusion row still exists and is still queryable.
The Flutter summary section displays this same `excluded_count` value
directly, so the UI never disagrees with the backend's definition.

## Accounting-snapshot confirmation (Prompt 06A-CLOSEOUT)

The immutable financial classifications — contribution category,
accounting treatment, setup/period amount mode, and penalty
configuration — are snapshotted **only** onto the `contribution_periods`
row itself (`snapshot_category`, `snapshot_accounting_treatment`,
`snapshot_amount_mode`, `snapshot_fixed_amount`, `snapshot_penalty_*`;
see "Configuration snapshot at OPEN" above), at the moment
`rpc_open_contribution_period` transitions `DRAFT`/`SCHEDULED` →
`OPEN`. `member_contribution_charges` and
`contribution_charge_components` carry no category/accounting-treatment/
amount-mode/penalty-configuration columns of their own at all — a
charge only references its period via `period_id`, and the period's
frozen snapshot is the sole authoritative record of what financial
classification applied when that charge was posted. This is a
deliberate relational design, not an oversight: duplicating those
fields onto every charge/component row would just be redundant data
that could drift from the period's snapshot, with no invariant the
schema would then need to enforce twice. Reading a charge's
classification is always "join to `member_contribution_charges.period_id`,
read the period's `snapshot_*` columns" — never a second, separately
mutable copy.

## Custom-per-member amounts

For `amount_mode = CUSTOM_PER_MEMBER`, per-member amounts are
configured on `contribution_period_member_amounts` (not a fake shared
default) via `rpc_set_contribution_period_member_amounts`, editable
only while the period is `DRAFT`/`SCHEDULED`. Opening the period
requires every automatically-eligible member to already have a
configured amount — if any is missing, `rpc_open_contribution_period`
raises `MISSING_CUSTOM_AMOUNTS` and creates **no** charges at all
(all-or-nothing; see below). `rpc_preview_contribution_period_open`
surfaces the exact missing set ahead of time so the UI never needs to
attempt-and-fail blindly.

## Open preview

`rpc_preview_contribution_period_open` is read-only (no mutation) and
returns: `eligible_members` (with the amount each would be charged),
`excluded_members` (with a reason — `EXCLUDED` for an explicit
pre-open exclusion, or a system reason: `SUSPENDED`, `EXITED`,
`JOINED_AFTER_ELIGIBILITY_DATE`, `EXITED_DURING_PERIOD`),
`missing_custom_amount_members`, `expected_total_assessment`, and a
`can_open` flag. Flutter uses this to build the confirmation screen
before the user presses Open — it never has to guess what OPEN will
do.

## Atomic, idempotent OPEN

`rpc_open_contribution_period`:

1. Authenticates, requires an active profile/membership/group and the
   `contribution.period.open` permission.
2. Locks the period row (`for update`).
3. If the period is already `OPEN`, returns the existing posting
   summary unchanged (`already_open: true`) instead of re-posting —
   this makes double-tap/network-retry safe without relying on
   Flutter disabling a button. The row lock plus this status recheck
   also makes two concurrent OPEN calls safe: the second blocks on the
   lock, then sees `OPEN` once it proceeds and takes the idempotent
   path.
4. Otherwise requires `DRAFT`/`SCHEDULED` and the setup to be active;
   validates custom amounts (all-or-nothing, see above); freezes the
   snapshot; and inserts one `member_contribution_charges` row plus
   exactly one `BASE` `contribution_charge_components` row per
   eligible member, in the same transaction as the snapshot/status
   update. If any step fails, nothing is committed — there is no
   partial posting.

A `CLOSED` period cannot be re-opened — `rpc_open_contribution_period`
raises `CONTRIBUTION_PERIOD_NOT_OPENABLE` for it (this is distinct
from the `already_open` idempotent path, which only applies while the
period is currently `OPEN`).

## Explicit post-open enrollment

A member who joins (or is otherwise added) after a period has already
opened is never silently back-charged. `rpc_enroll_member_in_contribution_period`
(requires `contribution.member_enroll`, `OPEN` periods only) creates
exactly one charge + one `BASE` component for that member: the
setup's fixed amount for `FIXED`, or an explicit required amount for
`CUSTOM_PER_MEMBER`. A member already charged for the period is
rejected (`MEMBER_ALREADY_CHARGED_FOR_PERIOD`), and cross-group
enrollment is rejected the same way any other cross-group reference
is.

## Close / cancel

`CLOSE` (`OPEN → CLOSED`, `contribution.period.close`) stops new
automatic charges, further exclusions/amount edits, and further
enrollment — but existing charges remain fully collectible; a future
Payments module settles them, they are never archived or deleted.

`CANCEL` (`DRAFT`/`SCHEDULED → CANCELLED`, `contribution.period.manage`)
is only available before any posting has happened. Once `OPEN`,
correcting a period is a future, explicit financial-correction
workflow — not something this module fakes with a status change.

## Immutability

Once `OPEN`, a charge/component row is never edited or deleted by
normal means: there is no client `UPDATE`/`DELETE` grant on
`member_contribution_charges` or `contribution_charge_components` at
all — every write goes through the `SECURITY DEFINER` RPCs above.
Corrections (adjustment/reversal/waiver/opening balance) are explicit,
distinct future concepts, not `UPDATE`/`DELETE` on posted rows.

## Penalty assessment & posting (Prompt 06B)

`public.contribution_penalty_mode`: `NONE`, `FIXED_ONCE`,
`FIXED_RECURRING`, `PERCENTAGE_ONCE`, `PERCENTAGE_RECURRING`, stored
and validated on Contribution Setup (`penalty_grace_days`,
`penalty_value`, `penalty_cap_amount`) and snapshotted into `OPEN`
periods (`snapshot_penalty_*`). Prompt 06A stored and snapshotted this
configuration but never posted a `PENALTY` component from it. Prompt
06B implements the actual assessment/posting engine —
`rpc_assess_contribution_penalties()` — on top of the same hierarchy,
introducing **no new tables**: a posted penalty is exactly one more row
in the existing `contribution_charge_components` table
(`component_type = 'PENALTY'`, a value 06A already defined and reserved
for this).

### Design decisions locked for 06B

06A's schema stores exactly *one* rate/grace/cap per setup — there is
no multi-tier "penalty levels" table. These decisions were confirmed
explicitly (not guessed) before implementation, precisely because the
schema doesn't spell them out on its own:

- **"Level" = successive recurrence occurrence**, not a distinct
  escalating rate. For `FIXED_ONCE`/`PERCENTAGE_ONCE`, at most one
  `PENALTY` component is ever posted per charge. For
  `FIXED_RECURRING`/`PERCENTAGE_RECURRING`, occurrence *N* is posted
  once `assessment_date >= due_date + N * penalty_grace_days` — i.e.
  the same configured rate recurs every `penalty_grace_days` interval
  since `due_date`. Occurrences are numbered via the existing
  `contribution_charge_components.sequence` column (already present
  since 06A, previously only ever `1` for `BASE`) — no new "level"
  concept was added to the schema.
- **Outstanding = the charge exists.** 06A has no payment/wallet
  subsystem at all (`member_contribution_charges` has no
  `paid_amount`, ever — see "Immutability" above). `outstanding > 0` is
  therefore definitionally true for as long as a charge exists;
  penalty eligibility is simply "this charge is overdue"
  (`assessment_date > due_date`). This does not invent a payment
  concept — it is the only state 06A's schema can represent, and 06B
  does not get ahead of the payments module by pretending otherwise.
- **Percentage basis is always the charge's original `BASE` component
  `assessed_amount`**, every occurrence — matching the locked "no
  penalty-on-penalty" rule. A recurring percentage penalty never
  compounds on top of previously-posted penalties.
- **`penalty_cap_amount` is a hard, cumulative cap per charge.** Once
  the sum of a charge's `PENALTY` components would reach/exceed the
  cap, the next occurrence is clamped to the remaining room (possibly
  zero), and no further occurrence is ever posted for that charge —
  there is no "repeat the final level past the cap" behaviour, since
  nothing in the locked docs describes that.

### Grace period and thresholds

- Overdue means `assessment_date > due_date`.
- A grace period delays when a penalty is *assessed*, but never
  changes the original `due_date` itself — `due_date` on the charge is
  never mutated by penalty assessment.
- Occurrence *N*'s threshold is `due_date + N * penalty_grace_days`;
  the penalty posts **on or after** that date (`assessment_date >=
  threshold`), not strictly after.
- Allocation order (once payments exist) remains `BASE` then
  `PENALTY` — unaffected by 06B, since no allocation exists yet.

### `rpc_assess_contribution_penalties(p_group_id, p_period_id, p_assessment_date default current_date)`

Atomic (one transaction; any failure rolls back the whole call — never
a partial posting across members) and idempotent:

- Requires `contribution.penalty.assess` and an `OPEN` period whose
  frozen snapshot has a real penalty policy (`snapshot_penalty_mode <>
  'NONE'`) — `CONTRIBUTION_PERIOD_NOT_OPEN` / `P0001` and
  `CONTRIBUTION_PERIOD_NO_PENALTY_POLICY` / `P0001` respectively
  otherwise. `DRAFT`/`SCHEDULED`/`CANCELLED` periods are never
  eligible; `CLOSED` periods are also not eligible for further
  assessment (only `OPEN` is listed as eligible) — this is a
  conservative reading of "do not invent reopening behaviour" rather
  than an explicitly documented pre-06B rule, and can be revisited as
  an explicit product decision later.
- Reads **only** the period's frozen `snapshot_penalty_*` columns —
  never the live `contribution_setups` row. A live setup edit after
  OPEN can never affect an already-OPEN period's penalty behaviour
  (and in practice, 06A's own `CONTRIBUTION_SETUP_CONFIG_LOCKED` guard
  already refuses to edit a setup's penalty fields once any period
  under it has posted, so this is enforced twice over).
- **Idempotent** at two levels: the assessment loop itself only ever
  posts an occurrence once its threshold is reached and it doesn't
  already exist, and a unique index —
  `contribution_charge_components_one_penalty_per_charge_sequence` on
  `(charge_id, sequence) where component_type = 'PENALTY'` — makes a
  duplicate impossible at the database level regardless of what any
  calling code does. Re-running the same `p_assessment_date` posts
  nothing new; advancing the date posts only the newly-due
  occurrences.
- Returns a server-computed summary only:
  `qualifying_charge_count`, `penalties_created_count`,
  `already_current_charge_count`, `total_penalty_assessed_this_run`.
  Flutter never derives any of these client-side.
- Eligibility is entirely inherited from which charges exist — a
  charge only exists for a member who was eligible at OPEN or was
  later explicitly enrolled (see "Explicit post-open enrollment"
  above). SUSPENDED/EXITED/excluded memberships never have a charge,
  so they're never penalized; an explicitly-enrolled member's charge is
  penalized exactly like any other overdue charge.

### Permission

`contribution.penalty.assess` (seeded in
`20260824090000_create_contribution_penalty_engine.sql`) — granted to
`ADMIN` and `TREASURER` only. Not granted to `CHAIRPERSON` (view/open/
close oversight only), `SECRETARY` (view only), or `MEMBER` (never a
group-wide financial mutation).

### Auditability

Every posted `PENALTY` component carries: `charge_id` (which original
charge), `sequence` (which occurrence), `effective_at` (the date the
occurrence's threshold was reached — not when it happened to be
posted; `created_at` remains the audit timestamp of the actual
database write), `assessed_amount`, and `group_id`. Nothing is ever
overwritten or deleted — a correction, if ever needed, would be an
explicit future adjustment/reversal concept, not an `UPDATE`/`DELETE`
on a posted `PENALTY` row (same rule as `BASE`).

### After `CLOSE`

Existing `PENALTY` components remain fully intact and queryable after
`CLOSE` — closing a period never touches posted charges/components.
Further penalty assessment is not available once `CLOSED` (see above).

## Corrections & opening balances (Prompt 06C)

Once a period is OPEN, its BASE/PENALTY components and charge identity
are locked — never `UPDATE`d or `DELETE`d. Any later correction is an
explicit new financial event, posted as one more row in
`contribution_charge_components`:

- **ADJUSTMENT** — a signed correction (`rpc_create_contribution_adjustment`).
  Positive increases the obligation, negative reduces it; never zero.
  A negative adjustment is rejected
  (`ADJUSTMENT_WOULD_MAKE_OBLIGATION_NEGATIVE`) if it would drive the
  charge's net assessed below zero.
- **WAIVER** — forgiveness of an already-charged obligation
  (`rpc_waive_contribution_charge`), distinct from an *exclusion*
  (which means the member was never charged at all). The caller always
  supplies a positive magnitude to waive; the backend always stores the
  component **negative** — Flutter never sends a signed waiver value,
  and never subtracts a positive waiver from a total itself. Rejected
  (`WAIVER_EXCEEDS_NET_ASSESSED`) if it would exceed the charge's
  current net assessed. A waiver never rewrites or deletes the
  PENALTY component it sits alongside, and is never payable — it only
  reduces debt, it does not create a payable line for a future
  payments module.
- **OPENING_BALANCE** — imported pre-Umoja debt
  (`rpc_import_contribution_opening_balances`), always positive.

Sign convention is enforced at the database level by the
`contribution_charge_components_amount_sign` CHECK constraint (added by
`20260825091000_create_contribution_corrections_and_opening_balances.sql`),
not merely by RPC logic:

| Component type | Stored sign |
|---|---|
| BASE / PENALTY / OPENING_BALANCE | always positive |
| ADJUSTMENT | either sign, never zero |
| WAIVER | always negative |

**Locked penalty interaction**: a later adjustment/waiver never
retroactively changes an already-posted PENALTY — 06B computes a
percentage penalty from the original BASE only, at assessment time,
and that is unaffected by any correction posted afterward.

**CLOSED-period corrections**: a CLOSED period stays CLOSED. An
adjustment or waiver may still post against one of its existing
charges as an explicit correction — this never reopens the period, and
never allows new normal enrollment into it.

**Idempotency**: both `rpc_create_contribution_adjustment` and
`rpc_waive_contribution_charge` accept an optional
`p_idempotency_key`; a retried call with the same
`(charge_id, component_type, key)` returns the original result
(`already_posted: true`) instead of posting again, enforced by the
partial unique index
`contribution_charge_components_idempotency_key_unique`.

**Opening balances** reuse 06A's model rather than inventing a
parallel table or a fake historical period: `rpc_import_contribution_opening_balances`
auto-provisions one system `contribution_setups` row
(`is_system = true`) and one system `contribution_periods` row
(`purpose = 'OPENING_BALANCE'`) per `(group, contribution_type,
effective_at)`, created directly `OPEN`. Both are excluded from the
normal `rpc_list_contribution_setups`/`rpc_list_contribution_periods`
listings, so an opening balance never pollutes a normal period report
— see `rpc_list_contribution_opening_balances` for the dedicated
report. Duplicate-import protection reuses 06A's existing
`unique(period_id, membership_id)` charge constraint rather than a new
mechanism. Import is atomic (two-pass validate-then-insert): a batch
containing one already-imported or invalid entry rejects the whole
batch, not just that row. A blank or zero amount for a member simply
means "no opening balance for that member" and is silently skipped —
only a negative amount is a validation error
(`OPENING_BALANCE_AMOUNT_MUST_BE_POSITIVE`). An opening balance never
creates a payment/cash/receipt row of any kind — only a
`member_contribution_charges` row plus one `OPENING_BALANCE` component.

**Read model**: `rpc_get_contribution_charge_detail` (per-charge
breakdown) and `rpc_get_member_contribution_summary` (the "Member
Contribution Obligation Summary", aggregated across all of a member's
charges) both expose `net_assessed` as the server-computed sum of every
component — Flutter never re-derives it. `rpc_get_contribution_period`
and `rpc_list_contribution_period_charges` were extended with
`total_adjustments_assessed`/`total_waivers_assessed`/`net_assessed_total`
(period-level) and `adjustment_amount`/`waiver_amount`/
`opening_balance_amount` (per-charge) without ever overwriting
`total_base_assessed`/`base_amount`, which always stay the original
BASE figures.

**Flutter**: the charge/member detail screen
(`ContributionChargeDetailScreen`, `/contributions/charges/:chargeId`)
shows the full breakdown and gates its Add Adjustment/Waive Obligation
actions on `contribution.adjustment.create`/`contribution.waiver.create`.
`ContributionAdjustmentFormScreen` converts an explicit
increase/reduce selector plus a positive magnitude into the signed
amount client-side before calling the repository — the user never
types a raw signed number. `ContributionWaiverFormScreen` shows the
backend-authoritative current net assessed/maximum waiver and
pre-fills the amount field for a full waiver, but never computes the
maximum itself. `ContributionOpeningBalancesScreen`/
`ContributionOpeningBalanceImportScreen` (`/contributions/opening-balances`,
gated on `contribution.opening_balance.manage`) provide the dedicated
report and the choose-type → effective-date → search-members →
amounts → server preview → confirm batch flow — the preview's member
count/total/already-imported flags are always the server's own, never
computed client-side.

## Permissions

New permission codes (seeded in
`20260823120000_create_contribution_engine_schema.sql`, `resource.action`
convention matching existing codes like `member.change_status`; the
final three seeded by 06C's migration):

| Code | Purpose |
|---|---|
| `contribution.view` | View types/setups/periods/all charges in the group |
| `contribution.type.manage` | Create/edit contribution types |
| `contribution.setup.manage` | Create/edit contribution setups |
| `contribution.period.manage` | Create/edit/cancel DRAFT/SCHEDULED periods |
| `contribution.period.open` | Preview + open a period |
| `contribution.period.close` | Close an OPEN period |
| `contribution.member_amount.manage` | Set per-member amounts (CUSTOM_PER_MEMBER) |
| `contribution.member_exclude` | Add/remove pre-open exclusions |
| `contribution.member_enroll` | Explicit post-open enrollment |
| `contribution.self_view` | View only the caller's own charges |
| `contribution.penalty.assess` | Run penalty assessment on an OPEN period (Prompt 06B, seeded in `20260824090000_create_contribution_penalty_engine.sql`) |
| `contribution.adjustment.create` | Post a contribution adjustment (Prompt 06C) |
| `contribution.waiver.create` | Waive a contribution obligation (Prompt 06C) |
| `contribution.opening_balance.manage` | Import contribution opening balances (Prompt 06C) |

Default role mapping:

| Role | Permissions |
|---|---|
| ADMIN | all fourteen |
| TREASURER | all except `contribution.self_view` (full `contribution.view` already covers it) |
| CHAIRPERSON | `contribution.view`, `contribution.period.open`, `contribution.period.close` |
| SECRETARY | `contribution.view` |
| MEMBER | `contribution.self_view` |

`contribution.penalty.assess` is deliberately scoped to `ADMIN`/
`TREASURER` only, matching every other group-wide financial mutation —
`CHAIRPERSON` keeps its lighter open/close oversight role without
gaining a financial-assessment trigger, and `MEMBER` can never trigger
group-wide penalty assessment.

Every mutation RPC follows the existing choke-point pattern: not
authenticated → `28000`; `assert_active_profile()`; then
`has_group_permission(group_id, '<code>')`, which itself already
requires an `ACTIVE` membership in an `ACTIVE` group (see
[docs/database/authorization.md](../database/authorization.md)). RLS on
every new table is enabled with no `USING (true)` policy, and there is
no direct client `INSERT`/`UPDATE`/`DELETE` grant on any of the seven
new tables — RPCs are the only mutation path, matching the
`group_memberships`/member-number precedent.

## What Prompt 06A deliberately does not build

No payments, receipts, payment allocation, wallet transactions,
financial accounts, cashbook entries, expenses, loan repayments, or
bank reconciliation. No `contribution_series` entity. No PASS_THROUGH
settlement/payout. No share redemption or share-to-loan offset. No
"paid"/balance concept anywhere in the UI — a charge existing is not
evidence anything has been collected. (Penalty *posting* is Prompt
06B, above — 06A only stored/snapshotted the configuration.)

## What Prompt 06B deliberately does not build

No payment recording, wallet deduction, cashbook posting, payment
allocation, receipt generation, bank integration, SMS reminders,
settlement, or arrears collection — a penalty being *assessed* is not
the same thing as it being *paid*, and none of those exist yet. No
multi-tier "penalty levels" table (see "Design decisions locked for
06B" above). No reopening of a CLOSED period to assess further
penalties.

## What Prompt 06C deliberately does not build

No payments, wallet, receipts, cashbook, financial accounts, loans, or
payment allocation logic — a WAIVER reduces debt, it does not create a
payable line for a future payments module to allocate against. No
fake historical monthly periods to carry opening balances (a single
system period per group/type/effective-date, explicitly flagged and
excluded from every normal listing, instead). No reopening of a CLOSED
period, and no retroactive change to an already-posted PENALTY. No
hard-delete of an adjustment/waiver/opening-balance row, ever — a
wrong correction is corrected only by another explicit compensating
entry.
