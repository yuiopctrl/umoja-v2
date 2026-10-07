-- Prompt 09G-B6-B: member-safe payments & receipts backend.
--
-- Proves rpc_get_my_payments/rpc_get_my_payment_detail/rpc_get_my_receipt
-- are strict self-owned, group-scoped reads: ownership resolved exclusively
-- via current_membership_id() + payment.self_view (no role-name, officer,
-- or ADMIN fallback), a wallet-funded allocation never becomes a payment,
-- a payment-created wallet credit stays part of that same payment, a
-- reversal stays on the same row, and B3's own interpretation of the same
-- payment agrees with B6's.
begin;

select plan(64);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('11400000-0000-0000-0000-000000000011', 'p09gb6b-admin@example.com'),
  ('11400000-0000-0000-0000-000000000012', 'p09gb6b-member-a@example.com'),
  ('11400000-0000-0000-0000-000000000013', 'p09gb6b-member-b@example.com'),
  ('11400000-0000-0000-0000-000000000014', 'p09gb6b-treasurer@example.com'),
  ('11400000-0000-0000-0000-000000000015', 'p09gb6b-secretary@example.com'),
  ('11400000-0000-0000-0000-000000000016', 'p09gb6b-chair@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('11400000-0000-0000-0000-000000000001', 'B6B Group One', '11400000-0000-0000-0000-000000000011', 'B6BG1', 'ACTIVE'),
  ('11400000-0000-0000-0000-000000000002', 'B6B Group Two', '11400000-0000-0000-0000-000000000011', 'B6BG2', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('11400000-0000-0000-0000-000000000101', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'B6BG1-0001', null),
  ('11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000012', 'Member A', 'ACTIVE', '2025-01-02', 'B6BG1-0002', null),
  ('11400000-0000-0000-0000-000000000103', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000013', 'Member B', 'ACTIVE', '2025-01-03', 'B6BG1-0003', null),
  ('11400000-0000-0000-0000-000000000104', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000014', 'Treasurer', 'ACTIVE', '2025-01-04', 'B6BG1-0004', null),
  ('11400000-0000-0000-0000-000000000105', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000015', 'Secretary', 'ACTIVE', '2025-01-05', 'B6BG1-0005', null),
  ('11400000-0000-0000-0000-000000000106', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000016', 'Chair', 'ACTIVE', '2025-01-06', 'B6BG1-0006', null),
  ('11400000-0000-0000-0000-000000000201', '11400000-0000-0000-0000-000000000002', '11400000-0000-0000-0000-000000000012', 'Member A In Two', 'ACTIVE', '2025-01-02', 'B6BG2-0001', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '11400000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '11400000-0000-0000-0000-000000000104', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '11400000-0000-0000-0000-000000000105', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select '11400000-0000-0000-0000-000000000106', id from public.roles where code = 'CHAIRPERSON';
-- 102/103/201 are ordinary linked memberships: MEMBER comes only from the
-- 09G-B5-B.1 baseline trigger, never an explicit row here.

insert into public.financial_accounts (id, group_id, name, account_type) values
  ('11400000-0000-0000-0000-000000000301', '11400000-0000-0000-0000-000000000001', 'Cash Box One', 'CASH'),
  ('11400000-0000-0000-0000-000000000302', '11400000-0000-0000-0000-000000000002', 'Cash Box Two', 'CASH');

insert into public.loan_products (id, group_id, code, name, minimum_principal, maximum_principal, minimum_term, maximum_term, interest_rate, interest_rate_basis, interest_method) values
  ('11400000-0000-0000-0000-000000000401', '11400000-0000-0000-0000-000000000001', 'STD', 'Standard Loan', 1000, 500000, 1, 12, 5, 'MONTHLY', 'FLAT');

insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11400000-0000-0000-0000-000000000402', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000401', 'LN-B6B-402', 200000, 5, 'MONTHLY', 'FLAT', 3, 'MONTH', 'MONTHLY', '2026-01-01', '2026-02-01', 'ACTIVE', 'NEW'),
  ('11400000-0000-0000-0000-000000000403', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000401', 'LN-B6B-403', 50000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-01-01', '2026-02-01', 'WRITTEN_OFF', 'NEW');

insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('11400000-0000-0000-0000-000000000404', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000402', 1, '2026-05-01', 100000, 20000);

insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days, basis_amount, fixed_amount, penalty_amount, origin) values
  ('11400000-0000-0000-0000-000000000405', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000402', '11400000-0000-0000-0000-000000000404', '2026-04-04', 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 0, 2000, 2000, 2000, 'ASSESSED');

insert into public.contribution_types (id, group_id, name, category, accounting_treatment) values
  ('11400000-0000-0000-0000-000000000501', '11400000-0000-0000-0000-000000000001', 'Monthly Hisa', 'GENERAL', 'GROUP_INCOME');
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount) values
  ('11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000501', 'Hisa Setup', 'ON_DEMAND', 'FIXED', 15000);
-- One period per charge, since a membership may hold only one charge per
-- period, and a charge may hold only one BASE component.
insert into public.contribution_periods (id, group_id, contribution_setup_id, label, period_start, period_end, obligation_date, eligibility_date, due_date, status, purpose, snapshot_type_name, snapshot_category) values
  ('11400000-0000-0000-0000-000000000503', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 1', '2026-04-01', '2026-04-30', '2026-04-01', '2026-04-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL'),
  ('11400000-0000-0000-0000-000000000511', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 2', '2026-04-01', '2026-04-30', '2026-04-02', '2026-04-02', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL'),
  ('11400000-0000-0000-0000-000000000512', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 3', '2026-04-01', '2026-04-30', '2026-04-03', '2026-04-03', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL'),
  ('11400000-0000-0000-0000-000000000513', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 4', '2026-04-01', '2026-04-30', '2026-04-06', '2026-04-06', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL'),
  ('11400000-0000-0000-0000-000000000514', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 5', '2026-04-01', '2026-04-30', '2026-04-07', '2026-04-07', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL'),
  ('11400000-0000-0000-0000-000000000515', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 6', '2026-04-01', '2026-04-30', '2026-04-08', '2026-04-08', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL'),
  ('11400000-0000-0000-0000-000000000516', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000502', 'Hisa Period 7', '2026-04-01', '2026-04-30', '2026-04-01', '2026-04-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Hisa', 'GENERAL');

insert into public.member_contribution_charges (id, group_id, period_id, contribution_setup_id, membership_id, member_number_snapshot, member_name_snapshot, effective_at, due_date) values
  ('11400000-0000-0000-0000-000000000504', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000503', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000102', 'B6BG1-0002', 'Member A', '2026-04-01', '2026-12-31'),
  ('11400000-0000-0000-0000-000000000505', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000511', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000102', 'B6BG1-0002', 'Member A', '2026-04-02', '2026-12-31'),
  ('11400000-0000-0000-0000-000000000506', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000512', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000102', 'B6BG1-0002', 'Member A', '2026-04-03', '2026-12-31'),
  ('11400000-0000-0000-0000-000000000507', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000513', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000102', 'B6BG1-0002', 'Member A', '2026-04-06', '2026-12-31'),
  ('11400000-0000-0000-0000-000000000508', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000514', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000102', 'B6BG1-0002', 'Member A', '2026-04-07', '2026-12-31'),
  ('11400000-0000-0000-0000-000000000509', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000515', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000102', 'B6BG1-0002', 'Member A', '2026-04-08', '2026-12-31'),
  ('11400000-0000-0000-0000-000000000510', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000516', '11400000-0000-0000-0000-000000000502', '11400000-0000-0000-0000-000000000103', 'B6BG1-0003', 'Member B', '2026-04-01', '2026-12-31');

insert into public.contribution_charge_components (id, group_id, charge_id, component_type, assessed_amount, effective_at, sequence) values
  ('11400000-0000-0000-0000-000000000601', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000504', 'BASE', 15000, '2026-04-01', 1),
  ('11400000-0000-0000-0000-000000000602', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000505', 'BASE', 15000, '2026-04-02', 1),
  ('11400000-0000-0000-0000-000000000603', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000505', 'PENALTY', 3000, '2026-04-02', 2),
  ('11400000-0000-0000-0000-000000000604', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000506', 'BASE', 10000, '2026-04-03', 1),
  ('11400000-0000-0000-0000-000000000605', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000507', 'BASE', 150000, '2026-04-06', 1),
  ('11400000-0000-0000-0000-000000000606', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000508', 'BASE', 80000, '2026-04-07', 1),
  ('11400000-0000-0000-0000-000000000607', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000509', 'BASE', 25000, '2026-04-08', 1),
  ('11400000-0000-0000-0000-000000000608', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000510', 'BASE', 5000, '2026-04-01', 1);

-- ---------------------------------------------------------------------
-- Payments (membership 102 = Member A, group one, unless noted).
-- ---------------------------------------------------------------------
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, external_reference, notes, status, receipt_number, reversed_at, reversed_by, reversal_reason) values
  ('11400000-0000-0000-0000-000000000701', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 15000, '2026-04-01', 'CASH', 'REF-001', 'internal note one', 'POSTED', 'B6-RCPT-001', null, null, null),
  ('11400000-0000-0000-0000-000000000702', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 18000, '2026-04-02', 'CASH', 'REF-002', 'internal note two', 'POSTED', 'B6-RCPT-002', null, null, null),
  ('11400000-0000-0000-0000-000000000703', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 60000, '2026-04-03', 'MOBILE_MONEY', 'REF-003', null, 'POSTED', 'B6-RCPT-003', null, null, null),
  ('11400000-0000-0000-0000-000000000704', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 62000, '2026-04-04', 'CASH', 'REF-004', null, 'POSTED', 'B6-RCPT-004', null, null, null),
  ('11400000-0000-0000-0000-000000000705', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 36000, '2026-04-05', 'CASH', 'REF-005', null, 'POSTED', 'B6-RCPT-005', null, null, null),
  ('11400000-0000-0000-0000-000000000706', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 200000, '2026-04-06', 'BANK_TRANSFER', 'REF-006', null, 'POSTED', 'B6-RCPT-006', null, null, null),
  ('11400000-0000-0000-0000-000000000707', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 100000, '2026-04-07', 'CASH', 'REF-007', null, 'POSTED', 'B6-RCPT-007', null, null, null),
  ('11400000-0000-0000-0000-000000000708', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', '11400000-0000-0000-0000-000000000301', 25000, '2026-04-08', 'CASH', 'REF-008', null, 'REVERSED', 'B6-RCPT-008', '2026-04-09 10:00:00+00', '11400000-0000-0000-0000-000000000011', 'Entered in error'),
  ('11400000-0000-0000-0000-000000000709', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000103', '11400000-0000-0000-0000-000000000301', 5000, '2026-04-01', 'CASH', 'REF-009', null, 'POSTED', 'B6-RCPT-009', null, null, null),
  ('11400000-0000-0000-0000-000000000710', '11400000-0000-0000-0000-000000000002', '11400000-0000-0000-0000-000000000201', '11400000-0000-0000-0000-000000000302', 5000, '2026-04-01', 'CASH', 'REF-010', null, 'POSTED', 'B6-RCPT-010', null, null, null);

insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number, wallet_entry_id) values
  ('11400000-0000-0000-0000-000000000801', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000701', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000504', '11400000-0000-0000-0000-000000000601', null, null, null, 15000, 1, null),
  ('11400000-0000-0000-0000-000000000802', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000702', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000505', '11400000-0000-0000-0000-000000000602', null, null, null, 15000, 1, null),
  ('11400000-0000-0000-0000-000000000803', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000702', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000505', '11400000-0000-0000-0000-000000000603', null, null, null, 3000, 2, null),
  ('11400000-0000-0000-0000-000000000804', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000703', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000506', '11400000-0000-0000-0000-000000000604', null, null, null, 10000, 1, null),
  ('11400000-0000-0000-0000-000000000805', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000703', '11400000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', null, null, '11400000-0000-0000-0000-000000000402', '11400000-0000-0000-0000-000000000404', null, 50000, 2, null),
  ('11400000-0000-0000-0000-000000000806', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000704', '11400000-0000-0000-0000-000000000102', 'LOAN_INTEREST', null, null, '11400000-0000-0000-0000-000000000402', '11400000-0000-0000-0000-000000000404', null, 10000, 1, null),
  ('11400000-0000-0000-0000-000000000807', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000704', '11400000-0000-0000-0000-000000000102', 'LOAN_PENALTY', null, null, '11400000-0000-0000-0000-000000000402', '11400000-0000-0000-0000-000000000404', '11400000-0000-0000-0000-000000000405', 2000, 2, null),
  ('11400000-0000-0000-0000-000000000808', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000704', '11400000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL_PREPAYMENT', null, null, '11400000-0000-0000-0000-000000000402', null, null, 50000, 3, null),
  ('11400000-0000-0000-0000-000000000809', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000705', '11400000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_PRINCIPAL', null, null, '11400000-0000-0000-0000-000000000403', null, null, 30000, 1, null),
  ('11400000-0000-0000-0000-000000000810', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000705', '11400000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_INTEREST', null, null, '11400000-0000-0000-0000-000000000403', null, null, 5000, 2, null),
  ('11400000-0000-0000-0000-000000000811', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000705', '11400000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_PENALTY', null, null, '11400000-0000-0000-0000-000000000403', null, null, 1000, 3, null),
  ('11400000-0000-0000-0000-000000000812', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000706', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000507', '11400000-0000-0000-0000-000000000605', null, null, null, 150000, 1, null),
  ('11400000-0000-0000-0000-000000000813', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000707', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000508', '11400000-0000-0000-0000-000000000606', null, null, null, 80000, 1, null),
  ('11400000-0000-0000-0000-000000000815', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000708', '11400000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000509', '11400000-0000-0000-0000-000000000607', null, null, null, 25000, 1, null),
  ('11400000-0000-0000-0000-000000000816', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000709', '11400000-0000-0000-0000-000000000103', 'CONTRIBUTION_COMPONENT', '11400000-0000-0000-0000-000000000510', '11400000-0000-0000-0000-000000000608', null, null, null, 5000, 1, null);

-- Wallet credit created by payment 706; a second credit (payment 707) that
-- is later reversed; and a wallet APPLICATION (no payment_id at all).
insert into public.member_wallet_entries (id, group_id, membership_id, entry_type, amount, effective_at, source_type, source_id, reverses_entry_id, idempotency_key) values
  ('11400000-0000-0000-0000-000000000901', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', 'PAYMENT_CREDIT', 50000, '2026-04-06', 'PAYMENT', '11400000-0000-0000-0000-000000000706', null, 'b6-wallet-901'),
  ('11400000-0000-0000-0000-000000000902', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', 'PAYMENT_CREDIT', 20000, '2026-04-07', 'PAYMENT', '11400000-0000-0000-0000-000000000707', null, 'b6-wallet-902'),
  ('11400000-0000-0000-0000-000000000903', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', 'REVERSAL', 20000, '2026-04-08', null, null, '11400000-0000-0000-0000-000000000902', 'b6-wallet-903'),
  ('11400000-0000-0000-0000-000000000904', '11400000-0000-0000-0000-000000000001', '11400000-0000-0000-0000-000000000102', 'ALLOCATION_DEBIT', 10000, '2026-04-10', null, null, null, 'b6-wallet-904');

insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, amount, line_number, wallet_entry_id) values
  ('11400000-0000-0000-0000-000000000817', '11400000-0000-0000-0000-000000000001', null, '11400000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11400000-0000-0000-0000-000000000402', '11400000-0000-0000-0000-000000000404', 10000, 1, '11400000-0000-0000-0000-000000000904');

-- =====================================================================
-- A. Catalog / permission audit (run as the owning role)
-- =====================================================================

select is(
  (select count(*)::int from public.permissions where code = 'payment.self_view'),
  1,
  '1: payment.self_view permission exists exactly once'
);

select is(
  (select array_agg(r.code order by r.code)
   from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where p.code = 'payment.self_view'),
  array['ADMIN', 'MEMBER'],
  '2/3/4: payment.self_view is granted directly to exactly MEMBER and ADMIN'
);

select ok(
  not exists (
    select 1 from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.id = rp.permission_id
    where p.code = 'payment.self_view' and r.code in ('TREASURER', 'SECRETARY', 'CHAIRPERSON')
  ),
  '5/6/7: no direct grant to TREASURER, SECRETARY or CHAIRPERSON'
);

select is(
  (select array_agg(p.proname::text order by p.proname::text)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('rpc_get_my_payments', 'rpc_get_my_payment_detail', 'rpc_get_my_receipt')),
  array['rpc_get_my_payment_detail', 'rpc_get_my_payments', 'rpc_get_my_receipt'],
  'the three intended member-safe RPCs exist'
);

select ok(
  has_function_privilege('authenticated', 'public.rpc_get_my_payments(uuid,payment_status,date,date,integer,integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.rpc_get_my_payment_detail(uuid,uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.rpc_get_my_receipt(uuid,uuid)', 'EXECUTE'),
  'all three RPCs are executable by authenticated'
);

select ok(
  not has_function_privilege('anon', 'public.rpc_get_my_payments(uuid,payment_status,date,date,integer,integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.rpc_get_my_payment_detail(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.rpc_get_my_receipt(uuid,uuid)', 'EXECUTE'),
  '55: anon has no EXECUTE on any of the three RPCs'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where n.nspname = 'public'
      and p.proname in ('rpc_get_my_payments', 'rpc_get_my_payment_detail', 'rpc_get_my_receipt', 'member_payment_membership_id', 'member_payment_record')
      and a.grantee = 0 and a.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no EXECUTE on the RPCs or the internal helpers'
);

select ok(
  not has_function_privilege('authenticated', 'public.member_payment_membership_id(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.member_payment_record(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.member_payment_membership_id(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.member_payment_record(uuid)', 'EXECUTE'),
  '58: internal helpers are not client-executable (authenticated or anon)'
);

select ok(
  (select bool_and(p.prosecdef) and bool_and(pg_get_userbyid(p.proowner) = 'postgres') and bool_and(array_to_string(p.proconfig, ',') = 'search_path=""')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('rpc_get_my_payments', 'rpc_get_my_payment_detail', 'rpc_get_my_receipt', 'member_payment_membership_id', 'member_payment_record')),
  '57: every new function is SECURITY DEFINER, owned by postgres, with an empty search_path'
);

select is(
  (select pg_get_function_arguments(oid) from pg_proc where proname = 'rpc_get_my_payments'),
  'p_group_id uuid, p_status payment_status DEFAULT NULL::payment_status, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0',
  '15: rpc_get_my_payments has no caller-supplied membership/user parameter'
);

select ok(
  pg_get_function_arguments((select oid from pg_proc where proname = 'rpc_get_my_payment_detail')) !~* 'membership_id|user_id'
  and pg_get_function_arguments((select oid from pg_proc where proname = 'rpc_get_my_receipt')) !~* 'membership_id|user_id',
  '15b: detail and receipt RPCs take no membership/user identity parameter'
);

-- =====================================================================
-- B. Authorization boundary (before any session is established)
-- =====================================================================

set local role anon;
select throws_ok(
  $$select public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 20, 0)$$,
  '42501', null,
  'anon cannot call rpc_get_my_payments'
);
reset role;

set local role authenticated;
select throws_ok(
  $$select public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 20, 0)$$,
  '28000', 'Not authenticated',
  '56: no session is rejected with Not authenticated'
);
reset role;

-- =====================================================================
-- C. Business-row side-effect and receipt-number audit
-- =====================================================================

create temporary table b6_pre_counts as
select
  (select count(*) from public.payments) as payments,
  (select count(*) from public.payment_allocations) as allocations,
  (select count(*) from public.member_wallet_entries) as wallet_entries,
  (select count(*) from public.receipt_number_counters) as counter_rows,
  (select last_seq from public.receipt_number_counters where year = 2026) as counter_2026;
grant select on b6_pre_counts to authenticated;

set local role authenticated;
set local request.jwt.claim.sub to '11400000-0000-0000-0000-000000000012';
select public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 50, 0);
select public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid);
select public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid);
select public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid);
reset role;

select ok(
  (select payments from b6_pre_counts) = (select count(*) from public.payments)
  and (select allocations from b6_pre_counts) = (select count(*) from public.payment_allocations)
  and (select wallet_entries from b6_pre_counts) = (select count(*) from public.member_wallet_entries),
  '59: calling all three read RPCs mutates no business row'
);

select ok(
  (select counter_rows from b6_pre_counts) = (select count(*) from public.receipt_number_counters)
  and (select counter_2026 from b6_pre_counts) is not distinct from (select last_seq from public.receipt_number_counters where year = 2026),
  '60: reading a receipt twice never advances the receipt-number counter'
);

-- =====================================================================
-- D. Member A (102): list, filters, pagination, ordering
-- =====================================================================

-- Computed as the owning role (not under RLS) for comparison below.
create temporary table b6_expected_order as
select array_agg(id::text) as ids from (
  select id from public.payments
  where group_id = '11400000-0000-0000-0000-000000000001' and membership_id = '11400000-0000-0000-0000-000000000102'
  order by effective_at desc, created_at desc, id desc
) x;
grant select on b6_expected_order to authenticated;

set local role authenticated;
set local request.jwt.claim.sub to '11400000-0000-0000-0000-000000000012';

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 50, 0)->'pagination'->>'total_count')::int),
  8,
  '8/9/10/11: ordinary MEMBER (no member.view/payment.view/payment.receipt.view) lists all 8 own external payments'
);

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, 'POSTED', null, null, 50, 0)->'pagination'->>'total_count')::int),
  7,
  '16: status filter POSTED returns 7'
);

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, 'REVERSED', null, null, 50, 0)->'pagination'->>'total_count')::int),
  1,
  '17/18: status filter REVERSED returns exactly the reversed payment'
);

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, '2026-04-03'::date, '2026-04-05'::date, 50, 0)->'pagination'->>'total_count')::int),
  3,
  '19/20: from/to date filter on the economic effective date returns exactly 3'
);

select is(
  (select jsonb_agg(it->>'payment_id' order by it->>'payment_id')
   from jsonb_array_elements(public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, '2026-04-03'::date, '2026-04-05'::date, 50, 0)->'items') it),
  '["11400000-0000-0000-0000-000000000703", "11400000-0000-0000-0000-000000000704", "11400000-0000-0000-0000-000000000705"]'::jsonb,
  'the from/to date filter selects exactly the three payments in range'
);

select is(
  (select array_agg(it->>'payment_id')
   from jsonb_array_elements(public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 50, 0)->'items') it),
  (select ids from b6_expected_order),
  '21: deterministic ordering is effective_at desc, created_at desc, id desc'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 3, 0)->'items')),
  3,
  '22: pagination limit 3 returns 3 items'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 3, 6)->'items')),
  2,
  '22b: offset 6 with limit 3 returns the final 2'
);

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, -5, -10)->'pagination'->>'limit')::int),
  1,
  '23: a negative limit is clamped to 1'
);

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 500000, 0)->'pagination'->>'limit')::int),
  200,
  '23b: an oversized limit is clamped to the 200 maximum'
);

