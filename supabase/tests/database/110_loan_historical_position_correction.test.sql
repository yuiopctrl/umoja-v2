-- Prompt 09G-B5-A3: Loan historical position correction.
--
-- Proves the canonical historical loan position (loan_historical_position)
-- against deterministic, effective-dated fixtures, and that B3's loan
-- opening/closing figures and the loan summary follow the locked
-- definitions:
--   principal = remaining funded principal receivable
--   earned    = interest payable by the business date (due_date <= D)
--   penalty   = assessed penalties effective by D
--   total     = principal + earned + penalty (scheduled unearned excluded)
--   write-off = receivable zero, NOT repayment; recovery is cash only
--   MIGRATED  = 0 before original disbursement, NOT_AVAILABLE before the
--               opening position, authoritative record from opening on.
--
-- Every expected figure below is derived by hand from the fixture rows
-- (see the comment above each scenario), never copied from the helper.

begin;

select plan(75);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('11000000-0000-0000-0000-000000000011', 'p09gb5a3-admin@example.com'),
  ('11000000-0000-0000-0000-000000000012', 'p09gb5a3-member@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('11000000-0000-0000-0000-000000000001', 'Loan History Group', '11000000-0000-0000-0000-000000000011', 'LHGA3', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('11000000-0000-0000-0000-000000000101', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000011', 'Admin', 'ACTIVE', '2025-01-01', 'LHGA3-0001', null),
  ('11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000012', 'Borrower', 'ACTIVE', '2025-01-02', 'LHGA3-0002', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '11000000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '11000000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER';

insert into public.financial_accounts (id, group_id, name, account_type) values
  ('11000000-0000-0000-0000-000000000201', '11000000-0000-0000-0000-000000000001', 'Cash Box', 'CASH');

insert into public.loan_products (id, group_id, code, name, minimum_principal, maximum_principal, minimum_term, maximum_term, interest_rate, interest_rate_basis, interest_method) values
  ('11000000-0000-0000-0000-000000000601', '11000000-0000-0000-0000-000000000001', 'STD', 'Standard Loan', 1000, 500000, 1, 12, 5, 'MONTHLY', 'FLAT');

-- ---------------------------------------------------------------------
-- L1 (NEW, disbursed 2026-03-01, principal 10000).
--   i1 due 04-01 P4000 I100; i2 due 05-01 P3000 I80; i3 due 06-01 P3000 I60.
--   P1 posted 04-10 (LOAN_INTEREST 100 + LOAN_PRINCIPAL 1000 on i1).
--   C1 penalty 50 on i1 assessed 04-20.
--   P2 posted 05-10, reversed 05-20 (LOAN_PRINCIPAL 500 on i2).
--   P3 posted 05-25, reversed 05-25 same day (LOAN_PRINCIPAL 200 on i3).
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-001', 10000, 5, 'MONTHLY', 'FLAT', 3, 'MONTH', 'MONTHLY', '2026-02-15', '2026-04-01', 'ACTIVE', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-000000000721', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000201', 10000, '2026-03-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-000000000711', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000701', 1, '2026-04-01', 4000, 100),
  ('11000000-0000-0000-0000-000000000712', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000701', 2, '2026-05-01', 3000, 80),
  ('11000000-0000-0000-0000-000000000713', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000701', 3, '2026-06-01', 3000, 60);
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number, reversed_at, reversed_by, reversal_reason) values
  ('11000000-0000-0000-0000-000000000801', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 1100, '2026-04-10', 'CASH', 'POSTED', 'LHA3-RCPT-001', null, null, null),
  ('11000000-0000-0000-0000-000000000802', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 500, '2026-05-10', 'CASH', 'REVERSED', 'LHA3-RCPT-002', '2026-05-20 10:00:00+00', '11000000-0000-0000-0000-000000000011', 'Wrong loan'),
  ('11000000-0000-0000-0000-000000000803', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 200, '2026-05-25', 'CASH', 'REVERSED', 'LHA3-RCPT-003', '2026-05-25 18:00:00+00', '11000000-0000-0000-0000-000000000011', 'Same-day correction');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-000000000811', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000801', '11000000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000711', null, 100, 1),
  ('11000000-0000-0000-0000-000000000812', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000801', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000711', null, 1000, 2),
  ('11000000-0000-0000-0000-000000000813', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000802', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000712', null, 500, 1),
  ('11000000-0000-0000-0000-000000000814', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000803', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000713', null, 200, 1);
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days, basis_amount, fixed_amount, penalty_amount, origin) values
  ('11000000-0000-0000-0000-000000000831', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000701', '11000000-0000-0000-0000-000000000711', '2026-04-20', 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 15, 4000, 50, 50, 'ASSESSED');

-- ---------------------------------------------------------------------
-- L3 (NEW, disbursed 2026-02-01, principal 5000). Written off 04-01,
-- write-off reversed 04-15. Recovery 300 posted 04-10 (cash only).
--   i1 due 03-01 P5000 I50.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000703', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-003', 5000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-01-15', '2026-03-01', 'WRITTEN_OFF', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-000000000723', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', '11000000-0000-0000-0000-000000000201', 5000, '2026-02-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-000000000731', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', 1, '2026-03-01', 5000, 50);
insert into public.loan_write_off_events (id, group_id, loan_account_id, event_type, principal_amount, interest_amount, penalty_amount, reason_code, effective_date, reverses_write_off_id) values
  ('11000000-0000-0000-0000-000000000741', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', 'WRITE_OFF', 5000, 50, 0, 'GROUP_DECISION', '2026-04-01', null),
  ('11000000-0000-0000-0000-000000000742', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', 'REVERSAL', -5000, -50, 0, 'GROUP_DECISION', '2026-04-15', '11000000-0000-0000-0000-000000000741'),
  -- A second, active write-off after the reversal: the loan is written off today.
  ('11000000-0000-0000-0000-000000000743', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', 'WRITE_OFF', 4700, 50, 0, 'GROUP_DECISION', '2026-04-20', null);
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number, reversed_at, reversed_by, reversal_reason) values
  ('11000000-0000-0000-0000-000000000804', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 300, '2026-04-10', 'CASH', 'REVERSED', 'LHA3-RCPT-004', '2026-04-12 10:00:00+00', '11000000-0000-0000-0000-000000000011', 'Recovery entered in error');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-000000000809', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 200, '2026-04-25', 'CASH', 'POSTED', 'LHA3-RCPT-009');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-000000000815', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000804', '11000000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_PRINCIPAL', '11000000-0000-0000-0000-000000000703', null, null, 300, 1),
  ('11000000-0000-0000-0000-000000000824', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000809', '11000000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_PRINCIPAL', '11000000-0000-0000-0000-000000000703', null, null, 200, 1);
insert into public.loan_recovery_events (id, group_id, loan_account_id, write_off_event_id, payment_id, principal_recovered, interest_recovered, penalty_recovered) values
  ('11000000-0000-0000-0000-0000000000a1', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', '11000000-0000-0000-0000-000000000741', '11000000-0000-0000-0000-000000000804', 300, 0, 0),
  ('11000000-0000-0000-0000-0000000000a2', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000703', '11000000-0000-0000-0000-000000000743', '11000000-0000-0000-0000-000000000809', 200, 0, 0);

-- ---------------------------------------------------------------------
-- L4 (NEW, disbursed 2026-01-01, principal 6000). Early settlement 06-02.
--   i1 due 02-01 P2000 I20; i2 due 03-01 P2000 I15;
--   i3 due 07-01 P2000 I10 (cancelled by the settlement).
--   Settlement 6035: P 2000+2000+2000 on i1..i3, I 20 on i1, I 15 on i2.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-004', 6000, 5, 'MONTHLY', 'FLAT', 3, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'CLOSED', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-000000000724', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000201', 6000, '2026-01-01');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-000000000805', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 6035, '2026-06-02', 'CASH', 'POSTED', 'LHA3-RCPT-005');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due, cancelled_at, cancellation_reason, cancelled_by_payment_id) values
  ('11000000-0000-0000-0000-000000000741', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000704', 1, '2026-02-01', 2000, 20, null, null, null),
  ('11000000-0000-0000-0000-000000000742', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000704', 2, '2026-03-01', 2000, 15, null, null, null),
  ('11000000-0000-0000-0000-000000000743', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000704', 3, '2026-07-01', 2000, 10, '2026-06-02 09:00:00+00', 'EARLY_SETTLEMENT', '11000000-0000-0000-0000-000000000805');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-000000000816', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000805', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000741', null, 2000, 1),
  ('11000000-0000-0000-0000-000000000817', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000805', '11000000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000741', null, 20, 2),
  ('11000000-0000-0000-0000-000000000818', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000805', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000742', null, 2000, 3),
  ('11000000-0000-0000-0000-000000000819', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000805', '11000000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000742', null, 15, 4),
  ('11000000-0000-0000-0000-000000000820', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000805', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000704', '11000000-0000-0000-0000-000000000743', null, 2000, 5);
insert into public.loan_account_events (id, group_id, loan_account_id, event_type, from_status, to_status, reason, metadata, created_at) values
  ('11000000-0000-0000-0000-000000000851', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000704', 'EARLY_SETTLED', 'ACTIVE', 'CLOSED', 'Early settlement', jsonb_build_object('payment_id', '11000000-0000-0000-0000-000000000805'), '2026-06-02 09:00:00+00');

-- ---------------------------------------------------------------------
-- L5 (NEW, disbursed 2026-01-01, principal 3000). Restructure 02-15.
--   i1 due 02-01 P1000 I10 (original).
--   i2 due 03-01 P1000 I10, i3 due 04-01 P1000 I10: cancelled 02-15 12:00
--   (RESTRUCTURE). i4 due 03-15 P1000 I9: replacement created 02-15 12:00.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000705', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-005', 3000, 5, 'MONTHLY', 'FLAT', 3, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'ACTIVE', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-000000000725', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000705', '11000000-0000-0000-0000-000000000201', 3000, '2026-01-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due, created_at, cancelled_at, cancellation_reason) values
  ('11000000-0000-0000-0000-000000000751', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000705', 1, '2026-02-01', 1000, 10, '2026-01-01 08:00:00+00', null, null),
  ('11000000-0000-0000-0000-000000000752', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000705', 2, '2026-03-01', 1000, 10, '2026-01-01 08:00:00+00', '2026-02-15 12:00:00+00', 'RESTRUCTURE'),
  ('11000000-0000-0000-0000-000000000753', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000705', 3, '2026-04-01', 1000, 10, '2026-01-01 08:00:00+00', '2026-02-15 12:00:00+00', 'RESTRUCTURE'),
  ('11000000-0000-0000-0000-000000000754', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000705', 4, '2026-03-15', 1000, 9, '2026-02-15 12:00:00+00', null, null);
insert into public.loan_restructure_events (id, group_id, loan_account_id, effective_date, reason, new_interest_rate, new_term, new_first_installment_date, old_remaining_schedule_snapshot, new_remaining_schedule_snapshot, created_at) values
  ('11000000-0000-0000-0000-000000000761', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000705', '2026-02-15', 'Hardship restructure', 5, 2, '2026-03-15', '[]'::jsonb, '[]'::jsonb, '2026-02-15 12:00:00+00');

-- ---------------------------------------------------------------------
-- L6 (NEW, disbursed 2026-01-01, principal 4000). Prepayment 1500 on
-- 03-15 (REDUCE_INSTALLMENT). Negative interest correction -1 on i1
-- effective 02-20.
--   i1 due 02-01 P1000 I10; i2 due 03-01 P1000 I10;
--   i3 due 04-01 and i4 due 05-01 (P1000 I10 each): cancelled 03-15.
--   i5 due 04-01 P1250 I5 and i6 due 05-01 P1250 I5: replacements 03-15.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000706', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-006', 4000, 5, 'MONTHLY', 'FLAT', 4, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'ACTIVE', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-000000000726', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', '11000000-0000-0000-0000-000000000201', 4000, '2026-01-01');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-000000000806', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 1500, '2026-03-15', 'CASH', 'POSTED', 'LHA3-RCPT-006');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due, created_at, cancelled_at, cancellation_reason, cancelled_by_payment_id, created_by_payment_id) values
  ('11000000-0000-0000-0000-000000000761', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 1, '2026-02-01', 1000, 10, '2026-01-01 08:00:00+00', null, null, null, null),
  ('11000000-0000-0000-0000-000000000762', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 2, '2026-03-01', 1000, 10, '2026-01-01 08:00:00+00', null, null, null, null),
  ('11000000-0000-0000-0000-000000000763', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 3, '2026-04-01', 1000, 10, '2026-01-01 08:00:00+00', '2026-03-15 10:00:00+00', 'PRINCIPAL_PREPAYMENT', '11000000-0000-0000-0000-000000000806', null),
  ('11000000-0000-0000-0000-000000000764', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 4, '2026-05-01', 1000, 10, '2026-01-01 08:00:00+00', '2026-03-15 10:00:00+00', 'PRINCIPAL_PREPAYMENT', '11000000-0000-0000-0000-000000000806', null),
  ('11000000-0000-0000-0000-000000000765', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 5, '2026-04-01', 1250, 5, '2026-03-15 10:00:00+00', null, null, null, '11000000-0000-0000-0000-000000000806'),
  ('11000000-0000-0000-0000-000000000766', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 6, '2026-05-01', 1250, 5, '2026-03-15 10:00:00+00', null, null, null, '11000000-0000-0000-0000-000000000806');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-000000000821', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000806', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL_PREPAYMENT', '11000000-0000-0000-0000-000000000706', null, null, 1500, 1);
insert into public.loan_prepayment_events (id, group_id, loan_account_id, membership_id, payment_id, effective_date, amount, treatment, old_future_schedule_snapshot, new_future_schedule_snapshot) values
  ('11000000-0000-0000-0000-000000000841', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000806', '2026-03-15', 1500, 'REDUCE_INSTALLMENT', '[]'::jsonb, '[]'::jsonb);
insert into public.loan_obligation_adjustments (id, group_id, loan_account_id, target_type, loan_installment_id, adjustment_type, amount, reason_code, effective_date) values
  ('11000000-0000-0000-0000-000000000771', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000706', 'LOAN_INTEREST', '11000000-0000-0000-0000-000000000761', 'CORRECTION_DECREASE', -1, 'DATA_ENTRY_ERROR', '2026-02-20');

-- ---------------------------------------------------------------------
-- L7 (NEW, disbursed 2026-01-01, principal 4000). Prepayment 1500 on
-- 03-15 with REDUCE_TERM: a single replacement row P2500 I10.
--   i1 due 02-01 P1000 I10; i2 due 03-01 P1000 I10;
--   i3 due 04-01, i4 due 05-01 (P1000 I10 each): cancelled 03-15.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000707', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-007', 4000, 5, 'MONTHLY', 'FLAT', 4, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'ACTIVE', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-000000000727', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', '11000000-0000-0000-0000-000000000201', 4000, '2026-01-01');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-000000000807', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 1500, '2026-03-15', 'CASH', 'POSTED', 'LHA3-RCPT-007');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due, created_at, cancelled_at, cancellation_reason, cancelled_by_payment_id, created_by_payment_id) values
  ('11000000-0000-0000-0000-000000000771', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', 1, '2026-02-01', 1000, 10, '2026-01-01 08:00:00+00', null, null, null, null),
  ('11000000-0000-0000-0000-000000000772', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', 2, '2026-03-01', 1000, 10, '2026-01-01 08:00:00+00', null, null, null, null),
  ('11000000-0000-0000-0000-000000000773', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', 3, '2026-04-01', 1000, 10, '2026-01-01 08:00:00+00', '2026-03-15 10:00:00+00', 'PRINCIPAL_PREPAYMENT', '11000000-0000-0000-0000-000000000807', null),
  ('11000000-0000-0000-0000-000000000774', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', 4, '2026-05-01', 1000, 10, '2026-01-01 08:00:00+00', '2026-03-15 10:00:00+00', 'PRINCIPAL_PREPAYMENT', '11000000-0000-0000-0000-000000000807', null),
  ('11000000-0000-0000-0000-000000000775', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', 5, '2026-04-01', 2500, 10, '2026-03-15 10:00:00+00', null, null, null, '11000000-0000-0000-0000-000000000807');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-000000000822', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000807', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL_PREPAYMENT', '11000000-0000-0000-0000-000000000707', null, null, 1500, 1);
insert into public.loan_prepayment_events (id, group_id, loan_account_id, membership_id, payment_id, effective_date, amount, treatment, old_future_schedule_snapshot, new_future_schedule_snapshot) values
  ('11000000-0000-0000-0000-000000000842', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000707', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000807', '2026-03-15', 1500, 'REDUCE_TERM', '[]'::jsonb, '[]'::jsonb);

-- ---------------------------------------------------------------------
-- L8 (MIGRATED). Original disbursement 2025-06-01, opening position
-- 2026-01-01: principal 9000 (all future), interest arrears 100, penalty
-- arrears 40 (OPENING charge), future interest 60.
--   f1 due 02-01 P3000 I20; f2 due 03-01 P3000 I20; f3 due 04-01 P3000 I20.
--   P_MG 02-15 posted 1000 LOAN_PRINCIPAL on f1.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000708', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-008', 12000, 5, 'MONTHLY', 'FLAT', 12, 'MONTH', 'MONTHLY', '2025-05-20', '2026-02-01', 'ACTIVE', 'MIGRATED');
insert into public.loan_opening_positions (id, group_id, loan_account_id, opening_as_of_date, original_disbursement_date, original_loan_number, original_principal, opening_principal_outstanding, opening_principal_arrears, opening_interest_arrears, opening_penalty_arrears, future_scheduled_principal, future_scheduled_interest, remaining_installment_count, next_due_date) values
  ('11000000-0000-0000-0000-000000000861', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000708', '2026-01-01', '2025-06-01', 'OLD-A3-008', 12000, 9000, 0, 100, 40, 9000, 60, 3, '2026-02-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-000000000781', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000708', 1, '2026-02-01', 3000, 20),
  ('11000000-0000-0000-0000-000000000782', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000708', 2, '2026-03-01', 3000, 20),
  ('11000000-0000-0000-0000-000000000783', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000708', 3, '2026-04-01', 3000, 20);
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_amount, origin) values
  ('11000000-0000-0000-0000-000000000832', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000708', '11000000-0000-0000-0000-000000000781', '2025-12-01', 0, 40, 'OPENING');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-000000000808', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 1000, '2026-02-15', 'CASH', 'POSTED', 'LHA3-RCPT-008'),
  ('11000000-0000-0000-0000-000000000810', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 25, '2026-02-20', 'CASH', 'POSTED', 'LHA3-RCPT-010');
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days, basis_amount, fixed_amount, penalty_amount, origin) values
  ('11000000-0000-0000-0000-000000000833', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000708', '11000000-0000-0000-0000-000000000781', '2026-02-10', 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 15, 3000, 25, 25, 'ASSESSED');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-000000000823', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000808', '11000000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11000000-0000-0000-0000-000000000708', '11000000-0000-0000-0000-000000000781', null, 1000, 1),
  ('11000000-0000-0000-0000-000000000825', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000810', '11000000-0000-0000-0000-000000000102', 'LOAN_PENALTY', '11000000-0000-0000-0000-000000000708', '11000000-0000-0000-0000-000000000781', '11000000-0000-0000-0000-000000000833', 25, 1);

-- ---------------------------------------------------------------------
-- L9 (NEW, malformed): write-off 03-05, recovery 100 posted 03-10 against
-- it, then a write-off REVERSAL 03-15 inserted directly. The write-path
-- guard forbids this; the historical helper must not manufacture a
-- receivable for it.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-000000000709', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-009', 1000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-01-15', '2026-03-01', 'ACTIVE', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-0000000000b9', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000709', '11000000-0000-0000-0000-000000000201', 1000, '2026-02-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-0000000000b1', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000709', 1, '2026-03-01', 1000, 10);
insert into public.loan_write_off_events (id, group_id, loan_account_id, event_type, principal_amount, interest_amount, penalty_amount, reason_code, effective_date, reverses_write_off_id) values
  ('11000000-0000-0000-0000-0000000000b3', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000709', 'WRITE_OFF', 1000, 10, 0, 'GROUP_DECISION', '2026-03-05', null),
  ('11000000-0000-0000-0000-0000000000b4', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000709', 'REVERSAL', -1000, -10, 0, 'GROUP_DECISION', '2026-03-15', '11000000-0000-0000-0000-0000000000b3');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-0000000000b5', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 100, '2026-03-10', 'CASH', 'POSTED', 'LHA3-RCPT-B5');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-0000000000b6', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000b5', '11000000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_PRINCIPAL', '11000000-0000-0000-0000-000000000709', null, null, 100, 1);
insert into public.loan_recovery_events (id, group_id, loan_account_id, write_off_event_id, payment_id, principal_recovered, interest_recovered, penalty_recovered) values
  ('11000000-0000-0000-0000-0000000000b7', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000709', '11000000-0000-0000-0000-0000000000b3', '11000000-0000-0000-0000-0000000000b5', 100, 0, 0);

-- ---------------------------------------------------------------------
-- L10 (NEW, write-off with no recovery): principal 1000, due 03-01,
-- written off 03-05. Write-off is not a payment.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-0000000000c0', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-010', 1000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-01-15', '2026-03-01', 'WRITTEN_OFF', 'NEW');
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11000000-0000-0000-0000-0000000000c1', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000c0', '11000000-0000-0000-0000-000000000201', 1000, '2026-02-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-0000000000c2', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000c0', 1, '2026-03-01', 1000, 0);
insert into public.loan_write_off_events (id, group_id, loan_account_id, event_type, principal_amount, interest_amount, penalty_amount, reason_code, effective_date) values
  ('11000000-0000-0000-0000-0000000000c3', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000c0', 'WRITE_OFF', 1000, 0, 0, 'GROUP_DECISION', '2026-03-05');


-- ---------------------------------------------------------------------
-- L11 (MIGRATED, A3.2 penalty buckets). Original disbursement 2025-06-01,
-- opening 2026-01-01: principal 3000 (future), penalty arrears 40 imported
-- as ONE OPENING charge (the same obligation, apportioned).
--   ASSESSED (distinct Umoja obligations, all on installment g1 due 02-01):
--     A1 assessed 2025-12-20 (pre-opening, recorded after import) 25
--     A2 assessed 2026-01-01 (on opening)                         15
--     A3 assessed 2026-02-01 (post-opening, recurring #3)          10
--     A4 assessed 2026-03-01 (post-opening, recurring #4)          12
--   Payments: 10 against the OPENING charge (01-20); 25 against A1
--   (01-25); 10 against A3 (02-10). Adjustments: -5 on the OPENING charge
--   (02-15); -2 on A4 (03-05).
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000601', 'LN-A3-011', 3000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-05-20', '2026-02-01', 'ACTIVE', 'MIGRATED');
insert into public.loan_opening_positions (id, group_id, loan_account_id, opening_as_of_date, original_disbursement_date, original_loan_number, original_principal, opening_principal_outstanding, opening_principal_arrears, opening_interest_arrears, opening_penalty_arrears, future_scheduled_principal, future_scheduled_interest, remaining_installment_count, next_due_date) values
  ('11000000-0000-0000-0000-0000000000d1', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', '2026-01-01', '2025-06-01', 'OLD-A3-011', 3000, 3000, 0, 0, 40, 3000, 0, 1, '2026-02-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-0000000000d2', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', 1, '2026-02-01', 3000, 0);
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_amount, origin) values
  ('11000000-0000-0000-0000-0000000000d3', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '2025-12-01', 0, 40, 'OPENING');
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days, basis_amount, fixed_amount, penalty_amount, origin) values
  ('11000000-0000-0000-0000-0000000000d4', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '2025-12-20', 1, 'FIXED', 'RECURRING_MONTHLY', 'OUTSTANDING_INSTALLMENT', 0, 3000, 25, 25, 'ASSESSED'),
  ('11000000-0000-0000-0000-0000000000d5', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '2026-01-01', 2, 'FIXED', 'RECURRING_MONTHLY', 'OUTSTANDING_INSTALLMENT', 0, 3000, 15, 15, 'ASSESSED'),
  ('11000000-0000-0000-0000-0000000000d6', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '2026-02-01', 3, 'FIXED', 'RECURRING_MONTHLY', 'OUTSTANDING_INSTALLMENT', 0, 3000, 10, 10, 'ASSESSED'),
  ('11000000-0000-0000-0000-0000000000d7', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '2026-03-01', 4, 'FIXED', 'RECURRING_MONTHLY', 'OUTSTANDING_INSTALLMENT', 0, 3000, 12, 12, 'ASSESSED');
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('11000000-0000-0000-0000-0000000000d8', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 10, '2026-01-20', 'CASH', 'POSTED', 'LHA3-RCPT-D8'),
  ('11000000-0000-0000-0000-0000000000d9', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 25, '2026-01-25', 'CASH', 'POSTED', 'LHA3-RCPT-D9'),
  ('11000000-0000-0000-0000-0000000000da', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000102', '11000000-0000-0000-0000-000000000201', 10, '2026-02-10', 'CASH', 'POSTED', 'LHA3-RCPT-DA');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('11000000-0000-0000-0000-0000000000e1', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d8', '11000000-0000-0000-0000-000000000102', 'LOAN_PENALTY', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '11000000-0000-0000-0000-0000000000d3', 10, 1),
  ('11000000-0000-0000-0000-0000000000e2', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d9', '11000000-0000-0000-0000-000000000102', 'LOAN_PENALTY', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '11000000-0000-0000-0000-0000000000d4', 25, 1),
  ('11000000-0000-0000-0000-0000000000e3', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000da', '11000000-0000-0000-0000-000000000102', 'LOAN_PENALTY', '11000000-0000-0000-0000-0000000000d0', '11000000-0000-0000-0000-0000000000d2', '11000000-0000-0000-0000-0000000000d6', 10, 1);
insert into public.loan_obligation_adjustments (id, group_id, loan_account_id, target_type, loan_penalty_charge_id, adjustment_type, amount, reason_code, effective_date) values
  ('11000000-0000-0000-0000-0000000000db', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', 'LOAN_PENALTY', '11000000-0000-0000-0000-0000000000d3', 'CORRECTION_DECREASE', -5, 'DATA_ENTRY_ERROR', '2026-02-15'),
  ('11000000-0000-0000-0000-0000000000dc', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000d0', 'LOAN_PENALTY', '11000000-0000-0000-0000-0000000000d7', 'CORRECTION_DECREASE', -2, 'DATA_ENTRY_ERROR', '2026-03-05');

-- ---------------------------------------------------------------------
-- L12 (MIGRATED, malformed): opening snapshot penalty arrears 40 but its
-- OPENING-origin detail sums to 30. Provenance cannot be reconstructed.
-- ---------------------------------------------------------------------
-- A separate membership holds the malformed loan so the borrower's own
-- B3 aggregates (above) stay exact; its NULL aggregate is asserted below.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('11000000-0000-0000-0000-000000000103', '11000000-0000-0000-0000-000000000001', null, 'Malformed Fixture', 'ACTIVE', '2025-01-03', 'LHA3-0003', null);
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11000000-0000-0000-0000-0000000000f0', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000103', '11000000-0000-0000-0000-000000000601', 'LN-A3-012', 1000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-05-20', '2026-02-01', 'ACTIVE', 'MIGRATED');
insert into public.loan_opening_positions (id, group_id, loan_account_id, opening_as_of_date, original_disbursement_date, original_loan_number, original_principal, opening_principal_outstanding, opening_principal_arrears, opening_interest_arrears, opening_penalty_arrears, future_scheduled_principal, future_scheduled_interest, remaining_installment_count, next_due_date) values
  ('11000000-0000-0000-0000-0000000000f1', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000f0', '2026-01-01', '2025-06-01', 'OLD-A3-012', 1000, 1000, 0, 0, 40, 1000, 0, 1, '2026-02-01');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11000000-0000-0000-0000-0000000000f2', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000f0', 1, '2026-02-01', 1000, 0);
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_amount, origin) values
  ('11000000-0000-0000-0000-0000000000f3', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-0000000000f0', '11000000-0000-0000-0000-0000000000f2', '2025-12-01', 0, 30, 'OPENING');

-- =====================================================================
-- A. Canonical historical position (direct helper)
-- =====================================================================

-- A1/A2: NEW loan before disbursement is an available zero.
select is(
  (select position_state from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-02-28')),
  'AVAILABLE', 'NEW loan before disbursement: position AVAILABLE (zero, never fabricated history)');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-02-28')),
  0::numeric, 'NEW loan before disbursement: total outstanding exactly 0');

-- A3: funded principal exists on disbursement, regardless of future due dates.
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-03-01')),
  10000::numeric, 'on disbursement: principal 10000 is the receivable, although no installment is due yet');

-- A4/A5: future/unearned interest is excluded from total and reported apart.
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-03-01')),
  10000::numeric, 'on disbursement: total excludes all future/unearned interest (240)');
select is(
  (select scheduled_unearned_interest from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-03-01')),
  240::numeric, 'on disbursement: scheduled unearned interest reported separately (100+80+60)');

-- A6: earned interest is included once it is payable (due_date <= D).
select is(
  (select earned_interest_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-04-09')),
  100::numeric, 'earned interest 100 on i1 is included on 2026-04-09 (due 04-01, unpaid)');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-04-09')),
  10100::numeric, 'total 10100 = principal 10000 + earned 100 (unearned 140 excluded)');

-- A7/A8: payment counts only on/after its effective date (end-of-day D).
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-04-09')),
  10000::numeric, 'payment P1 (effective 04-10) does not count on 04-09');
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-04-10')),
  9000::numeric, 'payment P1 counts on its own effective date 04-10 (principal 10000 - 1000)');

-- A9/A10: penalty counts only from its assessment date.
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-04-19')),
  0::numeric, 'penalty assessed 04-20 does not exist on 04-19');
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-04-20')),
  50::numeric, 'penalty 50 exists on its assessment date 04-20');

-- A11/A12: payment reversal window A <= D < B uses reversal date, not status.
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-05-10')),
  8500::numeric, 'reversal window: P2 (effective 05-10, reversed 05-20) counts on 05-10');
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-05-19')),
  8500::numeric, 'reversal window: P2 still counts on 05-19 (before its reversal)');
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-05-20')),
  9000::numeric, 'reversal window: P2 stops counting on its reversal date 05-20');

-- A13/A14: same-day reversal produces the correct end-of-day result.
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-05-24')),
  9000::numeric, 'same-day reversal: P3 does not count before its effective date 05-25');
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000701', '2026-05-25')),
  9000::numeric, 'same-day reversal: P3 (posted and reversed 05-25) does not count at end of 05-25');

-- A15: written-off is zero; recovery is cash and does not recreate the receivable.
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-03-31')),
  5050::numeric, 'L3 before write-off: principal 5000 + earned 50 (due 03-01)');
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-04-01')),
  'AVAILABLE/WRITTEN_OFF', 'write-off effective 04-01: receivable state WRITTEN_OFF');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-04-10')),
  0::numeric, 'recovery 300 on 04-10 does NOT recreate receivable while written off');

-- A16: a valid write-off reversal restores the receivable from its effective date.
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-04-12')),
  0::numeric, 'recovery reversed 04-12 but write-off still effective: receivable stays 0 (RR <= D < WR)');
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-04-15')),
  5000::numeric, 'write-off reversed 04-15 after recovery reversal: receivable restored to 5000 (reversed recovery no longer reduces it)');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-04-15')),
  5050::numeric, 'write-off reversed 04-15: restored total is principal 5000 + earned 50 (due 03-01)');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000703', '2026-04-25')),
  0::numeric, 'second write-off effective 04-20 with recovery 200 on 04-25 (cash only): total 0');

-- A17/A18: settlement — before, on, after (cancelled future rows).
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000704', '2026-06-01')),
  6035::numeric, 'early settlement: before 06-02 the cancelled future row still exists (principal 6000 + earned 35)');
select is(
  (select unearned_or_null from (select scheduled_unearned_interest as unearned_or_null from public.loan_historical_position('11000000-0000-0000-0000-000000000704', '2026-06-01')) x),
  10::numeric, 'early settlement: the future row interest 10 is still scheduled/unearned before settlement');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000704', '2026-06-02')),
  0::numeric, 'early settlement on 06-02: total 0 and the cancelled row is gone');

-- A19/A20: restructure — pre-restructure schedule, replacement absent before creation.
select is(
  (select scheduled_unearned_interest from public.loan_historical_position('11000000-0000-0000-0000-000000000705', '2026-02-14')),
  20::numeric, 'restructure: before 02-15 the cancelled rows (i2, i3) exist; replacement absent (unearned 10+10)');
select is(
  (select scheduled_unearned_interest from public.loan_historical_position('11000000-0000-0000-0000-000000000705', '2026-02-15')),
  9::numeric, 'restructure: on 02-15 the replacement exists and the cancelled rows are gone (unearned 9)');

-- A21/A22: prepayment REDUCE_INSTALLMENT: pre-event schedule, then reduced principal once.
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000706', '2026-03-14')),
  4000::numeric, 'prepayment (REDUCE_INSTALLMENT): principal 4000 before 03-15');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000706', '2026-03-15')),
  2519::numeric, 'prepayment on 03-15: principal 2500 (once) + earned 19 (not double-counted)');

-- A23: prepayment REDUCE_TERM reduces principal once as well.
select is(
  (select principal_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000707', '2026-03-15')),
  2500::numeric, 'prepayment (REDUCE_TERM): principal 2500 on 03-15, counted once');

-- A24/A25: signed negative interest correction takes effect on its date.
select is(
  (select earned_interest_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000706', '2026-02-19')),
  10::numeric, 'negative interest correction effective 02-20: earned still 10 on 02-19');
select is(
  (select earned_interest_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000706', '2026-02-20')),
  9::numeric, 'negative interest correction effective 02-20: earned 9 on 02-20 (signed)');

-- A26/A27: MIGRATED — zero before original disbursement; NOT_AVAILABLE before opening.
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2025-05-31')),
  'AVAILABLE/BEFORE_ORIGINAL_DISBURSEMENT', 'MIGRATED before original disbursement: AVAILABLE zero');
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2025-09-01')),
  'NOT_AVAILABLE/BEFORE_OPENING_POSITION', 'MIGRATED between original disbursement and opening: NOT_AVAILABLE');

-- A28/A29: MIGRATED at the opening date starts from the authoritative record.
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2026-01-01')),
  9140::numeric, 'MIGRATED at opening: principal 9000 + interest arrears 100 + penalty arrears 40 (= record)');
select is(
  (select scheduled_unearned_interest from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2026-01-01')),
  60::numeric, 'MIGRATED at opening: future scheduled interest 60 reported as unearned, not in total');

-- A30: MIGRATED after opening with repayment; no manufactured payment or disbursement.
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2026-02-15')),
  65::numeric, 'MIGRATED: distinct ASSESSED penalty 25 (after opening) is added to the opening penalty 40 on 02-15');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2026-02-15')),
  8185::numeric, 'MIGRATED after opening: principal 8000 + earned 120 + penalty 65 (opening 40 + assessed 25)');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000708', '2026-02-20')),
  8160::numeric, 'allocation of 25 to the ASSESSED penalty on 02-20 reduces penalty to 40 on that date (never double-counted)');

