# Payments, Wallet, Receipts (Prompt 07)

Prompt 07 implements external payment recording, server-side
deterministic allocation against contribution debt, an optional member
wallet, immutable receipts, and reversal — built directly on top of
the accepted Prompt 08A Financial Accounts + Cashbook foundation and
the locked 06A/06B/06C contribution engine. No second cashbook model
exists; no parallel obligation model exists.

## The three-layer accounting model (locked)

1. **Obligation ledger** — `contribution_charge_components` (06A/06B/
   06C). What a member owes: BASE, PENALTY, ADJUSTMENT (either sign),
   WAIVER (always negative), OPENING_BALANCE. Never mutated by
   payments.
2. **Allocation ledger** — `payment_allocations` (new here). How a
   specific payable component was settled — either by an external
   payment (`payment_id` set) or by an explicit wallet allocation
   (`wallet_entry_id` set), never both
   (`payment_allocations_exactly_one_source`). **Payment allocations
   are not cashbook entries** — they never move money, they only
   record which debt a payment/wallet application was applied against.
3. **Cashbook** — `financial_account_entries` (08A). Real money
   movement. One external payment always creates **exactly one**
   INFLOW, for the **full** payment amount, regardless of how many
   obligations it settles or whether any of it becomes wallet credit.
   A wallet allocation creates **zero** cashbook entries — it never
   touches the cashbook at all, since no external cash moves.

The core invariant: **one external payment → one payment record → zero
or more allocations → optional wallet credit → exactly one receipt →
exactly one cashbook INFLOW.**

## Allocation algorithm

Given a payment/wallet amount, the server (`contribution_compute_
payment_allocation_plan`) walks:

1. **Charges**, oldest `due_date` first. Since "overdue" is exactly
   `due_date < today`, sorting by `due_date` ascending alone already
   places every overdue charge before every not-yet-due charge — no
   separate overdue/current partitioning is needed.
2. **Components within one charge**, in priority order: BASE →
   PENALTY (by `sequence`) → positive ADJUSTMENT (by `created_at`) →
   OPENING_BALANCE. WAIVER and negative ADJUSTMENT are never directly
   allocated to — instead, the total `|negative components|` for the
   charge is netted off against this ordered list **front-to-back**
   before allocation, computing each component's "gross payable after
   corrections" before subtracting already-`POSTED`-payment or
   wallet-sourced allocations. This guarantees total allocation never
   exceeds a component's net payable amount.

The exact same server-side plan function is used by both the
non-posting preview RPCs (`rpc_preview_payment_allocation`,
`rpc_preview_wallet_allocation`) and the posting RPCs
(`rpc_post_payment`, `rpc_allocate_member_wallet`) — preview and
posting can never diverge for the same inputs.

A CLOSED contribution period's charges remain fully payable (period
lifecycle and settlement lifecycle are separate); a SUSPENDED/EXITED
member's historical charges remain settleable without reactivating
membership (the member picker searches every status).

## Wallet

A member-owned advance held by the group — **never** contribution
income, profit, obligation, or a cashbook account. `member_wallet_
entries` (PAYMENT_CREDIT / ALLOCATION_DEBIT / REVERSAL), balance always
derived (`member_wallet_balance()`), never negative, scoped to
`group_membership` (never an auth user — a membership may have
`user_id = null`).

- **PAYMENT_CREDIT**: created automatically when a payment exceeds
  allocatable debt.
- **ALLOCATION_DEBIT**: created by an explicit, manual wallet
  allocation (`rpc_allocate_member_wallet`) — atomic, creates no
  payment/receipt/cashbook entry. If the requested amount exceeds
  total outstanding debt, only the amount actually applied is debited;
  the unapplied remainder simply stays in the wallet (it never left in
  the first place).
- **REVERSAL**: created only when a payment reversal undoes an unused
  PAYMENT_CREDIT it originally created (see Reversal below).

No wallet-to-wallet transfer, expiry, negative balance, auto-
withdrawal, or cash refund exists in this phase.

## Receipts

Not a separate table — `rpc_get_receipt` is a read projection over
`payments` / `payment_allocations` / `financial_accounts`, since
`payments.receipt_number` alone is sufficient identity and nothing
else needs separate immutable storage beyond what is already
immutable. Exactly one receipt per payment, always, generated once at
posting time and never regenerated. Format: `UMOJA-RCP-{year}-
{seq:06d}` (e.g. `UMOJA-RCP-2026-000123`), via a **global** (not
per-group) counter table (`receipt_number_counters`), incremented
through `INSERT ... ON CONFLICT (year) DO UPDATE ... RETURNING` — its
row lock serializes concurrent callers within the same year, making
number generation collision-safe under concurrency without needing a
group identifier embedded in the text. A reversed payment's receipt
still renders, clearly labeled REVERSED, never hidden or deleted.

## Reversal

`rpc_reverse_payment` reverses **the books-recorded receipt of cash**
for one payment — not a separate physical-refund workflow. Atomic:

- Flips `payments.status` to REVERSED (`reversed_at`/`reversed_by`/
  `reversal_reason` all set together, enforced by a CHECK constraint).
  This alone makes the settled debt outstanding again, since
  `payment_allocations` validity for a payment-sourced row is derived
  by joining to `payments.status = 'POSTED'` — no allocation row is
  ever mutated or deleted.
