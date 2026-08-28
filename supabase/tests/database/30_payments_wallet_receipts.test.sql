-- Prompt 07: Payments, Wallet, Allocations, Receipts.
--
-- Exercises the three-layer accounting model (obligation ledger /
-- allocation ledger / cashbook) built on top of the accepted 08A
-- Financial Accounts foundation and the locked 06A/06B/06C
-- contribution engine. See docs/product/payments.md.
begin;

select plan(54);

-- ---------------------------------------------------------------------
-- Fixture: Group A (full scenario), Group B (cross-group isolation).
-- ---------------------------------------------------------------------

insert into auth.users (id, email) values
  ('f1000000-0000-0000-0000-000000000001', 'p07-admin@example.com'),
  ('f1000000-0000-0000-0000-000000000002', 'p07-treasurer@example.com'),
  ('f1000000-0000-0000-0000-000000000003', 'p07-member-a@example.com'),
  ('f1000000-0000-0000-0000-000000000004', 'p07-member-b@example.com'),
  ('f1000000-0000-0000-0000-000000000005', 'p07-member-c@example.com'),
  ('f1000000-0000-0000-0000-000000000006', 'p07-member-suspended@example.com'),
  ('f1000000-0000-0000-0000-000000000007', 'p07-groupb-treasurer@example.com');

insert into public.groups (id, name, created_by, code) values
  ('f1100000-0000-0000-0000-000000000001', 'P07 Group A', 'f1000000-0000-0000-0000-000000000001', 'P07AA'),
  ('f1100000-0000-0000-0000-000000000002', 'P07 Group B', 'f1000000-0000-0000-0000-000000000007', 'P07AB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('f1200000-0000-0000-0000-000000000001', 'f1100000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'P07 Admin', 'ACTIVE', '2025-01-01', 'P07AA-2026-0001'),
  ('f1200000-0000-0000-0000-000000000002', 'f1100000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000002', 'P07 Treasurer', 'ACTIVE', '2025-01-01', 'P07AA-2026-0002'),
  ('f1200000-0000-0000-0000-000000000003', 'f1100000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000003', 'P07 Member A', 'ACTIVE', '2025-01-01', 'P07AA-2026-0003'),
  ('f1200000-0000-0000-0000-000000000004', 'f1100000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000004', 'P07 Member B', 'ACTIVE', '2025-01-01', 'P07AA-2026-0004'),
  ('f1200000-0000-0000-0000-000000000005', 'f1100000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000005', 'P07 Member C', 'ACTIVE', '2025-01-01', 'P07AA-2026-0005'),
  ('f1200000-0000-0000-0000-000000000006', 'f1100000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000006', 'P07 Member Suspended', 'ACTIVE', '2025-01-01', 'P07AA-2026-0006'),
  ('f1200000-0000-0000-0000-000000000099', 'f1100000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000007', 'P07 GroupB Treasurer', 'ACTIVE', '2025-01-01', 'P07AB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000004', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000006', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

set local role authenticated;
set local request.jwt.claim.sub to 'f1000000-0000-0000-0000-000000000002';

create temporary table t_acct as
select public.rpc_create_financial_account('f1100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

create temporary table t_acct_inactive as
select public.rpc_create_financial_account('f1100000-0000-0000-0000-000000000001', 'Retired Account', 'BANK') as result;
select (result->>'id')::uuid as inactive_account_id from t_acct_inactive \gset
select public.rpc_update_financial_account('f1100000-0000-0000-0000-000000000001', :'inactive_account_id'::uuid, p_is_active => false);

create temporary table t_type as
select public.rpc_create_contribution_type('f1100000-0000-0000-0000-000000000001', 'Monthly', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  'f1100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Monthly Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount => 10000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

-- Two periods so a member can hold two obligations at once (multi-
-- obligation payment, deterministic cross-charge ordering).
create temporary table t_period_jan as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Jan 2026', '2026-01-01', '2026-01-31',
  p_due_date => '2026-01-15'
) as result;
select (result->>'id')::uuid as period_jan_id from t_period_jan \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_jan_id'::uuid);

-- Suspend this membership right after it received its Jan charge
-- while ACTIVE, so it never accumulates charges from any later
-- period opened in this file — proving test 13's "historical
-- obligation" scenario cleanly (a status transition, done directly
-- since testing that mechanism itself is out of scope here).
reset role;
update public.group_memberships set status = 'SUSPENDED'
where id = 'f1200000-0000-0000-0000-000000000006';
set local role authenticated;
set local request.jwt.claim.sub to 'f1000000-0000-0000-0000-000000000002';

create temporary table t_period_feb as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Feb 2026', '2026-02-01', '2026-02-28',
  p_due_date => '2026-02-15'
) as result;
select (result->>'id')::uuid as period_feb_id from t_period_feb \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_feb_id'::uuid);

