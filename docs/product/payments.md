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

## Allocation preview loan context (Prompt 09C-UAT-FIX-02)

Physical UAT found that Wallet → Loan "Preview Allocation" showed bare
`Interest — 20,000` / `Principal — 20,000` lines with no indication of
which loan — especially a problem for a member holding more than one
ACTIVE loan. `rpc_preview_payment_allocation`/
`rpc_preview_wallet_allocation` (and, for consistency,
`rpc_get_payment_detail`/`rpc_get_receipt`) now also resolve
`loan_product_name` via a live join to `loan_products` — the one field
that was genuinely missing alongside the already-present
`loan_number`/`installment_number`/`due_date`.

`AllocationLinesList` (`payments/presentation/widgets/`) is the single
shared widget every one of these four screens uses to render
allocation lines — contribution lines render individually as before;
loan lines for the SAME installment (interest + principal, which the
server's allocation walk always emits contiguously) are grouped under
one header naming the loan product, loan number, installment, and due
date. This is what makes two ACTIVE loans visually distinguishable
before an allocation is confirmed, and keeps Wallet and Record Payment
using the exact same presentation rather than one being richer than
the other.

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

**Historical immutability (UAT-FIX-01).** `payment_allocations`
carries its own `contribution_type_name_snapshot`/`period_label_
snapshot`/`period_purpose_snapshot`, populated at posting time from
the live join — mirroring the pre-existing `member_number_snapshot`/
`member_name_snapshot` on `member_contribution_charges`. A receipt or
payment detail always renders these snapshot columns, never a live
join back to `contribution_types`/`contribution_periods` — so
renaming a contribution type or period label later never rewrites the
meaning of an already-issued receipt. Proven by deliberately reverting
the read RPCs back to a live join in `31_payment_allocation_context
.test.sql`: exactly two assertions fail, confirming the snapshot
columns (not the live join) are what the RPCs actually read.

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

## Member-centric charges view (UAT-FIX-03)

`rpc_list_member_contribution_charges(p_group_id, p_membership_id,
p_filter default 'OUTSTANDING', p_limit default 10, p_offset default
0)` is a deliberately separate, purpose-built LIST RPC — every charge
for one membership across every period, filterable
(ALL/OUTSTANDING/SETTLED/OVERDUE) and paginated — rather than an
overload of `rpc_get_member_contribution_statement`, whose small,
unpaginated, always-outstanding-only contract is relied on by the
Record Payment pre-check flow and must not change. Gated by
`contribution.view AND payment.view` only (no `wallet.view` — it never
exposes wallet data). No membership-status restriction: a
SUSPENDED/EXITED member's historical charges remain fully listed.
Each charge's `components[]` is sourced from the raw
`contribution_charge_components` table (not the netted allocation-
state helper), so a WAIVER or negative ADJUSTMENT renders as its own
signed reducing line — it is never netted away or mislabeled as a
payment. `rpc_get_member_contribution_statement` gained one additive
field, `total_allocated` (a global sum across every charge, including
ones already excluded from its `charges[]` because they're fully
settled); its existing fields/contract are otherwise unchanged.

Flutter reaches this via a new `MemberChargesScreen`
(`/members/:membershipId/charges`), linked from a permission-gated
Charges/Madeni entry point on Member Detail — not a new top-level
section. It shows the member's Outstanding/Allocated/Wallet summary,
filter chips (default Outstanding), and a paginated charge list; each
row taps through to the *existing* Contribution Charge Detail screen
(no duplicate detail implementation), and a "Rekodi Malipo" shortcut
opens the *existing* Record Payment flow with the member already
selected (`/payments/record/:membershipId` — the membership id lives
in the route path, never a transient `extra`, per the UAT-FIX-02
lesson) rather than a second payment implementation.

## Flutter

Navigation lives under a dedicated Malipo (Payments) hub (`/payments`,
`PaymentsHomeScreen`), reached from Home — not the Contributions home
screen. This was Prompt 07's original placement, revisited in
09C-UAT-FIX-01 once loan repayment made the Payment Engine shared
across Contributions/Loans/Wallet rather than Contributions-owned: the
hub lists Rekodi Malipo (record payment), Historia ya Malipo (payment
history, `/payments/history` — the actual paginated list, moved off the
bare `/payments` path), Risiti (receipts, same history screen), and
Salio la Mwanachama (member wallet). Contributions keeps only
contribution-domain functions plus Madeni ya Mwanzo (Opening Balance —
obligation creation/import, never received cash, so it was never moved
here). `Batili Malipo` (reverse) is still reached from a payment's own
detail screen, never from a list-level entry. This is navigation/
information architecture only — every entry routes into the exact same
Prompt 07 screens/RPCs; nothing about the Payment Engine itself
changed.

The Record Payment flow (`/payments/record`, or `/payments/record/
:membershipId` with the member preselected) is a single stateful
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
member contribution summary/statement/charges, contribution charge/
period providers, wallet ledger, the affected financial account's
detail/entries) — the same whole-family invalidation pattern
established for 08A, and deliberately not the 08A staleness bug (a
payment/wallet screen re-fetches on every entry via `initState`, no
full-restart required).

