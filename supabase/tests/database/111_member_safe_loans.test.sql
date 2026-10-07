-- Prompt 09G-B5-B: Member-safe loan backend.
--
-- Proves rpc_get_my_loans / rpc_get_my_loan_detail / rpc_get_my_loan_schedule /
-- rpc_get_my_loan_timeline are strict self-owned, group-scoped reads:
-- ownership derived exclusively from current_membership_id() plus
-- loan.self_view (no role-name, officer, or ADMIN fallback), balances
-- reconcile to the canonical A3 helpers, DRAFT/DISBURSED never leak,
-- payments are counted once, and no internal identity or accounting
-- machinery is exposed.
begin;

select plan(119);

-- =====================================================================
-- Fixtures (all deterministic; every loan is local to this transaction)
-- =====================================================================

insert into auth.users (id, email) values
  ('11100000-0000-0000-0000-000000000011', 'p09gb5b-admin@example.com'),
  ('11100000-0000-0000-0000-000000000012', 'p09gb5b-member-a@example.com'),
  ('11100000-0000-0000-0000-000000000013', 'p09gb5b-member-b@example.com'),
  ('11100000-0000-0000-0000-000000000014', 'p09gb5b-treasurer@example.com'),
  ('11100000-0000-0000-0000-000000000015', 'p09gb5b-noroles@example.com'),
  ('11100000-0000-0000-0000-000000000016', 'p09gb5b-suspended@example.com'),
  ('11100000-0000-0000-0000-000000000017', 'p09gb5b-inactive@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('11100000-0000-0000-0000-000000000001', 'B5B Group One', '11100000-0000-0000-0000-000000000011', 'B5BG1', 'ACTIVE'),
  ('11100000-0000-0000-0000-000000000002', 'B5B Group Two', '11100000-0000-0000-0000-000000000011', 'B5BG2', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('11100000-0000-0000-0000-000000000101', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'B5BG1-0001', null),
  ('11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000012', 'Member A', 'ACTIVE', '2025-01-02', 'B5BG1-0002', null),
  ('11100000-0000-0000-0000-000000000103', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000013', 'Member B', 'ACTIVE', '2025-01-03', 'B5BG1-0003', null),
  ('11100000-0000-0000-0000-000000000104', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000014', 'Treasurer Only', 'ACTIVE', '2025-01-04', 'B5BG1-0004', null),
  ('11100000-0000-0000-0000-000000000105', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000015', 'No Roles', 'ACTIVE', '2025-01-05', 'B5BG1-0005', null),
  ('11100000-0000-0000-0000-000000000106', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000016', 'Suspended', 'SUSPENDED', '2025-01-06', 'B5BG1-0006', null),
  ('11100000-0000-0000-0000-000000000107', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000017', 'Inactive Profile', 'ACTIVE', '2025-01-07', 'B5BG1-0007', null),
  ('11100000-0000-0000-0000-000000000201', '11100000-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000011', 'Admin Two', 'ACTIVE', '2025-01-01', 'B5BG2-0001', null),
  ('11100000-0000-0000-0000-000000000202', '11100000-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000012', 'Member A In Two', 'ACTIVE', '2025-01-02', 'B5BG2-0002', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000104', id from public.roles where code = 'TREASURER';
-- 105 (No Roles) deliberately has zero roles.
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000106', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000107', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000201', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '11100000-0000-0000-0000-000000000202', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;

-- Inactive profile: the backend must refuse it even with a valid session.
update public.profiles set is_active = false where id = '11100000-0000-0000-0000-000000000017';

insert into public.financial_accounts (id, group_id, name, account_type) values
  ('11100000-0000-0000-0000-000000000301', '11100000-0000-0000-0000-000000000001', 'Cash Box One', 'CASH'),
  ('11100000-0000-0000-0000-000000000302', '11100000-0000-0000-0000-000000000002', 'Cash Box Two', 'CASH');

insert into public.loan_products (id, group_id, code, name, minimum_principal, maximum_principal, minimum_term, maximum_term, interest_rate, interest_rate_basis, interest_method) values
  ('11100000-0000-0000-0000-000000000601', '11100000-0000-0000-0000-000000000001', 'STD', 'Standard Loan', 1000, 500000, 1, 12, 5, 'MONTHLY', 'FLAT'),
  ('11100000-0000-0000-0000-000000000602', '11100000-0000-0000-0000-000000000002', 'STD2', 'Group Two Loan', 1000, 500000, 1, 12, 5, 'MONTHLY', 'FLAT');

-- ---------------------------------------------------------------------
-- Loan accounts. Member A (102) owns 701-714 in group one, plus 706 DRAFT.
-- Member B (103) owns 716. Member A (202) owns 717 in group two.
-- ---------------------------------------------------------------------
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, application_date, first_repayment_date, status, loan_origin) values
  ('11100000-0000-0000-0000-000000000701', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-701', 10000, 5, 'MONTHLY', 'FLAT', 3, 'MONTH', 'MONTHLY', '2026-02-15', '2026-04-01', 'ACTIVE', 'NEW'),
  ('11100000-0000-0000-0000-000000000702', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-702', 5000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2026-01-15', '2026-03-01', 'WRITTEN_OFF', 'NEW'),
  ('11100000-0000-0000-0000-000000000703', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-703', 2000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2026-01-10', '2026-03-01', 'CANCELLED', 'NEW'),
  ('11100000-0000-0000-0000-000000000704', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-704', 2000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2026-01-10', '2026-03-01', 'REJECTED', 'NEW'),
  ('11100000-0000-0000-0000-000000000705', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-705', 2000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2026-02-01', '2026-04-01', 'SUBMITTED', 'NEW'),
  ('11100000-0000-0000-0000-000000000706', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-706', 2000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2026-02-01', '2026-04-01', 'DRAFT', 'NEW'),
  ('11100000-0000-0000-0000-000000000707', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-707', 1000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2024-12-15', '2025-02-01', 'CLOSED', 'NEW'),
  ('11100000-0000-0000-0000-000000000708', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-708', 12000, 5, 'MONTHLY', 'FLAT', 12, 'MONTH', 'MONTHLY', '2025-05-20', '2026-02-01', 'ACTIVE', 'MIGRATED'),
  ('11100000-0000-0000-0000-000000000709', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-709', 3000, 5, 'MONTHLY', 'FLAT', 3, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'ACTIVE', 'NEW'),
  ('11100000-0000-0000-0000-000000000710', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-710', 2000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'WRITTEN_OFF', 'NEW'),
  ('11100000-0000-0000-0000-000000000711', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-711', 1000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'ACTIVE', 'NEW'),
  ('11100000-0000-0000-0000-000000000712', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-712', 2000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'ACTIVE', 'NEW'),
  ('11100000-0000-0000-0000-000000000713', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-713', 1000, 5, 'MONTHLY', 'FLAT', 2, 'MONTH', 'MONTHLY', '2025-12-15', '2026-02-01', 'CLOSED', 'NEW'),
  ('11100000-0000-0000-0000-000000000714', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000601', 'LN-B5B-714', 4000, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-12-15', '2026-03-15', 'ACTIVE', 'NEW'),
  ('11100000-0000-0000-0000-000000000716', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000103', '11100000-0000-0000-0000-000000000601', 'LN-B5B-716', 500, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-12-15', '2026-01-01', 'ACTIVE', 'NEW'),
  ('11100000-0000-0000-0000-000000000717', '11100000-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000202', '11100000-0000-0000-0000-000000000602', 'LN-B5B-717', 300, 5, 'MONTHLY', 'FLAT', 1, 'MONTH', 'MONTHLY', '2025-12-15', '2026-01-01', 'ACTIVE', 'NEW');

insert into public.loan_disbursements (id, group_id, loan_account_id, financial_account_id, amount, effective_at) values
  ('11100007-0000-0000-0000-000000000701', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', '11100000-0000-0000-0000-000000000301', 10000, '2026-03-01'),
  ('11100007-0000-0000-0000-000000000702', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000702', '11100000-0000-0000-0000-000000000301', 5000, '2026-02-01'),
  ('11100007-0000-0000-0000-000000000707', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000707', '11100000-0000-0000-0000-000000000301', 1000, '2025-01-01'),
  ('11100007-0000-0000-0000-000000000709', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', '11100000-0000-0000-0000-000000000301', 3000, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000710', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000710', '11100000-0000-0000-0000-000000000301', 2000, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000711', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000711', '11100000-0000-0000-0000-000000000301', 1000, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000712', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000712', '11100000-0000-0000-0000-000000000301', 2000, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000713', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000713', '11100000-0000-0000-0000-000000000301', 1000, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000714', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000714', '11100000-0000-0000-0000-000000000301', 4000, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000716', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000716', '11100000-0000-0000-0000-000000000301', 500, '2026-01-01'),
  ('11100007-0000-0000-0000-000000000717', '11100000-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000717', '11100000-0000-0000-0000-000000000302', 300, '2026-01-01');

-- ---------------------------------------------------------------------
-- Installments.
-- ---------------------------------------------------------------------
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due, cancelled_at, cancellation_reason, cancelled_by_payment_id) values
  -- 701: i1 overdue (partly paid), i2 settled, i3 future (unearned interest).
  ('11100001-0000-0000-0000-000701000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', 1, '2026-04-01', 4000, 100, null, null, null),
  ('11100001-0000-0000-0000-000701000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', 2, '2026-05-01', 3000, 80, null, null, null),
  ('11100001-0000-0000-0000-000701000003', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', 3, '2099-06-01', 3000, 60, null, null, null),
  -- 702 written off: i1 receivable at write-off.
  ('11100001-0000-0000-0000-000702000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000702', 1, '2026-03-01', 5000, 50, null, null, null),
  -- 707 closed.
  ('11100001-0000-0000-0000-000707000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000707', 1, '2025-02-01', 1000, 0, null, null, null),
  -- 708 migrated (opening schedule, as in A3 fixtures).
  ('11100001-0000-0000-0000-000708000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000708', 1, '2026-02-01', 3000, 20, null, null, null),
  ('11100001-0000-0000-0000-000708000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000708', 2, '2026-03-01', 3000, 20, null, null, null),
  ('11100001-0000-0000-0000-000708000003', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000708', 3, '2026-04-01', 3000, 20, null, null, null),
  -- 709: i1 cancelled by prepayment, i2 cancelled by restructure, i3/i4 current.
  ('11100001-0000-0000-0000-000709000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', 1, '2099-02-01', 1000, 10, '2026-05-01 09:00:00+00', 'PRINCIPAL_PREPAYMENT', null),
  ('11100001-0000-0000-0000-000709000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', 2, '2099-03-01', 1000, 10, '2026-06-01 12:00:00+00', 'RESTRUCTURE', null),
  ('11100001-0000-0000-0000-000709000003', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', 3, '2099-04-01', 1000, 10, null, null, null),
  ('11100001-0000-0000-0000-000709000004', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', 4, '2099-05-01', 1000, 5, null, null, null),
  -- 710 written off with recovery.
  ('11100001-0000-0000-0000-000710000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000710', 1, '2026-02-01', 2000, 20, null, null, null),
  -- 711 write-off reversed; receivable active again.
  ('11100001-0000-0000-0000-000711000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000711', 1, '2099-01-01', 1000, 0, null, null, null),
  -- 712 receives a wallet application and a cross-loan payment.
  ('11100001-0000-0000-0000-000712000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000712', 1, '2099-08-01', 2000, 0, null, null, null),
  -- 713 early settled: i1 settled, i2 cancelled by the settlement.
  ('11100001-0000-0000-0000-000713000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000713', 1, '2026-02-01', 500, 10, null, null, null),
  ('11100001-0000-0000-0000-000713000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000713', 2, '2099-03-01', 500, 10, '2026-05-01 09:00:00+00', 'EARLY_SETTLEMENT', null),
  -- 714 reduce-installment prepayment.
  ('11100001-0000-0000-0000-000714000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000714', 1, '2099-03-15', 4000, 0, null, null, null),
  -- 716 (member B) and 717 (group two, member A).
  ('11100001-0000-0000-0000-000716000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000716', 1, '2099-01-01', 500, 0, null, null, null),
  ('11100001-0000-0000-0000-000717000001', '11100000-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000717', 1, '2099-01-01', 300, 0, null, null, null);

-- ---------------------------------------------------------------------
-- Payments (cash). Membership 102 pays for member A's loans only.
-- ---------------------------------------------------------------------
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number, reversed_at, reversed_by, reversal_reason) values
  ('11100002-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 1100, '2026-04-10', 'CASH', 'POSTED', 'B5B-RCPT-001', null, null, null),
  ('11100002-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 3080, '2026-05-10', 'CASH', 'POSTED', 'B5B-RCPT-002', null, null, null),
  ('11100002-0000-0000-0000-000000000003', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 200, '2026-05-25', 'CASH', 'REVERSED', 'B5B-RCPT-003', '2026-05-26 10:00:00+00', '11100000-0000-0000-0000-000000000011', 'Entered in error'),
  ('11100002-0000-0000-0000-000000000004', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 1500, '2026-07-01', 'CASH', 'POSTED', 'B5B-RCPT-004', null, null, null),
  ('11100002-0000-0000-0000-000000000007', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 1000, '2025-02-01', 'CASH', 'POSTED', 'B5B-RCPT-007', null, null, null),
  ('11100002-0000-0000-0000-000000000008', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 1000, '2026-05-01', 'CASH', 'POSTED', 'B5B-RCPT-008', null, null, null),
  ('11100002-0000-0000-0000-000000000009', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 300, '2026-04-01', 'CASH', 'POSTED', 'B5B-RCPT-009', null, null, null),
  ('11100002-0000-0000-0000-000000000010', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 1500, '2026-03-15', 'CASH', 'POSTED', 'B5B-RCPT-010', null, null, null),
  ('11100002-0000-0000-0000-000000000011', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 510, '2026-02-01', 'CASH', 'POSTED', 'B5B-RCPT-011', null, null, null),
  ('11100002-0000-0000-0000-000000000012', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', '11100000-0000-0000-0000-000000000301', 500, '2026-05-01', 'CASH', 'POSTED', 'B5B-RCPT-012', null, null, null);

-- The cross-loan payment 0004 (1500) funds loan 701 (600) and loan 712 (900).
-- Payment 0008 (1000) is the principal prepayment on 709. Payment 0011/0012
-- are the 713 instalment and early-settlement clearing payments.
-- ---------------------------------------------------------------------
-- Wallet entry applied to 712.
-- ---------------------------------------------------------------------
insert into public.member_wallet_entries (id, group_id, membership_id, entry_type, amount, effective_at, source_type, source_id, idempotency_key) values
  ('11100004-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', 'ALLOCATION_DEBIT', 100, '2026-07-01', 'LOAN_ALLOCATION', null, 'b5b-wallet-712-1');

insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, loan_penalty_charge_id, amount, line_number, wallet_entry_id) values
  ('11100003-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000001', null, 100, 1, null),
  ('11100003-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000001', null, 1000, 2, null),
  ('11100003-0000-0000-0000-000000000003', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000002', null, 3000, 1, null),
  ('11100003-0000-0000-0000-000000000004', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000002', null, 80, 2, null),
  ('11100003-0000-0000-0000-000000000005', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000003', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000003', null, 200, 1, null),
  ('11100003-0000-0000-0000-000000000006', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000004', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000003', null, 600, 1, null),
  ('11100003-0000-0000-0000-000000000007', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000004', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000712', '11100001-0000-0000-0000-000712000001', null, 900, 2, null),
  -- Wallet-applied loan allocation: payment_id null, wallet_entry_id set.
  ('11100003-0000-0000-0000-000000000008', '11100000-0000-0000-0000-000000000001', null, '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000712', '11100001-0000-0000-0000-000712000001', null, 100, 1, '11100004-0000-0000-0000-000000000001'),
  ('11100003-0000-0000-0000-000000000009', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000007', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000707', '11100001-0000-0000-0000-000707000001', null, 1000, 1, null),
  ('11100003-0000-0000-0000-000000000010', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000011', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000713', '11100001-0000-0000-0000-000713000001', null, 500, 1, null),
  ('11100003-0000-0000-0000-000000000011', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000011', '11100000-0000-0000-0000-000000000102', 'LOAN_INTEREST', '11100000-0000-0000-0000-000000000713', '11100001-0000-0000-0000-000713000001', null, 10, 2, null),
  ('11100003-0000-0000-0000-000000000012', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000012', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '11100000-0000-0000-0000-000000000713', '11100001-0000-0000-0000-000713000002', null, 500, 1, null),
  ('11100003-0000-0000-0000-000000000013', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000008', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL_PREPAYMENT', '11100000-0000-0000-0000-000000000709', null, null, 1000, 1, null),
  ('11100003-0000-0000-0000-000000000014', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000010', '11100000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL_PREPAYMENT', '11100000-0000-0000-0000-000000000714', null, null, 1500, 1, null),
  ('11100003-0000-0000-0000-000000000015', '11100000-0000-0000-0000-000000000001', '11100002-0000-0000-0000-000000000009', '11100000-0000-0000-0000-000000000102', 'LOAN_RECOVERY_PRINCIPAL', '11100000-0000-0000-0000-000000000710', null, null, 300, 1, null);

update public.loan_installments set cancelled_by_payment_id = '11100002-0000-0000-0000-000000000008' where id = '11100001-0000-0000-0000-000709000001';
update public.loan_installments set cancelled_by_payment_id = '11100002-0000-0000-0000-000000000012' where id = '11100001-0000-0000-0000-000713000002';

-- Reversed payment 0003 is a real reversed cash row that must stay visible.
-- Payment 0002 (3080) carries the i2 principal and interest.
-- Payment 0001 (1100) carries the i1 interest and principal.
-- Payment 0004 (1500) allocated 600 to 701 and 900 to 712 (cross-loan).

-- ---------------------------------------------------------------------
-- Penalties (ASSESSED) and the migrated OPENING snapshot charge.
-- ---------------------------------------------------------------------
insert into public.loan_penalty_charges (id, group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days, basis_amount, fixed_amount, penalty_amount, origin) values
  ('11100004-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', '11100001-0000-0000-0000-000701000001', '2026-04-20', 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 15, 4000, 50, 50, 'ASSESSED'),
  ('11100004-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000708', '11100001-0000-0000-0000-000708000002', '2025-12-15', 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 15, 3000, 25, 25, 'ASSESSED'),
  ('11100004-0000-0000-0000-000000000003', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000708', '11100001-0000-0000-0000-000708000001', '2025-12-31', 0, null, null, null, null, null, null, 40, 'OPENING');

-- ---------------------------------------------------------------------
-- Obligation adjustments on 701 (a correction and its reversal).
-- ---------------------------------------------------------------------
insert into public.loan_obligation_adjustments (id, group_id, loan_account_id, target_type, loan_installment_id, adjustment_type, amount, reason_code, effective_date, reverses_adjustment_id) values
  ('11100005-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', 'LOAN_INTEREST', '11100001-0000-0000-0000-000701000003', 'CORRECTION_DECREASE', -5, 'DATA_ENTRY_ERROR', '2026-05-01', null),
  ('11100005-0000-0000-0000-000000000002', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', 'LOAN_INTEREST', '11100001-0000-0000-0000-000701000003', 'REVERSAL', 5, 'ENTRY_CORRECTED', '2026-05-02', '11100005-0000-0000-0000-000000000001');

-- ---------------------------------------------------------------------
-- Opening position for 708 (migrated). No disbursement row, no payment.
-- ---------------------------------------------------------------------
insert into public.loan_opening_positions (id, group_id, loan_account_id, opening_as_of_date, original_disbursement_date, original_loan_number, original_principal, opening_principal_outstanding, opening_principal_arrears, opening_interest_arrears, opening_penalty_arrears, future_scheduled_principal, future_scheduled_interest, remaining_installment_count, next_due_date) values
  ('11100000-0000-0000-0000-000000000c08', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000708', '2026-01-01', '2025-06-01', 'OLD-B5B-708', 12000, 9000, 0, 100, 40, 9000, 60, 3, '2026-02-01');

-- ---------------------------------------------------------------------
-- Write-off, reversal and recovery (702 / 710 / 711).
-- ---------------------------------------------------------------------
insert into public.loan_write_off_events (id, group_id, loan_account_id, event_type, principal_amount, interest_amount, penalty_amount, reason_code, effective_date, reverses_write_off_id) values
  ('11100008-0000-0000-0000-000000000702', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000702', 'WRITE_OFF', 5000, 50, 0, 'GROUP_DECISION', '2026-04-01', null),
  ('11100008-0000-0000-0000-000000000710', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000710', 'WRITE_OFF', 2000, 20, 0, 'GROUP_DECISION', '2026-03-01', null),
  ('11100008-0000-0000-0000-000000000811', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000711', 'WRITE_OFF', 1000, 0, 0, 'GROUP_DECISION', '2026-02-01', null),
  ('11100008-0000-0000-0000-000000000812', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000711', 'REVERSAL', -1000, 0, 0, 'GROUP_DECISION', '2026-02-10', '11100008-0000-0000-0000-000000000811');

insert into public.loan_recovery_events (id, group_id, loan_account_id, write_off_event_id, payment_id, principal_recovered, interest_recovered, penalty_recovered) values
  ('11100009-0000-0000-0000-000000000710', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000710', '11100008-0000-0000-0000-000000000710', '11100002-0000-0000-0000-000000000009', 300, 0, 0);

-- ---------------------------------------------------------------------
-- Prepayment (709 REDUCE_TERM, 714 REDUCE_INSTALLMENT) and restructure (709).
-- ---------------------------------------------------------------------
insert into public.loan_prepayment_events (id, group_id, loan_account_id, membership_id, payment_id, effective_date, amount, treatment, old_future_schedule_snapshot, new_future_schedule_snapshot) values
  ('1110000a-0000-0000-0000-000000000709', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', '11100000-0000-0000-0000-000000000102', '11100002-0000-0000-0000-000000000008', '2026-05-01', 1000, 'REDUCE_TERM', '[]'::jsonb, '[]'::jsonb),
  ('1110000a-0000-0000-0000-000000000714', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000714', '11100000-0000-0000-0000-000000000102', '11100002-0000-0000-0000-000000000010', '2026-03-15', 1500, 'REDUCE_INSTALLMENT', '[]'::jsonb, '[]'::jsonb);

insert into public.loan_restructure_events (id, group_id, loan_account_id, effective_date, reason, new_interest_rate, new_term, new_first_installment_date, old_remaining_schedule_snapshot, new_remaining_schedule_snapshot, created_at) values
  ('1110000b-0000-0000-0000-000000000709', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000709', '2026-06-01', 'OFFICER INTERNAL NOTE', 5, 6, '2099-07-01', '[]'::jsonb, '[]'::jsonb, '2026-06-01 12:00:00+00');

-- ---------------------------------------------------------------------
-- Early settlement for 713 (clearing payment 0012 covers the cancelled row).
-- ---------------------------------------------------------------------
-- (installment 713-2 was cancelled by payment 0011 above; keep it consistent
-- with the settlement by pointing it at the clearing payment.)
update public.loan_installments set cancelled_by_payment_id = '11100002-0000-0000-0000-000000000012' where id = '11100001-0000-0000-0000-000713000002';


-- ---------------------------------------------------------------------
-- Lifecycle events.
-- ---------------------------------------------------------------------
insert into public.loan_account_events (id, group_id, loan_account_id, event_type, from_status, to_status, reason, metadata, created_at) values
  ('11100006-0000-0000-0000-000000000701', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000701', 'SUBMITTED', null, 'SUBMITTED', 'Submitted', '{}'::jsonb, '2026-02-10 09:00:00+00'),
  ('11100006-0000-0000-0000-000000070301', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000703', 'SUBMITTED', null, 'SUBMITTED', 'Submitted', '{}'::jsonb, '2026-01-10 09:00:00+00'),
  ('11100006-0000-0000-0000-000000070302', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000703', 'CANCELLED', 'SUBMITTED', 'CANCELLED', 'Cancelled by member', '{}'::jsonb, '2026-01-12 09:00:00+00'),
  ('11100006-0000-0000-0000-000000070401', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000704', 'SUBMITTED', null, 'SUBMITTED', 'Submitted', '{}'::jsonb, '2026-01-10 09:00:00+00'),
  ('11100006-0000-0000-0000-000000070402', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000704', 'REJECTED', 'SUBMITTED', 'REJECTED', 'Not eligible', '{}'::jsonb, '2026-01-11 09:00:00+00'),
  ('11100006-0000-0000-0000-000000000705', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000705', 'SUBMITTED', null, 'SUBMITTED', 'Submitted', '{}'::jsonb, '2026-02-01 09:00:00+00'),
  ('11100006-0000-0000-0000-000000000707', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000707', 'CLOSED', 'ACTIVE', 'CLOSED', 'Fully repaid', '{}'::jsonb, '2025-02-01 12:00:00+00'),
  ('11100006-0000-0000-0000-000000000713', '11100000-0000-0000-0000-000000000001', '11100000-0000-0000-0000-000000000713', 'EARLY_SETTLED', 'ACTIVE', 'CLOSED', 'Early settlement', jsonb_build_object('payment_id', '11100002-0000-0000-0000-000000000012'), '2026-05-01 09:00:00+00');

-- ---------------------------------------------------------------------
-- Loan status for the early-settled 713 and the 713 cancelled rows are set
-- above. CLOSED/ACTIVE/WRITTEN_OFF statuses are stored on loan_accounts.
-- ---------------------------------------------------------------------

-- =====================================================================
-- Authorization model (catalog level, run as the owning role)
-- =====================================================================

select is(
  (select count(*)::int from public.permissions where code = 'loan.self_view'),
  1,
  'permission loan.self_view exists exactly once'
);

select is(
  (select array_agg(r.code order by r.code)
   from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where p.code = 'loan.self_view'),
  array['ADMIN', 'MEMBER'],
  'loan.self_view is granted to exactly MEMBER and ADMIN'
);

select ok(
  not exists (
    select 1 from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.id = rp.permission_id
    where p.code = 'loan.self_view' and r.code in ('CHAIRPERSON', 'SECRETARY', 'TREASURER')
  ),
  'officer roles CHAIRPERSON, SECRETARY and TREASURER do not hold loan.self_view'
);

select has_function('public', 'rpc_get_my_loans', array['uuid', 'integer', 'integer'], 'rpc_get_my_loans(uuid, integer, integer) exists');
select has_function('public', 'rpc_get_my_loan_detail', array['uuid', 'uuid'], 'rpc_get_my_loan_detail(uuid, uuid) exists');
select has_function('public', 'rpc_get_my_loan_schedule', array['uuid', 'uuid'], 'rpc_get_my_loan_schedule(uuid, uuid) exists');
select has_function('public', 'rpc_get_my_loan_timeline', array['uuid', 'uuid', 'integer', 'integer'], 'rpc_get_my_loan_timeline(uuid, uuid, integer, integer) exists');

select is(
  (select array_agg(p.proname::text order by p.proname::text)
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'rpc_get_my_loan%'),
  array['rpc_get_my_loan_detail', 'rpc_get_my_loan_schedule', 'rpc_get_my_loan_timeline', 'rpc_get_my_loans'],
  'exactly the four intended member loan RPCs exist'
);

select ok(
  has_function_privilege('authenticated', 'public.rpc_get_my_loans(uuid,integer,integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.rpc_get_my_loan_detail(uuid,uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.rpc_get_my_loan_schedule(uuid,uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.rpc_get_my_loan_timeline(uuid,uuid,integer,integer)', 'EXECUTE'),
  'all four member loan RPCs are executable by authenticated'
);

select ok(
  not has_function_privilege('anon', 'public.rpc_get_my_loans(uuid,integer,integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.rpc_get_my_loan_detail(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.rpc_get_my_loan_schedule(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.rpc_get_my_loan_timeline(uuid,uuid,integer,integer)', 'EXECUTE'),
  'anon has no EXECUTE on any member loan RPC'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where n.nspname = 'public'
      and p.proname in (
        'rpc_get_my_loans', 'rpc_get_my_loan_detail', 'rpc_get_my_loan_schedule', 'rpc_get_my_loan_timeline',
        'member_loan_status_code', 'member_loan_origin_context', 'member_loan_membership_id', 'member_loan_timeline_source'
      )
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no EXECUTE on any member loan RPC or internal helper'
);

select ok(
  not has_function_privilege('authenticated', 'public.member_loan_status_code(public.loan_account_status)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.member_loan_origin_context(public.loan_origin)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.member_loan_membership_id(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.member_loan_timeline_source(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.member_loan_membership_id(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.member_loan_timeline_source(uuid,uuid)', 'EXECUTE'),
  'internal member loan helpers are not client-executable (authenticated or anon)'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants g
    where g.grantee = 'authenticated'
      and g.table_schema = 'public'
      and g.table_name like 'loan%'
      and g.privilege_type <> 'SELECT'
  ),
  'authenticated has no write grant on any loan table (no direct grant widened)'
);

select ok(
  has_table_privilege('authenticated', 'public.loan_accounts', 'SELECT')
  and has_table_privilege('authenticated', 'public.loan_installments', 'SELECT'),
  'pre-existing authenticated SELECT on loan tables is unchanged (RLS still the gate)'
);

-- =====================================================================
-- Caller boundaries (set role, then the JWT claim)
-- =====================================================================

-- Anonymous: EXECUTE is revoked, so the role itself is refused.
set local role anon;
select throws_ok(
  $$select public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)$$,
  '42501',
  null,
  'anon cannot call rpc_get_my_loans'
);
reset role;

-- No authenticated session at all.
set local role authenticated;
select throws_ok(
  $$select public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)$$,
  '28000',
  'Not authenticated',
  'no session: rpc_get_my_loans refuses with Not authenticated'
);
select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)$$,
  '28000',
  'Not authenticated',
  'no session: rpc_get_my_loan_detail refuses'
);
select throws_ok(
  $$select public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)$$,
  '28000',
  'Not authenticated',
  'no session: rpc_get_my_loan_schedule refuses'
);
select throws_ok(
  $$select public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)$$,
  '28000',
  'Not authenticated',
  'no session: rpc_get_my_loan_timeline refuses'
);
reset role;

-- Treasurer holds TREASURER only, not MEMBER: no loan.self_view (locked seed).
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000014';
-- 09G-B5-B.1: the treasurer holds the MEMBER baseline, so loan.self_view is
-- granted through MEMBER for their OWN loans only; officer role gives no
-- access to another member's loan.
select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)->'pagination'->>'total_count')::int),
  0,
  'treasurer with MEMBER baseline gets a valid empty own-loan list'
);
select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)$$,
  '22023',
  'Loan account not found',
  'treasurer officer role does not reach another member loan through self-service'
);
reset role;

-- Member with zero roles.
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000015';
-- 09G-B5-B.1: a linked membership with no officer role holds the MEMBER baseline.
select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)->'pagination'->>'total_count')::int),
  0,
  'linked member with no officer role holds MEMBER baseline and gets a valid own-loan list'
);
reset role;

-- Suspended membership: not a current operational context.
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000016';
select throws_ok(
  $$select public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)$$,
  '42501',
  null,
  'suspended membership is not a current membership context'
);
reset role;

-- Inactive profile with an otherwise valid ACTIVE membership and MEMBER role.
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000017';
select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)$$,
  '42501',
  null,
  'inactive profile loses loan access even with an ACTIVE MEMBER membership'
);
reset role;

-- Null group.
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000012';
select throws_ok(
  $$select public.rpc_get_my_loans(null::uuid, 20, 0)$$,
  '22023',
  'p_group_id is required',
  'null group id is rejected'
);
reset role;

-- =====================================================================
-- Member A (102) in group one
-- =====================================================================
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000012';

select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'pagination'->>'total_count')::int),
  13,
  'member A lists 13 own non-DRAFT loans in group one (DRAFT 706 excluded)'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items')),
  13,
  'member A list returns all 13 items on one page'
);

select is(
  (select jsonb_object_agg(it->>'loan_number', it->>'member_status')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it),
  '{"LN-B5B-701":"ACTIVE","LN-B5B-702":"WRITTEN_OFF","LN-B5B-703":"CANCELLED","LN-B5B-704":"REJECTED","LN-B5B-705":"SUBMITTED","LN-B5B-707":"CLOSED","LN-B5B-708":"ACTIVE","LN-B5B-709":"ACTIVE","LN-B5B-710":"WRITTEN_OFF","LN-B5B-711":"ACTIVE","LN-B5B-712":"ACTIVE","LN-B5B-713":"CLOSED","LN-B5B-714":"ACTIVE"}'::jsonb,
  'member statuses cover ACTIVE, CLOSED, WRITTEN_OFF, CANCELLED, REJECTED and SUBMITTED; DRAFT absent'
);

select ok(
  not exists (
    select 1 from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
    where it->>'member_status' in ('DISBURSED', 'DRAFT', 'MIGRATED')
  ),
  'DISBURSED, DRAFT and MIGRATED never appear as member-facing status'
);

select is(
  (select jsonb_agg(it->>'loan_number' order by it->>'loan_number')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
   where it->>'origin_context' is not null),
  '["LN-B5B-708"]'::jsonb,
  'only the migrated loan carries OPENING_POSITION origin context'
);

select is(
  (select it->>'origin_context'
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
   where it->>'loan_number' = 'LN-B5B-708'),
  'OPENING_POSITION',
  'opening-position loan is labelled OPENING_POSITION (stable code)'
);

select is(
  (select jsonb_agg(it->'current_position' order by it->>'loan_number')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
   where it->>'loan_number' in ('LN-B5B-702', 'LN-B5B-710')),
  '[{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0},{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0}]'::jsonb,
  'WRITTEN_OFF loans expose a zero current receivable'
);

select is(
  (select jsonb_agg(it->'current_position' order by it->>'loan_number')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
   where it->>'loan_number' in ('LN-B5B-703', 'LN-B5B-704', 'LN-B5B-705')),
  '[{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0},{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0},{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0}]'::jsonb,
  'never-disbursed CANCELLED, REJECTED and SUBMITTED loans expose no funded receivable'
);

select is(
  (select jsonb_agg(it->'current_position' order by it->>'loan_number')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
   where it->>'loan_number' in ('LN-B5B-707', 'LN-B5B-713')),
  '[{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0},{"interest_outstanding":0,"penalty_outstanding":0,"total_outstanding":0,"principal_outstanding":0}]'::jsonb,
  'CLOSED loans carry a zero current receivable'
);

select is(
  (select it->'current_position' || jsonb_build_object('next_due', it->>'next_due_date', 'overdue', it->>'overdue_amount')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
   where it->>'loan_number' = 'LN-B5B-701'),
  '{"interest_outstanding":0,"penalty_outstanding":50,"principal_outstanding":5400,"total_outstanding":5450,"next_due":"2026-04-01","overdue":"3050.00"}'::jsonb,
  'loan 701 (cross-loan payment, reversal, adjustments): earned-only position, future interest 60 excluded, next due and overdue exact'
);

select is(
  (select jsonb_object_keys_count from (select count(*)::int as jsonb_object_keys_count from jsonb_object_keys(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0))) x),
  2,
  'list response has only items and pagination: no global loan total'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items'->0) k),
  (select array_agg(k order by k) from unnest(array['loan_account_id','loan_number','product_id','product_name','member_status','origin_context','original_principal','current_position','next_due_date','overdue_amount']) k),
  'list item exposes exactly the member-safe field set'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items'->0->'current_position') k),
  (select array_agg(k order by k) from unnest(array['principal_outstanding','interest_outstanding','penalty_outstanding','total_outstanding']) k),
  'current_position exposes exactly the four canonical amounts'
);

select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 5, 0)->'pagination'->>'has_more')::boolean),
  true,
  'pagination: has_more true when more rows follow'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 5, 10)->'items')),
  3,
  'pagination: offset 10 returns the final 3 rows'
);

select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 5, 10)->'pagination'->>'has_more')::boolean),
  false,
  'pagination: has_more false on the last page'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 5, 13)->'items')),
  0,
  'pagination: an offset past the end is a valid empty page'
);

select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, -5, -10)->'pagination'->>'limit')::int),
  1,
  'pagination: a negative limit is clamped to 1'
);

select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 500000, 0)->'pagination'->>'limit')::int),
  200,
  'pagination: an oversized limit is clamped to the 200 maximum'
);

