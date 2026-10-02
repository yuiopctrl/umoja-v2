-- Prompt 09G-B3-B: Member Financial Statement Backend Foundation.
--
-- Proves rpc_get_my_member_statement(p_group_id, p_from_date, p_to_date,
-- p_limit, p_offset) is a strict self-owned, group-scoped cross-domain
-- financial read: ownership resolved exclusively via
-- current_membership_id() (no p_user_id/p_membership_id/p_phone),
-- summary figures reconcile EXACTLY to the canonical derivation helpers
-- this codebase already uses everywhere else
-- (contribution_charge_component_states/loan_statement_schedule_position/
-- member_wallet_balance), a payment and its allocations never double-
-- count against the same obligation, and no synthetic cross-domain net
-- balance exists anywhere in the response.
--
-- NOTE ON PERMISSION OVERRIDES: fresh source inspection
-- (has_group_permission(), 20260819080634_create_authorization_
-- functions.sql) confirms this project has NO per-user permission
-- override/DENY mechanism — has_group_permission() is purely
-- role -> role_permissions. "Fails closed without the permission" is
-- therefore proven here via a membership with ZERO roles assigned
-- (so no role_permissions row can ever match), not via a fabricated
-- override table.
begin;

select plan(96);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('10700000-0000-0000-0000-000000000011', 'p09gb3b-admin@example.com'),
  ('10700000-0000-0000-0000-000000000012', 'p09gb3b-member@example.com'),
  ('10700000-0000-0000-0000-000000000014', 'p09gb3b-noroles@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('10700000-0000-0000-0000-000000000001', 'Statement Group A', '10700000-0000-0000-0000-000000000011', 'STB3BA', 'ACTIVE'),
  ('10700000-0000-0000-0000-000000000002', 'Statement Group B', '10700000-0000-0000-0000-000000000011', 'STB3BB', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10700000-0000-0000-0000-000000000101', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'STB3BA-0001', null),
  ('10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000012', 'Member Statement Caller', 'ACTIVE', '2025-01-02', 'STB3BA-0002', null),
  ('10700000-0000-0000-0000-000000000103', '10700000-0000-0000-0000-000000000002', '10700000-0000-0000-0000-000000000012', 'Member In Group B', 'ACTIVE', '2025-02-01', 'STB3BB-0001', null),
  ('10700000-0000-0000-0000-000000000104', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000014', 'No Roles Member', 'ACTIVE', '2025-01-03', 'STB3BA-0003', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10700000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10700000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10700000-0000-0000-0000-000000000103', id from public.roles where code = 'TREASURER';
-- Membership 104 (No Roles Member) deliberately has ZERO roles assigned.

insert into public.financial_accounts (id, group_id, name, account_type) values
  ('10700000-0000-0000-0000-000000000201', '10700000-0000-0000-0000-000000000001', 'Cash Box', 'CASH');

-- Contributions: one normal period + one opening-balance period.
insert into public.contribution_types (id, group_id, name, category, accounting_treatment) values
  ('10700000-0000-0000-0000-000000000301', '10700000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME');
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount) values
  ('10700000-0000-0000-0000-000000000302', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000301', 'Dues Setup', 'ON_DEMAND', 'FIXED', 50000),
  ('10700000-0000-0000-0000-000000000305', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000301', 'Opening Balance Setup', 'ON_DEMAND', 'FIXED', 10000);
update public.contribution_setups set is_system = true where id = '10700000-0000-0000-0000-000000000305';

insert into public.contribution_periods (id, group_id, contribution_setup_id, label, period_start, period_end, obligation_date, eligibility_date, due_date, status, purpose) values
  ('10700000-0000-0000-0000-000000000303', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000302', 'October 2026 Dues', '2026-10-01', '2026-10-31', '2026-10-01', '2026-10-01', '2026-10-15', 'OPEN', 'NORMAL'),
  ('10700000-0000-0000-0000-000000000304', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000305', 'Opening Balances', '2026-01-01', '2026-01-01', '2026-01-01', '2026-01-01', '2026-01-01', 'OPEN', 'OPENING_BALANCE');

insert into public.member_contribution_charges (id, group_id, period_id, contribution_setup_id, membership_id, member_number_snapshot, member_name_snapshot, effective_at, due_date) values
  ('10700000-0000-0000-0000-000000000401', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000303', '10700000-0000-0000-0000-000000000302', '10700000-0000-0000-0000-000000000102', 'STB3BA-0002', 'Member Statement Caller', '2026-10-01', '2026-10-15'),
  ('10700000-0000-0000-0000-000000000402', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000304', '10700000-0000-0000-0000-000000000305', '10700000-0000-0000-0000-000000000102', 'STB3BA-0002', 'Member Statement Caller', '2026-01-01', '2026-01-01');

-- Components inserted deliberately OUT of priority order (PENALTY
-- before BASE) to prove the activity ordering uses source_priority,
-- never insertion order / created_at (test 29).
insert into public.contribution_charge_components (id, group_id, charge_id, component_type, assessed_amount, effective_at, sequence) values
  ('10700000-0000-0000-0000-000000000502', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000401', 'PENALTY', 5000, '2026-10-01', 1),
  ('10700000-0000-0000-0000-000000000501', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000401', 'BASE', 50000, '2026-10-01', 1),
  ('10700000-0000-0000-0000-000000000503', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000401', 'ADJUSTMENT', 2000.50, '2026-10-02', 1),
  ('10700000-0000-0000-0000-000000000504', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000401', 'WAIVER', -1000, '2026-10-03', 1),
  ('10700000-0000-0000-0000-000000000505', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000402', 'OPENING_BALANCE', 10000, '2026-01-01', 1);

-- A dedicated third charge/period, fully isolated from charge-1/-2's
-- existing current-state assertions, whose single component has
-- effective_at far in the PAST (2025-01-01) but created_at defaulting
-- to "now" (today, far LATER) — proves as-of inclusion is driven by
-- effective_at, never created_at.
insert into public.contribution_periods (id, group_id, contribution_setup_id, label, period_start, period_end, obligation_date, eligibility_date, due_date, status, purpose) values
  ('10700000-0000-0000-0000-000000000306', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000302', 'Historical Test Period', '2025-01-01', '2025-01-31', '2025-01-01', '2025-01-01', '2025-01-15', 'OPEN', 'NORMAL');
insert into public.member_contribution_charges (id, group_id, period_id, contribution_setup_id, membership_id, member_number_snapshot, member_name_snapshot, effective_at, due_date) values
  ('10700000-0000-0000-0000-000000000403', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000306', '10700000-0000-0000-0000-000000000302', '10700000-0000-0000-0000-000000000102', 'STB3BA-0002', 'Member Statement Caller', '2025-01-01', '2025-01-15');
insert into public.contribution_charge_components (id, group_id, charge_id, component_type, assessed_amount, effective_at, sequence) values
  ('10700000-0000-0000-0000-000000000506', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000403', 'BASE', 100, '2025-01-01', 1);

-- Loan product.
insert into public.loan_products (id, group_id, code, name, minimum_principal, maximum_principal, minimum_term, maximum_term, interest_rate, interest_rate_basis, interest_method) values
  ('10700000-0000-0000-0000-000000000601', '10700000-0000-0000-0000-000000000001', 'STD', 'Standard Loan', 10000, 500000, 1, 12, 5, 'MONTHLY', 'FLAT');

-- Loan 1: ACTIVE, with a penalty + payment allocations.
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status) values
  ('10700000-0000-0000-0000-000000000701', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000601', 'LN-STB3B-001', 50000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-02-01', 'ACTIVE');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('10700000-0000-0000-0000-000000000711', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000701', 1, '2026-02-01', 50000, 10000);
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('10700000-0000-0000-0000-000000000721', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000701', '10700000-0000-0000-0000-000000000201', 50000, '2026-01-01');
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days, basis_amount, fixed_amount, penalty_amount) values
  ('10700000-0000-0000-0000-000000000731', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000701', '10700000-0000-0000-0000-000000000711', '2026-02-16', 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 15, 60000, 5000, 5000);
insert into public.loan_obligation_adjustments (id, group_id, loan_account_id, target_type, loan_installment_id, adjustment_type, amount, reason_code, effective_date) values
  ('10700000-0000-0000-0000-000000000741', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000701', 'LOAN_INTEREST', '10700000-0000-0000-0000-000000000711', 'CORRECTION_DECREASE', -500, 'DATA_ENTRY_ERROR', '2026-02-10');

-- Loan 2: ACTIVE, untouched — multi-loan distinguishability.
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status) values
  ('10700000-0000-0000-0000-000000000702', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000601', 'LN-STB3B-002', 20000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-03-01', 'ACTIVE');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('10700000-0000-0000-0000-000000000712', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000702', 1, '2026-03-01', 20000, 4000);
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('10700000-0000-0000-0000-000000000722', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000702', '10700000-0000-0000-0000-000000000201', 20000, '2026-02-01');

-- Loan 3: WRITTEN_OFF — must contribute ZERO to current_outstanding.
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status) values
  ('10700000-0000-0000-0000-000000000703', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000601', 'LN-STB3B-003', 15000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2026-01-15', 'WRITTEN_OFF');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('10700000-0000-0000-0000-000000000713', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000703', 1, '2026-01-15', 15000, 3000);
insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('10700000-0000-0000-0000-000000000723', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000703', '10700000-0000-0000-0000-000000000201', 15000, '2025-12-01');
insert into public.loan_write_off_events (id, group_id, loan_account_id, event_type, principal_amount, interest_amount, penalty_amount, reason_code, effective_date) values
  ('10700000-0000-0000-0000-000000000743', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000703', 'WRITE_OFF', 15000, 3000, 0, 'GROUP_DECISION', '2026-02-20');

-- Loan 4: MIGRATED, ACTIVE, no disbursement row — proves no fake
-- disbursement event is ever manufactured for a migrated loan, while
-- it still contributes normally to current_outstanding (loan_origin
-- is not branched on by loan_statement_schedule_position).
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status, loan_origin) values
  ('10700000-0000-0000-0000-000000000704', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000601', 'LN-STB3B-004', 20000, 0, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-06-01', 'ACTIVE', 'MIGRATED');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('10700000-0000-0000-0000-000000000714', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000704', 1, '2025-06-01', 20000, 0);

-- Prompt 09G-B3-B-FIX-02: Loan 5 — a dedicated narrative-only shell
-- (no installments, no disbursement row) that exists solely to hold
-- one real loan_restructure_events row. Deliberately contributes
-- ZERO to every outstanding total (zero installments means
-- loan_statement_schedule_position/loan_account_outstanding_as_of
-- both sum to exactly 0 for it), so every pre-existing hardcoded
-- opening/closing/current total in this file stays byte-for-byte
-- unchanged — the new RESTRUCTURED activity branch is proven in
-- complete isolation from the existing reconciliation fixtures.
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status) values
  ('10700000-0000-0000-0000-000000000705', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000601', 'LN-STB3B-005', 30000, 5, 'MONTHLY', 'FLAT', 6, 'MONTH', 'MONTHLY', '2026-01-01', 'ACTIVE');
insert into public.loan_restructure_events (id, group_id, loan_account_id, effective_date, reason, new_interest_rate, new_term, new_first_installment_date, old_remaining_schedule_snapshot, new_remaining_schedule_snapshot) values
  ('10700000-0000-0000-0000-000000000751', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000705', '2026-02-12', 'Member requested a lower installment amount', 4, 6, '2026-03-01', '[]'::jsonb, '[]'::jsonb);

-- Prompt 09G-B3-B-FIX-02: Loan 6 — a second dedicated narrative-only
-- shell (no installments, no disbursement row) that exists solely to
-- hold one real principal-prepayment PAYMENT + its
-- LOAN_PRINCIPAL_PREPAYMENT allocation + the corresponding
-- loan_prepayment_events audit row, so the "no second monetary
-- PREPAYMENT activity row" decision can be tested in complete
-- isolation too.
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status) values
  ('10700000-0000-0000-0000-000000000706', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000601', 'LN-STB3B-006', 20000, 5, 'MONTHLY', 'FLAT', 6, 'MONTH', 'MONTHLY', '2026-01-01', 'ACTIVE');

-- Payment 1: POSTED, 100000 total. Allocates 40000 to contribution
-- BASE (partial — component gross 50000), 5000 to contribution
-- PENALTY (full), and 30000 across loan 1's PENALTY(5000)+
-- INTEREST(10000, net 9500 after the -500 adjustment above — but the
-- allocation itself is independent of that net; it still sums to
-- 15000 here)+PRINCIPAL(15000 of 50000, partial). Remainder 25000
-- becomes a wallet credit.
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('10700000-0000-0000-0000-000000000801', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000201', 100000, '2026-02-05', 'CASH', 'POSTED', 'STB3B-RCPT-0001');

insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10700000-0000-0000-0000-000000000811', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000801', '10700000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10700000-0000-0000-0000-000000000401', '10700000-0000-0000-0000-000000000501', 40000, 1),
  ('10700000-0000-0000-0000-000000000812', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000801', '10700000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10700000-0000-0000-0000-000000000401', '10700000-0000-0000-0000-000000000502', 5000, 2);
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number) values
  ('10700000-0000-0000-0000-000000000813', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000801', '10700000-0000-0000-0000-000000000102', 'LOAN_PENALTY', '10700000-0000-0000-0000-000000000701', '10700000-0000-0000-0000-000000000711', '10700000-0000-0000-0000-000000000731', 5000, 3);
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, amount, line_number) values
  ('10700000-0000-0000-0000-000000000814', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000801', '10700000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '10700000-0000-0000-0000-000000000701', '10700000-0000-0000-0000-000000000711', 10000, 4),
  ('10700000-0000-0000-0000-000000000815', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000801', '10700000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '10700000-0000-0000-0000-000000000701', '10700000-0000-0000-0000-000000000711', 15000, 5);

insert into public.member_wallet_entries (id, group_id, membership_id, entry_type, amount, effective_at, source_type, source_id) values
  ('10700000-0000-0000-0000-000000000821', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', 'PAYMENT_CREDIT', 25000, '2026-02-05', 'PAYMENT', '10700000-0000-0000-0000-000000000801');

-- Payment 2: REVERSED — allocation to the opening-balance component
-- must NOT count (proves reversal makes debt outstanding again).
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number, reversed_at, reversed_by, reversal_reason) values
  ('10700000-0000-0000-0000-000000000802', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000201', 10000, '2026-01-10', 'CASH', 'REVERSED', 'STB3B-RCPT-0002', now(), '10700000-0000-0000-0000-000000000011', 'Wrong member credited');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10700000-0000-0000-0000-000000000822', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000802', '10700000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10700000-0000-0000-0000-000000000402', '10700000-0000-0000-0000-000000000505', 10000, 1);

-- Payment 3: POSTED, 20000 total, entirely a principal prepayment on
-- Loan 6 — dated well outside every opening/closing cutoff tested
-- elsewhere in this file (2026-06-01), so it can never perturb any
-- pre-existing hardcoded as-of total. Proves the "one PAYMENT row,
-- never a second PREPAYMENT cash row" decision (09G-B3-B-FIX-02 §E).
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('10700000-0000-0000-0000-000000000803', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000201', 20000, '2026-06-01', 'CASH', 'POSTED', 'STB3B-RCPT-0003');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, amount, line_number) values
  ('10700000-0000-0000-0000-000000000824', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000803', '10700000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL_PREPAYMENT', '10700000-0000-0000-0000-000000000706', 20000, 1);
insert into public.loan_prepayment_events (id, group_id, loan_account_id, membership_id, payment_id, effective_date, amount, treatment, old_future_schedule_snapshot, new_future_schedule_snapshot) values
  ('10700000-0000-0000-0000-000000000831', '10700000-0000-0000-0000-000000000001', '10700000-0000-0000-0000-000000000706', '10700000-0000-0000-0000-000000000102', '10700000-0000-0000-0000-000000000803', '2026-06-01', 20000, 'REDUCE_TERM', '[]'::jsonb, '[]'::jsonb);

-- =====================================================================
-- Pre-call business row counts (test 39 baseline).
-- =====================================================================
select set_eq(
  $$ select 'payments', count(*) from public.payments
     union all select 'contribution_charge_components', count(*) from public.contribution_charge_components
     union all select 'loan_accounts', count(*) from public.loan_accounts
     union all select 'member_wallet_entries', count(*) from public.member_wallet_entries
     union all select 'loan_penalty_charges', count(*) from public.loan_penalty_charges
     union all select 'loan_restructure_events', count(*) from public.loan_restructure_events
     union all select 'loan_prepayment_events', count(*) from public.loan_prepayment_events $$,
  $$ values ('payments', 3::bigint), ('contribution_charge_components', 6::bigint),
            ('loan_accounts', 6::bigint), ('member_wallet_entries', 1::bigint),
            ('loan_penalty_charges', 1::bigint), ('loan_restructure_events', 1::bigint),
            ('loan_prepayment_events', 1::bigint) $$,
  '0: fixture row counts are as expected before any RPC call'
);

-- =====================================================================
-- As Member Statement Caller (u12) — the primary caller. Comparison
-- queries below call locked-down internal helpers directly (e.g.
-- contribution_charge_component_states) to compute the "expected"
-- canonical value — those have zero EXECUTE grant to authenticated by
-- design (see 20260828092000), so this block stays unrestricted
-- (reset role) rather than role=authenticated; auth.uid() still
-- resolves correctly from request.jwt.claim.sub regardless of role,
-- and rpc_get_my_member_statement itself is SECURITY DEFINER so its
-- own authorization checks are unaffected by the calling role. Actual
-- grant enforcement (authenticated/anon) is proven separately below
-- (§G1-G3).
reset role;
set local request.jwt.claim.sub to '10700000-0000-0000-0000-000000000012';

-- 1: unauthenticated caller rejected — covered below under role=anon/no jwt.

-- 2/3/4/5: RPC signature has no membership_id/user_id/phone/role_id
-- parameter at all.
select is(
  (select count(*)::integer from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'rpc_get_my_member_statement'
     and pg_get_function_arguments(p.oid) = 'p_group_id uuid, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0'),
  1,
  '2-5: rpc_get_my_member_statement has exactly p_group_id/p_from_date/p_to_date/p_limit/p_offset — no membership_id/user_id/phone/role_id parameter'
);

-- 9: contribution outstanding equals canonical state.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'contributions' ->> 'current_outstanding')::numeric,
  (
    select coalesce(sum(s.outstanding), 0)
    from public.member_contribution_charges c
    cross join lateral public.contribution_charge_component_states(c.id) s
    where c.membership_id = '10700000-0000-0000-0000-000000000102' and c.group_id = '10700000-0000-0000-0000-000000000001'
  ),
  '9: summary.contributions.current_outstanding equals the canonical contribution_charge_component_states derivation exactly'
);

-- 10: partial contribution payment reconciles (BASE component: gross
-- 50000, netted against the WAIVER's 1000 front-to-back per the
-- canonical algorithm's own priority-ordered reduction -> 49000
-- gross_after_corrections, minus 40000 allocated = 9000 outstanding).
select is(
  (
    select s.outstanding
    from public.contribution_charge_component_states('10700000-0000-0000-0000-000000000401'::uuid) s
    where s.component_id = '10700000-0000-0000-0000-000000000501'
  ),
  9000::numeric,
  '10: a partial contribution payment reconciles to exactly the canonical gross_after_corrections-minus-allocated outstanding (9000)'
);

-- 11: contribution waiver reconciles — the WAIVER component itself
-- carries no independent "outstanding" (priority 99, netted into
-- gross_after_corrections of the positive components, never payable
-- on its own); proven by it having zero rows with priority < 99 for
-- that component_type.
select is(
  (
    select count(*)::integer
    from public.contribution_charge_component_states('10700000-0000-0000-0000-000000000401'::uuid) s
    where s.component_type = 'WAIVER'
  ),
  0,
  '11: the WAIVER component never appears as its own payable/outstanding line (it only reduces other components'' gross)'
);

-- 12: contribution adjustment reconciles — the positive ADJUSTMENT
-- component (2000.50) does appear as its own payable line.
select ok(
  (
    select count(*)::integer
    from public.contribution_charge_component_states('10700000-0000-0000-0000-000000000401'::uuid) s
    where s.component_type = 'ADJUSTMENT'
  ) = 1,
  '12: the positive ADJUSTMENT component reconciles as its own payable line in the canonical state'
);

-- 13: contribution penalty reconciles — fully settled (5000 of 5000).
select is(
  (
    select s.outstanding
    from public.contribution_charge_component_states('10700000-0000-0000-0000-000000000401'::uuid) s
    where s.component_id = '10700000-0000-0000-0000-000000000502'
  ),
  0::numeric,
  '13: the contribution PENALTY component (5000 assessed, 5000 allocated) reconciles to zero outstanding'
);

-- 14: contribution opening balance reconciles — REVERSED payment's
-- allocation does not count, so still fully outstanding (10000).
select is(
  (
    select s.outstanding
    from public.contribution_charge_component_states('10700000-0000-0000-0000-000000000402'::uuid) s
    where s.component_id = '10700000-0000-0000-0000-000000000505'
  ),
  10000::numeric,
  '14: the OPENING_BALANCE component remains fully outstanding — its only allocation belongs to a REVERSED payment'
);

-- 15: loan outstanding equals canonical loan state (sum across ACTIVE
-- loans only — loan 3 is WRITTEN_OFF and contributes 0).
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'loans' ->> 'current_outstanding')::numeric,
  (
    select coalesce(sum(pos.total_outstanding), 0)
    from public.loan_accounts la
    cross join lateral public.loan_statement_schedule_position(la.id, current_date) pos
    where la.membership_id = '10700000-0000-0000-0000-000000000102'
      and la.group_id = '10700000-0000-0000-0000-000000000001'
      and la.status = 'ACTIVE'
  ),
  '15: summary.loans.current_outstanding equals the canonical loan_statement_schedule_position derivation exactly, across every ACTIVE loan'
);

-- 16: multiple loans remain distinguishable in activity (loan 1 and
-- loan 2 disbursement events both present with their own loan_number).
select is(
  (
    select count(distinct item->'metadata'->>'loan_number')::integer
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'domain' = 'LOAN' and item->>'event_type' = 'DISBURSEMENT'
  ),
  3,
  '16: three distinct loan_number values appear across DISBURSEMENT activity items (loans 1, 2, 3 — loan 4 is migrated, no disbursement row)'
);

-- 17: loan repayment allocation reconciles (installment 1: penalty
-- gross 5000 fully allocated, interest gross 9500 after the -500
-- adjustment with 10000 allocated -> 0 outstanding (never negative),
-- principal gross 50000 with 15000 allocated -> 35000 outstanding).
select is(
  (
    select s.outstanding
    from public.loan_installment_component_states('10700000-0000-0000-0000-000000000711'::uuid) s
    where s.component_type = 'PRINCIPAL'
  ),
  35000::numeric,
  '17: loan repayment allocation reconciles — installment 1 PRINCIPAL (50000 gross, 15000 allocated) is 35000 outstanding'
);

-- 18: loan penalty reconciles — installment 1 PENALTY (5000 gross,
-- 5000 allocated) is fully settled.
select is(
  (
    select s.outstanding
    from public.loan_installment_component_states('10700000-0000-0000-0000-000000000711'::uuid) s
    where s.component_type = 'PENALTY'
  ),
  0::numeric,
  '18: loan penalty reconciles — installment 1 PENALTY (5000 gross, 5000 allocated) is 0 outstanding'
);

-- 19: migrated loan semantics preserved — loan 4 (MIGRATED) has no
-- loan_disbursements row and therefore no fabricated DISBURSEMENT
-- activity item, while still contributing normally to outstanding.
select is(
  (
    select count(*)::integer
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->'metadata'->>'loan_account_id' = '10700000-0000-0000-0000-000000000704'
      and item->>'event_type' = 'DISBURSEMENT'
  ),
  0,
  '19: migrated loan semantics preserved — no fake DISBURSEMENT activity item is manufactured for loan 4 (loan_origin=MIGRATED, no disbursement row)'
);
select is(
  (
    select pos.total_outstanding
    from public.loan_statement_schedule_position('10700000-0000-0000-0000-000000000704'::uuid, current_date) pos
  ),
  20000::numeric,
  '19b: the migrated loan still contributes its real 20000 outstanding — loan_origin is not branched on by the canonical derivation'
);

-- 20/21: payment appears once as receipt/cash event; allocations do
-- not double-count (payment 1's nested allocations sum to exactly
-- 75000 = 100000 - 25000 wallet remainder; the payment amount field
-- itself, 100000, never independently reduces any outstanding figure
-- — only the allocations, already netted inside the canonical
-- helpers above, do).
select is(
  (
    select count(*)::integer
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'domain' = 'PAYMENT' and item->>'event_id' = '10700000-0000-0000-0000-000000000801'
  ),
  1,
  '20: payment 1 appears exactly once in activity, never split into separate payment+allocation top-level events'
);
select is(
  (
    select coalesce(sum((alloc->>'amount')::numeric), 0)
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    cross join lateral jsonb_array_elements(item->'metadata'->'allocations') alloc
    where item->>'event_id' = '10700000-0000-0000-0000-000000000801'
  ),
  75000::numeric,
  '21: payment 1''s nested allocations sum to exactly 75000 (contribution 45000 + loan 30000) — never double-counted against the 100000 payment amount itself'
);

-- 22: wallet remainder behavior — 25000 (= 100000 - 75000 allocated)
-- is exactly the wallet credit amount, and member_wallet_balance()
-- reconciles.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'wallet' ->> 'current_balance')::numeric,
  public.member_wallet_balance('10700000-0000-0000-0000-000000000102'::uuid),
  '22: summary.wallet.current_balance equals the canonical member_wallet_balance() derivation exactly'
);
select is(
  public.member_wallet_balance('10700000-0000-0000-0000-000000000102'::uuid),
  25000::numeric,
  '22b: the wallet remainder (100000 payment - 75000 allocated) reconciles to exactly 25000'
);

-- 17 (no global balance, §D): no synthetic net-balance field exists
-- anywhere in the response.
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' ? 'total_net_member_balance',
  false,
  '17b: no total_net_member_balance (or any synthetic cross-domain net) field exists in the response'
);
select is(
  jsonb_path_exists(public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid), '$.** ? (@.type() == "string" && @ like_regex "total_net" flag "i")'),
  false,
  '17c: no key anywhere in the response matches a "total_net*" synthetic-balance naming pattern'
);

-- 25: reversed payment reconciles — still appears in activity,
-- correctly marked reversed, and its allocation never counted.
select is(
  (
    select item->>'is_reversed'
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'event_id' = '10700000-0000-0000-0000-000000000802'
  ),
  'true',
  '25: the reversed payment (2) still appears in activity, correctly marked is_reversed=true — history is never hidden'
);

-- 28: effective-date filtering is correct (payment 2's effective_at
-- is 2026-01-10 — excluded when p_from_date = 2026-02-01).
select is(
  (
    select count(*)::integer
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-01'::date, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'event_id' = '10700000-0000-0000-0000-000000000802'
  ),
  0,
  '28: p_from_date correctly excludes payment 2 (effective_at 2026-01-10, before the 2026-02-01 cutoff)'
);

-- 29: created_at does not incorrectly drive business chronology — the
-- PENALTY component (inserted BEFORE BASE above) still sorts AFTER it
-- in activity, because both share effective_at=2026-10-01 and
-- source_priority orders BASE(2) before PENALTY(3).
select ok(
  (
    with ordered as (
      select row_number() over () as rn, item->>'event_id' as event_id
      from jsonb_array_elements(
        public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
      ) item
    )
    select (select rn from ordered where event_id = '10700000-0000-0000-0000-000000000501')
         < (select rn from ordered where event_id = '10700000-0000-0000-0000-000000000502')
  ),
  '29: BASE sorts before PENALTY despite being inserted after it — source_priority (not created_at/insertion order) drives same-date ordering'
);

-- 30/31: deterministic same-date ordering + pagination page 1/page 2
-- stable, no overlap, no missing event.
select is(
  (
    select jsonb_agg(item->>'event_id')
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 5, 0) -> 'activity' -> 'items'
    ) item
  ),
  (
    select jsonb_agg(item->>'event_id')
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 5, 0) -> 'activity' -> 'items'
    ) item
  ),
  '30: identical requests return identical, stable ordering (page 1)'
);
select is(
  (
    select count(*)::integer
    from (
      select item->>'event_id' as id from jsonb_array_elements(
        public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 9, 0) -> 'activity' -> 'items'
      ) item
      intersect
      select item->>'event_id' from jsonb_array_elements(
        public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 9, 9) -> 'activity' -> 'items'
      ) item
    ) overlap
  ),
  0,
  '31a: page 1 (limit 9 offset 0) and page 2 (limit 9 offset 9) share zero events — no duplication'
);
select is(
  (
    select count(distinct item->>'event_id')::integer
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 9, 0) -> 'activity' -> 'items'
      ||
      (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 9, 9) -> 'activity' -> 'items')
    ) item
  ),
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'activity' ->> 'total_count')::integer,
  '31b: page 1 + page 2 (limit 9 each) together cover every event with no gap (union count equals total_count, now 17 after FIX-02''s additions)'
);

-- 32: pagination does not reset balances — summary figures are
-- identical regardless of what limit/offset is requested.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 2, 50) -> 'summary'),
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'summary'),
  '32: summary is identical at offset=50 (past the last page) as at offset=0 — balances are never computed only over the returned page'
);

-- 38: numeric precision preserved (the 2000.50 ADJUSTMENT component).
select is(
  (
    select (item->>'amount')::numeric
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'event_id' = '10700000-0000-0000-0000-000000000503'
  ),
  2000.50::numeric,
  '38: numeric precision is preserved exactly (2000.50), never rounded/truncated'
);

-- =====================================================================
-- 09G-B3-B-FIX-02: Activity Narrative Completeness.
--
-- PENALTY ASSESSMENT: loan_penalty_charges 731 (Loan 1,
-- assessment_date 2026-02-16, penalty_amount 5000) is a real,
-- immutable accrual event, independent of the later payment that
-- settles it.
-- =====================================================================

-- 41: the persisted penalty assessment appears exactly once.
select is(
  (
    select count(*)::integer
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'event_id' = '10700000-0000-0000-0000-000000000731' and item->>'event_type' = 'PENALTY_ASSESSED'
  ),
  1,
  '41: the persisted loan_penalty_charges row (731) appears exactly once as a PENALTY_ASSESSED activity item'
);

-- 42: amount equals the persisted penalty_amount, never recalculated.
select is(
  (
    select (item->>'amount')::numeric
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  5000::numeric,
  '42: PENALTY_ASSESSED amount equals loan_penalty_charges.penalty_amount exactly (5000)'
);

-- 43: effective_date equals assessment_date, never created_at.
select is(
  (
    select (item->>'effective_date')::date
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  '2026-02-16'::date,
  '43: PENALTY_ASSESSED effective_date equals loan_penalty_charges.assessment_date exactly (2026-02-16)'
);

-- 44-48: date-boundary semantics around the 2026-02-16 assessment_date.
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-17'::date, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  0,
  '44: PENALTY_ASSESSED is excluded when p_from_date (2026-02-17) is strictly after its assessment_date'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-16'::date, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  1,
  '45: PENALTY_ASSESSED is included when p_from_date equals its assessment_date exactly (inclusive boundary)'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-01'::date, '2026-02-28'::date, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  1,
  '46: PENALTY_ASSESSED is included when strictly inside a p_from_date/p_to_date range'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-16'::date, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  1,
  '47: PENALTY_ASSESSED is included when p_to_date equals its assessment_date exactly (inclusive boundary)'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-15'::date, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000731'
  ),
  0,
  '48: PENALTY_ASSESSED is excluded when p_to_date (2026-02-15) is strictly before its assessment_date'
);

-- 49: the assessment and its later settling payment remain two
-- distinct, non-duplicated events — the payment's own allocation
-- (LOAN_PENALTY, 5000) is nested under payment 801, never a second
-- top-level PENALTY_ASSESSED/PAYMENT row for the same cash.
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'domain' = 'PAYMENT'
  ),
  3,
  '49: exactly 3 PAYMENT items total exist (payments 801, 802, 803) — the new PENALTY_ASSESSED/RESTRUCTURED activity branches create zero additional PAYMENT rows'
);

-- =====================================================================
-- PREPAYMENT: cash is already fully represented by the existing
-- PAYMENT contract — no independent monetary PREPAYMENT row is added.
-- =====================================================================

-- 50: the prepayment's cash appears exactly once, as a PAYMENT.
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000803' and item->>'domain' = 'PAYMENT'
  ),
  1,
  '50: the prepayment payment (803) appears exactly once as a PAYMENT activity item'
);