select id as charge_a_jan from public.member_contribution_charges
where period_id = :'period_jan_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000003' \gset
select id as charge_a_feb from public.member_contribution_charges
where period_id = :'period_feb_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000003' \gset
select id as charge_b_jan from public.member_contribution_charges
where period_id = :'period_jan_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000004' \gset
select id as charge_c_jan from public.member_contribution_charges
where period_id = :'period_jan_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000005' \gset

-- ---------------------------------------------------------------------
-- 1. Exact payment.
-- ---------------------------------------------------------------------

create temporary table t_pay_exact as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  10000, '2026-01-10', 'CASH'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_pay_exact), 10000.00::numeric,
  'exact payment: full amount allocated'
);
select is(
  (select (result->>'wallet_credit_amount')::numeric from t_pay_exact), 0.00::numeric,
  'exact payment: zero wallet credit'
);
select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_b_jan'::uuid)->>'total_outstanding')::numeric),
  0.00::numeric,
  'exact payment: charge fully settled'
);

-- ---------------------------------------------------------------------
-- 2. Partial payment.
-- ---------------------------------------------------------------------

create temporary table t_pay_partial as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid,
  4000, '2026-01-10', 'CASH'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_pay_partial), 4000.00::numeric,
  'partial payment: only the paid amount is allocated'
);
select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_c_jan'::uuid)->>'total_outstanding')::numeric),
  6000.00::numeric,
  'partial payment: remaining outstanding reduced by exactly the paid amount'
);

-- ---------------------------------------------------------------------
-- 3. Multi-obligation payment (Member A owes Jan + Feb = 20000).
-- ---------------------------------------------------------------------

create temporary table t_pay_multi as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  20000, '2026-02-20', 'CASH'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_pay_multi), 20000.00::numeric,
  'multi-obligation payment: settles both Jan and Feb charges in full'
);
select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_a_jan'::uuid)->>'total_outstanding')::numeric),
  0.00::numeric,
  'multi-obligation payment: Jan charge fully settled'
);
select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_a_feb'::uuid)->>'total_outstanding')::numeric),
  0.00::numeric,
  'multi-obligation payment: Feb charge fully settled'
);

-- ---------------------------------------------------------------------
-- 4/5. Overpayment wallet credit + core payment invariant. Member B's
-- Feb charge (created when period_feb opened for every active member)
-- is settled first so the Mar overpayment below is against exactly
-- one known 10000 obligation.
-- ---------------------------------------------------------------------

select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  10000, '2026-02-20', 'CASH'
);

create temporary table t_period_mar as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Mar 2026', '2026-03-01', '2026-03-31',
  p_due_date => '2026-03-15'
) as result;
select (result->>'id')::uuid as period_mar_id from t_period_mar \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_mar_id'::uuid);

create temporary table t_pay_over as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  13000, '2026-03-10', 'CASH'
) as result;

select is(
  (select (result->>'wallet_credit_amount')::numeric from t_pay_over), 3000.00::numeric,
  'overpayment: excess beyond outstanding debt becomes wallet credit'
);
select is(
  (
    select (select (result->>'total_allocated')::numeric from t_pay_over)
         + (select (result->>'wallet_credit_amount')::numeric from t_pay_over)
  ),
  (select (result->>'amount')::numeric from t_pay_over),
  'invariant A: sum(allocations) + wallet credit = payment amount'
);

-- ---------------------------------------------------------------------
-- 6/7. Deterministic allocation order: overdue-oldest-first across
-- charges, then BASE-before-PENALTY within one charge. Uses a fresh,
-- dedicated group so this scenario's charges are not entangled with
-- Group A's other test sections.
-- ---------------------------------------------------------------------

reset role;
insert into public.groups (id, name, created_by, code) values
  ('f1100000-0000-0000-0000-000000000003', 'P07 Order Group', 'f1000000-0000-0000-0000-000000000002', 'P07OR');
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('f1200000-0000-0000-0000-000000000010', 'f1100000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000002', 'Order Treasurer', 'ACTIVE', '2025-01-01', 'P07OR-2026-0001'),
  ('f1200000-0000-0000-0000-000000000011', 'f1100000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000003', 'Order Member', 'ACTIVE', '2025-01-01', 'P07OR-2026-0002');
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000010', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f1200000-0000-0000-0000-000000000011', id from public.roles where code = 'MEMBER';
set local role authenticated;
set local request.jwt.claim.sub to 'f1000000-0000-0000-0000-000000000002';

