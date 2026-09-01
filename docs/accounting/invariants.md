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