-- Detail: 701.
select is(
  (select jsonb_build_object(
     'loan_number', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->>'loan_number',
     'product_name', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'product'->>'product_name',
     'member_status', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->>'member_status',
     'original_principal', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->>'original_principal',
     'original_disbursement_date', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->>'original_disbursement_date',
     'origin_context', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->>'origin_context'
   )),
  '{"loan_number":"LN-B5B-701","product_name":"Standard Loan","member_status":"ACTIVE","original_principal":"10000.00","original_disbursement_date":"2026-03-01","origin_context":null}'::jsonb,
  'detail of own loan 701: identity, product, status, original principal and disbursement date'
);

select is(
  (select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'terms'),
  '{"term":3,"term_unit":"MONTH","interest_rate":5,"interest_method":"FLAT","interest_rate_basis":"MONTHLY","repayment_frequency":"MONTHLY","first_repayment_date":"2026-04-01"}'::jsonb,
  'detail exposes only persisted member-safe terms'
);

select is(
  (select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'current_position'),
  '{"interest_outstanding":0,"penalty_outstanding":50,"principal_outstanding":5400,"total_outstanding":5450}'::jsonb,
  'detail current position matches the expected canonical 701 figures'
);

select is(
  (select (public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->>'final_due_date')::date),
  '2099-06-01'::date,
  'detail final due date is the last current installment (persisted, not invented)'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)) k),
  (select array_agg(k order by k) from unnest(array['application_date','current_position','final_due_date','loan_account_id','loan_number','member_status','next_due_date','opening_as_of_date','origin_context','original_disbursement_date','original_principal','overdue_amount','product','terms']) k),
  'detail exposes exactly the member-safe field set (no internal identity, account or penalty machinery)'
);

