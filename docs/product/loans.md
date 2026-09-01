# Loans — Product, Account, Schedule, Workflow & Disbursement (Prompts 09A/09B)

Prompt 09A built the foundational Loan Engine data model: Loan
Products, DRAFT Loan Accounts, and server-generated repayment
schedules. Prompt 09B extends it with the full pre-repayment lifecycle
— Submit → Approve/Reject → Disburse — and atomic disbursement against
a real Financial Account. Both phases together still implement **no**
repayment posting, payment allocation, penalties, restructuring,
refinancing, write-off, disbursement reversal, or guarantors/
collateral. Those are later phases (09C Repayment/Payment Integration,
09D Penalties/Restructuring, a future controlled reversal/correction
phase, ...).

## Why this exists

Before this phase, no loan concept existed anywhere in the schema.
This phase establishes the vocabulary and schema that every later loan
phase builds on: a group's reusable lending policy (Loan Product), one
member's specific loan instance (Loan Account), and its planned
repayment obligations (Loan Installments) — without touching money at
all.

## Core distinction: Product vs Account vs Schedule

- **Loan Product** (`loan_products`) — a group's reusable lending
  policy/configuration: code, name, principal bounds, term bounds,
  interest rate/basis/method, repayment frequency. Never a member's
  loan itself.
- **Loan Account** (`loan_accounts`) — one specific member's loan
  instance, created from a Loan Product. Identified by a
  server-generated `loan_number` (`<CODE>-LN-<YEAR>-<SEQ4>`, e.g.
  `STD-LN-2026-0001`).
- **Loan Installment** (`loan_installments`) — one scheduled repayment
  obligation belonging to a Loan Account: due date, principal due,
  interest due. Planned only — never collectible debt until a later
  phase disburses/activates the loan.

## Product snapshot rule

A Loan Account **freezes** every financial term (principal, interest
rate/basis/method, term, repayment frequency) from its Loan Product at
creation time. `loan_accounts.loan_product_id` is kept for provenance
only — it is never re-read live. Editing a Loan Product afterwards
(rate change, deactivation, term-bound change) never affects any Loan
Account already created from it. This is why the Loan Product edit
form only allows changing `name`/`description`/`is_active` — code,
principal/term bounds, interest rate/basis/method are create-only,
since a live edit to those fields would have no defined effect on
existing loans and would be misleading to show as editable.

## What is, and is not, a cash/income event (accounting)

A DRAFT, SUBMITTED, or APPROVED loan account is:

- **not** a cash transaction — creating/submitting/approving one posts
  no `financial_account_entries` row and moves no money.
- **not** a funded receivable — no debt exists yet; nothing is owed by
  anyone. Approval is authorization only.
- **not** an income-recognition event — generating/regenerating a
  schedule, submitting, or approving never touches income/expense.

Disbursement (09B) is the one and only point where this changes:

- **is** a cash OUTFLOW (physical funds decrease by exactly the
  principal).
- **is not** an expense — `financial_manual_entries` is never touched;
  the disbursement's cashbook entry is classified via
  `source_type = 'LOAN_DISBURSEMENT'`, a distinct classification from
  `EXPENSE`.
- **activates** the loan's principal as a funded receivable
  (`funded_loan_principal_receivable` in Financial Position) — the
  loan moves straight to `ACTIVE`.
- **does not** recognize the loan's scheduled future interest as group
  income — that stays a separate `scheduled_unearned_interest` figure
  in Financial Position; interest recognition policy is 09C's job, not
  09B's.

Financial Position (`docs/product/financial_operations.md`) is
provably unaffected by a DRAFT loan's creation, terms edit, schedule
regeneration, submission, or approval — pgTAP tests
`42_loan_regeneration_isolation_tenancy.test.sql` (item 50) and
`46_loan_disbursement_financial_position.test.sql` assert this, and
the same suite proves the *only* things that change on disbursement
are `total_financial_account_balance` (down by the principal) and
`funded_loan_principal_receivable` (up by the same amount) —
`expenses`, `group_income`, `pass_through_received`, and
`member_wallet_liability` are all byte-for-byte unchanged.

## Loan Account status lifecycle

`loan_account_status` enum: `DRAFT`, `SUBMITTED`, `APPROVED`,
`REJECTED`, `CANCELLED`, `DISBURSED`, `ACTIVE`, `CLOSED`.

Implemented transitions (09A + 09B):

```
DRAFT ──submit──▶ SUBMITTED ──approve──▶ APPROVED ──disburse──▶ ACTIVE
  │                   │                      │
  └──cancel──▶ CANCELLED ◀──cancel───────────┘
                   ▲
                   └──reject── SUBMITTED
```

