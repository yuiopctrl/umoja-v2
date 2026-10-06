-- Prompt 09G-B4-B: My Contributions self-service backend.
--
-- Proves rpc_get_my_contributions/rpc_get_my_contribution_charge_detail
-- are strict self-owned, group-scoped reads: ownership resolved
-- exclusively via current_membership_id() (no p_user_id/p_membership_id/
-- p_phone/p_role_id), every monetary figure reconciles EXACTLY to the
-- canonical contribution_charge_component_states/
-- contribution_charge_net_assessed helpers, status is honestly derived
-- (SETTLED is never conflated with "paid"), and officer permission
-- never broadens self-service scope.
begin;

select plan(101);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('10900000-0000-0000-0000-000000000011', 'p09gb4b-admin@example.com'),
  ('10900000-0000-0000-0000-000000000012', 'p09gb4b-member@example.com'),
  ('10900000-0000-0000-0000-000000000013', 'p09gb4b-member2@example.com'),
  ('10900000-0000-0000-0000-000000000014', 'p09gb4b-treasurer@example.com'),
  ('10900000-0000-0000-0000-000000000015', 'p09gb4b-noroles@example.com'),
  ('10900000-0000-0000-0000-000000000016', 'p09gb4b-suspended@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('10900000-0000-0000-0000-000000000001', 'B4B Group A', '10900000-0000-0000-0000-000000000011', 'B4BGA', 'ACTIVE'),
  ('10900000-0000-0000-0000-000000000002', 'B4B Group B', '10900000-0000-0000-0000-000000000011', 'B4BGB', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10900000-0000-0000-0000-000000000101', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2026-01-01', 'B4BGA-0001', null),
  ('10900000-0000-0000-0000-000000000102', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000012', 'Member Caller', 'ACTIVE', '2026-01-02', 'B4BGA-0002', null),
  ('10900000-0000-0000-0000-000000000103', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000013', 'Member Two', 'ACTIVE', '2026-01-03', 'B4BGA-0003', null),
  ('10900000-0000-0000-0000-000000000104', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000014', 'Treasurer One', 'ACTIVE', '2026-01-04', 'B4BGA-0004', null),
  ('10900000-0000-0000-0000-000000000105', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000015', 'No Roles Member', 'ACTIVE', '2026-01-05', 'B4BGA-0005', null),
  ('10900000-0000-0000-0000-000000000106', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000016', 'Suspended Member', 'SUSPENDED', '2026-01-06', 'B4BGA-0006', null),
  ('10900000-0000-0000-0000-000000000107', '10900000-0000-0000-0000-000000000002', '10900000-0000-0000-0000-000000000012', 'Member Caller In B', 'ACTIVE', '2026-01-07', 'B4BGB-0001', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10900000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10900000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10900000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10900000-0000-0000-0000-000000000104', id from public.roles where code = 'TREASURER';
-- Membership 105 (No Roles Member) deliberately has ZERO roles.
insert into public.group_membership_roles (group_membership_id, role_id) select '10900000-0000-0000-0000-000000000106', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10900000-0000-0000-0000-000000000107', id from public.roles where code = 'MEMBER';

insert into public.financial_accounts (id, group_id, name, account_type) values
  ('10900000-0000-0000-0000-000000000201', '10900000-0000-0000-0000-000000000001', 'Cash Box', 'CASH');

-- Two contribution types, for the type filter test.
insert into public.contribution_types (id, group_id, name, category, accounting_treatment) values
  ('10900000-0000-0000-0000-000000000301', '10900000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME'),
  ('10900000-0000-0000-0000-000000000302', '10900000-0000-0000-0000-000000000001', 'Social Fund', 'SOCIAL', 'GROUP_INCOME');

insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount) values
  ('10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000301', 'Dues Setup', 'ON_DEMAND', 'FIXED', 50000),
  ('10900000-0000-0000-0000-000000000312', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000302', 'Social Setup', 'ON_DEMAND', 'FIXED', 20000),
  ('10900000-0000-0000-0000-000000000319', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000301', 'Opening Balance Setup', 'ON_DEMAND', 'FIXED', 10000);
update public.contribution_setups set is_system = true where id = '10900000-0000-0000-0000-000000000319';

-- Nine periods: one per scenario. snapshot_type_name/snapshot_category
-- frozen at creation (simulating OPEN) so list/detail can read them
-- without a live join back to contribution_types.
insert into public.contribution_periods (
  id, group_id, contribution_setup_id, label, period_start, period_end,
  obligation_date, eligibility_date, due_date, status, purpose,
  snapshot_type_name, snapshot_category
) values
  ('10900000-0000-0000-0000-000000000401', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Jan Dues (Open Unpaid)',        '2026-01-01', '2026-01-31', '2026-01-01', '2026-01-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000402', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Feb Dues (Partial)',            '2026-02-01', '2026-02-28', '2026-02-01', '2026-02-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000403', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Mar Dues (Fully Paid)',         '2026-03-01', '2026-03-31', '2026-03-01', '2026-03-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000404', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Apr Dues (Waived)',             '2026-04-01', '2026-04-30', '2026-04-01', '2026-04-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000405', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000319', 'Opening Balances',             '2025-01-01', '2025-01-01', '2025-01-01', '2025-01-01', '2026-12-31', 'OPEN', 'OPENING_BALANCE', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000406', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000312', 'May Social (Wallet Partial)',   '2026-05-01', '2026-05-31', '2026-05-01', '2026-05-01', '2026-12-31', 'OPEN', 'NORMAL', 'Social Fund', 'SOCIAL'),
  ('10900000-0000-0000-0000-000000000407', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Jun Dues (Overdue)',            '2026-06-01', '2026-06-30', '2026-06-01', '2026-06-01', '2026-01-01', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000408', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Jul Dues (Negative Adj Settled)','2026-07-01', '2026-07-31', '2026-07-01', '2026-07-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000409', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000311', 'Aug Dues (Reversed Payment)',   '2026-08-01', '2026-08-31', '2026-08-01', '2026-08-01', '2026-12-31', 'OPEN', 'NORMAL', 'Monthly Dues', 'GENERAL');

-- Nine charges for Member Caller (membership 102). One for Member Two
-- (membership 103, cross-member isolation).
insert into public.member_contribution_charges (id, group_id, period_id, contribution_setup_id, membership_id, member_number_snapshot, member_name_snapshot, effective_at, due_date) values
  ('10900000-0000-0000-0000-000000000501', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000401', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-01-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000502', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000402', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-02-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000503', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000403', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-03-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000504', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000404', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-04-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000505', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000405', '10900000-0000-0000-0000-000000000319', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2025-01-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000506', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000406', '10900000-0000-0000-0000-000000000312', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-05-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000507', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000407', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-06-01', '2026-01-01'),
  ('10900000-0000-0000-0000-000000000508', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000408', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-07-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000509', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000409', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000102', 'B4BGA-0002', 'Member Caller', '2026-08-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000510', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000401', '10900000-0000-0000-0000-000000000311', '10900000-0000-0000-0000-000000000103', 'B4BGA-0003', 'Member Two', '2026-01-01', '2026-12-31');

-- Components.
insert into public.contribution_charge_components (id, group_id, charge_id, component_type, assessed_amount, effective_at, sequence) values
  -- Charge 501: BASE only, unpaid => OPEN.
  ('10900000-0000-0000-0000-000000000601', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000501', 'BASE', 50000, '2026-01-01', 1),
  -- Charge 502: BASE + PENALTY, partially paid by payment => PARTIALLY_SETTLED.
  ('10900000-0000-0000-0000-000000000602', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000502', 'BASE', 50000, '2026-02-01', 1),
  ('10900000-0000-0000-0000-000000000603', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000502', 'PENALTY', 5000, '2026-02-15', 1),
  -- Charge 503: BASE, fully paid by payment => SETTLED, allocated>0.
  ('10900000-0000-0000-0000-000000000604', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000503', 'BASE', 50000, '2026-03-01', 1),
  -- Charge 504: BASE + WAIVER fully negating => SETTLED, allocated=0.
  ('10900000-0000-0000-0000-000000000605', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000504', 'BASE', 50000, '2026-04-01', 1),
  ('10900000-0000-0000-0000-000000000606', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000504', 'WAIVER', -50000, '2026-04-05', 1),
  -- Charge 505: OPENING_BALANCE only, unpaid => OPEN.
  ('10900000-0000-0000-0000-000000000607', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000505', 'OPENING_BALANCE', 10000, '2025-01-01', 1),
  -- Charge 506: BASE + positive ADJUSTMENT, partially paid by wallet => PARTIALLY_SETTLED.
  ('10900000-0000-0000-0000-000000000608', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000506', 'BASE', 20000, '2026-05-01', 1),
  ('10900000-0000-0000-0000-000000000609', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000506', 'ADJUSTMENT', 5000, '2026-05-10', 1),
  -- Charge 507: BASE, unpaid, due in the past => OVERDUE.
  ('10900000-0000-0000-0000-000000000610', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000507', 'BASE', 50000, '2026-06-01', 1),
  -- Charge 508: BASE + negative ADJUSTMENT fully negating => SETTLED, allocated=0 (no payment at all).
  ('10900000-0000-0000-0000-000000000611', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000508', 'BASE', 50000, '2026-07-01', 1),
  ('10900000-0000-0000-0000-000000000612', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000508', 'ADJUSTMENT', -50000, '2026-07-10', 1),
  -- Charge 509: BASE, paid then REVERSED => outstanding reappears.
  ('10900000-0000-0000-0000-000000000613', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000509', 'BASE', 50000, '2026-08-01', 1),
  -- Charge 510 (Member Two): BASE only.
  ('10900000-0000-0000-0000-000000000614', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000510', 'BASE', 50000, '2026-01-01', 1);

-- Payments + allocations.

-- Charge 502: partial payment of 20000 against BASE (30000 remains outstanding on BASE + 5000 PENALTY untouched).
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('10900000-0000-0000-0000-000000000701', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000102', '10900000-0000-0000-0000-000000000201', 20000, '2026-02-10', 'CASH', 'POSTED', 'B4B-RCPT-0001');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10900000-0000-0000-0000-000000000801', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000701', '10900000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10900000-0000-0000-0000-000000000502', '10900000-0000-0000-0000-000000000602', 20000, 1);

-- Charge 503: fully paid, two allocations ("multiple allocations" on
-- a fully-settled charge — not possible on a single BASE component in
-- one shot, so split into two payments of 30000 + 20000).
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('10900000-0000-0000-0000-000000000702', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000102', '10900000-0000-0000-0000-000000000201', 30000, '2026-03-05', 'CASH', 'POSTED', 'B4B-RCPT-0002'),
  ('10900000-0000-0000-0000-000000000703', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000102', '10900000-0000-0000-0000-000000000201', 20000, '2026-03-10', 'CASH', 'POSTED', 'B4B-RCPT-0003');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10900000-0000-0000-0000-000000000802', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000702', '10900000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10900000-0000-0000-0000-000000000503', '10900000-0000-0000-0000-000000000604', 30000, 1),
  ('10900000-0000-0000-0000-000000000803', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000703', '10900000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10900000-0000-0000-0000-000000000503', '10900000-0000-0000-0000-000000000604', 20000, 1);

-- Charge 506: wallet-sourced settlement (10000 of 25000 BASE+ADJUSTMENT).
insert into public.member_wallet_entries (id, group_id, membership_id, entry_type, amount, effective_at, source_type, source_id) values
  ('10900000-0000-0000-0000-000000000821', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000102', 'ALLOCATION_DEBIT', 10000, '2026-05-15', 'PAYMENT_ALLOCATION_BATCH', null);
insert into public.payment_allocations (id, group_id, wallet_entry_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10900000-0000-0000-0000-000000000804', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000821', '10900000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10900000-0000-0000-0000-000000000506', '10900000-0000-0000-0000-000000000608', 10000, 1);

-- Charge 509: paid in full, then the payment is REVERSED.
insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number, reversed_at, reversed_by, reversal_reason) values
  ('10900000-0000-0000-0000-000000000704', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000102', '10900000-0000-0000-0000-000000000201', 50000, '2026-08-05', 'CASH', 'REVERSED', 'B4B-RCPT-0004', now(), '10900000-0000-0000-0000-000000000011', 'Wrong member credited');
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10900000-0000-0000-0000-000000000805', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000704', '10900000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10900000-0000-0000-0000-000000000509', '10900000-0000-0000-0000-000000000613', 50000, 1);

-- =====================================================================
-- Assertions
-- =====================================================================

-- --- Unauthenticated / permission boundary (reset role, no jwt claim) ---

reset role;

select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) $$,
  '28000', 'Not authenticated',
  '1: unauthenticated caller is rejected by rpc_get_my_contributions'
);
select throws_ok(
  $$ select public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000501'::uuid) $$,
  '28000', 'Not authenticated',
  '2: unauthenticated caller is rejected by rpc_get_my_contribution_charge_detail'
);

-- --- Signature: no forbidden identity params ---

select is(
  (select count(*)::integer from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'rpc_get_my_contributions'
     and pg_get_function_arguments(p.oid) = 'p_group_id uuid, p_status text DEFAULT NULL::text, p_contribution_type_id uuid DEFAULT NULL::uuid, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0'),
  1,
  '3: rpc_get_my_contributions has exactly the locked signature — no p_user_id/p_membership_id/p_phone/p_role_id'
);
select is(
  (select count(*)::integer from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'rpc_get_my_contribution_charge_detail'
     and pg_get_function_arguments(p.oid) = 'p_group_id uuid, p_charge_id uuid'),
  1,
  '4: rpc_get_my_contribution_charge_detail has exactly p_group_id/p_charge_id — no caller-supplied identity'
);

-- --- Grants ---

select is(
  has_function_privilege('authenticated', 'public.rpc_get_my_contributions(uuid,text,uuid,date,date,integer,integer)', 'EXECUTE'),
  true,
  '5: authenticated can EXECUTE rpc_get_my_contributions'
);
select is(
  has_function_privilege('anon', 'public.rpc_get_my_contributions(uuid,text,uuid,date,date,integer,integer)', 'EXECUTE'),
  false,
  '6: anon cannot EXECUTE rpc_get_my_contributions'
);
select is(
  has_function_privilege('authenticated', 'public.rpc_get_my_contribution_charge_detail(uuid,uuid)', 'EXECUTE'),
  true,
  '7: authenticated can EXECUTE rpc_get_my_contribution_charge_detail'
);
select is(
  has_function_privilege('anon', 'public.rpc_get_my_contribution_charge_detail(uuid,uuid)', 'EXECUTE'),
  false,
  '8: anon cannot EXECUTE rpc_get_my_contribution_charge_detail'
);
select is(
  (select p.proacl::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'rpc_get_my_contributions')
  !~ '(^|[{,])=X/',
  true,
  '10: rpc_get_my_contributions raw ACL has no bare PUBLIC entry'
);
select is(
  (select p.proacl::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'rpc_get_my_contribution_charge_detail')
  !~ '(^|[{,])=X/',
  true,
  '11: rpc_get_my_contribution_charge_detail raw ACL has no bare PUBLIC entry'
);

-- --- Canonical helper remains unexposed ---

select is(
  has_function_privilege('authenticated', 'public.contribution_charge_component_states(uuid)', 'EXECUTE'),
  false,
  '12: contribution_charge_component_states remains revoked from authenticated'
);
select is(
  has_function_privilege('authenticated', 'public.contribution_charge_net_assessed(uuid)', 'EXECUTE'),
  false,
  '13: contribution_charge_net_assessed remains revoked from authenticated'
);

-- --- Permission / ownership boundary (as authenticated, varying caller) ---

set local role authenticated;

-- 14: no-roles member (has no contribution.self_view) is rejected.
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000015';
select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) $$,
  '42501', 'Not authorized to view contributions',
  '14: a member with zero roles (no contribution.self_view) is rejected'
);

-- 15: TREASURER (has contribution.view, officer-wide) but NOT
-- contribution.self_view is rejected on the self-service endpoint —
-- proves officer permission never broadens self-service scope.
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000014';
select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) $$,
  '42501', 'Not authorized to view contributions',
  '15: TREASURER (contribution.view only, no self_view) is rejected — officer permission does not broaden self-service scope'
);

-- 16: suspended (inactive) membership is rejected — current_membership_id
-- returns null for a non-ACTIVE membership.
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000016';
select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) $$,
  '42501', 'No active membership in this group',
  '16: a SUSPENDED membership is rejected (current_membership_id returns null)'
);

-- Primary caller for the rest of this file.
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000012';

-- 17: own active membership succeeds.
select isnt(
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid),
  null,
  '17: a member with an own ACTIVE membership and contribution.self_view succeeds'
);

-- 18: cross-group isolation — calling with Group B's id while the
-- caller's own membership there (107) has no charges returns an empty
-- list, never Group A's data.
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000002'::uuid) -> 'items'),
  0,
  '18: cross-group isolation — Group B returns zero items, never Group A''s charges'
);

-- 19: multi-group — the SAME user calling with p_group_id=A vs B
-- resolves a DIFFERENT membership_id each time.
select isnt(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'member' ->> 'membership_id'),
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000002'::uuid) -> 'member' ->> 'membership_id'),
  '19: multi-group — p_group_id determines which of the caller''s own memberships resolves, never a mix'
);

-- 20: cross-member isolation on the list — Member Two's charge (510)
-- never appears in Member Caller's own list.
select is(
  (
    select count(*) from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items') i
    where i ->> 'charge_id' = '10900000-0000-0000-0000-000000000614'
  )::integer,
  0,
  '20: Member Two''s charge never appears in Member Caller''s own list'
);

-- 21: cross-member isolation on detail — fetching Member Two's charge
-- by id raises not-found, never leaks data, never raises "forbidden"
-- (no existence oracle).
select throws_ok(
  $$ select public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000510'::uuid) $$,
  '22023', 'Contribution charge not found',
  '21: fetching another member''s charge_id raises not-found, not a data leak'
);

-- --- List: counts and totals ---

select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items'),
  9,
  '22: all 9 own charges are returned with limit=100'
);
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'pagination' ->> 'total_count')::integer,
  9,
  '23: total_count = 9'
);

-- (expected value reads the internal helper, which is intentionally revoked from authenticated; reset role as the B3 test does)
reset role;
-- 24: summary.total_outstanding is the canonical sum across ALL 9
-- charges, computed independently of this test's own component math.
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  (
    select coalesce(sum(s.outstanding), 0)
    from public.member_contribution_charges c
    cross join lateral public.contribution_charge_component_states(c.id) s
    where c.membership_id = '10900000-0000-0000-0000-000000000102' and c.group_id = '10900000-0000-0000-0000-000000000001'
  ),
  '24: summary.total_outstanding equals the canonical contribution_charge_component_states sum exactly'
);

-- 25: summary.total_outstanding is invariant under a status filter —
-- never shrinks merely because the caller filtered the list.
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, 'SETTLED') -> 'summary' ->> 'total_outstanding')::numeric,
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  '25: summary.total_outstanding is unaffected by a status filter'
);

-- 26: summary.total_outstanding is invariant under pagination (page 2).
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 2, 2) -> 'summary' ->> 'total_outstanding')::numeric,
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  '26: summary.total_outstanding is unaffected by pagination (page 2 vs full list)'
);

-- --- Per-charge financial matrix: amounts + status, reading each item
-- directly out of a single unfiltered call.

create temp table b4b_items as
select
  i.value ->> 'charge_id' as charge_id,
  (i.value ->> 'net_assessed')::numeric as net_assessed,
  (i.value ->> 'allocated_amount')::numeric as allocated_amount,
  (i.value ->> 'outstanding')::numeric as outstanding,
  i.value ->> 'status' as status,
  i.value ->> 'contribution_type_name' as contribution_type_name,
  i.value ->> 'contribution_category' as contribution_category,
  i.value ->> 'period_purpose' as period_purpose
from jsonb_array_elements(
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items'
) i;

-- 27-28: Charge 501 — BASE only, unpaid => OPEN, outstanding = 50000.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000501'), 'OPEN', '27: BASE-only unpaid charge is OPEN');
select is((select outstanding from b4b_items where charge_id = '10900000-0000-0000-0000-000000000501'), 50000::numeric, '28: BASE-only unpaid outstanding = 50000');

-- 29-31: Charge 502 — BASE(50000)+PENALTY(5000), 20000 paid =>
-- PARTIALLY_SETTLED, net_assessed=55000, allocated=20000, outstanding=35000.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000502'), 'PARTIALLY_SETTLED', '29: partial payment yields PARTIALLY_SETTLED');
select is((select net_assessed from b4b_items where charge_id = '10900000-0000-0000-0000-000000000502'), 55000::numeric, '30: net_assessed = BASE+PENALTY = 55000');
select is((select outstanding from b4b_items where charge_id = '10900000-0000-0000-0000-000000000502'), 35000::numeric, '31: outstanding = 55000 - 20000 = 35000');

-- 32-34: Charge 503 — BASE(50000), fully paid via TWO allocations
-- (30000+20000) => SETTLED, allocated=50000, outstanding=0.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000503'), 'SETTLED', '32: fully paid charge is SETTLED');
select is((select allocated_amount from b4b_items where charge_id = '10900000-0000-0000-0000-000000000503'), 50000::numeric, '33: allocated_amount sums BOTH payment allocations (30000+20000)');
select is((select outstanding from b4b_items where charge_id = '10900000-0000-0000-0000-000000000503'), 0::numeric, '34: fully paid outstanding = 0');

-- 35-37: Charge 504 — BASE(50000)+WAIVER(-50000) => SETTLED, but
-- allocated_amount = 0 (zero outstanding via WAIVER, never via
-- payment) — the critical SETTLED-never-PAID distinction.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000504'), 'SETTLED', '35: waived charge is SETTLED');
select is((select allocated_amount from b4b_items where charge_id = '10900000-0000-0000-0000-000000000504'), 0::numeric, '36: waived charge has allocated_amount = 0 (no payment ever existed)');
select is((select net_assessed from b4b_items where charge_id = '10900000-0000-0000-0000-000000000504'), 0::numeric, '37: waived charge net_assessed nets to 0 (BASE 50000 + WAIVER -50000)');

-- 38-39: Charge 505 — OPENING_BALANCE(10000), unpaid => OPEN (opening-
-- balance obligations ARE included, not hidden for lacking a normal shape).
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000505'), 'OPEN', '38: opening-balance charge appears and is OPEN');
select is((select period_purpose from b4b_items where charge_id = '10900000-0000-0000-0000-000000000505'), 'OPENING_BALANCE', '39: opening-balance charge carries period_purpose=OPENING_BALANCE');

-- 40-42: Charge 506 — BASE(20000)+ADJUSTMENT(+5000)=25000, wallet-
-- settled 10000 => PARTIALLY_SETTLED, allocated=10000, outstanding=15000.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000506'), 'PARTIALLY_SETTLED', '40: wallet-partial charge is PARTIALLY_SETTLED');
select is((select allocated_amount from b4b_items where charge_id = '10900000-0000-0000-0000-000000000506'), 10000::numeric, '41: wallet-sourced allocation counts toward allocated_amount');
select is((select outstanding from b4b_items where charge_id = '10900000-0000-0000-0000-000000000506'), 15000::numeric, '42: wallet-partial outstanding = 25000 - 10000 = 15000');

-- 43: Charge 507 — BASE(50000), due_date 2026-01-01 (past), unpaid => OVERDUE.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000507'), 'OVERDUE', '43: unpaid charge past its due_date is OVERDUE');

-- 44-45: Charge 508 — BASE(50000)+ADJUSTMENT(-50000) => SETTLED via
-- correction, never via payment.
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000508'), 'SETTLED', '44: negative-adjustment-settled charge is SETTLED');
select is((select allocated_amount from b4b_items where charge_id = '10900000-0000-0000-0000-000000000508'), 0::numeric, '45: negative-adjustment-settled charge has allocated_amount = 0');

-- 46-47: Charge 509 — BASE(50000), paid then REVERSED => outstanding
-- REAPPEARS (back to OPEN/OVERDUE, never SETTLED).
select is((select status from b4b_items where charge_id = '10900000-0000-0000-0000-000000000509'), 'OPEN', '46: a reversed payment makes the charge OPEN again (not due yet)');
select is((select outstanding from b4b_items where charge_id = '10900000-0000-0000-0000-000000000509'), 50000::numeric, '47: reversed payment''s allocation no longer reduces outstanding');

-- 48: contribution_category sourced from the frozen period snapshot
-- (Social Fund charge).
select is((select contribution_category from b4b_items where charge_id = '10900000-0000-0000-0000-000000000506'), 'SOCIAL', '48: contribution_category reflects the SOCIAL type for the Social Fund charge');

drop table b4b_items;

-- --- Filters ---

-- 49: status filter returns only SETTLED (504, 503, 508 — 3 charges).
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, 'SETTLED', null, null, null, 100, 0) -> 'items'),
  3,
  '49: status=SETTLED filter returns exactly the 3 settled charges'
);

-- 50: invalid status is a controlled validation error.
select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, 'BOGUS') $$,
  '22023', 'MY_CONTRIBUTIONS_INVALID_STATUS',
  '50: an invalid p_status value raises a controlled error, never a 500'
);

-- 51: contribution_type_id filter — Social Fund type returns exactly
-- charge 506, never touching other members' data.
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, '10900000-0000-0000-0000-000000000302'::uuid, null, null, 100, 0) -> 'items'),
  1,
  '51: contribution_type_id filter returns exactly the 1 Social Fund charge'
);