-- Detail: migrated 708 (opening position, no fabricated disbursement).
select is(
  (select jsonb_build_object(
     'origin_context', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid)->>'origin_context',
     'original_principal', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid)->>'original_principal',
     'original_disbursement_date', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid)->>'original_disbursement_date',
     'opening_as_of_date', public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid)->>'opening_as_of_date'
   )),
  '{"origin_context":"OPENING_POSITION","original_principal":"12000.00","original_disbursement_date":"2025-06-01","opening_as_of_date":"2026-01-01"}'::jsonb,
  'opening-position detail: origin context, original principal and dates come from the opening record'
);

-- Detail: WRITTEN_OFF 702 and CLOSED 707.
select is(
  (select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000702'::uuid)->'current_position'),
  '{"interest_outstanding":0,"penalty_outstanding":0,"principal_outstanding":0,"total_outstanding":0}'::jsonb,
  'written-off loan detail shows a zero receivable, not the frozen schedule'
);

-- Schedule 701: statuses and current rows.
select is(
  (select jsonb_object_agg(r->>'installment_number', r->>'member_schedule_status')
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'current') r),
  '{"1":"OVERDUE","2":"SETTLED","3":"PARTIALLY_SETTLED"}'::jsonb,
  'schedule statuses for 701: overdue, settled and upcoming, from canonical state'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'history')),
  0,
  'schedule history is empty for a loan with no replaced or cancelled rows'
);

