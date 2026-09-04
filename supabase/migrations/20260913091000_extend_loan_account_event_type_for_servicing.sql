-- Prompt 09E: three new lifecycle events for the loan-servicing
-- foundation (early settlement, principal prepayment, restructure).
-- Kept alone in its own migration — same enum-in-same-transaction
-- restriction as every prior loan_account_event_type extension
-- (20260904090000, 20260909091000).

alter type public.loan_account_event_type add value 'EARLY_SETTLED';
alter type public.loan_account_event_type add value 'PRINCIPAL_PREPAID';
alter type public.loan_account_event_type add value 'RESTRUCTURED';