-- 51: its LOAN_PRINCIPAL_PREPAYMENT allocation is nested detail only.
select is(
  (
    select alloc->>'target_type'
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    cross join lateral jsonb_array_elements(item->'metadata'->'allocations') alloc
    where item->>'event_id' = '10700000-0000-0000-0000-000000000803'
  ),
  'LOAN_PRINCIPAL_PREPAYMENT',
  '51: the prepayment''s LOAN_PRINCIPAL_PREPAYMENT allocation is nested under the PAYMENT item''s metadata.allocations, never a separate top-level activity'
);

-- 52: no independent monetary PREPAYMENT/PRINCIPAL_PREPAYMENT activity
-- type exists anywhere in the member statement.
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_type' in ('PREPAYMENT', 'PRINCIPAL_PREPAYMENT')
  ),
  0,
  '52: no independent PREPAYMENT/PRINCIPAL_PREPAYMENT activity row exists anywhere — loan_prepayment_events contributes zero additional activity rows, confirming the cash is represented exactly once'
);

-- 53: the prepayment's own nested allocation sums to exactly its own
-- payment amount — never doubled against a second PREPAYMENT row.
select is(
  (
    select coalesce(sum((alloc->>'amount')::numeric), 0)
    from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item
    cross join lateral jsonb_array_elements(item->'metadata'->'allocations') alloc
    where item->>'event_id' = '10700000-0000-0000-0000-000000000803'
  ),
  20000::numeric,
  '53: the prepayment payment (803)''s nested allocation sums to exactly its own amount (20000)'
);