create temporary table t_acct_order as
select public.rpc_create_financial_account('f1100000-0000-0000-0000-000000000003', 'Order Cash', 'CASH') as result;
select (result->>'id')::uuid as order_account_id from t_acct_order \gset

create temporary table t_type_order as
select public.rpc_create_contribution_type('f1100000-0000-0000-0000-000000000003', 'Monthly', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as order_type_id from t_type_order \gset

create temporary table t_setup_order as
select public.rpc_create_contribution_setup(
  'f1100000-0000-0000-0000-000000000003', :'order_type_id'::uuid, 'Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 10000
) as result;
select (result->>'id')::uuid as order_setup_id from t_setup_order \gset

create temporary table t_period_order as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000003', :'order_setup_id'::uuid, 'Jan', '2026-01-01', '2026-01-31', p_due_date => '2026-01-01'
) as result;
select (result->>'id')::uuid as order_period_id from t_period_order \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000003', :'order_period_id'::uuid);

select id as order_charge_id from public.member_contribution_charges
where period_id = :'order_period_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000011' \gset

create temporary table t_period_order_feb as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000003', :'order_setup_id'::uuid, 'Feb', '2026-02-01', '2026-02-28', p_due_date => '2026-02-01'
) as result;
select (result->>'id')::uuid as order_period_feb_id from t_period_order_feb \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000003', :'order_period_feb_id'::uuid);

select id as order_charge_feb_id from public.member_contribution_charges
where period_id = :'order_period_feb_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000011' \gset

-- Cross-charge ordering: with two open charges (Jan due 2026-01-01,
-- Feb due 2026-02-01), a small payment must land on the older one.
select is(
  (
    select (public.rpc_preview_payment_allocation(
      'f1100000-0000-0000-0000-000000000003', 'f1200000-0000-0000-0000-000000000011', :'order_account_id'::uuid, 100
    )->'allocations'->0->>'charge_id')::uuid
  ),
  :'order_charge_id'::uuid,
  'cross-charge ordering: a small payment is allocated to the charge with the oldest due date'
);

-- Within-charge ordering: the Jan charge gets a directly-posted
-- PENALTY on top of its already-outstanding BASE — a partial payment
-- must settle BASE before PENALTY.
reset role;
insert into public.contribution_charge_components (group_id, charge_id, component_type, assessed_amount, effective_at, sequence, created_by)
values ('f1100000-0000-0000-0000-000000000003', :'order_charge_id'::uuid, 'PENALTY', 800, '2026-01-10', 1, 'f1000000-0000-0000-0000-000000000002');
set local role authenticated;
set local request.jwt.claim.sub to 'f1000000-0000-0000-0000-000000000002';

create temporary table t_pay_order as
select public.rpc_preview_payment_allocation(
  'f1100000-0000-0000-0000-000000000003', 'f1200000-0000-0000-0000-000000000011', :'order_account_id'::uuid, 5000
) as result;

select is(
  (select result->'allocations'->0->>'component_type' from t_pay_order),
  'BASE',
  'within-charge ordering: BASE is settled before PENALTY, even though PENALTY was posted first'
);
select is(
  (select (result->>'total_allocated')::numeric from t_pay_order),
  5000.00::numeric,
  'the partial payment is allocated entirely to BASE, none reaching PENALTY yet'
);

-- ---------------------------------------------------------------------
-- 8. Waiver-adjusted debt.
-- ---------------------------------------------------------------------

create temporary table t_period_apr as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Apr 2026', '2026-04-01', '2026-04-30',
  p_due_date => '2026-04-15'
) as result;
select (result->>'id')::uuid as period_apr_id from t_period_apr \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_apr_id'::uuid);

select id as charge_b_apr from public.member_contribution_charges
where period_id = :'period_apr_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000004' \gset

select public.rpc_waive_contribution_charge(
  'f1100000-0000-0000-0000-000000000001', :'charge_b_apr'::uuid, 4000, 'hardship waiver'
);

select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_b_apr'::uuid)->>'total_outstanding')::numeric),
  6000.00::numeric,
  'waiver-adjusted debt: BASE outstanding reduced by the waived amount before any payment'
);