-- A30b: malformed state (write-off reversed while a recovery is live) is NOT_AVAILABLE.
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-000000000709'::uuid, '2026-03-15')),
  'NOT_AVAILABLE/INVALID_WRITEOFF_RECOVERY_STATE', 'malformed: write-off reversed while recovery is live -> NOT_AVAILABLE, never a manufactured receivable');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-000000000709'::uuid, '2026-03-15')),
  null::numeric, 'malformed: no amount is fabricated (NULL, not zero)');
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-000000000709'::uuid, '2026-03-09')),
  'AVAILABLE/WRITTEN_OFF', 'malformed loan before the reversal: write-off effective, receivable 0');

-- A30c: write-off with no recovery is zero and remains non-payment.
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000c0'::uuid, '2026-03-04')),
  1000::numeric, 'write-off without recovery: principal 1000 before the write-off date');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000c0'::uuid, '2026-03-05')),
  0::numeric, 'write-off without recovery: receivable 0 on the write-off date');
select is(
  (select principal_repaid from public.loan_account_summary('11000000-0000-0000-0000-0000000000c0'::uuid)),
  0::numeric, 'write-off is NOT a repayment: principal_repaid stays 0');

-- A31: summary of a written-off loan is zero; principal_repaid stays actual.
select is(
  (select total_outstanding from public.loan_account_summary('11000000-0000-0000-0000-000000000703')),
  0::numeric, 'written-off loan: summary total outstanding is 0');