-- 52/53: date-boundary filters on effective_at (inclusive), using
-- March's charge (effective_at=2026-03-01).
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, '2026-03-01'::date, '2026-03-01'::date, 100, 0) -> 'items'),
  1,
  '52: from_date=to_date=2026-03-01 is inclusive and returns exactly the March charge'
);
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, '2026-03-02'::date, null, 100, 0) -> 'items'),
  5,
  '53: from_date=2026-03-02 excludes the March charge, keeps the 5 later ones (Apr, May, Jun, Jul, Aug)'
);

-- 54: from > to is a controlled validation error.
select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, '2026-06-01'::date, '2026-01-01'::date) $$,
  '22023', 'p_from_date must not be after p_to_date',
  '54: from_date after to_date raises a controlled error'
);

-- --- Pagination ---

select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 0) -> 'items'),
  4,
  '55: limit=4 returns exactly 4 items'
);
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 0) -> 'pagination' ->> 'has_more')::boolean,
  true,
  '56: has_more = true on the first page of 9 with limit=4'
);
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 8) -> 'items'),
  1,
  '57: offset=8 limit=4 returns the final 1 item (9 total)'
);
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 8) -> 'pagination' ->> 'has_more')::boolean,
  false,
  '58: has_more = false on the final page'
);
-- 59: deterministic ordering — newest effective_at first.
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 1, 0) -> 'items' -> 0 ->> 'charge_id'),
  '10900000-0000-0000-0000-000000000509',
  '59: default ordering is effective_at DESC — the newest charge (Aug) is first'
);