create temporary table t_pay_waived as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  6000, '2026-04-10', 'CASH'
) as result;

select is(
  (select (result->>'wallet_credit_amount')::numeric from t_pay_waived), 0.00::numeric,
  'waiver-adjusted debt: paying exactly the net (post-waiver) debt produces zero wallet credit, never allocating the full pre-waiver BASE'
);

-- ---------------------------------------------------------------------
-- 9. Negative-adjustment debt (same netting mechanism as WAIVER).
-- ---------------------------------------------------------------------

create temporary table t_period_may as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'May 2026', '2026-05-01', '2026-05-31',
  p_due_date => '2026-05-15'
) as result;
select (result->>'id')::uuid as period_may_id from t_period_may \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_may_id'::uuid);

select id as charge_c_may from public.member_contribution_charges
where period_id = :'period_may_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000005' \gset

select public.rpc_create_contribution_adjustment(
  'f1100000-0000-0000-0000-000000000001', :'charge_c_may'::uuid, -2500, 'billing correction'
);

select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_c_may'::uuid)->>'total_outstanding')::numeric),
  7500.00::numeric,
  'negative adjustment reduces allocatable debt exactly like a waiver'
);

-- ---------------------------------------------------------------------
-- 10. Positive-adjustment debt (payable, settled after BASE/PENALTY).
-- Member C's leftover 6000 on charge_c_jan (from test 2) is settled
-- first so the preview below is against exactly one known obligation.
-- ---------------------------------------------------------------------

select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid,
  6000, '2026-01-20', 'CASH'
);

select public.rpc_create_contribution_adjustment(
  'f1100000-0000-0000-0000-000000000001', :'charge_c_may'::uuid, 1000, 'late submission fee'
);

create temporary table t_pay_posadj as
select public.rpc_preview_payment_allocation(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid, 8500
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_pay_posadj), 8500.00::numeric,
  'positive ADJUSTMENT is payable and gets allocated alongside BASE (net 7500 + 1000 adjustment = 8500)'
);

-- ---------------------------------------------------------------------
-- 11. Opening-balance settlement.
-- ---------------------------------------------------------------------

create temporary table t_ob_preview as
select public.rpc_preview_contribution_opening_balance_import(
  'f1100000-0000-0000-0000-000000000001', :'type_id'::uuid, '2025-12-01',
  jsonb_build_array(
    jsonb_build_object('membership_id', 'f1200000-0000-0000-0000-000000000003', 'amount', 5000)
  )
) as result;

select public.rpc_import_contribution_opening_balances(
  'f1100000-0000-0000-0000-000000000001', :'type_id'::uuid, '2025-12-01',
  jsonb_build_array(
    jsonb_build_object('membership_id', 'f1200000-0000-0000-0000-000000000003', 'amount', 5000)
  )
);

select id as charge_a_ob from public.member_contribution_charges c
where c.membership_id = 'f1200000-0000-0000-0000-000000000003' and c.effective_at = '2025-12-01' \gset

create temporary table t_pay_ob as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  5000, '2025-12-15', 'CASH'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_pay_ob), 5000.00::numeric,
  'an OPENING_BALANCE component is payable and gets allocated like any other payable component'
);

-- ---------------------------------------------------------------------
-- 12. CLOSED-period debt remains payable. Member B also got charged
-- for period_may (opened for test 9's Member C scenario) — clear it
-- first so the Jun payment below is against exactly one obligation.
-- ---------------------------------------------------------------------

create temporary table t_clear_member_b_pre_jun as
select (public.rpc_get_member_contribution_summary(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004'
)->>'total_outstanding')::numeric as amount;
select amount as member_b_prior_debt from t_clear_member_b_pre_jun \gset
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  :'member_b_prior_debt', '2026-05-20', 'CASH'
);

create temporary table t_period_jun as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Jun 2026', '2026-06-01', '2026-06-30',
  p_due_date => '2026-06-15'
) as result;
select (result->>'id')::uuid as period_jun_id from t_period_jun \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_jun_id'::uuid);

select id as charge_b_jun from public.member_contribution_charges
where period_id = :'period_jun_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000004' \gset

select public.rpc_close_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_jun_id'::uuid);

select lives_ok(
  format(
    $sql$ select public.rpc_post_payment('f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', %L, 10000, '2026-06-20', 'CASH') $sql$,
    :'account_id'
  ),
  'a CLOSED period''s member charge remains payable (period lifecycle and settlement lifecycle are separate)'
);