-- =====================================================================
-- E. List contract and field exposure
-- =====================================================================

select is(
  (select array_agg(k order by k) from jsonb_object_keys(
     (select it from jsonb_array_elements(public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 50, 0)->'items') it limit 1)
   ) k),
  (select array_agg(k order by k) from unnest(array['payment_id', 'effective_at', 'amount', 'payment_method', 'external_reference', 'receipt_number', 'status', 'allocation_count']) k),
  '53a: list item exposes exactly the member-safe field set (no membership_id/financial_account_id/notes)'
);

-- =====================================================================
-- F. Detail: canonical amount/date, allocation targets, cross-domain,
-- multi-allocation, wallet credit, reversal
-- =====================================================================

select is(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid)->'payment'->>'amount')::numeric,
  15000::numeric,
  '24: canonical amount is payments.amount, not a derived sum'
);

select is(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid)->'payment'->>'effective_at')::date,
  '2026-04-01'::date,
  '25: canonical date is effective_at, not created_at'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'allocations')),
  2,
  '26: a cross-domain payment is still exactly one payment with its 2 allocations'
);

select is(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'payment'->>'amount')::numeric,
  60000::numeric,
  '26b: the cross-domain payment amount is not duplicated across its two allocations'
);

select is(
  (select jsonb_agg(a->>'target_type' order by a->>'target_type')
   from jsonb_array_elements(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000702'::uuid)->'allocations') a),
  '["CONTRIBUTION_COMPONENT", "CONTRIBUTION_COMPONENT"]'::jsonb,
  '27/28/29: the multi-allocation payment appears once, with BASE and PENALTY both resolved as CONTRIBUTION_COMPONENT allocations'
);

select is(
  (select jsonb_agg(a->>'component_type' order by (a->>'amount')::numeric desc)
   from jsonb_array_elements(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000702'::uuid)->'allocations') a),
  '["BASE", "PENALTY"]'::jsonb,
  '28b/29b: component_type resolves BASE and PENALTY distinctly, never collapsed'
);

select is(
  (select a->>'target_type' from jsonb_array_elements(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'allocations') a where a->>'target_type' = 'LOAN_PRINCIPAL'),
  'LOAN_PRINCIPAL',
  '30: loan PRINCIPAL allocation target preserved'
);

select is(
  (select jsonb_agg(a->>'target_type' order by a->>'target_type')
   from jsonb_array_elements(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000704'::uuid)->'allocations') a),
  '["LOAN_INTEREST", "LOAN_PENALTY", "LOAN_PRINCIPAL_PREPAYMENT"]'::jsonb,
  '31/32/33: loan INTEREST, PENALTY and PRINCIPAL_PREPAYMENT targets each preserved distinctly'
);

select is(
  (select jsonb_agg(a->>'target_type' order by a->>'target_type')
   from jsonb_array_elements(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000705'::uuid)->'allocations') a),
  '["LOAN_RECOVERY_INTEREST", "LOAN_RECOVERY_PENALTY", "LOAN_RECOVERY_PRINCIPAL"]'::jsonb,
  '34/35/36: recovery PRINCIPAL/INTEREST/PENALTY targets each preserved distinctly'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000706'::uuid)->'allocations')),
  1,
  '37: a payment that also creates wallet credit remains one payment with its own allocation list'
);

select is(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000706'::uuid)->'wallet_credit'->>'amount')::numeric,
  50000::numeric,
  '38: the wallet credit that payment created is returned in detail (200,000 = 150,000 allocated + 50,000 wallet credit)'
);

select ok(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000706'::uuid)->'wallet_credit'->>'is_reversed')::boolean is false,
  'an unreversed wallet credit reports is_reversed = false'
);

select ok(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000707'::uuid)->'wallet_credit'->>'is_reversed')::boolean is true,
  'a reversed wallet credit reports is_reversed = true'
);

-- =====================================================================
-- G. Wallet application exclusion
-- =====================================================================

select is(
  (select (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 50, 0)->'pagination'->>'total_count')::int),
  8,
  '39: the wallet application (payment_id IS NULL) does not inflate the My Payments count beyond the 8 real payments'
);

reset role;
select ok(
  not exists (select 1 from public.payments where id = '11400000-0000-0000-0000-000000000904'::uuid),
  '39b: the wallet application has no corresponding payments row at all'
);
set local role authenticated;
set local request.jwt.claim.sub to '11400000-0000-0000-0000-000000000012';

select throws_ok(
  $$select public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000904'::uuid)$$,
  '22023', 'Payment not found',
  '40: the wallet application cannot be fabricated into a payment detail'
);

-- =====================================================================
-- H. Reversal
-- =====================================================================

select is(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid)->'payment'->>'status'),
  'REVERSED',
  '41: a reversed payment remains visible and reports status REVERSED'
);

select is(
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid)->'payment'->>'reversal_reason'),
  'Entered in error',
  '42: the reversal reason is returned'
);

select ok(
  not (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid) ? 'reversed_by')
  and not ((public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid)->'payment') ? 'reversed_by'),
  '43: reversed_by is excluded from member output'
);

-- =====================================================================
-- I. Receipt
-- =====================================================================

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid)->>'receipt_number'),
  'B6-RCPT-001',
  '44: receipt available for a POSTED payment, using the existing stored receipt_number'
);

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid)->>'receipt_number'),
  'B6-RCPT-008',
  '45: receipt still available for a REVERSED payment'
);

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid)->>'status'),
  'REVERSED',
  '46: the reversed receipt reports status REVERSED in stable data'
);

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->>'amount')::numeric,
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'payment'->>'amount')::numeric,
  '47: detail and receipt agree on amount for the same payment'
);

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->>'effective_at')::date,
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'payment'->>'effective_at')::date,
  '48: detail and receipt agree on effective date'
);

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'allocations'),
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'allocations'),
  '49: detail and receipt agree exactly on the allocation breakdown'
);