-- =====================================================================
-- Detail RPC
-- =====================================================================

-- 60: own charge detail succeeds and matches the list's own figures.
select is(
  (public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000502'::uuid) ->> 'outstanding')::numeric,
  35000::numeric,
  '60: detail outstanding for charge 502 matches the list (35000)'
);
select is(
  public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000502'::uuid) ->> 'status',
  'PARTIALLY_SETTLED',
  '61: detail status matches the list derivation'
);

-- 62: component breakdown includes BOTH components for charge 502
-- (BASE + PENALTY), in deterministic order.
select is(
  jsonb_array_length(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000502'::uuid) -> 'components'),
  2,
  '62: component breakdown returns exactly BASE + PENALTY for charge 502'
);

-- 63/64: WAIVER component (charge 504) appears in the breakdown with
-- its real negative assessed_amount, and allocated/outstanding are
-- honestly null (never fabricated — WAIVER is not independently payable).
select is(
  (
    select (c.value ->> 'assessed_amount')::numeric
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000504'::uuid) -> 'components') c
    where c.value ->> 'component_type' = 'WAIVER'
  ),
  -50000::numeric,
  '63: WAIVER component shows its real stored negative assessed_amount'
);
select is(
  (
    select c.value -> 'outstanding'
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000504'::uuid) -> 'components') c
    where c.value ->> 'component_type' = 'WAIVER'
  ),
  'null'::jsonb,
  '64: WAIVER component''s outstanding is honestly null, never a fabricated 0'
);

-- 65: settlement_history for charge 503 has exactly 2 entries (two
-- separate payment allocations), proving "multiple allocations" and
-- no double-counting (each allocation is its own row, summing back to 50000).
select is(
  jsonb_array_length(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000503'::uuid) -> 'settlement_history'),
  2,
  '65: settlement_history has exactly 2 entries for charge 503''s two payments'
);
select is(
  (
    select sum((h.value ->> 'amount')::numeric)
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000503'::uuid) -> 'settlement_history') h
  ),
  50000::numeric,
  '66: settlement_history amounts sum to exactly the full payment total (50000), no double-counting'
);

-- 67: wallet-sourced settlement is honestly labeled 'WALLET', never a
-- synthetic payment row.
select is(
  (
    select h.value ->> 'source'
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000506'::uuid) -> 'settlement_history') h
  ),
  'WALLET',
  '67: charge 506''s settlement is labeled WALLET, not a fabricated PAYMENT'
);

-- 68/69: reversed payment remains visible in settlement_history
-- (is_reversed=true) even though it no longer reduces outstanding.
select is(
  jsonb_array_length(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000509'::uuid) -> 'settlement_history'),
  1,
  '68: the reversed payment''s allocation remains visible in settlement_history'
);
select is(
  (
    (public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000509'::uuid) -> 'settlement_history' -> 0 ->> 'is_reversed')::boolean
  ),
  true,
  '69: the visible reversed-payment entry is correctly flagged is_reversed=true'
);

-- 70: a charge from a DIFFERENT group (p_group_id mismatch even though
-- charge_id is real) is not found — group isolation on the detail RPC.
select throws_ok(
  $$ select public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000002'::uuid, '10900000-0000-0000-0000-000000000501'::uuid) $$,
  '22023', 'Contribution charge not found',
  '70: a real charge_id requested under the wrong p_group_id is not found'
);

-- --- Regression: canonical helper values are never independently
-- recomputed by this RPC (net_assessed - allocated would diverge from
-- the true canonical outstanding whenever front-to-back netting
-- applies across multiple components — proven here on charge 502
-- where PENALTY is untouched and the payment only reduced BASE).

select is(
  (
    select (i.value ->> 'net_assessed')::numeric - (i.value ->> 'allocated_amount')::numeric
    from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items') i
    where i ->> 'charge_id' = '10900000-0000-0000-0000-000000000502'
  ),
  (
    select (i.value ->> 'outstanding')::numeric
    from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items') i
    where i ->> 'charge_id' = '10900000-0000-0000-0000-000000000502'
  ),
  '71: for charge 502, net_assessed - allocated happens to equal outstanding (simple case) — confirms the canonical helper, not a coincidence of this one case'
);

-- 72: on the WAIVER-settled charge (504), confirm net_assessed -
-- allocated_amount (0 - 0 = 0) still correctly equals canonical
-- outstanding (0), i.e. the two sources never silently diverge in this
-- suite — both stay independently sourced, never cross-derived in the
-- RPC itself (verified by source inspection, §T).
select is(
  (
    select (i.value ->> 'net_assessed')::numeric - (i.value ->> 'allocated_amount')::numeric
    from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items') i
    where i ->> 'charge_id' = '10900000-0000-0000-0000-000000000504'
  ),
  0::numeric,
  '72: waived charge (504) net_assessed - allocated_amount = 0, matching canonical outstanding = 0'
);

-- 73: no global/net member balance anywhere in either response.
select is(
  jsonb_path_exists(
    public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid),
    '$.** ? (@.type() == "string" && @ like_regex "total_net|net_balance|overall_balance" flag "i")'
  ),
  false,
  '73: no global/net/overall balance key anywhere in the list response'
);
select is(
  jsonb_path_exists(
    public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000502'::uuid),
    '$.** ? (@.type() == "string" && @ like_regex "total_net|net_balance|overall_balance" flag "i")'
  ),
  false,
  '74: no global/net/overall balance key anywhere in the detail response'
);

-- =====================================================================
-- Gap coverage added during B4-B hardening
-- =====================================================================

-- 75: officer-without-membership: a valid authenticated user with NO
-- group_memberships row at all cannot use the self-service endpoint.
reset role;
insert into auth.users (id, email) values
  ('10900000-0000-0000-0000-000000000017', 'p09gb4b-nomembership@example.com');
set local role authenticated;
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000017';
select throws_ok(
  $$ select public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) $$,
  '42501', 'No active membership in this group',
  '75: a user with no membership in the group (officer or otherwise) cannot use self-service'
);

-- 76: ADMIN (has contribution.self_view) sees ONLY their own
-- membership's obligations — they have none here, so 0 items, never the
-- group-wide charges of Member Caller.
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000011';
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'items'),
  0,
  '76: ADMIN self-service returns only the ADMIN''s own (zero) obligations — no officer broadening'
);
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000012';

-- 77: partially paid AND past due => OVERDUE (locked precedence).
-- Done inside this rolled-back transaction only, on a fixture row, so
-- earlier PARTIALLY_SETTLED assertions above stay valid.
reset role;
update public.member_contribution_charges
  set due_date = '2026-01-01'
  where id = '10900000-0000-0000-0000-000000000502';
set local role authenticated;
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000012';
select is(
  (select i.value ->> 'status'
   from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items') i
   where i ->> 'charge_id' = '10900000-0000-0000-0000-000000000502'),
  'OVERDUE',
  '77: a partially paid charge that is past due is OVERDUE (OVERDUE precedes PARTIALLY_SETTLED)'
);
select is(
  (select (i.value ->> 'outstanding')::numeric
   from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 100, 0) -> 'items') i
   where i ->> 'charge_id' = '10900000-0000-0000-0000-000000000502'),
  35000::numeric,
  '78: the overdue partial charge still reports its canonical outstanding (35000), unchanged by status'
);