select is(
  (select principal_repaid from public.loan_account_summary('11000000-0000-0000-0000-000000000703')),
  200::numeric, 'written-off loan: principal_repaid is actual posted recovery cash 200 (reversed 300 excluded), not original minus outstanding');
select is(
  (select next_due_date from public.loan_account_summary('11000000-0000-0000-0000-000000000703')),
  null::date, 'written-off loan: next due date is null (no receivable)');

-- A32: summary of an open loan uses the earned definition (unearned excluded).
select is(
  (select total_outstanding from public.loan_account_summary('11000000-0000-0000-0000-000000000701')),
  9190::numeric, 'current summary L1 = principal 9000 + earned 140 (i2 80, i3 60) + penalty 50; P2/P3 reversed');
select is(
  (select interest_outstanding from public.loan_account_summary('11000000-0000-0000-0000-000000000701')),
  140::numeric, 'current summary L1 interest_outstanding is earned only (unearned excluded)');

-- A33: an internal canonical helper is never exposed to clients.
select ok(
  not has_function_privilege('authenticated', 'public.loan_historical_position(uuid, date)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.loan_historical_position(uuid, date)', 'EXECUTE')
  and not has_function_privilege('public', 'public.loan_historical_position(uuid, date)', 'EXECUTE'),
  'loan_historical_position is internal: no client execute grant');