- If the payment created a PAYMENT_CREDIT that has since been spent
  (a wallet allocation reduced the wallet below the original credit
  amount), the reversal is **blocked** with
  `PAYMENT_REVERSAL_BLOCKED_WALLET_CREDIT_CONSUMED` — it never
  silently reverses wallet value that belongs to a different
  transaction. If the credit is still fully intact, a REVERSAL wallet
  entry undoes exactly that amount.
- Posts exactly one new, immutable OUTFLOW cashbook entry via
  `financial_account_post_entry`, linked to the original INFLOW via
  `reverses_entry_id` — the original entry is never edited or deleted.

Reversing an already-REVERSED payment is rejected
(`PAYMENT_ALREADY_REVERSED`). There is no Edit/Delete Payment anywhere
— a correction is always reverse-then-repost.

## 06B penalty-engine integration

`rpc_assess_contribution_penalties` (extended via `CREATE OR REPLACE`
on its exact 06B signature — the original migration is never touched)
now skips a charge whose total outstanding (across payment + wallet
allocations) is already zero, even though it may still be technically
overdue by `due_date` alone. A partially-settled charge remains fully
eligible. Already-posted PENALTY components, and the original BASE
amount a percentage penalty was computed from, are never recalculated
by this change — only whether a *new* occurrence is considered this
run.

## Permissions

| Permission | ADMIN | TREASURER | CHAIRPERSON | SECRETARY | MEMBER |
|---|---|---|---|---|---|
| `payment.view` | ✓ | ✓ | ✓ | ✓ | — |
| `payment.create` | ✓ | ✓ | — | — | — |
| `payment.reverse` | ✓ | ✓ | — | — | — |
| `payment.receipt.view` | ✓ | ✓ | ✓ | ✓ | — |
| `wallet.view` | ✓ | ✓ | ✓ | — | — |
| `wallet.allocate` | ✓ | ✓ | — | — | — |

**MEMBER self-service is deliberately deferred.** A safe self-view
portal (a member seeing only their own payments/receipts/wallet)
requires backend verification that the target membership belongs to
the authenticated user — a real design surface of its own — and
broadening scope to build it now was judged to risk the treasury
workflow, which is the priority for this phase. MEMBER holds none of
the six permissions above. `rpc_get_member_contribution_summary` and
`rpc_get_contribution_charge_detail` (06C) were extended with
`total_allocated`/`total_outstanding` fields reachable via the
existing `contribution.self_view` path, since those are
contribution-domain figures already safe for a member to see about
themselves — but wallet balance is deliberately **not** added there;
it is exposed only via `rpc_get_member_wallet`/`rpc_list_member_
wallet_entries`, both gated by `wallet.view`, which MEMBER does not
hold. `rpc_get_member_contribution_statement` is likewise gated by
full `contribution.view` + `payment.view` + `wallet.view` together
(no self-view path), for the same reason.

## Concurrency

Every mutating RPC (`rpc_post_payment`, `rpc_reverse_payment`,
`rpc_allocate_member_wallet`) takes
`select 1 from group_memberships where id = p_membership_id for update`
as its first step — a single lock point per membership that
serializes every payment post / reversal / wallet allocation touching
that member's obligations, wallet, and allocations against each other.
A second transaction for the same membership can only proceed (and
recompute a fresh, correct plan) after the first has committed or
rolled back. `rpc_reverse_payment` locks the same way, in the same
order (membership row, then the payment row), to avoid deadlocks
against `rpc_post_payment`.

## Idempotency

`rpc_post_payment` and `rpc_allocate_member_wallet` accept an optional
`p_idempotency_key`. A retry with the same key and an **identical**
payload returns the original result (`already_posted: true`), never
posting twice. A retry with the same key and a **conflicting** payload
(different amount/member/account/date/method/reference) is rejected
with a specific error, never silently ignored and never silently
double-posted. The underlying unique index
(`payments_idempotency_key_unique` / `member_wallet_entries_
idempotency_key_unique`) is the ultimate backstop even under a race
between two concurrent first-time submissions with the same key.

## Flutter

Navigation lives under the existing Michango (Contributions) home
screen — Malipo (payment list), Rekodi Malipo (record payment), Salio
la Mwanachama (member wallet) — rather than a new top-level section.
Risiti (receipt) and Batili Malipo (reverse) are reached from a
payment's own detail screen, never from a list-level entry.

The Record Payment flow (`/payments/record`) is a single stateful
screen with four internal steps (pick member → amount/date/method/
account/reference/notes → preview → confirm/success) — never posts
before an explicit confirm on the preview step. The member picker
reuses the existing `rpc_list_group_members` search (via
`MemberRepository`), with no status filter, so a SUSPENDED/EXITED
member with historical debt can still be found. The financial-account
picker reuses the existing 08A `financialAccountsActiveForPickerProvider`
unchanged — no second implementation.

Every provider that this phase's mutations can affect is invalidated
whole-family after posting/reversing/allocating (payment list/detail,
member contribution summary, contribution charge/period providers,
wallet ledger, the affected financial account's detail/entries) —
the same whole-family invalidation pattern established for 08A, and
deliberately not the 08A staleness bug (a payment/wallet screen
re-fetches on every entry via `initState`, no full-restart required).

## Explicitly out of scope for this phase

Loans and loan repayments, bank statement reconciliation, expense
management, income analytics, full financial-position reporting,
wallet-to-wallet transfer, wallet withdrawal/cash refund, and a
MEMBER self-service portal (see Permissions above). A dedicated
"member contribution statement" screen was not built in Flutter —
the backend RPC (`rpc_get_member_contribution_statement`) exists and
is tested, ready for a future portal/report phase, but nothing in this
phase's UI requirements calls for its own screen.
