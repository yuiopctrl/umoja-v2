-- Prompt 09E: extend payment_allocation_target_type with
-- LOAN_PRINCIPAL_PREPAYMENT — a principal prepayment is NOT tied to any
-- specific scheduled installment (unlike LOAN_PRINCIPAL, which always
-- settles one installment's principal_due). It reduces the loan's
-- aggregate outstanding principal directly, ahead of the future
-- schedule being recomputed. Kept alone in its own migration —
-- PostgreSQL does not allow a newly added enum value to be referenced
-- within the same transaction that added it (same precedent as
-- LOAN_PENALTY, 20260908092000).

alter type public.payment_allocation_target_type add value 'LOAN_PRINCIPAL_PREPAYMENT';