select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_b_jun'::uuid)->>'total_outstanding')::numeric),
  0.00::numeric,
  'CLOSED-period charge was actually settled by the payment above'
);

-- ---------------------------------------------------------------------
-- 13. Suspended member historical debt remains payable.
-- ---------------------------------------------------------------------

select id as charge_susp_jan from public.member_contribution_charges
where period_id = :'period_jan_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000006' \gset

select lives_ok(
  format(
    $sql$ select public.rpc_post_payment('f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000006', %L, 10000, '2026-01-20', 'CASH') $sql$,
    :'account_id'
  ),
  'a SUSPENDED member''s historical obligation remains settleable without reactivating membership'
);

select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_susp_jan'::uuid)->>'total_outstanding')::numeric),
  0.00::numeric,
  'suspended member''s charge was actually settled'
);

-- ---------------------------------------------------------------------
-- 14/15/16. Cashbook invariants: exactly one INFLOW, for the FULL
-- payment amount, with correct source linkage.
-- ---------------------------------------------------------------------

select is(
  (select count(*)::int from public.financial_account_entries
   where source_type = 'PAYMENT' and source_id = (select (result->>'payment_id')::uuid from t_pay_over)),
  1,
  'invariant B: exactly one cashbook entry exists for the overpayment above'
);
select is(
  (select entry_type::text from public.financial_account_entries
   where source_type = 'PAYMENT' and source_id = (select (result->>'payment_id')::uuid from t_pay_over)),
  'INFLOW',
  'the one cashbook entry is an INFLOW'
);
select is(
  (select amount from public.financial_account_entries
   where source_type = 'PAYMENT' and source_id = (select (result->>'payment_id')::uuid from t_pay_over)),
  (select (result->>'amount')::numeric from t_pay_over),
  'the cashbook INFLOW is for the FULL payment amount, never just the allocated portion'
);

-- ---------------------------------------------------------------------
-- 17. Receipt exactly once (unique, generated once per payment).
-- ---------------------------------------------------------------------

select is(
  (select count(distinct receipt_number)::int from public.payments where group_id = 'f1100000-0000-0000-0000-000000000001'),
  (select count(*)::int from public.payments where group_id = 'f1100000-0000-0000-0000-000000000001'),
  'every payment has a distinct receipt_number — receipts are exactly-once'
);

-- ---------------------------------------------------------------------
-- 18/19. Idempotency: same key + same payload returns existing result;
-- same key + conflicting payload is rejected.
-- ---------------------------------------------------------------------

create temporary table t_period_jul as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Jul 2026', '2026-07-01', '2026-07-31',
  p_due_date => '2026-07-15'
) as result;
select (result->>'id')::uuid as period_jul_id from t_period_jul \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_jul_id'::uuid);

create temporary table t_pay_idem1 as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  2000, '2026-07-10', 'CASH', p_idempotency_key => 'idemtest1'
) as result;
create temporary table t_pay_idem2 as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  2000, '2026-07-10', 'CASH', p_idempotency_key => 'idemtest1'
) as result;

select is(
  (select result->>'payment_id' from t_pay_idem1),
  (select result->>'payment_id' from t_pay_idem2),
  'idempotent retry: same key + same payload returns the original payment_id'
);
select is(
  (select (result->>'already_posted')::boolean from t_pay_idem2), true,
  'idempotent retry is flagged already_posted'
);
select is(
  (select count(*)::int from public.payments where idempotency_key = 'idemtest1'),
  1,
  'idempotent retry never creates a second payment row'
);

select throws_ok(
  $sql$ select public.rpc_post_payment(
    'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004',
    (select id from public.financial_accounts where group_id = 'f1100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    9999, '2026-07-10', 'CASH', p_idempotency_key => 'idemtest1'
  ) $sql$,
  'P0001', 'PAYMENT_IDEMPOTENCY_KEY_CONFLICT',
  'a conflicting payload reusing the same idempotency key is rejected, never silently double-posted'
);

-- ---------------------------------------------------------------------
-- 20. Sequential allocation-consistency (concurrency protection is
-- provided by the group_memberships row lock in rpc_post_payment; a
-- single-transaction pgTAP suite can prove the sequential case —
-- a second payment for the same member correctly sees the first's
-- already-posted allocations rather than recomputing stale outstanding).
-- ---------------------------------------------------------------------

-- Member A has accumulated unpaid debt from every period opened since
-- test 3 (mar/apr/may/jun charge every active member; jul was only
-- partly settled by the idempotency test) — clear all of it first.
create temporary table t_clear_member_a_pre_aug as
select (public.rpc_get_member_contribution_summary(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003'
)->>'total_outstanding')::numeric as amount;
select amount as member_a_prior_debt from t_clear_member_a_pre_aug \gset
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  :'member_a_prior_debt', '2026-07-20', 'CASH'
);

