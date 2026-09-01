# Financial Operations, Cashbook, Reconciliation & Financial Position (Prompt 08B)

Extends the Prompt 08A cashbook foundation
([docs/product/financial_accounts.md](financial_accounts.md)) with the
group's own income/expense recording, reconciliation against external
statements, controlled adjustments, and a read-only Financial Position
report. Builds directly on 08A's `financial_accounts` /
`financial_account_entries` — there is no parallel cashbook or account
model.

## What this is not

Per the prompt's explicit scope lock, this phase does **not**
implement: loans, a full double-entry general ledger (see
[docs/accounting/invariants.md](../accounting/invariants.md)), bank API
integration, or expense approval workflows beyond the permissions
below. Those remain later phases.

## Classification design — reused, not duplicated

08B adds no new classification column. It extends the same
`financial_account_entries.source_type`/`source_id` polymorphic tag
08A/Prompt 07 already established, with five new values:
`'MANUAL_INCOME'`, `'EXPENSE'`, `'MANUAL_INCOME_REVERSAL'`,
`'EXPENSE_REVERSAL'`, `'FINANCIAL_ADJUSTMENT'` (alongside the existing
`'PAYMENT'`, `'PAYMENT_REVERSAL'`, `'TRANSFER'`, `'OPENING_BALANCE'`).

## Financial categories

`financial_categories` — group-owned, `category_type` INCOME/EXPENSE,
unique per `(group_id, category_type, lower(name))`. Deactivating never
deletes a category, so historical entries keep their category
identity. `rpc_seed_default_financial_categories` seeds standard
Swahili-named categories on request — deliberately **not** hooked into
`rpc_create_group`, to avoid touching locked Prompt 02 tenancy code for
a non-essential nicety.

## Manual income / expense

