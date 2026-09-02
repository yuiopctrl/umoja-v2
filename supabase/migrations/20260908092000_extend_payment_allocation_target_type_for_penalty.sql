-- Prompt 09D: extend payment_allocation_target_type with LOAN_PENALTY
-- (section 16). Kept alone in its own migration — PostgreSQL does not
-- allow a newly added enum value to be referenced (e.g. in a CHECK
-- constraint or cast) within the same transaction that added it. Same
-- safe-ordering precedent already used for loan_account_event_type's
-- CLOSED/REOPENED values (20260904090000).

alter type public.payment_allocation_target_type add value 'LOAN_PENALTY';
