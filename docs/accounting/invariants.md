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
- Hisa/share capital is not normal group income.
- Financial balances must be reproducible from authoritative ledgers.
- Posted financial history is never silently edited or deleted.
- `effective_at` and `created_at` are distinct (see
  [docs/database/conventions.md](../database/conventions.md)).
- The backend/database is the source of truth for financial calculations.
- Flutter must not calculate authoritative financial balances
  independently — it displays server-derived state.

See also [docs/database/conventions.md](../database/conventions.md) for
the schema-level rules that enforce these invariants.
