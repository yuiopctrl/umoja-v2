-- Prompt 09D-UAT-BLOCKER-01: a migrated loan's ONE lifecycle event
-- (section 23/24) — never a fake SUBMITTED/APPROVED/DISBURSED sequence.
-- Kept alone in its own migration — PostgreSQL does not allow a newly
-- added enum value to be referenced within the same transaction that
-- added it (same precedent as CLOSED/REOPENED, 20260904090000).

alter type public.loan_account_event_type add value 'MIGRATED';