-- =====================================================================
-- B. B3 integration (caller = borrower membership, self-service only)
-- =====================================================================

set local request.jwt.claim.sub to '11000000-0000-0000-0000-000000000012';

-- B1: B3 opening loans equal the sum of the canonical position at the cutoff.
select is(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2026-01-02'::date, null) -> 'period' -> 'opening' -> 'loans' ->> 'outstanding')::numeric,
  (select sum(h.total_outstanding) from public.loan_accounts la cross join lateral public.loan_historical_position(la.id, '2026-01-01'::date) h where la.membership_id = '11000000-0000-0000-0000-000000000102'),
  'B3 opening (cutoff 2026-01-01) equals the sum of canonical positions for the member');

-- B2: a NOT_AVAILABLE loan makes the aggregate NULL, never a silent partial sum.
select ok(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2025-09-02'::date, null) -> 'period' -> 'opening' -> 'loans' ->> 'outstanding') is null,
  'B3 opening with an unreconstructable loan (cutoff 2025-09-01) is NULL (NOT_AVAILABLE), not a partial sum');

-- B2b: an unavailable loan does not disturb the contribution or wallet figures.
select ok(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2025-09-02'::date, null) -> 'period' -> 'opening' -> 'contributions' ->> 'outstanding') is not null
  and (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2025-09-02'::date, null) -> 'period' -> 'opening' -> 'wallet' ->> 'balance') is not null,
  'B3 with an unavailable loan: contribution and wallet opening figures remain available');

-- B3: loans that have not yet existed contribute 0, so the aggregate is available.
select is(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2025-06-01'::date, null) -> 'period' -> 'opening' -> 'loans' ->> 'outstanding')::numeric,
  0::numeric, 'B3 opening before any loan existed is 0 (not NULL): nothing financially existed yet');

-- B4: B3 closing equals the sum of the canonical position at the cutoff.
select is(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, null, '2026-02-15'::date) -> 'period' -> 'closing' -> 'loans' ->> 'outstanding')::numeric,
  (select sum(h.total_outstanding) from public.loan_accounts la cross join lateral public.loan_historical_position(la.id, '2026-02-15'::date) h where la.membership_id = '11000000-0000-0000-0000-000000000102'),
  'B3 closing (cutoff 2026-02-15) equals the sum of canonical positions for the member');

