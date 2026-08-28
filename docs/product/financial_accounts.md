# Financial Accounts — Cashbook Foundation (Prompt 08A)

Prompt 08A is a **scoped dependency phase** pulled forward ahead of
Prompt 07 (Payments, Wallet, Allocations, Receipts). Before Prompt 07
could implement external payment posting, it needed a real place for
posted money to "land" — this document covers only that minimal
foundation.

## Why this exists

Prompt 07 requires every external payment to reference a real
financial account and to post exactly one cash movement. Before this
phase, no financial-account/cashbook concept existed anywhere in the
schema — only invariant statements in
[docs/accounting/invariants.md](../accounting/invariants.md) describing
what a future cashbook must obey. This phase builds just enough schema
to satisfy that dependency, so Prompt 07 does not have to invent one ad
hoc.

## What this is

- **`financial_accounts`** — a CASH/BANK/MOBILE_MONEY account,
  active/inactive, owned by one group. No hard delete; deactivate via
  `is_active`.
- **`financial_account_entries`** — the immutable cashbook. Every row
  is INFLOW, OUTFLOW, TRANSFER_IN, or TRANSFER_OUT, `amount` is always
  positive, and the entry type carries the sign meaning.
- **Server-derived balance** (`financial_account_balance()`) — credits
  (INFLOW + TRANSFER_IN) minus debits (OUTFLOW + TRANSFER_OUT). Never a
  stored/mutable column; always recomputed from the ledger.
- **Internal transfers** — an atomic pair of TRANSFER_OUT (source
  account) + TRANSFER_IN (destination account), sharing one
  `transfer_reference`. Money never leaves the group; this is not an
  external payment path.
- **Opening balances** — an account may be created with an initial
  positive amount, posted as its first INFLOW entry
  (`source_type = 'OPENING_BALANCE'`) in the same transaction as
  account creation. Blank/zero posts no entry at all (matches 06C's
  opening-balance convention); only negative is rejected.

## What this is not

This phase deliberately does **not** implement: contribution payments,
wallet, receipts, payment allocations, loans, bank statement
reconciliation, expense management UI, income analytics, or full
financial position/reporting. Those remain Prompt 07/08/09. There is no
manual "record an outflow" (expense) screen in this phase — the only
way money leaves an account here is an internal transfer.

## Reversal-safe posting architecture (extension point for Prompt 07)

Every `financial_account_entries` row carries:

- `source_type` / `source_id` — an unconstrained, nullable polymorphic
  tag (e.g. `'OPENING_BALANCE'`, `'TRANSFER'` today; `'PAYMENT'`,
  `'PAYMENT_REVERSAL'` once Prompt 07 exists) plus the id of whatever
  row caused the entry. No CHECK/FK ties this down, so later phases can
  add new source types without a schema change here.
- `reverses_entry_id` — a nullable self-reference. Reversing an entry
  never updates or deletes it — it posts a new, opposite entry that
  references the one it reverses. Unused in 08A (nothing here is
  reversible yet); Prompt 07's payment reversal is expected to use it
  directly.
- `idempotency_key` — optional, unique per `(financial_account_id,
  idempotency_key)`. A retried transfer with the same key returns the
  original result (`already_posted: true`) instead of posting again.

`financial_account_post_entry()` is the single internal INSERT path
into the cashbook — every RPC that posts an entry (opening balance,
transfer, and later Prompt 07's payment posting) calls it, so the
immutability/idempotency/reversal-safety rules live in exactly one
place.

## Immutability

No RPC ever issues `UPDATE`/`DELETE` against `financial_account_entries`,
and no client role is ever granted `UPDATE`/`DELETE` on it — the only
mutation path is `INSERT` via `financial_account_post_entry()`. A
correction is always a new, opposite entry, never an edit.

## Permissions

| Code | Purpose |
|---|---|
| `financial_account.view` | View financial accounts, balances, and cashbook entries |
| `financial_account.manage` | Create/rename/activate/deactivate accounts, including recording an opening balance |
| `financial_account.transfer.create` | Record an internal transfer between two of the group's own accounts |

| Role | Permissions |
|---|---|
| ADMIN | all three |
| TREASURER | all three |
| CHAIRPERSON | `financial_account.view` only |
| SECRETARY | `financial_account.view` only |
| MEMBER | none |

Financial accounts are internal group treasury records, not
member-personal data — unlike contribution charges, there is no "self"
view concept here, so MEMBER gets nothing.

## RPCs

- `rpc_create_financial_account` / `rpc_update_financial_account`
- `rpc_record_financial_account_transfer`
- `rpc_get_financial_account` / `rpc_list_financial_accounts`
- `rpc_list_financial_account_entries`

All follow the existing choke-point pattern: not authenticated →
`28000`; `assert_active_profile()`; `has_group_permission(group_id,
'<code>')` (which itself already enforces ACTIVE profile/membership/
group); `SECURITY DEFINER` with `set search_path = ''`; explicit
REVOKE/GRANT per role; cross-group access blocked. RLS is enabled on
both tables with no `USING (true)` policy and no direct client
INSERT/UPDATE/DELETE grant — all mutation goes through these RPCs.

`financial_account_balance()` and `financial_account_post_entry()` are
internal helpers only — like `contribution_charge_net_assessed()` in
the Contribution Engine, they do no group-scoping/permission check
themselves, so they are locked to `SECURITY DEFINER` callers and never
granted to any client role.

## Flutter

`app/lib/features/financial_accounts/` — a list screen (search,
balances, active/inactive badges), a create/edit form (opening balance
is create-only), a detail screen (balance + paginated entries,
activate/deactivate, edit), and a deliberately minimal transfer screen
(from/to account picker, amount, optional description) — no advanced
scheduling/batch transfer UI, just enough to exercise
TRANSFER_IN/TRANSFER_OUT. Reached from a new Home screen shortcut
gated on `financial_account.view`.

## Deferred to Prompt 07/08/09

- Contribution payment posting (referencing a `financial_account_id`
  and creating exactly one INFLOW entry per payment).
- Payment allocation ledger, member wallet, receipts.
- Payment reversal (expected to use `reverses_entry_id` directly).
- Loans, loan repayments, expenses, bank statement reconciliation,
  income analytics, full financial position/reporting.