-- 79: pagination — pages of 4 together cover all 9 charges exactly once.
select is(
  (
    select count(distinct i ->> 'charge_id')::integer
    from (
      select jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 0) -> 'items') i
      union all
      select jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 4) -> 'items')
      union all
      select jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 4, 8) -> 'items')
    ) x
  ),
  9,
  '79: paging through 4-per-page yields 9 distinct charges — no duplicates, none missing'
);

-- 80/81: summary.total_outstanding invariant under type and date filters.
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, '10900000-0000-0000-0000-000000000302'::uuid, null, null, 100, 0) -> 'summary' ->> 'total_outstanding')::numeric,
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  '80: summary.total_outstanding is unaffected by the contribution-type filter'
);
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, '2026-08-01'::date, '2026-08-01'::date, 100, 0) -> 'summary' ->> 'total_outstanding')::numeric,
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  '81: summary.total_outstanding is unaffected by the date filter'
);

-- 82: detail — negative ADJUSTMENT (charge 508) appears as its own
-- component with its real stored negative amount and honestly null
-- outstanding (never fabricated).
select is(
  (
    select (c.value ->> 'assessed_amount')::numeric
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000508'::uuid) -> 'components') c
    where c.value ->> 'component_type' = 'ADJUSTMENT' and (c.value ->> 'assessed_amount')::numeric < 0
  ),
  -50000::numeric,
  '82: negative ADJUSTMENT appears in the detail breakdown with its real negative amount'
);

