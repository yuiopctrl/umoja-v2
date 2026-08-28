-- Prompt 07: Payments, Wallet, Allocations, Receipts — schema.
--
-- Integrates directly with the accepted Prompt 08A Financial Accounts +
-- Cashbook foundation (financial_accounts / financial_account_entries /
-- financial_account_post_entry) — no second cashbook model is created
-- here. Every POSTED external payment references an existing, ACTIVE
-- financial_accounts row and posts exactly one financial_account_entries
-- INFLOW (source_type = 'PAYMENT', source_id = payments.id).
--
-- Three layers stay separate, per the locked accounting model:
--   1. Obligation ledger  — contribution_charge_components (06A/06B/06C).
--   2. Allocation ledger  — payment_allocations (new here) — how a
--      payment/wallet settles obligations. Never a cash event.
--   3. Cashbook           — financial_account_entries (08A) — real money
--      movement. One external payment = one INFLOW, regardless of how
--      many obligations it settles.
--
-- Deliberately NOT built here: loans, loan repayments, expenses, bank
-- reconciliation/statement import, full income analytics, full
-- financial-position reporting, wallet transfers between members,
-- wallet withdrawal/refund. Those remain later phases.

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------

create type public.payment_method as enum (
  'CASH',
  'BANK_TRANSFER',
  'MOBILE_MONEY',
  'OTHER'
);

comment on type public.payment_method is
  'Descriptive metadata only — never a substitute for
  financial_account_id, which is the authoritative destination of the
  cash (e.g. method = BANK_TRANSFER, financial account = "NMB Main").';

create type public.payment_status as enum (
  'POSTED',
  'REVERSED'
);

comment on type public.payment_status is
  'No DRAFT — a payment is only ever recorded after an explicit,
  non-posting server preview (rpc_preview_payment_allocation) has
  already been shown to the user; there is no partially-entered
  payment state worth persisting. POSTED is immutable; a correction is
  always reverse-then-repost, never an edit.';

create type public.member_wallet_entry_type as enum (
  'PAYMENT_CREDIT',
  'ALLOCATION_DEBIT',
  'REVERSAL'
);

comment on type public.member_wallet_entry_type is
  'PAYMENT_CREDIT: an external payment exceeded allocatable debt: the
  excess becomes wallet credit. ALLOCATION_DEBIT: wallet balance was
  explicitly allocated against an outstanding obligation. REVERSAL:
  undoes a PAYMENT_CREDIT whose source payment was reversed (the only
  reversal scenario in this phase — wallet-to-wallet transfers,
  expiry, and withdrawal do not exist).';

-- ---------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('payment.view', 'View payments', 'View payment history, detail, and allocations for the group.'),
  ('payment.create', 'Record payments', 'Post an external payment and its allocations.'),
  ('payment.reverse', 'Reverse payments', 'Reverse a POSTED payment.'),
  ('payment.receipt.view', 'View receipts', 'View a payment''s immutable receipt.'),
  ('wallet.view', 'View member wallets', 'View a member''s wallet balance and ledger history.'),
  ('wallet.allocate', 'Allocate member wallets', 'Allocate a member''s wallet balance against outstanding obligations.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in (
    'payment.view', 'payment.create', 'payment.reverse',
    'payment.receipt.view', 'wallet.view', 'wallet.allocate'
  )
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'payment.view', 'payment.create', 'payment.reverse',
    'payment.receipt.view', 'wallet.view', 'wallet.allocate'
  )
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('payment.view', 'payment.receipt.view', 'wallet.view')
where r.code = 'CHAIRPERSON';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('payment.view', 'payment.receipt.view')
where r.code = 'SECRETARY';

-- MEMBER intentionally gets none of these six in Prompt 07 — per
-- prompt section 37, a safe self-view portal is explicitly deferred
-- ("if safe self-view would broaden scope excessively, defer MEMBER
-- portal actions and report it — treasury workflow is priority").
-- Reported explicitly as a deferred item.

-- ---------------------------------------------------------------------
-- receipt_number_counters — internal only, never exposed to any
-- client role. One row per calendar year; the counter is GLOBAL
-- (shared across every group) rather than per-group, so the
-- generated text needs no embedded group identifier to stay
-- collision-free — see payment_generate_receipt_number().
-- ---------------------------------------------------------------------

create table public.receipt_number_counters (
  year integer primary key,
  last_seq integer not null default 0
);

alter table public.receipt_number_counters enable row level security;
revoke all on public.receipt_number_counters from anon, authenticated;

-- ---------------------------------------------------------------------
-- payments
-- ---------------------------------------------------------------------

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  financial_account_id uuid not null references public.financial_accounts (id),

  amount numeric(14, 2) not null,
  effective_at date not null,
  payment_method public.payment_method not null,
  external_reference text,
  notes text,

  status public.payment_status not null default 'POSTED',
  receipt_number text not null,
  idempotency_key text,

  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),

  reversed_at timestamptz,
  reversed_by uuid references auth.users (id),
  reversal_reason text,

  constraint payments_amount_positive check (amount > 0),
  constraint payments_reversal_fields_consistent check (
    (status = 'POSTED' and reversed_at is null and reversed_by is null and reversal_reason is null)
    or (status = 'REVERSED' and reversed_at is not null and reversed_by is not null and reversal_reason is not null)
  )
);