select is(
  (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000706'::uuid)->'wallet_credit'),
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000706'::uuid)->'wallet_credit'),
  'detail and receipt agree on wallet credit'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid)) k),
  (select array_agg(k order by k) from unnest(array['receipt_number', 'effective_at', 'amount', 'payment_method', 'external_reference', 'status', 'reversal_reason', 'member_display_name', 'member_number', 'group_name', 'allocations', 'wallet_credit']) k),
  '53b: receipt exposes exactly the member-safe field set'
);

-- =====================================================================
-- J. Field-exposure audit on the JSON output (not source text)
-- =====================================================================

select ok(
  not (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid)::text ~*
       'membership_id|created_by|reversed_by|financial_account|idempotency|internal note|cashbook|wallet_entry_id|charge_component_id|loan_account_id|loan_installment_id|loan_penalty_charge_id'),
  '26 & U: detail JSON (as text) contains none of the excluded internal fields or notes'
);

select ok(
  not (public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000701'::uuid)::text ~*
       'membership_id|created_by|reversed_by|financial_account|idempotency|internal note|cashbook|wallet_entry_id|charge_component_id|loan_account_id|loan_installment_id|loan_penalty_charge_id'),
  'receipt JSON (as text) contains none of the excluded internal fields or notes'
);

select ok(
  not (public.rpc_get_my_payments('11400000-0000-0000-0000-000000000001'::uuid, null, null, null, 50, 0)::text ~*
       'membership_id|financial_account|idempotency|internal note'),
  'list JSON (as text) contains none of the excluded internal fields or notes'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(
     (select a from jsonb_array_elements(public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'allocations') a limit 1)
   ) k),
  (select array_agg(k order by k) from unnest(array['allocation_id', 'target_type', 'amount', 'contribution_type_name', 'period_label', 'period_purpose', 'component_type', 'loan_number', 'loan_product_name', 'installment_number']) k),
  'K/J: an allocation row exposes exactly the member-safe field set (no charge_id/charge_component_id/loan ids)'
);