create temporary table t_period_aug as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Aug 2026', '2026-08-01', '2026-08-31',
  p_due_date => '2026-08-15'
) as result;
select (result->>'id')::uuid as period_aug_id from t_period_aug \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_aug_id'::uuid);

select id as charge_a_aug from public.member_contribution_charges
where period_id = :'period_aug_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000003' \gset

create temporary table t_pay_seq1 as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  6000, '2026-08-10', 'CASH'
) as result;
create temporary table t_pay_seq2 as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  4000, '2026-08-11', 'CASH'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_pay_seq2), 4000.00::numeric,
  'a second sequential payment against the same member correctly sees the first''s allocation and allocates only the remaining 4000'
);
select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_a_aug'::uuid)->>'total_outstanding')::numeric),
  0.00::numeric,
  'after both sequential payments the charge is fully settled exactly once'
);

-- ---------------------------------------------------------------------
-- 21. Cross-group membership/account rejection.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_post_payment(
    'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000099',
    (select id from public.financial_accounts where group_id = 'f1100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    1000, '2026-01-10', 'CASH'
  ) $sql$,
  '22023', null,
  'a membership belonging to a different group is rejected'
);

-- ---------------------------------------------------------------------
-- 22. Inactive financial account rejection.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_post_payment(
    'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003',
    (select id from public.financial_accounts where group_id = 'f1100000-0000-0000-0000-000000000001' and name = 'Retired Account'),
    1000, '2026-01-10', 'CASH'
  ) $sql$,
  'P0001', 'FINANCIAL_ACCOUNT_INACTIVE',
  'posting a payment against an inactive financial account is rejected'
);

-- ---------------------------------------------------------------------
-- 23. Permission denial (MEMBER cannot create/reverse payments).
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'f1000000-0000-0000-0000-000000000003';

select throws_ok(
  $sql$ select public.rpc_post_payment(
    'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003',
    (select id from public.financial_accounts where group_id = 'f1100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    1000, '2026-01-10', 'CASH'
  ) $sql$,
  '42501', null,
  'a MEMBER without payment.create cannot post a payment'
);

set local request.jwt.claim.sub to 'f1000000-0000-0000-0000-000000000002';

-- ---------------------------------------------------------------------
-- 24/25. Wallet allocation + wallet never goes negative. Member B also
-- got charged for jul/aug (opened for Member A's idempotency/sequential
-- tests) — clear that debt first, without touching the wallet credit
-- itself, so the wallet allocation below lands on the fresh Sep charge.
-- ---------------------------------------------------------------------

create temporary table t_clear_member_b_pre_sep as
select (public.rpc_get_member_contribution_summary(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004'
)->>'total_outstanding')::numeric as amount;
select amount as member_b_prior_debt_2 from t_clear_member_b_pre_sep \gset
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  :'member_b_prior_debt_2', '2026-08-20', 'CASH'
);

create temporary table t_period_sep as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Sep 2026', '2026-09-01', '2026-09-30',
  p_due_date => '2026-09-15'
) as result;
select (result->>'id')::uuid as period_sep_id from t_period_sep \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_sep_id'::uuid);

select id as charge_b_sep from public.member_contribution_charges
where period_id = :'period_sep_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000004' \gset

-- Member B's wallet carries 3000 credit from the overpayment test above.
create temporary table t_wallet_alloc as
select public.rpc_allocate_member_wallet(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', 3000
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_wallet_alloc), 3000.00::numeric,
  'wallet allocation settles obligations without any payment/receipt/cashbook entry'
);
select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'PAYMENT_ALLOCATION_BATCH'),
  0,
  'invariant C: a wallet allocation creates zero cashbook entries'
);
select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_b_sep'::uuid)->>'total_outstanding')::numeric),
  7000.00::numeric,
  'wallet-settled portion is reflected in the charge''s outstanding'
);

select throws_ok(
  $sql$ select public.rpc_allocate_member_wallet(
    'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', 999999
  ) $sql$,
  'P0001', 'WALLET_INSUFFICIENT_BALANCE',
  'wallet balance never goes negative — an allocation beyond the available balance is rejected'
);