`rpc_record_manual_income` / `rpc_record_expense` — both row-lock the
target account, validate the category's type/active state, and post
exactly one cashbook entry via the same `financial_account_post_entry()`
choke point 08A established. An expense is never allowed to overdraw
the account by default (`FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE`, the
same guard 08A's transfer path uses). Idempotent on
`(financial_account_id, idempotency_key)`, matching Prompt 07's
payment-posting convention.

## Reversal — never an in-place edit

`rpc_reverse_financial_manual_entry` posts one compensating entry in
the opposite direction (using `reverses_entry_id`, per 08A's reversal-
safe design) and marks the original `financial_manual_entries` row
REVERSED. The original is never edited or deleted. A wrong entry is
corrected by reversing it, then posting a new, correct one — there is
no other correction path anywhere in this phase.

## Contribution accounting treatment (GROUP_INCOME / PASS_THROUGH / SHARE_CAPITAL / MEMBER_SAVINGS)

Financial Position must not simply sum all payment inflows as income —
a Mzunguko/Rambirambi-style pass-through collection and Hisa/share
capital are not group income. `contribution_types.accounting_treatment`
is the authoritative classification, and it becomes **permanently
locked** the first time a period under that type is ever opened
(`contribution_type_has_posted_period()`, enforced inside
`rpc_update_contribution_type`). Because allocation against a charge
requires an OPEN period, any contribution type that could ever have a
payment allocated against it already has its treatment locked from
that point on — so a live join
(`payment_allocations → member_contribution_charges → contribution_setups → contribution_types.accounting_treatment`)
is safe for historical reporting. No new snapshot column was needed.

## Reconciliation

`financial_reconciliations` — compares the authoritative derived
balance (`financial_account_balance()`) against a stated
bank/mobile/cash-count figure at a point in time. `difference =
stated_balance - system_balance`, always server-computed. **Never posts
a cashbook entry of its own** — it is pure evidence. A non-zero
difference is recorded as-is; the only way to actually correct the
ledger is a separate, explicit Financial Adjustment. Immutable after
creation except the single RECONCILED → CANCELLED transition
(`rpc_cancel_financial_reconciliation`, requires a reason) — a
cancelled record is never deleted, only marked cancelled.

## Financial adjustment

`financial_adjustments` — a highly-permissioned, explicit correction
for a verified real-world discrepancy (e.g. after a reconciliation),
posted via `source_type = 'FINANCIAL_ADJUSTMENT'` so it is never
counted as ordinary income/expense in Financial Position. Always
requires a reason. `direction` is INCREASE or DECREASE; a DECREASE is
subject to the same insufficient-balance guard as an expense.

## Financial Position ("Hali ya Fedha")

`rpc_get_financial_position(group_id, date_from, date_to)` — explicitly
**not** presented as a full accounting balance sheet. Returns, as
distinct figures (never folded together):

- `accounts[]` / `total_financial_account_balance` — point-in-time,
  never period-bound.
- `group_income` / `expenses` / `net_operating_result` — period-bound
  when a range is given, unbounded otherwise. Only GROUP_INCOME-treated
  contribution inflows plus manual income count as income.
- `pass_through_received` / `share_capital_received` — shown
  separately, never added into `group_income`.
- `member_wallet_liability` — a liability figure, never deducted from
  cash or folded into the balance.
- `total_outstanding_member_obligations` — point-in-time.
- `funded_loan_principal_receivable` (Prompt 09B) — point-in-time sum
  of frozen principal across every DISBURSED/ACTIVE loan; increases
  only at the instant of disbursement, never before.
- `scheduled_unearned_interest` (Prompt 09B) — that same set of loans'
  contractual future interest, deliberately kept out of `group_income`
  — interest recognition is a Prompt 09C policy decision.

See [docs/product/loans.md](loans.md) for the full lifecycle
(Submit/Approve/Reject/Cancel/Disburse) that produces these two
figures.

No "current month" default is assumed server-side; an unbounded range
returns unbounded totals. Any default date range lives in the Flutter
date-range picker only.

## Permissions

| Code | Purpose |
|---|---|
| `financial_entry.view` | View manual income/expense entries and the cashbook |
| `financial_income.create` | Record manual income |
| `financial_expense.create` | Record an expense |
| `financial_entry.reverse` | Reverse a posted manual income/expense entry |
| `financial_reconciliation.view` | View reconciliation history |
| `financial_reconciliation.create` | Create/cancel a reconciliation |
| `financial_adjustment.create` | Record a financial adjustment |
| `financial_report.view` | View Financial Position |

| Role | Permissions |
|---|---|
| ADMIN | all |
| TREASURER | all |
| CHAIRPERSON | `financial_entry.view`, `financial_reconciliation.view`, `financial_report.view` |
| SECRETARY | `financial_entry.view`, `financial_report.view` |
| MEMBER | none |

`financial_entry.reverse` is a distinct permission from Prompt 07's
`payment.reverse` — reversing a manual income/expense entry and
reversing an external payment are different operations with different
accounting consequences, so they are never collapsed into one
permission key.

## Flutter

`app/lib/features/financial_accounts/` gained: a minimal Fedha
(`/finance`) home listing only Hali ya Fedha and Akaunti za Fedha (no
excessive sidebar entries — recording income/expense, reconciliation,
and adjustment all live per-account on Account Detail, since each needs
an account context first); `FinancialPositionScreen`; a shared
`ManualEntryFormScreen` parameterized by `entryKind` for both Record
Income and Record Expense (one screen, not two, since only the
category-type/RPC/permission/labels differ); `CashbookScreen` (the
full, filterable, paginated cashbook — Account Detail itself keeps only
a short recent-movements preview); `FinancialReconciliationScreen`
(form + live difference preview + history); `FinancialAdjustmentScreen`;
`FinancialEntryReversalScreen`; `FinancialCategoriesScreen`.

Two defects were found and fixed while building this out, both worth
knowing before adding further screens under `/finance`:

- **Route guard allowlist**: `_isOperationalRoute()` in
  `app/lib/app/routing/route_guard.dart` is an explicit allowlist of
  reachable-once-a-group-is-resolved paths. It did not know about the
  new `/finance` prefix, so the redirect guard silently bounced
  `/finance`, `/finance/position`, `/finance/categories`, and
  `/finance/entries/:id/reverse` back to `/home` on every navigation.
  Any future new top-level route prefix (not nested under an existing
  allowlisted one) needs its own entry here.
- **`ref.invalidate()` synchronously in `initState()`**: when a screen
  is reached via `context.push` from a screen that is *also* currently
  watching the exact same provider instance (e.g. pushing from Account
  Detail into a screen that invalidates
  `financialAccountDetailProvider(accountId)` for the same
  `accountId`), the outgoing screen is still mid-build during the push
  transition — invalidating synchronously calls `setState` on a widget
  currently building. `ManualEntryFormScreen`,
  `FinancialReconciliationScreen`, and `FinancialAdjustmentScreen` all
  hit this; fixed by deferring the invalidate to
  `WidgetsBinding.instance.addPostFrameCallback`. This only matters
  when the *same* provider+argument is plausibly still being watched by
  the pushing screen — 08A's `financial_account_transfer_screen.dart`
  invalidates a *different* provider (`financialAccountsActiveForPickerProvider`,
  unparameterized and not watched by the list screen it's pushed from)
  and was never affected.

## Deferred

Loans, full double-entry general ledger, bank API integration, expense
approval workflows, and a full Hisa/share-capital ledger all remain out
of scope for this phase.
