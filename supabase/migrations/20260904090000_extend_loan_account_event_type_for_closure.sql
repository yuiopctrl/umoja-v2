-- Prompt 09C: adds the two lifecycle event types repayment introduces
-- (section 19/20) — CLOSED (a loan's collectible obligations are fully
-- settled) and REOPENED (a payment reversal restored outstanding debt
-- on a loan that had been CLOSED). Kept in its own migration, ahead of
-- any function that references these labels, since a newly added enum
-- value cannot safely be used in the same transaction that adds it.

alter type public.loan_account_event_type add value 'CLOSED';
alter type public.loan_account_event_type add value 'REOPENED';