-- B5: today's closing and today's current loan position use the SAME definition.
select is(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, null, current_date) -> 'period' -> 'closing' -> 'loans' ->> 'outstanding')::numeric,
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, null, null) -> 'summary' -> 'loans' ->> 'current_outstanding')::numeric,
  'today: B3 closing loans equals B3 current loans (same earned-interest definition)');

-- B6: contribution and wallet figures stay on their own (unchanged) paths.
select ok(
  (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2026-01-02'::date, null) -> 'period' -> 'opening' -> 'contributions' ->> 'outstanding') is not null
  and (public.rpc_get_my_member_statement('11000000-0000-0000-0000-000000000001'::uuid, '2026-01-02'::date, null) -> 'period' -> 'opening' -> 'wallet' ->> 'balance') is not null,
  'B3 contribution and wallet period figures are still returned as before');

-- B7: the borrower sees only their own loans (no caller-supplied identity).
select ok(
  not has_function_privilege('authenticated', 'public.loan_historical_position(uuid, date)', 'EXECUTE'),
  'self-service callers cannot reach the canonical helper directly');


-- =====================================================================
-- P. Penalty buckets (A3.2): OPENING obligation vs distinct ASSESSED
-- =====================================================================

-- P1/P2: the imported opening penalty is represented ONCE (snapshot 40,
-- not 40 + its OPENING charge) and distinct ASSESSED penalties are added.
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-01-01')),
  80::numeric, 'opening: imported penalty 40 (once) + distinct ASSESSED pre-opening 25 + on-opening 15 = 80');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-01-01')),
  3080::numeric, 'opening: total = principal 3000 + penalty 80 (no earned or unearned interest)');

