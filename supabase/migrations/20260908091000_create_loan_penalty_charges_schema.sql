-- Prompt 09D: loan_penalty_charges — an immutable penalty assessment
-- table (section 7/8). No mutable paid_amount/balance/outstanding
-- column is added, exactly mirroring the loan_installments precedent
-- (09A) and the payment_allocations-is-append-only precedent (07/09C):
-- outstanding is always derived, at read time, from this row's
-- penalty_amount minus active LOAN_PENALTY payment_allocations rows
-- against it (see loan_penalty_charge_states,
-- 20260908094000_create_loan_penalty_allocation_helpers.sql).
--
-- A posted charge is never UPDATEd or DELETEd by any RPC in this
-- phase — correction/waiver is explicitly deferred (section 8/52).

create table public.loan_penalty_charges (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),
  loan_installment_id uuid not null references public.loan_installments (id),

  assessment_date date not null,
  sequence_number integer not null,

  -- Policy snapshot at the instant of assessment (itself already
  -- frozen on the loan account — section 6) — traced onto the charge
  -- row too so a charge remains fully self-describing/auditable even
  -- if this were ever inspected independently of the loan account.
  penalty_type public.loan_penalty_type not null,
  penalty_frequency public.loan_penalty_frequency not null,
  penalty_basis public.loan_penalty_basis not null,
  penalty_grace_days integer not null,

  basis_amount numeric(14, 2) not null,
  rate numeric(7, 4),
  fixed_amount numeric(14, 2),
  penalty_amount numeric(14, 2) not null,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint loan_penalty_charges_sequence_positive check (sequence_number > 0),
  constraint loan_penalty_charges_basis_amount_non_negative check (basis_amount >= 0),
  constraint loan_penalty_charges_penalty_amount_positive check (penalty_amount > 0),
  constraint loan_penalty_charges_type_consistency check (
    (penalty_type = 'FIXED' and fixed_amount is not null and rate is null)
    or
    (penalty_type = 'PERCENTAGE' and rate is not null and fixed_amount is null)
  )
);

comment on table public.loan_penalty_charges is
  'Prompt 09D: one immutable row per assessed loan penalty occurrence.
  Never UPDATEd/DELETEd by any RPC — correction/waiver is deferred
  (section 8). Outstanding is always derived (never stored) from
  penalty_amount minus active payment_allocations rows referencing
  this charge — see loan_penalty_charge_states.';

-- Structural idempotency (section 13/14/22/29-30): at most one charge
-- per (installment, occurrence) — the hard DB-level backstop that
-- makes a retried/concurrent assessment run provably create zero
-- duplicates, never relying on "check then insert" alone.
create unique index loan_penalty_charges_installment_sequence_unique
  on public.loan_penalty_charges (loan_installment_id, sequence_number);

create index loan_penalty_charges_group_id_idx on public.loan_penalty_charges (group_id);
create index loan_penalty_charges_loan_account_id_idx on public.loan_penalty_charges (loan_account_id);
create index loan_penalty_charges_loan_installment_id_idx on public.loan_penalty_charges (loan_installment_id);

alter table public.loan_penalty_charges enable row level security;
revoke all on public.loan_penalty_charges from anon, authenticated;

-- Read-only to clients — every write goes through
-- rpc_assess_loan_penalties (SECURITY DEFINER, bypasses RLS as the
-- function owner). No insert/update/delete policy is ever added for
-- authenticated — direct client mutation is structurally impossible.
grant select on public.loan_penalty_charges to authenticated;

create policy loan_penalty_charges_select
  on public.loan_penalty_charges
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan_penalty.view'));