-- =====================================================================
-- RESTRUCTURE: loan_restructure_events 751 (Loan 5, effective_date
-- 2026-02-12) is a real, immutable, non-cash contractual event.
-- =====================================================================

-- 54: the persisted restructure appears exactly once.
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751' and item->>'event_type' = 'RESTRUCTURED'
  ),
  1,
  '54: the persisted loan_restructure_events row (751) appears exactly once as a RESTRUCTURED activity item'
);

-- 55: effective_date equals the persisted effective_date exactly.
select is(
  (
    select (item->>'effective_date')::date from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  '2026-02-12'::date,
  '55: RESTRUCTURED effective_date equals loan_restructure_events.effective_date exactly (2026-02-12)'
);

-- 56: amount is exactly 0 — the true, non-fabricated zero cash
-- movement (restructure replaces the future schedule only).
select is(
  (
    select (item->>'amount')::numeric from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  0::numeric,
  '56: RESTRUCTURED amount is exactly 0 — restructure moves no cash and changes no balance; this is the true figure, never a fabricated placeholder'
);

-- 57-60: metadata carries only the actually-persisted facts.
select is(
  (
    select item->'metadata'->>'reason' from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  'Member requested a lower installment amount',
  '57: RESTRUCTURED metadata.reason equals the persisted loan_restructure_events.reason exactly'
);
select is(
  (
    select (item->'metadata'->>'new_interest_rate')::numeric from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  4::numeric,
  '58: RESTRUCTURED metadata.new_interest_rate equals the persisted new_interest_rate exactly (4)'
);
select is(
  (
    select (item->'metadata'->>'new_term')::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  6,
  '59: RESTRUCTURED metadata.new_term equals the persisted new_term exactly (6)'
);
select is(
  (
    select (item->'metadata'->>'new_first_installment_date')::date from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  '2026-03-01'::date,
  '60: RESTRUCTURED metadata.new_first_installment_date equals the persisted value exactly (2026-03-01)'
);

-- 61-65: date-boundary semantics around the 2026-02-12 effective_date.
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-13'::date, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  0,
  '61: RESTRUCTURED is excluded when p_from_date (2026-02-13) is strictly after its effective_date'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-12'::date, null, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  1,
  '62: RESTRUCTURED is included when p_from_date equals its effective_date exactly (inclusive boundary)'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-02-01'::date, '2026-02-28'::date, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  1,
  '63: RESTRUCTURED is included when strictly inside a p_from_date/p_to_date range'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-12'::date, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  1,
  '64: RESTRUCTURED is included when p_to_date equals its effective_date exactly (inclusive boundary)'
);
select is(
  (
    select count(*)::integer from jsonb_array_elements(
      public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-11'::date, 100, 0) -> 'activity' -> 'items'
    ) item where item->>'event_id' = '10700000-0000-0000-0000-000000000751'
  ),
  0,
  '65: RESTRUCTURED is excluded when p_to_date (2026-02-11) is strictly before its effective_date'
);

-- 66: both new activity types survive pagination at a page boundary —
-- present exactly once across the combined 9+9 paginated pages, never
-- duplicated or dropped.
select is(
  (
    select count(*)::integer
    from (
      select item->>'event_id' as id from jsonb_array_elements(
        public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 9, 0) -> 'activity' -> 'items'
      ) item
      union all
      select item->>'event_id' from jsonb_array_elements(
        public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 9, 9) -> 'activity' -> 'items'
      ) item
    ) pages
    where id in ('10700000-0000-0000-0000-000000000731', '10700000-0000-0000-0000-000000000751')
  ),
  2,
  '66: the penalty assessment (731) and the restructure (751) are each present exactly once across the combined 9+9 paginated pages, never duplicated/dropped at a page boundary'
);

-- =====================================================================
-- Regression: narrative additions never alter canonical balance
-- semantics (opening/closing/current positions remain invariant).
-- =====================================================================

-- 67: opening position is unchanged — Loan 5/Loan 6 (both zero
-- installments) and the new events contribute exactly 0.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-01-16'::date, null) -> 'period' -> 'opening' -> 'loans' ->> 'outstanding')::numeric,
  98000::numeric,
  '67: period.opening.loans.outstanding is unchanged at 98000 after adding the narrative-only Loan 5 (restructure) and Loan 6 (prepayment) shells — both contribute exactly 0'
);

-- 68: closing position is unchanged for the same reason.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-10'::date) -> 'period' -> 'closing' -> 'loans' ->> 'outstanding')::numeric,
  97000::numeric,
  '68: period.closing.loans.outstanding is unchanged at 97000 — the restructure (2026-02-12) and prepayment (2026-06-01) both postdate this cutoff, and the penalty-assessment branch never alters any outstanding derivation'
);

-- 69: current summary still reconciles exactly to the canonical
-- derivation — activity is narrative only, never a parallel balance
-- source.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'loans' ->> 'current_outstanding')::numeric,
  (
    select coalesce(sum(pos.total_outstanding), 0)
    from public.loan_accounts la
    cross join lateral public.loan_statement_schedule_position(la.id, current_date) pos
    where la.membership_id = '10700000-0000-0000-0000-000000000102'
      and la.group_id = '10700000-0000-0000-0000-000000000001'
      and la.status = 'ACTIVE'
  ),
  '69: summary.loans.current_outstanding still reconciles exactly to the canonical loan_statement_schedule_position derivation after adding the new narrative-only activity branches'
);

