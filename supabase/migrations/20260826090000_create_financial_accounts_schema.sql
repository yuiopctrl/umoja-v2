-- Prompt 08A: minimal Financial Accounts + Cashbook foundation.
--
-- Scoped dependency pulled forward ahead of Prompt 07 (Payments,
-- Wallet, Allocations, Receipts) — Prompt 07 requires a real place for
-- posted money to "land" before external payment posting can be
-- accounting-safe. This migration builds ONLY:
--   - financial_accounts (CASH/BANK/MOBILE_MONEY, active/inactive)
--   - financial_account_entries (immutable cashbook: INFLOW/OUTFLOW/
--     TRANSFER_IN/TRANSFER_OUT)
--   - server-authoritative derived balance (never a mutable column)
--   - a reversal-safe extension point (reverses_entry_id, source_type/
--     source_id) for Prompt 07 to hook payment posting/reversal into
--     later, without any schema change here.
--
-- Deliberately NOT built here: contribution payments, wallet, receipts,
-- payment allocations, loans, bank statement reconciliation, expense
-- management UI, income analytics, full financial position/reporting.
-- Those remain Prompt 07/08/09.

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------

create type public.financial_account_type as enum (
  'CASH',
  'BANK',
  'MOBILE_MONEY'
);

create type public.financial_account_entry_type as enum (
  'INFLOW',
  'OUTFLOW',
  'TRANSFER_IN',
  'TRANSFER_OUT'
);

comment on type public.financial_account_entry_type is
  'INFLOW/OUTFLOW are real external cash movements. TRANSFER_IN/
  TRANSFER_OUT are internal movements between two of the group''s own
  accounts (paired rows sharing one transfer_reference) — money that
  never left the group, so future income reporting must never count a
  transfer pair as new income/expense.';

-- ---------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('financial_account.view', 'View financial accounts', 'View financial accounts, balances, and cashbook entries.'),
  ('financial_account.manage', 'Manage financial accounts', 'Create/rename/activate/deactivate financial accounts, including recording an opening balance.'),
  ('financial_account.transfer.create', 'Transfer between financial accounts', 'Record an internal transfer between two of the group''s own financial accounts.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in (
    'financial_account.view',
    'financial_account.manage',
    'financial_account.transfer.create'
  )
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'financial_account.view',
    'financial_account.manage',
    'financial_account.transfer.create'
  )
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('financial_account.view')
where r.code in ('CHAIRPERSON', 'SECRETARY');

-- MEMBER intentionally gets none of these — financial accounts are
-- internal group treasury records, not member-personal data (unlike
-- contribution charges, there is no "self" concept here).

-- ---------------------------------------------------------------------
-- financial_accounts
-- ---------------------------------------------------------------------

create table public.financial_accounts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  name text not null,
  account_type public.financial_account_type not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint financial_accounts_name_not_blank check (btrim(name) <> '')
);

comment on table public.financial_accounts is
  'Where posted money physically lives (cash box, bank account, mobile
  money account) — the minimal Prompt 08A dependency Prompt 07 payments
  post an INFLOW against. No hard delete — deactivate via is_active.
  Never carries a mutable balance column; see
  financial_account_balance().';

create unique index financial_accounts_group_name_unique
  on public.financial_accounts (group_id, name);
create index financial_accounts_group_id_idx on public.financial_accounts (group_id);

create trigger financial_accounts_set_updated_at
  before update on public.financial_accounts
  for each row execute function public.set_updated_at();

alter table public.financial_accounts enable row level security;
revoke all on public.financial_accounts from anon, authenticated;

-- ---------------------------------------------------------------------
-- financial_account_entries — the cashbook. Append-only: no RPC ever
-- issues UPDATE/DELETE against this table, and no client role is ever
-- granted UPDATE/DELETE — the only mutation path is INSERT via
-- financial_account_post_entry(), matching the group_memberships/
-- contribution_charge_components precedent for immutability.
-- ---------------------------------------------------------------------

create table public.financial_account_entries (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  financial_account_id uuid not null references public.financial_accounts (id),
  entry_type public.financial_account_entry_type not null,
  amount numeric(14, 2) not null,
  effective_at date not null,
  description text,
  reference text,

  -- Links the two rows (TRANSFER_OUT on the source account,
  -- TRANSFER_IN on the destination account) that make up one internal
  -- transfer. Null for INFLOW/OUTFLOW.
  transfer_reference uuid,

  -- Polymorphic extension point for Prompt 07+: tags what caused this
  -- entry (e.g. 'OPENING_BALANCE', 'TRANSFER' now; 'PAYMENT',
  -- 'PAYMENT_REVERSAL' later) plus the id of that source row. Both
  -- nullable and unconstrained (no CHECK/FK) so later phases can add
  -- new source types without a schema change here.
  source_type text,
  source_id uuid,

  -- Reversal-safe posting architecture: reversing an entry never
  -- updates/deletes it — it posts a new, opposite entry referencing
  -- the one it reverses. Unused in 08A (nothing here is reversible
  -- yet); ready for Prompt 07's payment reversal.
  reverses_entry_id uuid references public.financial_account_entries (id),

  idempotency_key text,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint financial_account_entries_amount_positive check (amount > 0),
  constraint financial_account_entries_transfer_pair_rule check (
    (entry_type in ('TRANSFER_IN', 'TRANSFER_OUT') and transfer_reference is not null)
    or (entry_type in ('INFLOW', 'OUTFLOW') and transfer_reference is null)
  )
);

comment on table public.financial_account_entries is
  'Immutable cashbook. amount is always positive; entry_type carries
  the sign meaning (see financial_account_balance()). Never mutated or
  deleted after insert — a correction is always a new, opposite entry
  (see reverses_entry_id).';

create index financial_account_entries_account_id_idx
  on public.financial_account_entries (financial_account_id);
create index financial_account_entries_group_id_idx
  on public.financial_account_entries (group_id);
create index financial_account_entries_transfer_reference_idx
  on public.financial_account_entries (transfer_reference)
  where transfer_reference is not null;
create unique index financial_account_entries_idempotency_key_unique
  on public.financial_account_entries (financial_account_id, idempotency_key)
  where idempotency_key is not null;

alter table public.financial_account_entries enable row level security;
revoke all on public.financial_account_entries from anon, authenticated;