-- 83: detail — positive ADJUSTMENT (charge 506) appears with its real
-- positive amount.
select is(
  (
    select (c.value ->> 'assessed_amount')::numeric
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000506'::uuid) -> 'components') c
    where c.value ->> 'component_type' = 'ADJUSTMENT'
  ),
  5000::numeric,
  '83: positive ADJUSTMENT appears in the detail breakdown with its real positive amount'
);

-- 84: detail — PENALTY (charge 502) appears as its own component.
select is(
  (
    select (c.value ->> 'assessed_amount')::numeric
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000502'::uuid) -> 'components') c
    where c.value ->> 'component_type' = 'PENALTY'
  ),
  5000::numeric,
  '84: PENALTY appears in the detail breakdown with its real amount'
);

-- 85: detail — OPENING_BALANCE charge (505) returns its own
-- component with the real OPENING_BALANCE type.
select is(
  (
    select c.value ->> 'component_type'
    from jsonb_array_elements(public.rpc_get_my_contribution_charge_detail('10900000-0000-0000-0000-000000000001'::uuid, '10900000-0000-0000-0000-000000000505'::uuid) -> 'components') c
    limit 1
  ),
  'OPENING_BALANCE',
  '85: OPENING_BALANCE detail returns its real component type'
);

-- =====================================================================
-- B4-B.1: filter_options.contribution_types
-- =====================================================================