-- ---------------------------------------------------------------------
-- 26/27/28/29. Payment reversal: restores outstanding, restores
-- account balance, preserves immutable history. Member C has
-- accumulated unpaid debt from every period opened since test 9/10
-- (every rpc_open_contribution_period charges every active member,
-- not just the one under test) — clear all of it first so the Oct
-- charge below is the only thing an allocation walk can reach.
-- ---------------------------------------------------------------------

create temporary table t_clear_member_c as
select (public.rpc_get_member_contribution_summary(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005'
)->>'total_outstanding')::numeric as amount;
select amount as member_c_prior_debt from t_clear_member_c \gset
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid,
  :'member_c_prior_debt', '2026-09-20', 'CASH'
);

create temporary table t_period_oct as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Oct 2026', '2026-10-01', '2026-10-31',
  p_due_date => '2026-10-15'
) as result;
select (result->>'id')::uuid as period_oct_id from t_period_oct \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_oct_id'::uuid);

select id as charge_c_oct from public.member_contribution_charges
where period_id = :'period_oct_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000005' \gset

create temporary table t_pay_reversible as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid,
  10000, '2026-10-10', 'CASH'
) as result;
select (result->>'payment_id')::uuid as reversible_payment_id from t_pay_reversible \gset

select public.rpc_reverse_payment('f1100000-0000-0000-0000-000000000001', :'reversible_payment_id'::uuid, 'accidental duplicate entry');

select is(
  (select (public.rpc_get_contribution_charge_detail('f1100000-0000-0000-0000-000000000001', :'charge_c_oct'::uuid)->>'total_outstanding')::numeric),
  10000.00::numeric,
  'reversal restores the charge''s outstanding to its pre-payment value'
);
select is(
  (select status::text from public.payments where id = :'reversible_payment_id'::uuid),
  'REVERSED',
  'reversal flips payment status to REVERSED'
);
select is(
  (select count(*)::int from public.payment_allocations where payment_id = :'reversible_payment_id'::uuid),
  1,
  'reversal preserves the original allocation row — never deleted'
);
select is(
  (select amount from public.payment_allocations where payment_id = :'reversible_payment_id'::uuid),
  10000.00::numeric,
  'the preserved allocation row is historically unchanged'
);
select is(
  (select count(*)::int from public.financial_account_entries where reverses_entry_id is not null and source_id = :'reversible_payment_id'::uuid),
  1,
  'reversal posts exactly one new reversing cashbook entry, linked via reverses_entry_id'
);
select is(
  (select reversed_by is not null and reversed_at is not null and reversal_reason = 'accidental duplicate entry'
   from public.payments where id = :'reversible_payment_id'::uuid),
  true,
  'reversal records who/when/why'
);

-- ---------------------------------------------------------------------
-- 30. Reversal blocked when wallet credit already consumed. The
-- reversal above reopened charge_c_oct's 10000 debt — clear it first
-- so the Nov payment below produces a clean, known wallet credit.
-- ---------------------------------------------------------------------

select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid,
  10000, '2026-10-20', 'CASH'
);

create temporary table t_period_nov as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Nov 2026', '2026-11-01', '2026-11-30',
  p_due_date => '2026-11-15'
) as result;
select (result->>'id')::uuid as period_nov_id from t_period_nov \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_nov_id'::uuid);

create temporary table t_pay_wc as
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', :'account_id'::uuid,
  15000, '2026-11-10', 'CASH'
) as result;
select (result->>'payment_id')::uuid as wc_payment_id from t_pay_wc \gset

create temporary table t_period_dec as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Dec 2026', '2026-12-01', '2026-12-31',
  p_due_date => '2026-12-15'
) as result;
select (result->>'id')::uuid as period_dec_id from t_period_dec \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_dec_id'::uuid);

select public.rpc_allocate_member_wallet('f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000005', 5000);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f1100000-0000-0000-0000-000000000001', %L, 'testing blocked reversal') $sql$,
    :'wc_payment_id'
  ),
  'P0001', 'PAYMENT_REVERSAL_BLOCKED_WALLET_CREDIT_CONSUMED',
  'reversal is blocked when the wallet credit it created has already been consumed — never silently reverses unrelated wallet value'
);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f1100000-0000-0000-0000-000000000001', %L, 'double reversal attempt') $sql$,
    :'reversible_payment_id'
  ),
  'P0001', 'PAYMENT_ALREADY_REVERSED',
  'reversing an already-REVERSED payment is rejected'
);