-- P3/P6: ASSESSED penalty dated before opening, recorded after the import, is effective at its assessment date.
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2025-12-31')),
  'NOT_AVAILABLE/BEFORE_OPENING_POSITION', 'the pre-opening ASSESSED event does not fabricate a complete position inside the NOT_AVAILABLE interval');

-- P7: allocation against the OPENING charge reduces the opening bucket only.
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-01-20')),
  70::numeric, 'payment 10 on the OPENING charge (01-20): opening bucket 40->30, ASSESSED unchanged -> 30 + 25 + 15 = 70');

-- P8/P10: allocation against the pre-opening ASSESSED reduces ASSESSED only (paying ASSESSED does not touch the opening bucket).
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-01-25')),
  45::numeric, 'payment 25 on pre-opening ASSESSED (01-25): ASSESSED 25->0, opening stays 30 -> 30 + 15 = 45');

-- P5/P9: a post-opening ASSESSED penalty is distinct; its allocation reduces only its own bucket.
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-02-01')),
  55::numeric, 'post-opening ASSESSED 10 (02-01) is included: opening 30 + A2 15 + A3 10 = 55');
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-02-10')),
  45::numeric, 'payment 10 on post-opening ASSESSED A3 (02-10): A3 cleared, opening still 30 -> 45');