-- 6/35/36: group isolation — calling with Group B's id for this same
-- user returns ONLY Group B data (membership 103, zero contributions/
-- loans/wallet there) — never Group A's.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000002'::uuid) -> 'member' ->> 'membership_id'),
  '10700000-0000-0000-0000-000000000103',
  '6: calling with Group B resolves the caller''s Group B membership, never Group A''s'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000002'::uuid) -> 'summary' -> 'contributions' ->> 'current_outstanding')::numeric,
  0::numeric,
  '35a: Group B statement shows zero contribution outstanding — Group A''s charges never leak across groups'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000002'::uuid) -> 'activity' ->> 'total_count')::integer,
  0,
  '35b: Group B statement has zero activity items — none of Group A''s payments/contributions/loans/wallet entries leak across groups'
);

-- 7: multi-group correctness — the SAME caller gets correct, distinct
-- results for Group A vs Group B on independent calls.
select isnt(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'member' ->> 'membership_id'),
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000002'::uuid) -> 'member' ->> 'membership_id'),
  '7: the same authenticated caller resolves a DIFFERENT membership_id per group — no cross-group confusion'
);

-- 33/34: no-loan/no-wallet/no-contribution member behaves safely
-- (empty statement) — No Roles Member has none of these, though they
-- will be denied by the permission check below; verify safety via
-- Admin instead, who legitimately has zero contributions/loans/wallet
-- entries of their own.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10700000-0000-0000-0000-000000000011';
select lives_ok(
  $$ select public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) $$,
  '33/34/36: a member with zero contributions/loans/wallet entries (Admin) gets a safe, non-erroring empty statement'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'loans' ->> 'current_outstanding')::numeric,
  0::numeric,
  '33b: the empty statement''s loan outstanding is exactly 0, not null/error'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'activity' -> 'items'),
  '[]'::jsonb,
  '34b: the empty statement''s activity items is an empty array, not null'
);