-- ---------------------------------------------------------------------
-- 31/32. 06B integration: fully-settled charges stop qualifying for
-- new penalties; already-posted percentage penalties stay unchanged.
-- ---------------------------------------------------------------------

create temporary table t_type_pen as
select public.rpc_create_contribution_type('f1100000-0000-0000-0000-000000000001', 'PenaltyMonthly', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_pen_id from t_type_pen \gset

create temporary table t_setup_pen as
select public.rpc_create_contribution_setup(
  'f1100000-0000-0000-0000-000000000001', :'type_pen_id'::uuid, 'Penalty Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount => 10000, p_penalty_mode => 'PERCENTAGE_RECURRING', p_penalty_grace_days => 5,
  p_penalty_value => 5, p_penalty_cap_amount => 3000
) as result;
select (result->>'id')::uuid as setup_pen_id from t_setup_pen \gset

create temporary table t_period_pen as
select public.rpc_create_contribution_period(
  'f1100000-0000-0000-0000-000000000001', :'setup_pen_id'::uuid, 'Pen Jan 2026', '2026-01-01', '2026-01-31',
  p_due_date => '2026-01-01'
) as result;
select (result->>'id')::uuid as period_pen_id from t_period_pen \gset
select public.rpc_open_contribution_period('f1100000-0000-0000-0000-000000000001', :'period_pen_id'::uuid);

select id as charge_paid_pen from public.member_contribution_charges
where period_id = :'period_pen_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000003' \gset
select id as charge_unpaid_pen from public.member_contribution_charges
where period_id = :'period_pen_id'::uuid and membership_id = 'f1200000-0000-0000-0000-000000000004' \gset

select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003', :'account_id'::uuid,
  10000, '2026-01-01', 'CASH'
);

select public.rpc_assess_contribution_penalties('f1100000-0000-0000-0000-000000000001', :'period_pen_id'::uuid, '2026-01-10');

select is(
  (select count(*)::int from public.contribution_charge_components where charge_id = :'charge_paid_pen'::uuid and component_type = 'PENALTY'),
  0,
  'a fully-settled charge never receives a new penalty occurrence, even while technically overdue'
);
select is(
  (select count(*)::int from public.contribution_charge_components where charge_id = :'charge_unpaid_pen'::uuid and component_type = 'PENALTY'),
  1,
  'a partially/un-settled charge remains fully eligible for penalty assessment'
);

select is(
  (select assessed_amount from public.contribution_charge_components
   where charge_id = :'charge_unpaid_pen'::uuid and component_type = 'PENALTY' and sequence = 1),
  500.00::numeric,
  'the posted percentage penalty is computed from the original BASE amount (10000 * 5% = 500), unaffected by this integration'
);

-- Re-run assessment after paying off the previously-unpaid charge too:
-- the already-posted PENALTY component must never be recalculated.
select public.rpc_post_payment(
  'f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000004', :'account_id'::uuid,
  10500, '2026-01-12', 'CASH'
);
select public.rpc_assess_contribution_penalties('f1100000-0000-0000-0000-000000000001', :'period_pen_id'::uuid, '2026-01-20');

select is(
  (select count(*)::int from public.contribution_charge_components where charge_id = :'charge_unpaid_pen'::uuid and component_type = 'PENALTY'),
  1,
  'once fully settled, the charge stops accruing further penalty occurrences (still only the one from before settlement)'
);
select is(
  (select assessed_amount from public.contribution_charge_components
   where charge_id = :'charge_unpaid_pen'::uuid and component_type = 'PENALTY' and sequence = 1),
  500.00::numeric,
  'the already-posted percentage penalty amount is never recalculated after later settlement'
);

-- ---------------------------------------------------------------------
-- 33. Direct client mutation denied.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ insert into public.payments (group_id, membership_id, financial_account_id, amount, effective_at, payment_method, receipt_number)
        values ('f1100000-0000-0000-0000-000000000001', 'f1200000-0000-0000-0000-000000000003',
                (select id from public.financial_accounts where group_id = 'f1100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
                1000, '2026-01-01', 'CASH', 'FAKE-0001') $sql$,
  '42501',
  null,
  'direct client INSERT into payments is denied — every mutation must go through a SECURITY DEFINER RPC'
);

select throws_ok(
  $sql$ update public.payments set amount = 1 where group_id = 'f1100000-0000-0000-0000-000000000001' $sql$,
  '42501',
  null,
  'direct client UPDATE on payments is denied'
);

select * from finish();
rollback;