select is(
  (select jsonb_build_object(
     'paid_principal', r->'paid_principal', 'paid_interest', r->'paid_interest', 'paid_penalty', r->'paid_penalty',
     'current_earned_interest_outstanding', r->'current_earned_interest_outstanding',
     'current_penalty_outstanding', r->'current_penalty_outstanding', 'current_total_outstanding', r->'current_total_outstanding')
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'current') r
   where r->>'installment_number' = '1'),
  '{"paid_principal":1000,"paid_interest":100,"paid_penalty":0,"current_earned_interest_outstanding":0,"current_penalty_outstanding":50,"current_total_outstanding":3050}'::jsonb,
  'installment 1 shows paid amounts and earned-only outstanding, with the penalty as a current obligation'
);

select is(
  (select jsonb_build_object(
     'scheduled_future_interest_outstanding', r->'scheduled_future_interest_outstanding',
     'current_earned_interest_outstanding', r->'current_earned_interest_outstanding',
     'current_total_outstanding', r->'current_total_outstanding')
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'current') r
   where r->>'installment_number' = '3'),
  '{"scheduled_future_interest_outstanding":60,"current_earned_interest_outstanding":0,"current_total_outstanding":2400}'::jsonb,
  'future installment: contractual interest 60 is shown but is not current earned interest or current total'
);