-- =====================================================================
-- K. Ownership isolation
-- =====================================================================

select throws_ok(
  $$select public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000709'::uuid)$$,
  '22023', 'Payment not found',
  '12/14: member A cannot read member B''s payment; missing and foreign report the same not-found'
);

select throws_ok(
  $$select public.rpc_get_my_receipt('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000709'::uuid)$$,
  '22023', 'Payment not found',
  'member A cannot read member B''s receipt'
);

select throws_ok(
  $$select public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000710'::uuid)$$,
  '22023', 'Payment not found',
  '13/14: a payment from another group is hidden the same way'
);

select throws_ok(
  $$select public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, gen_random_uuid())$$,
  '22023', 'Payment not found',
  '14b: a nonexistent payment id reports the same not-found'
);

reset role;

-- =====================================================================
-- L. B3 parity (same payment, same interpretation)
-- =====================================================================

set local role authenticated;
set local request.jwt.claim.sub to '11400000-0000-0000-0000-000000000012';

select is(
  (select ((select activity_items from (
     select jsonb_array_elements(public.rpc_get_my_member_statement('11400000-0000-0000-0000-000000000001'::uuid, null, null, 200, 0)->'activity'->'items') activity_items) x
   where (activity_items->>'event_id') = '11400000-0000-0000-0000-000000000703')->>'amount')::numeric),
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'payment'->>'amount')::numeric,
  '50: B3 and B6 agree on the amount of the same payment'
);

select is(
  (select ((select activity_items from (
     select jsonb_array_elements(public.rpc_get_my_member_statement('11400000-0000-0000-0000-000000000001'::uuid, null, null, 200, 0)->'activity'->'items') activity_items) x
   where (activity_items->>'event_id') = '11400000-0000-0000-0000-000000000703')->>'effective_date')::date),
  (public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000703'::uuid)->'payment'->>'effective_at')::date,
  '51: B3 and B6 agree on the effective date of the same payment'
);

select is(
  (select ((select activity_items from (
     select jsonb_array_elements(public.rpc_get_my_member_statement('11400000-0000-0000-0000-000000000001'::uuid, null, null, 200, 0)->'activity'->'items') activity_items) x
   where (activity_items->>'event_id') = '11400000-0000-0000-0000-000000000708')->>'is_reversed')::boolean),
  ((public.rpc_get_my_payment_detail('11400000-0000-0000-0000-000000000001'::uuid, '11400000-0000-0000-0000-000000000708'::uuid)->'payment'->>'status') = 'REVERSED'),
  '52: B3 and B6 agree on the reversed state of the same payment'
);

reset role;

select * from finish();
rollback;