-- =====================================================================
-- Permission model (§Y) — role grants, and fails-closed with no roles.
-- =====================================================================

-- As No Roles Member (u14) — zero roles assigned, so
-- has_group_permission can never match -> fails closed.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10700000-0000-0000-0000-000000000014';
select throws_ok(
  $$ select public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  'Not authorized to view a financial statement',
  '8: a membership with zero roles assigned (so financial_report.self_view can never match) fails closed'
);

-- As Admin (ADMIN role) — already proven callable above (lives_ok) —
-- confirms the role-based ALLOW works for ADMIN specifically.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10700000-0000-0000-0000-000000000011';
select lives_ok(
  $$ select public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) $$,
  '1b: ADMIN (holding financial_report.self_view via role grant) can call the RPC successfully'
);

-- As plain MEMBER (u12) — role-based ALLOW works for MEMBER too
-- (already exercised extensively above); officer-role-name alone
-- never substitutes for ownership — MEMBER still only ever sees their
-- OWN membership/data despite having no officer permissions at all,
-- already proven by the full reconciliation suite above.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10700000-0000-0000-0000-000000000012';
select ok(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'member' ->> 'membership_id') = '10700000-0000-0000-0000-000000000102',
  '2b: MEMBER role (no officer permissions) successfully retrieves their own statement via financial_report.self_view alone'
);