- `DRAFT`: freely editable (terms, schedule regeneration), or
  submitted, or cancelled (no reason required).
- `SUBMITTED`: terms and schedule are **frozen** — no ordinary edit or
  regenerate is possible (both RPCs still require `DRAFT`). Can be
  approved, rejected (reason mandatory), or cancelled (reason
  mandatory).
- `APPROVED`: authorization only, still zero cash impact. Can be
  disbursed, or cancelled (reason mandatory) — but never once a
  disbursement has actually occurred.
- `REJECTED` / `CANCELLED`: terminal. Historically readable, schedule
  stays a historical/planned record, can never be disbursed. Nothing
  is ever hard-deleted.
- `DISBURSED`: **deliberately not a durable, observable status** — see
  below.
- `ACTIVE`: the funded/collectible resting state after disbursement.
  No edit/regenerate/cancel action exists here; a future controlled
  reversal/correction phase (not 09B) would handle any mistake.
- `CLOSED`: reserved for a later phase (loan fully repaid).

### Why DISBURSED is transactional, not durable

`rpc_disburse_loan_account()` moves a loan straight from `APPROVED` to
`ACTIVE` inside one atomic call — the `DISBURSED` status value exists
in the enum (and as an `event_type`) but is never left as the loan's
resting `status`. Introducing a separate observable `DISBURSED` state
between "money moved" and "loan is collectible" would be a meaningless
extra transition for 09B: nothing in this phase inspects or acts on a
loan differently between those two instants, so the schedule and
column reserve the value (for a future phase that might need it, e.g.
a disbursement queued for a later date) without 09B pretending it is a
real, separately-reachable state today.

## Lifecycle audit trail — `loan_account_events`

Every transition (including the original `CREATED`) is recorded as one
immutable row in `loan_account_events`: `event_type`, `from_status`,
`to_status`, an optional `reason`, and the actor/timestamp via
`created_by`/`created_at`. This table is an **audit trail, not a
second source of current-status truth** — `loan_accounts.status`
remains the only authoritative current status. Rather than
accumulating `submitted_at`/`submitted_by`/`approved_at`/`approved_by`/
`rejected_at`/`rejected_by`/`rejection_reason`/`cancelled_at`/
`cancelled_by`/`cancellation_reason` as ever-growing columns on
`loan_accounts`, every one of those facts is recoverable from this one
table's history instead.

This is also the **maker/checker foundation** (never enforced as a
hard rule in 09B, but structurally ready for one): "who created", "who
submitted", "who approved", "who rejected", "who cancelled", and "who
disbursed" are all independently queryable without any schema change —
see Permissions below for how 09B's own role mapping already separates
the submit/disburse actor from the approve/reject actor.

No client role ever gets an INSERT/UPDATE/DELETE grant on
`loan_account_events` — every row is written internally by a
`SECURITY DEFINER` lifecycle RPC.

## Borrower rules

The borrower is a `group_memberships` row (`membership_id`), never a
`user_id` — matching the CLAUDE.md rule that a domain member and an
authenticated user are not the same thing. A loan account can only be
created for a membership whose `membership_status = 'ACTIVE'`
(`LOAN_ACCOUNT_BORROWER_NOT_ACTIVE` otherwise) — a suspended or exited
member cannot start a new loan, though an already-existing loan is
unaffected by a later status change (out of scope here; a later phase
governs in-flight loans against membership status changes).

## Schedule math

Both formulas are computed **only** on the server
(`loan_schedule_compute()`), a pure/stable SQL function used
identically by the pre-persistence preview RPC
(`rpc_preview_loan_schedule`) and the persisting
`loan_schedule_generate()` — Flutter never reimplements either formula
and only ever renders what the server returns.

- **FLAT**: interest is a constant amount per installment, computed
  from the original principal for every installment
  (`principal * rate_per_period`). Principal is split evenly across
  installments (see rounding below).
- **REDUCING_BALANCE**: interest per installment is computed against
  the declining outstanding principal balance, so successive
  installments' interest strictly decreases.

`interest_rate_basis` (`MONTHLY` or `ANNUAL`) is normalized to a
per-period rate before either formula runs; `ANNUAL` divides by 12 for
a monthly repayment frequency.

### Rounding / exact-money policy

Money math never loses or fabricates a shilling. Each principal (and
FLAT interest) split computes `base = trunc(total / n, 2)` — always
rounds down for positive amounts — then `remainder = total - base * n`.
Every installment gets `base` except the **final** installment, which
gets `base + remainder`. This guarantees `sum(installments) = total`
exactly, with any rounding remainder landing on the last installment.

### Month-end / date generation policy