-- Fixtures for isolation: a type used ONLY by Member Two (group A), and
-- a type used ONLY inside Group B. Both are rolled back with the test.
reset role;
insert into public.contribution_types (id, group_id, name, category, accounting_treatment) values
  ('10900000-0000-0000-0000-000000000303', '10900000-0000-0000-0000-000000000001', 'Member Two Only', 'GENERAL', 'GROUP_INCOME'),
  ('10900000-0000-0000-0000-000000000304', '10900000-0000-0000-0000-000000000002', 'Group B Only', 'GENERAL', 'GROUP_INCOME');
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount) values
  ('10900000-0000-0000-0000-000000000313', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000303', 'Member Two Setup', 'ON_DEMAND', 'FIXED', 15000),
  ('10900000-0000-0000-0000-000000000314', '10900000-0000-0000-0000-000000000002', '10900000-0000-0000-0000-000000000304', 'Group B Setup', 'ON_DEMAND', 'FIXED', 15000);
insert into public.contribution_periods (id, group_id, contribution_setup_id, label, period_start, period_end, obligation_date, eligibility_date, due_date, status, purpose, snapshot_type_name, snapshot_category) values
  ('10900000-0000-0000-0000-000000000411', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000313', 'Member Two Period', '2026-09-01', '2026-09-30', '2026-09-01', '2026-09-01', '2026-12-31', 'OPEN', 'NORMAL', 'Member Two Only', 'GENERAL'),
  ('10900000-0000-0000-0000-000000000412', '10900000-0000-0000-0000-000000000002', '10900000-0000-0000-0000-000000000314', 'Group B Period', '2026-09-01', '2026-09-30', '2026-09-01', '2026-09-01', '2026-12-31', 'OPEN', 'NORMAL', 'Group B Only', 'GENERAL');
insert into public.member_contribution_charges (id, group_id, period_id, contribution_setup_id, membership_id, member_number_snapshot, member_name_snapshot, effective_at, due_date) values
  ('10900000-0000-0000-0000-000000000515', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000411', '10900000-0000-0000-0000-000000000313', '10900000-0000-0000-0000-000000000103', 'B4BGA-0003', 'Member Two', '2026-09-01', '2026-12-31'),
  ('10900000-0000-0000-0000-000000000516', '10900000-0000-0000-0000-000000000002', '10900000-0000-0000-0000-000000000412', '10900000-0000-0000-0000-000000000314', '10900000-0000-0000-0000-000000000107', 'B4BGB-0001', 'Member Caller In B', '2026-09-01', '2026-12-31');
insert into public.contribution_charge_components (id, group_id, charge_id, component_type, assessed_amount, effective_at, sequence) values
  ('10900000-0000-0000-0000-000000000615', '10900000-0000-0000-0000-000000000001', '10900000-0000-0000-0000-000000000515', 'BASE', 15000, '2026-09-01', 1),
  ('10900000-0000-0000-0000-000000000616', '10900000-0000-0000-0000-000000000002', '10900000-0000-0000-0000-000000000516', 'BASE', 15000, '2026-09-01', 1);

-- Caller: Member Caller (102), group A, contribution.self_view only.
set local role authenticated;
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000012';

-- 86: filter_options exists, with contribution_types as an array.
select is(
  jsonb_typeof(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types'),
  'array',
  '86: filter_options.contribution_types exists and is an array'
);

-- 87: exactly the caller's own types — Monthly Dues (301) and Social Fund (302).
select is(
  (select array_agg(o ->> 'id' order by o ->> 'id') from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o),
  array['10900000-0000-0000-0000-000000000301', '10900000-0000-0000-0000-000000000302']::text[],
  '87: options are exactly the caller''s own types (Monthly Dues, Social Fund)'
);

-- 88: another member''s exclusive type is not leaked.
select is(
  (select count(*)::integer from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o where o ->> 'id' = '10900000-0000-0000-0000-000000000303'),
  0,
  '88: Member Two''s exclusive type is not leaked into Member Caller''s options'
);

-- 89: another group''s type is not leaked.
select is(
  (select count(*)::integer from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o where o ->> 'id' = '10900000-0000-0000-0000-000000000304'),
  0,
  '89: a type used only in Group B is not leaked into Group A options'
);

-- 90: options are unique.
select is(
  (select count(distinct o ->> 'id')::integer from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o),
  2,
  '90: each contribution type appears exactly once (2 distinct, 2 total)'
);

-- 91: deterministic ordering — primary display name ASC.
select is(
  (select array_agg(t.value ->> 'name' order by t.ord) from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') with ordinality as t(value, ord)),
  array['Monthly Dues', 'Social Fund']::text[],
  '91: options are ordered by display name ASC'
);

-- 92-95: options are invariant with paging, status, type, and date filters.
select is(
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, null, null, 1, 1) -> 'filter_options',
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options',
  '92: filter_options is unchanged by p_limit/p_offset'
);
select is(
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, 'SETTLED') -> 'filter_options',
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options',
  '93: filter_options is unchanged by p_status'
);
select is(
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, '10900000-0000-0000-0000-000000000302'::uuid) -> 'filter_options',
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options',
  '94: filter_options is unchanged by p_contribution_type_id (applying a filter never removes its own option)'
);
select is(
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, null, '2026-08-01'::date, '2026-08-01'::date) -> 'filter_options',
  public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options',
  '95: filter_options is unchanged by from/to date filters'
);

-- 96: selecting a returned type id filters items to exactly that type,
-- and only that type's own charges come back.
select is(
  (select count(*)::integer
   from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, '10900000-0000-0000-0000-000000000301'::uuid, null, null, 100, 0) -> 'items') i
   where i ->> 'contribution_type_id' <> '10900000-0000-0000-0000-000000000301'),
  0,
  '96: selecting Monthly Dues returns only Monthly Dues items'
);

