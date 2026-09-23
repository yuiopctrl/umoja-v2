-- Prompt 09F-B: extend payment_allocations to support recovery
-- payments, reusing the existing infrastructure exactly.
--
-- Three new allocation_target_type values — LOAN_RECOVERY_PRINCIPAL/
-- INTEREST/PENALTY — each populated with loan_account_id ONLY, the
-- exact precedent LOAN_PRINCIPAL_PREPAYMENT already established
-- (20260913092000) for "a real cash allocation not tied to any one
-- scheduled installment". A recovery is against the loan's aggregate
-- written-off balance per component, not any specific installment/
-- penalty charge, so loan_installment_id/loan_penalty_charge_id are
-- deliberately never populated for these three target types.

alter type public.payment_allocation_target_type add value 'LOAN_RECOVERY_PRINCIPAL';
alter type public.payment_allocation_target_type add value 'LOAN_RECOVERY_INTEREST';
alter type public.payment_allocation_target_type add value 'LOAN_RECOVERY_PENALTY';