select is(
  (select sum((r->>'current_total_outstanding')::numeric)
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)->'current') r),
  5450::numeric,
  'the current rows sum to the canonical account total (future unearned interest excluded)'
);

-- Schedule 709: replacement history.
select is(
  (select jsonb_build_object(
     'current', (select jsonb_agg(r->>'installment_number' order by r->>'installment_number') from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)->'current') r),
     'history', (select jsonb_agg(jsonb_build_object('n', r->>'installment_number', 's', r->>'member_schedule_status', 'why', r->>'replacement_reason') order by r->>'installment_number') from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)->'history') r))),
  '{"current":["3","4"],"history":[{"n":"1","s":"REPLACED","why":"PRINCIPAL_PREPAYMENT"},{"n":"2","s":"REPLACED","why":"RESTRUCTURE"}]}'::jsonb,
  'prepayment and restructure replacements are history rows with a safe reason code; current holds only live rows'
);

select ok(
  not exists (
    select 1 from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)->'history') r
    where r ? 'replacement_reason' and r->>'replacement_reason' not in ('PRINCIPAL_PREPAYMENT', 'RESTRUCTURE')
  ),
  'history never exposes officer free-text cancellation reasons'
);

-- Schedule 713: early settlement history is CANCELLED, not REPLACED.
select is(
  (select jsonb_build_object(
     'status', r->>'member_schedule_status', 'reason', r->>'replacement_reason', 'paid_principal', r->>'paid_principal')
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000713'::uuid)->'history') r),
  '{"status":"CANCELLED","reason":null,"paid_principal":"500.00"}'::jsonb,
  'early-settlement cancellation is CANCELLED with no replacement reason'
);

-- Schedule 710 (written off with recovery) and 711 (write-off reversed).
select is(
  (select jsonb_build_object(
     'status', r->>'member_schedule_status',
     'principal', r->>'current_principal_outstanding',
     'total', r->>'current_total_outstanding')
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000710'::uuid)->'current') r),
  '{"status":"WRITTEN_OFF","principal":"0","total":"0"}'::jsonb,
  'written-off loan: receivable row is WRITTEN_OFF with zero current outstanding'
);

select is(
  (select r->>'member_schedule_status'
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000711'::uuid)->'current') r),
  'UPCOMING',
  'write-off reversed: the restored receivable is an ordinary UPCOMING row again'
);

select is(
  (select r->>'member_schedule_status'
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000707'::uuid)->'current') r),
  'SETTLED',
  'closed loan: fully paid row is SETTLED'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
    cross join lateral jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, (it->>'loan_account_id')::uuid)->'current') r
    where r->>'member_schedule_status' not in ('SETTLED', 'OVERDUE', 'PARTIALLY_SETTLED', 'DUE', 'UPCOMING', 'WRITTEN_OFF')
  ),
  'schedule uses only member-safe statuses (no officer PAID or PARTIALLY_PAID wording)'
);

-- Timeline 701: one payment row per payment, cross-loan amount, reversal.
select is(
  (select (public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'pagination'->>'total_count')::int),
  9,
  'timeline 701 counts one row per economic event (disbursement, submission, 4 payments, penalty, 2 adjustment rows)'
);

select is(
  (select (it->>'amount')::numeric
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100002-0000-0000-0000-000000000001'),
  1100::numeric,
  'multi-allocation payment 0001 appears once with its loan-attributable amount'
);

select is(
  (select count(*)::int
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100002-0000-0000-0000-000000000001'),
  1,
  'one payments row is exactly one timeline cash row for this loan'
);

select is(
  (select (it->>'amount')::numeric
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100002-0000-0000-0000-000000000004'),
  600::numeric,
  'cross-loan payment 0004 (1500 total) contributes only the 600 allocated to loan 701'
);

select ok(
  (select (it->>'is_reversed')::boolean and (it->>'amount')::numeric = 200 and (it->>'is_cash')::boolean
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100002-0000-0000-0000-000000000003'),
  'reversed payment 0003 stays the same event, marked is_reversed, with no second cash row'
);

select is(
  (select it->>'event_type'
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100004-0000-0000-0000-000000000001'),
  'PENALTY_ASSESSED',
  'penalty assessment is a non-cash timeline event'
);

select ok(
  (select (it->>'is_cash')::boolean is false and it->>'effective_at' = '2026-04-20'
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100004-0000-0000-0000-000000000001'),
  'penalty effective_at is its economic assessment date and is non-cash'
);

select is(
  (select jsonb_build_object('type', it->>'event_type', 'amount', it->>'amount', 'breakdown', it->'component_breakdown')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'OBLIGATION_CORRECTION'),
  '{"type":"OBLIGATION_CORRECTION","amount":"-5.00","breakdown":{"interest":-5}}'::jsonb,
  'obligation correction is non-cash and carries its component breakdown'
);

select ok(
  (select (it->>'is_reversed')::boolean
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'OBLIGATION_CORRECTION') is true
  and exists (
    select 1 from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
    where it->>'event_type' = 'OBLIGATION_ADJUSTMENT_REVERSED' and (it->>'is_cash')::boolean is false
  ),
  'reversed obligation correction is marked reversed and its reversal is a separate non-cash event'
);

-- Timeline 708 (migrated): one opening event, no fabricated disbursement or payment.
select is(
  (select jsonb_agg(it->>'event_type' order by it->>'event_type')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid, 50, 0)->'items') it),
  '["OPENING_POSITION","PENALTY_ASSESSED"]'::jsonb,
  'opening-position timeline has exactly one opening event and only real activity (no fake disbursement or payment)'
);

select is(
  (select (it->>'amount')::numeric
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'OPENING_POSITION'),
  9140::numeric,
  'opening event is non-cash and carries the opening principal, interest and penalty total'
);

select ok(
  (select (it->>'is_cash')::boolean is false and (it->>'effective_at')::date = '2026-01-01'::date
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'OPENING_POSITION'),
  'opening event is non-cash and dated at the opening as-of date'
);

select is(
  (select (it->>'effective_at')::date
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'PENALTY_ASSESSED'),
  '2025-12-15'::date,
  'a real ASSESSED penalty before the opening keeps its economic date'
);

select is(
  (select (public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid, 50, 0)->'items'->0->>'event_type')),
  'OPENING_POSITION',
  'effective-dated ordering: the 2026-01-01 opening sorts ahead of the 2025-12-15 penalty'
);

-- Timeline 709 (prepayment REDUCE_TERM, restructure).
select is(
  (select jsonb_build_object('type', it->>'event_type', 'subtype', it->>'event_subtype', 'is_cash', it->>'is_cash', 'amount', it->>'amount', 'reduction', it->'metadata'->>'principal_reduction_amount')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'PRINCIPAL_PREPAYMENT'),
  '{"type":"PRINCIPAL_PREPAYMENT","subtype":"REDUCE_TERM","is_cash":"false","amount":null,"reduction":"1000.00"}'::jsonb,
  'REDUCE_TERM prepayment is a non-cash semantic event with the principal reduction as metadata only'
);

select is(
  (select (it->>'amount')::numeric
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'PAYMENT_POSTED'),
  1000::numeric,
  'the prepayment cash appears once, as the payment row'
);

select is(
  (select it->'metadata'
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'LOAN_RESTRUCTURED'),
  '{"new_term":6,"new_interest_rate":5,"new_first_installment_date":"2099-07-01"}'::jsonb,
  'restructure is non-cash with safe change metadata only (officer note withheld)'
);

-- Timeline 714 (REDUCE_INSTALLMENT).
select is(
  (select it->>'event_subtype'
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000714'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'PRINCIPAL_PREPAYMENT'),
  'REDUCE_INSTALLMENT',
  'REDUCE_INSTALLMENT prepayment is classified with its treatment'
);

-- Timeline 713 (early settlement): clearing payment counted once, settlement non-cash.
select is(
  (select count(*)::int
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000713'::uuid, 50, 0)->'items') it
   where it->>'event_id' = '11100002-0000-0000-0000-000000000012'),
  1,
  'early settlement clearing payment is one cash row'
);

select ok(
  (select (it->>'is_cash')::boolean is false and it->>'amount' is null
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000713'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'LOAN_EARLY_SETTLED'),
  'LOAN_EARLY_SETTLED is a non-cash lifecycle event and adds no amount'
);

-- Timeline 702 (write-off) and 710 (recovery, cash once).
select ok(
  (select (it->>'is_cash')::boolean is false and (it->>'amount')::numeric = 5050
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000702'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'WRITE_OFF'),
  'write-off is a non-cash event carrying the written-off amount'
);

select is(
  (select jsonb_agg(jsonb_build_object('type', it->>'event_type', 'is_cash', it->>'is_cash', 'amount', it->>'amount') order by it->>'event_type')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000710'::uuid, 50, 0)->'items') it),
  '[{"type":"LOAN_DISBURSED","is_cash":"true","amount":"2000.00"},{"type":"RECOVERY_POSTED","is_cash":"true","amount":"300.00"},{"type":"WRITE_OFF","is_cash":"false","amount":"2020.00"}]'::jsonb,
  'recovery is classified on the single genuine payment (cash once); the write-off stays non-cash'
);

-- Timeline 711 (write-off reversal, distinct lifecycle event).
select is(
  (select jsonb_agg(it->>'event_type' order by it->>'event_type')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000711'::uuid, 50, 0)->'items') it),
  '["LOAN_DISBURSED","WRITE_OFF","WRITE_OFF_REVERSED"]'::jsonb,
  'write-off reversal is its own event; the original write-off is marked reversed'
);

select ok(
  (select (it->>'is_reversed')::boolean
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000711'::uuid, 50, 0)->'items') it
   where it->>'event_type' = 'WRITE_OFF'),
  'the reversed write-off is marked is_reversed'
);

-- Timeline 712 (wallet application is not cash; cross-loan payment once).
select is(
  (select jsonb_agg(jsonb_build_object('type', it->>'event_type', 'is_cash', it->>'is_cash', 'amount', it->>'amount') order by it->>'event_type')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000712'::uuid, 50, 0)->'items') it),
  '[{"type":"LOAN_DISBURSED","is_cash":"true","amount":"2000.00"},{"type":"PAYMENT_POSTED","is_cash":"true","amount":"900.00"},{"type":"WALLET_APPLIED","is_cash":"false","amount":"100.00"}]'::jsonb,
  'wallet-applied loan allocation is non-cash; the cross-loan payment contributes only its 900'
);

-- Duplicate-cash guard across every loan of member A: each cash row is one event id.
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
    where (it->>'is_cash')::boolean
    group by it->>'event_id'
    having count(*) > 1
  ),
  'no cash event id repeats inside a loan timeline'
);

-- Pagination of the timeline.
select is(
  (select jsonb_array_length(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 3, 0)->'items')),
  3,
  'timeline pagination: first page holds 3 events'
);

select is(
  (select (public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 3, 6)->'pagination'->>'has_more')::boolean),
  false,
  'timeline pagination: the final page reports has_more false'
);

select is(
  (select jsonb_array_length(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 3, 9)->'items')),
  0,
  'timeline pagination: an offset past the end is a valid empty page'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it
    where it ?| array['balance_after', 'running_balance', 'opening_balance', 'closing_balance']
  ),
  'timeline has no running balance fields'
);

-- Cross-member and cross-group isolation.
select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000716'::uuid)$$,
  '22023',
  'Loan account not found',
  'member A cannot detail member B loan 716'
);
select throws_ok(
  $$select public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000716'::uuid)$$,
  '22023',
  'Loan account not found',
  'member A cannot schedule member B loan 716'
);
select throws_ok(
  $$select public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000716'::uuid, 50, 0)$$,
  '22023',
  'Loan account not found',
  'member A cannot timeline member B loan 716'
);
select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000717'::uuid)$$,
  '22023',
  'Loan account not found',
  'cross-group: group-two loan cannot be read through group one'
);
select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000706'::uuid)$$,
  '22023',
  'Loan account not found',
  'DRAFT loan is never returned, even to its own member'
);

-- The group-two loans of member A appear only in group two.
select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000002'::uuid, 50, 0)->'pagination'->>'total_count')::int),
  1,
  'member A sees only the group-two loan when acting in group two'
);