-- Dual-role (TREASURER in Group B): still retrieves their own
-- statement through the identical self-service contract — no
-- role-name branch, no officer-only path taken.
select ok(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000002'::uuid) -> 'member' ->> 'membership_id') = '10700000-0000-0000-0000-000000000103',
  '5b: a dual-role user (TREASURER in Group B) retrieves their own statement through the same self-service contract as a plain MEMBER'
);

-- =====================================================================
-- 09G-B3-B-FIX-01: period.opening / period.closing (as-of positions).
--
-- Cutoffs chosen against the fixture timeline:
--   opening (p_from_date=2026-01-16, cutoff=2026-01-15): charge-1's
--   Oct-2026 components don't exist yet; charge-2 (opening balance,
--   2026-01-01) and charge-3 (2025-01-01) do; loan-1 disbursed
--   2026-01-01 exists with no allocations/adjustments/penalty yet
--   (all dated Feb 2026); loan-2 (disbursed Feb 1) doesn't exist yet;
--   loan-3 exists, not yet written off (write-off is 2026-02-20);
--   loan-4 (MIGRATED) always exists; wallet entry (2026-02-05) doesn't
--   exist yet.
--   closing (p_to_date=2026-02-10): payment 1 and its allocations
--   (2026-02-05) and the loan interest adjustment (2026-02-10,
--   inclusive) now count; the loan penalty (assessed 2026-02-16) and
--   loan-3's write-off (2026-02-20) still don't.
-- =====================================================================

