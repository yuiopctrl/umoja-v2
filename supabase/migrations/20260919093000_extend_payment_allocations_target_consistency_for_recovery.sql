-- Prompt 09F-B: payment_allocations_target_consistency — add the three
-- LOAN_RECOVERY_* branches, each requiring loan_account_id only
-- (mirroring the existing LOAN_PRINCIPAL_PREPAYMENT branch exactly).
-- Every other branch is byte-for-byte unchanged from 20260913092000.

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
    or
    (
      allocation_target_type in (
        'LOAN_PRINCIPAL_PREPAYMENT',
        'LOAN_RECOVERY_PRINCIPAL', 'LOAN_RECOVERY_INTEREST', 'LOAN_RECOVERY_PENALTY'
      )
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is null
      and loan_penalty_charge_id is null
    )
  );

comment on column public.payment_allocations.allocation_target_type is
  'CONTRIBUTION_COMPONENT (Prompt 07) | LOAN_PRINCIPAL | LOAN_INTEREST
  (Prompt 09C) | LOAN_PENALTY (Prompt 09D) | LOAN_PRINCIPAL_PREPAYMENT
  (Prompt 09E — an explicit principal prepayment, never tied to one
  installment) | LOAN_RECOVERY_PRINCIPAL/INTEREST/PENALTY (Prompt 09F-B
  — a cash recovery against a written-off loan''s aggregate balance,
  also never tied to one installment). Discriminates which FK group is
  populated — see payment_allocations_target_consistency.';