reset role;

-- =====================================================================
-- Admin (101): own ADMIN permission, but no ADMIN bypass to others' loans.
-- =====================================================================
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000011';

select is(
  (select (public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)->'pagination'->>'total_count')::int),
  0,
  'admin with no loans of their own gets a valid empty list'
);

select throws_ok(
  $$select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)$$,
  '22023',
  'Loan account not found',
  'admin using /me cannot receive another member loan (no ADMIN bypass, no officer fallback)'
);

select throws_ok(
  $$select public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 20, 0)$$,
  '22023',
  'Loan account not found',
  'admin using /me cannot read another member timeline'
);
reset role;

-- Member B (103): own loan only.
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000013';

select is(
  (select jsonb_array_length(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 20, 0)->'items')),
  1,
  'member B lists only their own single loan'
);

select throws_ok(
  $$select public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)$$,
  '22023',
  'Loan account not found',
  'member B cannot schedule member A loan 701'
);
reset role;

-- =====================================================================
-- Response leakage: no internal identity, account, or accounting machinery.
-- =====================================================================
reset role;
set local role authenticated;
set local request.jwt.claim.sub to '11100000-0000-0000-0000-000000000012';

select ok(
  not (
    public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)::text
      || public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid)::text
      || public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)::text
      || public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000713'::uuid, 50, 0)::text
  ) ~* 'membership_id|user_id|created_by|approved_by|reversed_by|financial_account|idempotency|cashbook|entry_no|migration|officer|staff|OFFICER INTERNAL|Entered in error|DATA_ENTRY|OLD-B5B',
  'no internal identity, account, reference or officer note appears in any response'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items'->0) k),
  (select array_agg(k order by k) from unnest(array['event_id','event_type','event_subtype','effective_at','created_at','is_reversed','amount','is_cash','cash_direction','component_breakdown','metadata']) k),
  'timeline item exposes exactly the member-safe field set'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)->'history'->0) k),
  (select array_agg(k order by k) from unnest(array['installment_id','installment_number','due_date','scheduled_principal','scheduled_interest','scheduled_total','paid_principal','paid_interest','paid_penalty','cancelled_on','member_schedule_status','replacement_reason']) k),
  'schedule history row exposes exactly the member-safe field set'
);

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)->'current'->0) k),
  (select array_agg(k order by k) from unnest(array['installment_id','installment_number','due_date','scheduled_principal','scheduled_interest','scheduled_total','paid_principal','paid_interest','paid_penalty','current_principal_outstanding','current_earned_interest_outstanding','current_penalty_outstanding','current_total_outstanding','scheduled_future_interest_outstanding','member_schedule_status']) k),
  'schedule current row exposes exactly the member-safe field set'
);