Every installment's due date is anchored to the loan's own
`first_repayment_date` plus `(installment_number - 1)` months —
**never** cumulatively added from the previous installment's date.
PostgreSQL's `date + interval 'N months'` clips to the last valid day
of the target month when anchored this way (e.g. `2026-01-31 + 1/2/3
months` → Feb 28 / Mar 31 / Apr 30, not drifted), and correctly
advances leap years (`2024-01-31 + 1 month` → Feb 29). Anchoring to the
original date on every installment, rather than adding one month to
the previous installment's due date, is what prevents cumulative
drift across a schedule spanning a short month.

## Schedule regeneration

`rpc_regenerate_loan_schedule()` only operates on a `DRAFT` loan
account (`LOAN_ACCOUNT_NOT_DRAFT` otherwise). It atomically deletes
every existing `loan_installments` row for that loan account and
re-inserts from `loan_schedule_compute()` using the loan's own current
frozen terms — never partially applied, and never available once a
loan has left DRAFT.

## Disbursement (Prompt 09B)

`loan_disbursements` is one immutable row per successfully-disbursed
loan, linked to exactly one `financial_account_entries` OUTFLOW via
`financial_account_entry_id`. `rpc_disburse_loan_account()` runs
atomically — in Postgres, a single `SECURITY DEFINER` function
invocation is one transaction, so any failure anywhere in the function
(inactive/cross-group financial account, insufficient balance, wrong
loan status) rolls back everything already attempted in that call:
zero disbursement row, zero cashbook row, zero status change.

- **One disbursement per loan, structurally enforced**: a `UNIQUE`
  index on `loan_disbursements(loan_account_id)` makes a second
  disbursement for the same loan impossible at the database level,
  not merely rejected by application logic — this holds even under
  concurrent requests, since the unique-index violation is atomic
  under Postgres MVCC. 09B implements one full-principal disbursement
  only; partial/multiple-tranche disbursement is out of scope.
- **Amount is never operator-entered**: the disbursed amount is always
  exactly `loan_accounts.principal_amount`. The Flutter disbursement
  screen shows this amount read-only; there is no field to type a
  different figure, and no fee-netting exists in 09B.
- **Financial account requirement**: the operator must choose an
  *active* Financial Account (Cash/Bank/Mobile Money) belonging to the
  same group. The account is row-locked (`for update`) and its balance
  re-checked against the loan's principal using the exact same
  `financial_account_balance()` helper every other cash-moving RPC
  uses — insufficient balance raises
  `LOAN_DISBURSEMENT_INSUFFICIENT_BALANCE` and aborts the entire
  operation before any row is written.
- **Idempotency**: an optional `p_idempotency_key`, checked the same
  way `rpc_record_financial_account_transfer()` already does — a retry
  with the same key against an already-`ACTIVE` loan returns the
  original result (`already_posted: true`) instead of posting again. A
  retry *without* a matching key against an already-disbursed loan is
  a genuine `LOAN_ACCOUNT_ALREADY_DISBURSED` error, never a silent
  no-op.
- **Cashbook classification**: `source_type = 'LOAN_DISBURSEMENT'`,
  `entry_type = 'OUTFLOW'` — reuses the exact same
  `financial_account_post_entry()` internal helper every other 08A/08B
  posting RPC calls; there is no second cash ledger anywhere in this
  codebase. The cashbook read model (`rpc_list_financial_account_entries`)
  resolves the loan's number and borrower name for display, the same
  way a PAYMENT row resolves its receipt number.
- **`effective_at` vs `created_at`**: kept separate like every other
  financial posting in this codebase — `effective_at` is the
  economic/cash date the operator chooses (bounded like every other
  financial-account date field); `created_at` is the audit timestamp
  and is never backdated.

### Reversal is deferred

Once a loan has actually been disbursed, ordinary cancellation is
blocked (`rpc_cancel_loan_account` only accepts `SUBMITTED`/`APPROVED`)
— there is no "un-disburse" in 09B. Financial correction of a
mistakenly-disbursed loan is deferred to a future, deliberately
controlled loan-correction/reversal phase; this is never solved by
deleting `loan_disbursements`/`financial_account_entries` rows.

## Loan numbering

`loan_number_counters (group_id, year, last_number)` backs a
concurrency-safe `next_loan_number()` (`INSERT ... ON CONFLICT
(group_id, year) DO UPDATE SET last_number = last_number + 1 RETURNING
last_number`), formatted by `generate_loan_number()` as
`<PRODUCT_CODE>-LN-<YEAR>-<SEQ4>` — the same server-generated,
per-group-per-year counter pattern already used for member numbers.

