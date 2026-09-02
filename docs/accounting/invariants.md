# Accounting Invariants

This document records the non-negotiable architectural principles that
every future Umoja v2 task must obey. It is **not** the accounting
specification — it does not describe how contributions, penalties,
loans, wallet, or Hisa actually work.

> **Do not implement financial features without checking the relevant
> locked Umoja v2 accounting specification.**

## Invariants

- Cash movement is not automatically income or expense.
- One real payment creates one cash movement.
- Payment allocations do not create duplicate cashbook movements.
- Wallet allocations are non-cash internal ownership changes.
- Pass-through collections (e.g. Mzunguko, Rambirambi) are not group
  income.
- Pass-through payouts are not group expenses.
- Loan disbursement is a cash outflow but not an expense.
- Loan principal repayment is a cash inflow but not income.
- A draft loan account is not a cash transaction, not a funded
  receivable, and creates no income-recognition event — creating a
  loan account or generating/regenerating its repayment schedule posts
  no cashbook entry and must leave Financial Position unchanged (see
  [docs/product/loans.md](../product/loans.md)).
- A Loan Account snapshots its financial terms from its Loan Product at
  creation time; editing a Loan Product afterwards never alters any
  Loan Account already created from it.
- Submitting or approving a loan (Prompt 09B) is authorization only —
  neither creates a cashbook entry, a funded receivable, or income of
  any kind. Only disbursement moves money.
- A loan's principal becomes a funded receivable at the instant of
  disbursement, not before — and only ever by exactly the loan's
  frozen principal amount, never an arbitrary operator-entered figure.
- A loan's scheduled future interest is never recognized as group
  income at disbursement — it remains a separate, contractual
  "scheduled/unearned interest" figure until a later phase's repayment/
  interest-recognition policy says otherwise.
- A loan account may be disbursed at most once (Prompt 09B) — enforced
  structurally (a unique constraint), not merely by application logic.
- Once a loan has been disbursed, ordinary cancellation is blocked;
  financial correction of a disbursed loan is deferred to a future
  controlled reversal/correction phase, never solved by deleting
  cashbook/disbursement rows.
- Loan repayment reuses the existing Prompt 07 Payment Engine — one
  external repayment still creates exactly one cashbook INFLOW; a loan
  allocation is never a second cash event and never a competing
  ledger (Prompt 09C).
- Loan principal repayment reduces the funded principal receivable and
  is never counted as group income.
- Loan interest is recognized as group income only at the instant an
  allocation actually settles it — never merely because it is
  scheduled, and never both as "scheduled/unearned" and "recognized"
  at once.
- Wallet-to-loan settlement, like wallet-to-contribution settlement,
  creates zero cashbook movement.
- A loan closes only when its principal AND interest are both fully
  settled across every installment — never merely by payment amount or
  installment count — and a payment reversal that restores outstanding
  debt on a CLOSED loan reopens it, audited, never leaving it CLOSED
  with positive outstanding debt.
- A loan installment is automatically allocatable only when its
  `due_date` is on or before the payment's own effective date — an
  ordinary payment, however large, never silently prepays a future
  installment, never recognizes its scheduled interest early, and
  never closes a loan ahead of its actual due dates (Prompt
  09C-UAT-FIX-01). Explicit loan prepayment is a separate, deferred
  policy decision. Contribution allocatability is unaffected — a
  not-yet-due contribution charge remains a valid early-payment target.
- Assessing a loan penalty (Prompt 09D) is a pure obligation increase —
  zero cash movement, zero cashbook entry, zero income — regardless of
  how overdue the installment is. Income is recognized only when an
  active payment or wallet allocation actually settles `LOAN_PENALTY`.
- A loan penalty's calculation basis is the installment's current
  principal + interest outstanding only; it never includes that same
  installment's own existing penalty outstanding (no penalty-on-penalty
  compounding, ever).
- Within one loan installment, penalty is allocated before interest,
  and interest before principal; the reuse of the existing Payment
  Engine and its "exactly one cashbook INFLOW per external payment"
  invariant is unaffected by adding a third loan allocation target.
- A loan closes only when its principal, interest, AND penalty are all
  fully settled across every installment — never merely principal and
  interest — and a payment reversal that restores any of the three on
  a CLOSED loan reopens it, audited, never leaving it CLOSED with
  positive outstanding debt of any kind.
- A loan is either NEW (originated inside Umoja — the normal
  DRAFT-to-ACTIVE lifecycle and real disbursement) or MIGRATED (already
  funded before the group started using Umoja, posted as an opening
  financial position via `rpc_create_migrated_loan`, Prompt
  09D-UAT-BLOCKER-01) — every pre-existing loan defaults to NEW, never
  inferred from dates.
- Posting a migrated loan creates funded principal receivable directly
  as an opening position — it NEVER creates a cashbook entry, income,
  expense, a payment, a receipt, or a fake `loan_disbursements` row,
  and it never requires a Financial Account. Crediting a Financial
  Account with fake "opening balance" income and then "disbursing" it
  back out is forbidden even though cash nets to zero — it would
  falsely report income, cash movement, and a disbursement that never
  happened.
- A migrated loan's funded-principal contribution to Financial Position
  is its `opening_principal_outstanding`, never its historical
  `original_principal` (most of which may already have been repaid
  before Umoja) — using the original figure would permanently overstate
  the receivable with no installment ever able to pay it off.