-- P11/P19: an adjustment against the OPENING obligation rewrites only the opening bucket (effective 02-15).
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-02-15')),
  40::numeric, 'OPENING adjustment -5 effective 02-15: opening 30->25, ASSESSED 15 unchanged -> 40');

-- P12: multiple recurring ASSESSED occurrences remain separate and exact.
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-03-01')),
  52::numeric, 'recurring #4 (12, 03-01) is separate: opening 25 + A2 15 + A4 12 = 52');

-- P19: an ASSESSED adjustment rewrites only its own ASSESSED bucket (-2 on A4, effective 03-05).
select is(
  (select penalty_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-03-05')),
  50::numeric, 'ASSESSED adjustment -2 on A4 (03-05): A4 12->10 only -> opening 25 + A2 15 + A4 10 = 50');

-- P13: opening + assessed + allocations produce the exact total.
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2026-03-05')),
  3050::numeric, 'exact total at 03-05: principal 3000 + penalty 50 (scheduled interest none)');

-- P14: before original disbursement the migrated position is an available zero.
select is(
  (select position_state || '/' || total_outstanding::text from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2025-05-31')),
  'AVAILABLE/0', 'migrated: before original disbursement the position is AVAILABLE 0');

-- P15: between original disbursement and opening: NOT_AVAILABLE.
select is(
  (select position_state from public.loan_historical_position('11000000-0000-0000-0000-0000000000d0', '2025-09-01')),
  'NOT_AVAILABLE', 'migrated: between original disbursement and opening is NOT_AVAILABLE');

-- P18: opening snapshot and its OPENING detail disagree: NOT_AVAILABLE, never silently summed.
select is(
  (select position_state || '/' || reason_code from public.loan_historical_position('11000000-0000-0000-0000-0000000000f0', '2026-01-01')),
  'NOT_AVAILABLE/OPENING_PENALTY_PROVENANCE_MISMATCH', 'malformed OPENING detail (30) vs snapshot (40): NOT_AVAILABLE, neither added nor guessed');
select is(
  (select total_outstanding from public.loan_historical_position('11000000-0000-0000-0000-0000000000f0', '2026-01-01')),
  null::numeric, 'malformed OPENING provenance: no amount fabricated (NULL)');

select * from finish();
rollback;