`PaymentReversalScreen` derives `groupId` from `selectedGroupProvider`
(UAT-FIX-04) — never from `PaymentDetail.membershipId`, which is the
paying member's own id, not a group id. Passing the wrong id made
`has_group_permission` check a UUID that could never match the
caller's real membership row, denying reversal for every role
regardless of their actual permissions; this was a pure client-side
parameter bug, not an authorization or role-matrix defect.

## Loan repayment integration (Prompt 09C, tightened by 09C-UAT-FIX-01)

Loan repayment is **not** a separate payment system — it integrates
directly into this exact pipeline. `payment_compute_combined_
allocation_plan()` extends the charge-walk above into a single ordered
walk across both contribution charges and one borrower's ACTIVE loan
installments (oldest `due_date` first; contribution before loan on an
exact tie; within a loan installment, INTEREST before PRINCIPAL) —
`rpc_post_payment`/`rpc_allocate_member_wallet`/`rpc_reverse_payment`
keep their exact 07 signatures (`rpc_preview_payment_allocation` gained
one new, defaulted `p_effective_at` parameter). See
[docs/product/loans.md](loans.md#repayment-prompt-09c) for the full
accounting model (principal receivable, interest income recognition,
closure/reopening).

Physical UAT found that a sufficiently large payment silently prepaid a
borrower's ENTIRE future loan schedule. The locked correction: a loan
installment is only ever automatically allocatable when its `due_date`
is on or before the payment's own effective date (`p_effective_at` for
an external payment; `current_date` for a wallet allocation, matching
every other wallet posting's dating convention) — an UPCOMING
installment is never included, regardless of amount. Preview and
posting share the exact same date basis so they can never diverge.
Contribution allocatability is **unchanged** — a not-yet-due
contribution charge remains payable early, exactly as before; this
restriction is loan-side only. See
[docs/product/loans.md](loans.md#collectibility-09c-tightened-by-09c-uat-fix-01)
for the full rule and its rationale.

The "before payment" statement (`rpc_get_member_contribution_
statement`) now also returns a `loans[]` block (per ACTIVE loan:
overdue/due-now/currently-payable amounts, next due date, and a
separately-labeled `upcoming_amount`) and a `total_payable_now` that
combines both domains under this same currently-due rule — shown to
the operator immediately after selecting a member, before any amount
is entered, so a large payment's actual effect is never a surprise at
Preview time.

## Explicitly out of scope for this phase

Bank statement reconciliation, expense management, income analytics,
full financial-position reporting, wallet-to-wallet transfer, wallet
withdrawal/cash refund, and a MEMBER self-service portal (see
Permissions above). The member-centric
Charges/Madeni view (`MemberChargesScreen`, UAT-FIX-03 — see above)
covers the treasurer-facing "see all of one member's charges" need;
`rpc_get_member_contribution_statement` itself still has no screen of
its own beyond its pre-payment-check usage, ready for a future
portal/report phase if one is scoped later.
