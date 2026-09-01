-- Prompt 09B: loan disbursement record (section 10).
--
-- One immutable row per successful disbursement, linked to exactly one
-- `financial_account_entries` OUTFLOW (section 14) — never a second,
-- competing cash ledger. `loan_account_id` is UNIQUE: for 09B, one
-- loan account can be disbursed exactly once (section 10/19/49) — this
-- is a structural, concurrency-proof guarantee, not merely an
-- application-level check, since a UNIQUE constraint violation is
-- atomic under Postgres MVCC regardless of how two concurrent
-- transactions race. Partial/multiple-tranche disbursement is
-- explicitly out of scope; a future phase would need a different
-- table shape, not a relaxation of this constraint.

create table public.loan_disbursements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  loan_account_id uuid not null references public.loan_accounts(id),
  financial_account_id uuid not null references public.financial_accounts(id),
  amount numeric(14, 2) not null,
  effective_at date not null,
  reference text,
  notes text,
  idempotency_key text,
  financial_account_entry_id uuid references public.financial_account_entries(id),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),

  constraint loan_disbursements_amount_positive check (amount > 0)
);

comment on table public.loan_disbursements is
  'Prompt 09B: one immutable disbursement per loan account (enforced by
  the unique index below, not merely an RPC-level check). Disbursement
  is a cash OUTFLOW, never an expense (see docs/accounting/
  invariants.md) — financial_account_entry_id points at the single
  cashbook row it created, classified via source_type =
  ''LOAN_DISBURSEMENT'', never financial_manual_entries.';

create unique index loan_disbursements_loan_account_unique
  on public.loan_disbursements (loan_account_id);
create unique index loan_disbursements_group_idempotency_key_unique
  on public.loan_disbursements (group_id, idempotency_key)
  where idempotency_key is not null;
create index loan_disbursements_group_id_idx on public.loan_disbursements (group_id);
create index loan_disbursements_financial_account_id_idx
  on public.loan_disbursements (financial_account_id);

alter table public.loan_disbursements enable row level security;

create policy loan_disbursements_select on public.loan_disbursements
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));

-- Read-only from Flutter — every INSERT happens inside
-- rpc_disburse_loan_account (SECURITY DEFINER), never directly.
revoke all on public.loan_disbursements from public, anon, authenticated;
grant select on public.loan_disbursements to authenticated;