## Permissions

- `loan_product.view` / `loan_product.manage` — view / create-edit
  Loan Products.
- `loan.view` / `loan.create` / `loan.edit` — view / create draft /
  edit-cancel draft Loan Accounts.
- `loan_schedule.view` / `loan_schedule.generate` — view schedule /
  preview and regenerate schedule.
- `loan.submit` / `loan.approve` / `loan.reject` / `loan.cancel` /
  `loan.disburse` (Prompt 09B) — the workflow/disbursement actions.

09A's ADMIN/TREASURER-full, CHAIRPERSON/SECRETARY-view-only,
MEMBER-none posture continues, but 09B's five new permissions are
deliberately **not** granted en bloc to both ADMIN and TREASURER —
**separation of duties** is built into the mapping itself:

| Role | 09B grants |
| --- | --- |
| ADMIN | all five (submit, approve, reject, cancel, disburse) |
| TREASURER | submit, cancel, disburse — the group's financial executor |
| CHAIRPERSON | approve, reject, cancel — the group's governance decision-maker |
| SECRETARY | none (still view-only from 09A) |
| MEMBER | none |

TREASURER can submit and disburse but **cannot** approve/reject; only
CHAIRPERSON (or ADMIN) can approve/reject. This means the actor who
creates/submits/disburses a loan is never, by permission alone, the
same actor who decides whether to approve it — a real maker/checker
split, not merely a documented convention. Enforced by RLS and each
RPC's own `SECURITY DEFINER` permission check, using permission codes
only — no RPC ever checks a role name directly. Flutter's
permission-gated UI (hiding every action a caller cannot perform) is
UX only, never the authorization boundary.

## Multi-tenancy

Every table and RPC is group-scoped exactly like every other Umoja v2
domain: RLS restricts all reads to the caller's own group membership(s)
with the matching `.view` permission, and every mutating RPC takes an
explicit `p_group_id` and re-derives/validates it server-side. pgTAP
test `42_loan_regeneration_isolation_tenancy.test.sql` proves this with
a caller holding full legitimate ADMIN access to a *second* group,
showing zero Group A data leaks even then (not merely "no access at
all").

## Flutter module

`/loans` (Mikopo) — deliberately minimal landing (Aina za Mikopo +
Akaunti za Mikopo), mirroring Fedha's "no excessive sidebar entries"
precedent. The New Loan workflow (`/loans/accounts/new`) is a locked
five-step flow: Borrower (member search, active-only) → Product
(active products only) → Terms (principal/term/first repayment date)
→ Schedule Preview (`rpc_preview_loan_schedule`, rendered read-only) →
Save Draft.

Loan Account Detail (`/loans/accounts/:id`) renders actions purely by
status + permission — never merely disabled for an unauthorized user,
hidden outright instead:

- `DRAFT`: Edit, Regenerate, Submit, Cancel (no reason).
- `SUBMITTED`: Approve, Reject (`/reject`, reason mandatory), Cancel
  (`/cancel`, reason mandatory).
- `APPROVED`: Disburse (`/disburse`), Cancel (`/cancel`).
- `ACTIVE`/`DISBURSED`: no edit/regenerate/cancel — shows the
  disbursement detail (financial account, amount, effective date,
  reference) and the funded schedule instead.
- `REJECTED`/`CANCELLED`: read-only history, showing the recorded
  reason from `loan_account_events`.

Submit shows a confirmation summary (borrower, loan number, product,
principal, interest, term, total scheduled interest, total repayment,
first repayment date) and explicitly warns that terms freeze on
submission ("Wasilisha kwa Idhini"). Approve and Reject are always two
separate actions/confirmations, never combined. The Disburse screen
("Toa Mkopo") shows the loan's principal read-only, an active-accounts-
only financial account picker with each account's live balance, an
effective-date picker, optional reference/notes — and deliberately
**no expense-category selector anywhere**, since a loan disbursement
is not an expense. A final confirmation names the exact amount,
source account, and borrower before the RPC is ever called.

No Approve/Disburse/Receive-Payment-style action exists as a disabled
placeholder anywhere — an unauthorized user simply does not see the
button, matching every other module's convention; the backend RPC
permission check remains the actual authorization boundary regardless
of what Flutter renders.

## Deferred to later phases

- 09C: repayment posting, payment allocation against installments,
  interest income recognition policy.
- 09D: penalties, restructuring, refinancing, write-off.
- A future controlled loan-correction/reversal phase: financial
  correction of a mistakenly-disbursed loan (09B deliberately does not
  implement this — see "Reversal is deferred" above).
- Guarantors/collateral, if required, are deferred until a phase that
  actually needs them.