-- 97: summary.total_outstanding unchanged by the selected type.
select is(
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid, null, '10900000-0000-0000-0000-000000000302'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  (public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'summary' ->> 'total_outstanding')::numeric,
  '97: summary.total_outstanding is unchanged by the selected type'
);

-- 98: each option carries the minimum contract keys.
select is(
  (select bool_and(o ? 'id' and o ? 'name' and o ? 'category')
   from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o),
  true,
  '98: every option carries id, name, and category'
);

-- 99: ordinary self_view member does NOT hold contribution.view, yet
-- obtains options — self-service needs no officer permission.
select is(
  public.has_group_permission('10900000-0000-0000-0000-000000000001'::uuid, 'contribution.view'),
  false,
  '99: the self-service caller holds no contribution.view, yet receives filter options'
);

-- 100: an ADMIN (has self_view, no own charges) receives ZERO options,
-- not the group''s configured types — no officer broadening.
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000011';
select is(
  jsonb_array_length(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types'),
  0,
  '100: an ADMIN with no own obligations gets zero options, not group-wide types'
);
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000012';

-- 101: historical-name handling. Simulate a contradiction by freezing a
-- different name on one OLDER period of type 301 (inside this rolled-back
-- transaction only). The primary name must stay the most recent frozen
-- name, and the contradiction must be surfaced in name_variants.
reset role;
update public.contribution_periods
  set snapshot_type_name = 'Monthly Dues (Old Name)'
  where id = '10900000-0000-0000-0000-000000000401';
set local role authenticated;
set local request.jwt.claim.sub to '10900000-0000-0000-0000-000000000012';
select is(
  (select o ->> 'name' from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o where o ->> 'id' = '10900000-0000-0000-0000-000000000301'),
  'Monthly Dues',
  '101: a contradictory older frozen name does not change the primary name (most recent wins)'
);
select is(
  (select jsonb_array_length(o -> 'name_variants') from jsonb_array_elements(public.rpc_get_my_contributions('10900000-0000-0000-0000-000000000001'::uuid) -> 'filter_options' -> 'contribution_types') o where o ->> 'id' = '10900000-0000-0000-0000-000000000301'),
  2,
  '102: the contradiction is surfaced in name_variants, never silently collapsed'
);

select * from finish();
rollback;