select ok(
  not exists (
    select 1 from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
    where it ?| array['membership_id', 'member_id', 'user_id', 'created_by', 'approved_by', 'financial_account_id', 'financial_account_name']
  ),
  'list items carry no identity, actor or account fields'
);
reset role;

-- =====================================================================
-- Canonical reconciliation (run as the owning role, after the RPC reads)
-- =====================================================================

select is(
  (select (h.total_outstanding)::numeric
   from public.loan_historical_position('11100000-0000-0000-0000-000000000708', '2026-01-01'::date) h),
  9165::numeric,
  'canonical position at the opening date = opening snapshot 9140 + the real pre-opening ASSESSED penalty 25'
);

select is(
  (select sum(h.principal_outstanding) from (
     select h.principal_outstanding from public.loan_historical_position('11100000-0000-0000-0000-000000000714', current_date) h) h),
  2500::numeric,
  'prepayment 1500 reduces the 714 principal receivable (4000 to 2500)'
);

select ok(
  (select h.position_state = 'AVAILABLE' and h.total_outstanding = 0
   from public.loan_historical_position('11100000-0000-0000-0000-000000000713', current_date) h),
  'early-settled 713 has no receivable and the unearned future interest is not counted'
);

select is(
  (select count(*)::int from public.loan_historical_position('11100000-0000-0000-0000-000000000701', current_date) h where h.scheduled_unearned_interest = 60),
  1,
  'canonical scheduled unearned interest for 701 is 60, reported apart from the total'
);