- A migrated loan's opening principal arrears, interest arrears, and
  penalty arrears are three distinct obligations, never merged into one
  generic figure — their accounting treatment differs (principal
  arrears repayment is never income; interest/penalty arrears are
  recognized as income only when actually allocated after onboarding,
  exactly like a NEW loan's scheduled interest/penalty).
- An opening penalty (already owed as of migration) is tracked
  separately from a penalty later assessed by the 09D Penalty Engine,
  but both settle through the same Payment Engine and both recognize
  income identically on allocation — an opening penalty never blocks or
  renumbers a fresh assessment on the same installment, and the 09D
  penalty basis excludes ALL existing penalty (opening or previously
  assessed) regardless of origin.
- A migrated loan's opening position (`loan_opening_positions`) is
  immutable once posted — no RPC edits or deletes one; a data-entry
  mistake requires a future controlled correction workflow, not yet
  implemented.
- A migrated loan may have zero or more SEPARATE historical overdue
  installments (Prompt 09D-UAT-BLOCKER-02) — never one synthetic row
  combining them. Each preserves its own real due date, principal/
  interest/opening-penalty outstanding, and is settled independently
  (oldest due date first, penalty before interest before principal),
  assessed independently by the 09D Penalty Engine, and reported
  independently — exactly like any loan with multiple overdue
  installments. `loan_opening_positions`' aggregate arrears columns are
  DERIVED from these rows, never an independent source of truth, and
  can never drift from them.
- A Simple-Import migrated loan (Prompt 09D-UAT-BLOCKER-04) requires the
  ORIGINAL LOAN TERM and derives `paid_before_umoja_count = original_term
  - historical_unpaid_count - remaining_future_count` (rejected if
  negative). The full original contractual schedule is reconstructed
  first and classified oldest-first into PAID_BEFORE_UMOJA (historical
  context only — never persisted, never a fake payment/receipt/
  cashbook/income row), HISTORICAL_OVERDUE, and FUTURE. The opening
  funded principal receivable is the sum of ONLY the HISTORICAL_OVERDUE
  + FUTURE installments' principal — never the full original principal
  when some installments were already settled before Umoja (the
  BLOCKER-03 bug this fixes). Every installment's contractual amount
  (including the term's own final-installment reconciliation
  adjustment) is fixed by its POSITION in the original schedule, never
  by which bucket it is classified into, and a regular contractual
  installment amount is never redistributed into a different repeated
  value by re-splitting an aggregate total.
- A Simple-Import migrated loan (Prompt 09D-UAT-BLOCKER-03) derives its
  historical arrears/principal/interest breakdown SERVER-SIDE from the
  original contract terms and the total historical arrears alone — the
  user never enters a per-installment breakdown. Its legacy/opening
  penalty (`total_historical_arrears` minus the derived contractual
  arrears) is a BROUGHT-FORWARD BALANCE ONLY, distributed across
  historical installments purely as an import/reporting allocation
  (equal split, remainder on the most recent installment) — never a
  claim that historical penalty was actually assessed
  installment-by-installment, and never a reconstruction of whatever
  pre-Umoja penalty rule (whole-balance, compounding, or otherwise)
  produced that figure. `total_historical_arrears` below the derived
  contractual arrears is rejected, never silently turned into a
  negative penalty.
- A migrated loan is never posted before its full historical + future
  schedule has been previewed server-side (Prompt 09D-UAT-BLOCKER-03,
  `rpc_preview_migrated_loan`) — the preview writes to zero tables, and
  posting (`rpc_create_migrated_loan`) always independently recomputes
  the same figures from the raw contract inputs, never trusting a
  Flutter-held preview payload as authoritative.
- Flutter's shared money input (`ThousandsInputFormatter`) and display
  (`formatAmount`) formatters are the ONLY amount-entry/display
  components in the app — no screen may reimplement its own currency
  formatter — and both cap at 2 decimal places, matching every
  authoritative money column's `numeric(14, 2)` scale. Flutter never
  computes authoritative money in binary floating-point; every
  calculation remains server-side exact `numeric`.
- Hisa/share capital is not normal group income.
- Internal transfers between a group's own financial accounts are not
  income or expense — they net to zero across the group and are
  excluded from income/expense totals.
- Financial reconciliation compares the derived ledger balance against
  an external statement/count; it never automatically adjusts the
  ledger. A non-zero difference is recorded as evidence only.
- A correction to a posted financial entry is always a reversal
  followed by a new, correct entry — never an in-place edit of the
  original.
- Umoja v2 does not implement a full double-entry general ledger
  (Phase 08B and earlier) — the cashbook plus `source_type`
  classification tags are the model; do not assume ledger accounts,
  debits/credits, or a chart of accounts exist anywhere in the schema.
- Financial balances must be reproducible from authoritative ledgers.
- Posted financial history is never silently edited or deleted.
- `effective_at` and `created_at` are distinct (see
  [docs/database/conventions.md](../database/conventions.md)).
- The backend/database is the source of truth for financial calculations.
- Flutter must not calculate authoritative financial balances
  independently — it displays server-derived state.

See also [docs/database/conventions.md](../database/conventions.md) for
the schema-level rules that enforce these invariants.
