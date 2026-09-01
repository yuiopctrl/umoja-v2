# Loans — Product + Account + Schedule Foundation (Prompt 09A)

Prompt 09A builds only the foundational Loan Engine data model: Loan
Products, DRAFT Loan Accounts, and server-generated repayment
schedules. It deliberately implements **no** loan approval,
disbursement, cashbook movement, repayment/payment allocation,
penalties, restructuring, refinancing, write-off, reversal, or
guarantors/collateral. Those are later phases (09B Approval +
Disbursement, 09C Repayment/Payment Integration, 09D Penalties/
Restructuring, ...).

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

## What this is not (accounting)

A DRAFT loan account is:

- **not** a cash transaction — creating one posts no
  `financial_account_entries` row and moves no money.
- **not** a funded receivable — no debt exists yet; nothing is owed by
  anyone.
- **not** an income-recognition event — generating or regenerating a
  repayment schedule never touches income/expense.

Financial Position (`docs/product/financial_operations.md`) is
provably unaffected by a DRAFT loan's creation, terms edit, or
schedule regeneration — pgTAP test `42_loan_regeneration_isolation_tenancy.test.sql`
item 50 asserts byte-for-byte identical Financial Position output
before and after creating a draft loan.

## Loan Account status lifecycle

`loan_account_status` enum: `DRAFT`, `SUBMITTED`, `APPROVED`,
`REJECTED`, `CANCELLED`, `DISBURSED`, `ACTIVE`, `CLOSED`. **Only
`DRAFT` and `CANCELLED` are reachable in Prompt 09A** — every other
value is reserved for later phases (09B+). A DRAFT loan account can
only be edited, have its schedule regenerated, or be cancelled; it can
never be approved or disbursed from this phase's UI or RPCs.

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

ADMIN and TREASURER hold every loan permission; CHAIRPERSON and
SECRETARY hold only the `.view` permissions (no manage/create/edit/
generate); MEMBER holds none. Enforced by RLS and each RPC's own
`SECURITY DEFINER` permission check — Flutter's permission-gated UI
(hiding New Loan Product/New Loan/Regenerate/Cancel actions) is UX
only, never the authorization boundary.

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
precedent. The New Loan workflow
(`/loans/accounts/new`) is a locked five-step flow: Borrower (member
search, active-only) → Product (active products only) → Terms
(principal/term/first repayment date) → Schedule Preview
(`rpc_preview_loan_schedule`, rendered read-only) → Save Draft. No
Approve/Disburse/Receive Payment action exists anywhere in this
module, not even as a disabled placeholder — those routes/screens do
not exist until 09B/09C.

## Deferred to later phases

- 09B: loan approval workflow, disbursement (cash outflow, financial
  account posting).
- 09C: repayment posting, payment allocation against installments.
- 09D: penalties, restructuring, refinancing, write-off, reversal.
- Guarantors/collateral, if required, are deferred until a phase that
  actually needs them.