-- AO1/AO4: opening contribution position.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-01-16'::date, null) -> 'period' -> 'opening' -> 'contributions' ->> 'outstanding')::numeric,
  10100::numeric,
  'AO1: period.opening.contributions.outstanding is correct (charge-2''s 10000 + charge-3''s 100; charge-1''s Oct components don''t exist yet)'
);

-- AO6: opening loan position — loan-1 (60000, nothing allocated yet)
-- + loan-3 (18000, not yet written off) + loan-4 MIGRATED (20000);
-- loan-2 doesn't exist yet.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-01-16'::date, null) -> 'period' -> 'opening' -> 'loans' ->> 'outstanding')::numeric,
  98000::numeric,
  'AO6: period.opening.loans.outstanding correctly includes the not-yet-written-off loan-3 and the always-present MIGRATED loan-4, excludes the not-yet-disbursed loan-2'
);

-- AO8: opening wallet position — the wallet credit (2026-02-05)
-- doesn't exist yet at this cutoff.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-01-16'::date, null) -> 'period' -> 'opening' -> 'wallet' ->> 'balance')::numeric,
  0::numeric,
  'AO8: period.opening.wallet.balance is 0 — the wallet credit postdates the opening cutoff'
);

-- AO5: closing contribution position (same as opening here — nothing
-- contribution-related happens between the two cutoffs in this
-- fixture; charge-1''s Oct components still don''t exist by Feb 10).
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-10'::date) -> 'period' -> 'closing' -> 'contributions' ->> 'outstanding')::numeric,
  10100::numeric,
  'AO5: period.closing.contributions.outstanding is correct as of 2026-02-10'
);

-- AO7/AO10/AO11/AO14: closing loan position — proves effective_date
-- (not created_at) drives inclusion of the interest adjustment
-- (effective_date exactly 2026-02-10, inclusive) and the payment
-- allocations (2026-02-05); the not-yet-assessed penalty (2026-02-16)
-- and loan-3's not-yet-posted write-off (2026-02-20) are correctly
-- excluded, so loan-3 still counts at full 18000. Three loans (1, 3,
-- 4) remain individually summed correctly; loan-2 (disbursed Feb 1)
-- now exists too.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-10'::date) -> 'period' -> 'closing' -> 'loans' ->> 'outstanding')::numeric,
  97000::numeric,
  'AO7/AO10/AO14: period.closing.loans.outstanding (35000 loan-1 + 24000 loan-2 + 18000 loan-3 + 20000 loan-4) is correct, proving effective_date (not created_at/assessment date past the cutoff) drives inclusion'
);

-- AO9/AO16: closing wallet position reconciles exactly to the
-- payment-remainder wallet credit (now within range).
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2026-02-10'::date) -> 'period' -> 'closing' -> 'wallet' ->> 'balance')::numeric,
  25000::numeric,
  'AO9/AO16: period.closing.wallet.balance reconciles exactly to the payment remainder, now within the as-of range'
);

-- AO2/AO3: closing as of a safely-future fixed date equals summary's
-- CURRENT position exactly, for all three domains — the strongest
-- possible proof the as-of helpers never diverge from the
-- current-state canonical helpers (never comparing against a
-- host-clock-dependent current_date to avoid any flakiness).
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2027-01-01'::date) -> 'period' -> 'closing' -> 'contributions' -> 'outstanding',
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'contributions' -> 'current_outstanding',
  'AO2a: period.closing (far-future cutoff) contributions.outstanding equals summary.contributions.current_outstanding exactly'
);
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2027-01-01'::date) -> 'period' -> 'closing' -> 'loans' -> 'outstanding',
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'loans' -> 'current_outstanding',
  'AO2b: period.closing (far-future cutoff) loans.outstanding equals summary.loans.current_outstanding exactly'
);
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, '2027-01-01'::date) -> 'period' -> 'closing' -> 'wallet' -> 'balance',
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'summary' -> 'wallet' -> 'current_balance',
  'AO3: period.closing (far-future cutoff) wallet.balance equals summary.wallet.current_balance exactly'
);

-- AO10b/AO11b: dedicated effective_at-vs-created_at proof — charge-3's
-- component (effective_at=2025-01-01, created_at defaults to "today",
-- far later) is the ONLY contribution component in existence at a
-- cutoff of 2025-06-01 (charge-1/charge-2 are both dated 2026). If
-- created_at (not effective_at) drove inclusion, it would be excluded
-- here (its created_at is "today", long after any 2025 cutoff).
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2025-06-02'::date, null) -> 'period' -> 'opening' -> 'contributions' ->> 'outstanding')::numeric,
  100::numeric,
  'AO10b/AO11b: effective_at (not created_at) drives as-of inclusion — only charge-3''s component (effective_at 2025-01-01) is included at a 2025-06-01 cutoff'
);

