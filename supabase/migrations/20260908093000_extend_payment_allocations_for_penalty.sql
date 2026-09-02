-- Prompt 09D: payment_allocations gains a LOAN_PENALTY target branch,
-- mirroring the exact discriminator pattern 09C already established
-- for LOAN_PRINCIPAL/LOAN_INTEREST (allocation_target_type + a
-- consistency CHECK) — never a second payment/receipt/cashbook system
-- (section 3).
--
-- loan_account_id/loan_installment_id are already populated for the
-- other loan targets; a LOAN_PENALTY row additionally requires
-- loan_penalty_charge_id, since an installment may have MULTIPLE
-- outstanding penalty charges (RECURRING_MONTHLY) that must each be
-- traceable to the exact charge they settle (section 4/16).

alter table public.payment_allocations
  add column loan_penalty_charge_id uuid references public.loan_penalty_charges (id);

alter table public.payment_allocations
  drop constraint payment_allocations_target_consistency;

alter table public.payment_allocations
  add constraint payment_allocations_target_consistency check (
    (
      allocation_target_type = 'CONTRIBUTION_COMPONENT'
      and charge_id is not null
      and charge_component_id is not null
      and loan_account_id is null
      and loan_installment_id is null
      and loan_penalty_charge_id is null
    )
    or
    (
      allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_INTEREST')
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is not null
      and loan_penalty_charge_id is null
    )
    or
    (
      allocation_target_type = 'LOAN_PENALTY'
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is not null
      and loan_penalty_charge_id is not null
    )
  );

comment on column public.payment_allocations.loan_penalty_charge_id is
  'Prompt 09D. Populated only when allocation_target_type =
  LOAN_PENALTY — identifies exactly which loan_penalty_charges row
  (occurrence) this allocation settles, since an installment may carry
  more than one outstanding penalty charge (RECURRING_MONTHLY).';

create index payment_allocations_loan_penalty_charge_id_idx
  on public.payment_allocations (loan_penalty_charge_id);