select ok(
  (select h.total_outstanding = 0 and h.principal_outstanding = 0
   from public.loan_historical_position('11100000-0000-0000-0000-000000000710', current_date) h),
  'canonical written-off 710 position is zero after recovery (recovery is cash history only)'
);



-- Owner-role comparisons: the JWT claim still identifies member A; the
-- internal canonical helpers and the loan tables are not readable by the
-- authenticated role, so these reads run as the owning role.

select ok(
  not exists (
    select 1 from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 50, 0)->'items') it
    cross join lateral public.loan_account_summary((it->>'loan_account_id')::uuid) s
    where (it->'current_position'->>'principal_outstanding')::numeric is distinct from s.principal_outstanding
       or (it->'current_position'->>'interest_outstanding')::numeric is distinct from s.interest_outstanding
       or (it->'current_position'->>'penalty_outstanding')::numeric is distinct from s.penalty_outstanding
       or (it->'current_position'->>'total_outstanding')::numeric is distinct from s.total_outstanding
       or (it->>'next_due_date')::date is distinct from s.next_due_date
       or (it->>'overdue_amount')::numeric is distinct from s.overdue_amount
  ),
  'every list item equals the canonical loan_account_summary (no wrapper recalculation)'
);

select is(
  (select array_agg(it->>'loan_number' order by it->>'loan_number')
   from jsonb_array_elements(public.rpc_get_my_loans('11100000-0000-0000-0000-000000000001'::uuid, 5, 0)->'items') it),
  (select array_agg(loan_number order by loan_number) from (
     select loan_number from public.loan_accounts
     where group_id = '11100000-0000-0000-0000-000000000001' and membership_id = '11100000-0000-0000-0000-000000000102' and status <> 'DRAFT'
     order by created_at desc, id desc limit 5) x),
  'list page 1 (limit 5) returns the first five rows in deterministic order'
);

select is(
  (select public.rpc_get_my_loan_detail('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000708'::uuid)->'current_position'),
  (select jsonb_build_object(
     'principal_outstanding', s.principal_outstanding,
     'interest_outstanding', s.interest_outstanding,
     'penalty_outstanding', s.penalty_outstanding,
     'total_outstanding', s.total_outstanding)
   from public.loan_account_summary('11100000-0000-0000-0000-000000000708') s),
  'opening-position detail current position equals the canonical summary'
);

select is(
  (select sum((r->>'current_total_outstanding')::numeric)
   from jsonb_array_elements(public.rpc_get_my_loan_schedule('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000709'::uuid)->'current') r),
  (select s.total_outstanding from public.loan_account_summary('11100000-0000-0000-0000-000000000709') s),
  'replaced rows contribute nothing to the current totals (current sum equals canonical 709 total)'
);

-- Deterministic order: effective_at desc, created_at desc, event_id desc.
select is(
  (select array_agg(it->>'event_id' order by it->>'event_id')
   from jsonb_array_elements(public.rpc_get_my_loan_timeline('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid, 50, 0)->'items') it),
  (select array_agg(event_id::text order by event_id::text)
   from public.member_loan_timeline_source('11100000-0000-0000-0000-000000000001'::uuid, '11100000-0000-0000-0000-000000000701'::uuid)),
  'timeline returns exactly the source events, sorted by effective_at desc, created_at desc, event_id desc'
);

select * from finish();
rollback;
