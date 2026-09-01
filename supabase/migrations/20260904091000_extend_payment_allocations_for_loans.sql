-- Prompt 09C: extends `payment_allocations` (Prompt 07) to also target
-- an ACTIVE loan installment's principal or interest component —
-- section 5 ("inspect the existing payment_allocations schema, extend
-- it safely, avoid awkward nullable-FK explosion").
--
-- The existing table has no generic source_type/source_id tag to
-- reuse (unlike financial_account_entries) — charge_id/
-- charge_component_id are dedicated, NOT NULL FKs. Rather than bolting
-- on a second unrelated nullable-FK pair with no discriminator, this
-- migration follows the *exact* pattern the table already uses for
-- payment_id/wallet_entry_id: one discriminator column
-- (allocation_target_type) plus a CHECK constraint enforcing that
-- exactly the correct FK group is populated for that type. No
-- loan_installment "components" table is introduced — a loan
-- installment's principal/interest components are identified purely
-- by (loan_installment_id, allocation_target_type), mirroring the "no
-- mutable paid_amount column" rule already locked for loan_installments
-- (09A): outstanding is always derived, never stored.
--
-- Every existing row backfills to CONTRIBUTION_COMPONENT with its
-- charge_id/charge_component_id untouched — zero behavior change for
-- Prompt 07 contribution allocations.

create type public.payment_allocation_target_type as enum (
  'CONTRIBUTION_COMPONENT',
  'LOAN_PRINCIPAL',
  'LOAN_INTEREST'
);

alter table public.payment_allocations
  add column allocation_target_type public.payment_allocation_target_type
    not null default 'CONTRIBUTION_COMPONENT',
  add column loan_account_id uuid references public.loan_accounts (id),
  add column loan_installment_id uuid references public.loan_installments (id);

alter table public.payment_allocations
  alter column charge_id drop not null,
  alter column charge_component_id drop not null;

alter table public.payment_allocations
  add constraint payment_allocations_target_consistency check (
    (
      allocation_target_type = 'CONTRIBUTION_COMPONENT'
      and charge_id is not null
      and charge_component_id is not null
      and loan_account_id is null
      and loan_installment_id is null
    )
    or
    (
      allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_INTEREST')
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is not null
    )
  );

comment on column public.payment_allocations.allocation_target_type is
  'CONTRIBUTION_COMPONENT (Prompt 07, default) | LOAN_PRINCIPAL |
  LOAN_INTEREST (Prompt 09C). Discriminates which FK group below is
  populated — see payment_allocations_target_consistency. Every row
  predating 09C is CONTRIBUTION_COMPONENT.';
comment on column public.payment_allocations.loan_account_id is
  'Denormalized alongside loan_installment_id purely for query
  convenience (e.g. "every allocation against this loan") — the same
  redundancy the table already accepts for charge_id alongside
  charge_component_id. Never the authoritative link on its own.';
comment on column public.payment_allocations.loan_installment_id is
  'Together with allocation_target_type, identifies exactly which
  component (principal or interest) of which installment this
  allocation settles. loan_installments has no paid_amount/balance
  column by design (09A) — outstanding is always derived from
  installment.principal_due/interest_due minus the sum of active rows
  here (see loan_installment_component_states).';

create index payment_allocations_loan_installment_id_idx
  on public.payment_allocations (loan_installment_id);
create index payment_allocations_loan_account_id_idx
  on public.payment_allocations (loan_account_id);