comment on table public.payments is
  'One external cash event. Immutable once POSTED — no direct
  UPDATE/DELETE grant to any client role; a correction is always
  reverse-then-repost (rpc_reverse_payment + a fresh
  rpc_post_payment). financial_account_id is required and must
  reference an ACTIVE account in the same group — enforced in
  rpc_post_payment, not by a DB-level FK alone, since "active at
  posting time" is a point-in-time business rule, not a schema
  invariant.';

create unique index payments_receipt_number_unique on public.payments (receipt_number);
create unique index payments_idempotency_key_unique
  on public.payments (group_id, idempotency_key)
  where idempotency_key is not null;
create index payments_group_id_idx on public.payments (group_id);
create index payments_membership_id_idx on public.payments (membership_id);
create index payments_financial_account_id_idx on public.payments (financial_account_id);
create index payments_status_idx on public.payments (status);

alter table public.payments enable row level security;
revoke all on public.payments from anon, authenticated;

-- ---------------------------------------------------------------------
-- member_wallet_entries — the wallet ledger. Balance is always
-- derived (see member_wallet_balance()), never a stored mutable
-- column, matching the financial_account_entries precedent exactly.
-- Defined before payment_allocations so the latter's wallet_entry_id
-- foreign key can reference it.
-- ---------------------------------------------------------------------

create table public.member_wallet_entries (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  entry_type public.member_wallet_entry_type not null,
  amount numeric(14, 2) not null,
  effective_at date not null,
  source_type text,
  source_id uuid,
  reverses_entry_id uuid references public.member_wallet_entries (id),
  idempotency_key text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint member_wallet_entries_amount_positive check (amount > 0)
);

comment on table public.member_wallet_entries is
  'Wallet ledger for one group_membership (never auth.users — a
  membership may have user_id = null and still hold wallet credit).
  amount is always positive; entry_type carries the sign meaning.
  Balance = sum(PAYMENT_CREDIT) - sum(ALLOCATION_DEBIT) -
  sum(REVERSAL); see member_wallet_balance(). source_type/source_id
  tag what caused the entry (e.g. ''PAYMENT'' + payments.id for a
  PAYMENT_CREDIT, ''PAYMENT_ALLOCATION_BATCH'' for an
  ALLOCATION_DEBIT). No member-to-member transfer, no expiry, no
  withdrawal — a balance never goes negative (enforced in every
  RPC that debits it).';

create unique index member_wallet_entries_idempotency_key_unique
  on public.member_wallet_entries (membership_id, idempotency_key)
  where idempotency_key is not null;
create index member_wallet_entries_membership_id_idx on public.member_wallet_entries (membership_id);
create index member_wallet_entries_group_id_idx on public.member_wallet_entries (group_id);

alter table public.member_wallet_entries enable row level security;
revoke all on public.member_wallet_entries from anon, authenticated;

-- ---------------------------------------------------------------------
-- payment_allocations — immutable. Validity ("is this allocation still
-- in effect") is derived by joining to payments.status = 'POSTED' for
-- a payment-sourced row (a wallet-sourced row is always valid — see
-- below), rather than a redundant per-allocation reversed flag: a
-- payment reversal always reverses ALL of its own allocations
-- atomically, so there is no partial-allocation-reversal state to
-- track separately. Never mutated/deleted — a reversal leaves every
-- row exactly as posted and simply changes the parent payment's
-- status.
-- ---------------------------------------------------------------------

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  payment_id uuid references public.payments (id),
  wallet_entry_id uuid references public.member_wallet_entries (id),
  membership_id uuid not null references public.group_memberships (id),
  charge_id uuid not null references public.member_contribution_charges (id),
  charge_component_id uuid not null references public.contribution_charge_components (id),
  amount numeric(14, 2) not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint payment_allocations_amount_positive check (amount > 0),
  constraint payment_allocations_exactly_one_source check (
    (payment_id is not null and wallet_entry_id is null)
    or (payment_id is null and wallet_entry_id is not null)
  )
);

comment on table public.payment_allocations is
  'How a specific payable component was settled — either by an
  external payment (payment_id set) or by an explicit wallet
  allocation (wallet_entry_id set, an ALLOCATION_DEBIT row on
  member_wallet_entries), never both. Never a cash event itself — see
  financial_account_entries for the one INFLOW an external payment
  creates; a wallet allocation creates zero cashbook entries. A
  payment-sourced row is "active" only while its parent
  payments.status = ''POSTED''; a wallet-sourced row is always active
  (wallet allocations are not reversible in this phase). Reversal
  never deletes or edits rows here.';

create index payment_allocations_payment_id_idx on public.payment_allocations (payment_id);
create index payment_allocations_wallet_entry_id_idx on public.payment_allocations (wallet_entry_id);
create index payment_allocations_charge_component_id_idx on public.payment_allocations (charge_component_id);
create index payment_allocations_charge_id_idx on public.payment_allocations (charge_id);
create index payment_allocations_membership_id_idx on public.payment_allocations (membership_id);

alter table public.payment_allocations enable row level security;
revoke all on public.payment_allocations from anon, authenticated;