-- AO12: reversed payment's historical effect — the opening-balance
-- component stays fully outstanding (10000, within the 10100 total)
-- at every as-of cutoff on/after the REVERSED payment's own
-- effective_at (2026-01-10), since a REVERSED payment''s allocation
-- never counts regardless of date.
select is(
  (
    select s.outstanding
    from public.contribution_charge_component_states_as_of('10700000-0000-0000-0000-000000000402'::uuid, '2026-01-16'::date) s
    where s.component_id = '10700000-0000-0000-0000-000000000505'
  ),
  10000::numeric,
  'AO12: the reversed payment''s allocation never counts at any as-of date on/after its own effective_at — the opening-balance component remains fully outstanding'
);

-- AO13: migrated loan (loan-4) opening semantics — present even at an
-- as-of date far before ANY other fixture event, with no fabricated
-- disbursement.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2020-01-02'::date, null) -> 'period' -> 'opening' -> 'loans' ->> 'outstanding')::numeric,
  20000::numeric,
  'AO13/AO18: empty-history opening (cutoff 2020-01-01, before every other fixture event) correctly shows ONLY the MIGRATED loan-4''s real 20000 — never a fabricated zero, never a fabricated disbursement for it'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2020-01-02'::date, null) -> 'period' -> 'opening' -> 'contributions' ->> 'outstanding')::numeric,
  0::numeric,
  'AO18b: empty-history opening contributions is correctly 0 (not fabricated — genuinely nothing existed by that cutoff)'
);

-- AO19/AO20: cross-group isolation and multi-group correctness are
-- preserved for period positions too — Group B''s own (otherwise
-- empty) statement returns a null/absent period section gracefully
-- when no date range is requested, and a zero opening when one is.
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000002'::uuid, '2026-01-16'::date, null) -> 'period' -> 'opening' -> 'contributions' ->> 'outstanding')::numeric,
  0::numeric,
  'AO19/AO20: Group B''s opening position is correctly 0 — none of Group A''s financial history leaks across groups into the as-of calculation'
);

-- AO17: period positions are independent of pagination — identical
-- opening/closing at different limit/offset for the same date range.
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-01-16'::date, '2026-02-10'::date, 2, 0) -> 'period',
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-01-16'::date, '2026-02-10'::date, 100, 50) -> 'period',
  'AO17: period.opening/period.closing are byte-identical regardless of p_limit/p_offset — never computed only over the returned activity page'
);

-- AO1b/AO5b: no opening/closing is fabricated when the corresponding
-- bound isn''t supplied — both are null, never an invented zero.
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'period' -> 'opening',
  'null'::jsonb,
  'AO1b: period.opening is null (not a fabricated zero) when p_from_date is not supplied'
);
select is(
  public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) -> 'period' -> 'closing',
  'null'::jsonb,
  'AO5b: period.closing is null (not a fabricated zero) when p_to_date is not supplied'
);

-- AO15/AO21: the new as-of helpers are themselves locked down exactly
-- like every other internal derivation helper in this codebase.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in ('contribution_charge_component_states_as_of', 'loan_installment_component_states_as_of', 'loan_account_outstanding_as_of', 'member_wallet_balance_as_of_membership')
     and grantee in ('anon', 'authenticated', 'public')),
  0,
  'AO15/AO21: zero EXECUTE grants to anon/authenticated/PUBLIC exist on any of the four new as-of helpers'
);

-- =====================================================================
-- Validation.
-- =====================================================================
select throws_ok(
  $$ select public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, '2026-03-01'::date, '2026-01-01'::date) $$,
  '22023',
  'p_from_date must not be after p_to_date',
  'V1: p_from_date after p_to_date is rejected'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 1000, -5) -> 'activity' ->> 'limit')::integer,
  200,
  'V2: an oversized p_limit is clamped to the bounded maximum (200)'
);
select is(
  (public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid, null, null, 1000, -5) -> 'activity' ->> 'offset')::integer,
  0,
  'V3: a negative p_offset is clamped to 0'
);

-- =====================================================================
-- Grants (§X).
-- =====================================================================
reset role;
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'rpc_get_my_member_statement'
     and grantee in ('anon', 'public')),
  0,
  'G1: zero EXECUTE grants to anon/PUBLIC exist on rpc_get_my_member_statement'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'rpc_get_my_member_statement'
     and grantee = 'authenticated'),
  1,
  'G2: exactly one EXECUTE grant to authenticated exists for rpc_get_my_member_statement'
);

set local role anon;
select throws_ok(
  $$ select public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  null,
  'G3 (behavioral): anon cannot invoke rpc_get_my_member_statement'
);

-- Unauthenticated (authenticated role, no jwt sub set at all).
reset role;
set local role authenticated;
reset request.jwt.claim.sub;
select throws_ok(
  $$ select public.rpc_get_my_member_statement('10700000-0000-0000-0000-000000000001'::uuid) $$,
  '28000',
  'Not authenticated',
  '1: an authenticated-role caller with no jwt sub (unauthenticated) is rejected'
);

-- =====================================================================
-- Legacy regression (§40).
-- =====================================================================
set local request.jwt.claim.sub to '10700000-0000-0000-0000-000000000011';
select lives_ok(
  $$ select public.rpc_get_member_contribution_summary('10700000-0000-0000-0000-000000000001'::uuid, '10700000-0000-0000-0000-000000000102'::uuid) $$,
  '40a: the pre-existing officer RPC rpc_get_member_contribution_summary remains callable/unchanged'
);
select lives_ok(
  $$ select public.rpc_get_loan_statement('10700000-0000-0000-0000-000000000001'::uuid, '10700000-0000-0000-0000-000000000701'::uuid) $$,
  '40b: the pre-existing officer RPC rpc_get_loan_statement remains callable/unchanged'
);

-- =====================================================================
-- 39: no business rows mutated by this read RPC, across every call
-- made above.
-- =====================================================================
reset role;
select set_eq(
  $$ select 'payments', count(*) from public.payments
     union all select 'contribution_charge_components', count(*) from public.contribution_charge_components
     union all select 'loan_accounts', count(*) from public.loan_accounts
     union all select 'member_wallet_entries', count(*) from public.member_wallet_entries
     union all select 'loan_penalty_charges', count(*) from public.loan_penalty_charges
     union all select 'loan_restructure_events', count(*) from public.loan_restructure_events
     union all select 'loan_prepayment_events', count(*) from public.loan_prepayment_events $$,
  $$ values ('payments', 3::bigint), ('contribution_charge_components', 6::bigint),
            ('loan_accounts', 6::bigint), ('member_wallet_entries', 1::bigint),
            ('loan_penalty_charges', 1::bigint), ('loan_restructure_events', 1::bigint),
            ('loan_prepayment_events', 1::bigint) $$,
  '39: fixture row counts are unchanged after every rpc_get_my_member_statement call above — a read RPC mutated nothing, including the new loan_penalty_charges/loan_restructure_events/loan_prepayment_events sources this fix newly reads from'
);

select * from finish();
rollback;
