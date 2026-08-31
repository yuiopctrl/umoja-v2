-- Prompt 08B: financial position (AD-AI) and permissions (AJ-AM).
begin;

select plan(13);

insert into auth.users (id, email) values
  ('fe000000-0000-0000-0000-000000000001', 'p08bp-admin@example.com'),
  ('fe000000-0000-0000-0000-000000000002', 'p08bp-treasurer@example.com'),
  ('fe000000-0000-0000-0000-000000000003', 'p08bp-chairperson@example.com'),
  ('fe000000-0000-0000-0000-000000000004', 'p08bp-secretary@example.com'),
  ('fe000000-0000-0000-0000-000000000005', 'p08bp-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('fe100000-0000-0000-0000-000000000001', 'P08BP Group A', 'fe000000-0000-0000-0000-000000000001', 'FEAA'),
  ('fe100000-0000-0000-0000-000000000002', 'P08BP Group B', 'fe000000-0000-0000-0000-000000000001', 'FEBB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('fe200000-0000-0000-0000-000000000001', 'fe100000-0000-0000-0000-000000000001', 'fe000000-0000-0000-0000-000000000001', 'FE Admin', 'ACTIVE', '2025-01-01', 'FEAA-2026-0001'),
  ('fe200000-0000-0000-0000-000000000002', 'fe100000-0000-0000-0000-000000000001', 'fe000000-0000-0000-0000-000000000002', 'FE Treasurer', 'ACTIVE', '2025-01-01', 'FEAA-2026-0002'),
  ('fe200000-0000-0000-0000-000000000003', 'fe100000-0000-0000-0000-000000000001', 'fe000000-0000-0000-0000-000000000003', 'FE Chairperson', 'ACTIVE', '2025-01-01', 'FEAA-2026-0003'),
  ('fe200000-0000-0000-0000-000000000004', 'fe100000-0000-0000-0000-000000000001', 'fe000000-0000-0000-0000-000000000004', 'FE Secretary', 'ACTIVE', '2025-01-01', 'FEAA-2026-0004'),
  ('fe200000-0000-0000-0000-000000000005', 'fe100000-0000-0000-0000-000000000001', 'fe000000-0000-0000-0000-000000000005', 'FE Member', 'ACTIVE', '2025-01-01', 'FEAA-2026-0005'),
  ('fe200000-0000-0000-0000-000000000098', 'fe100000-0000-0000-0000-000000000002', 'fe000000-0000-0000-0000-000000000001', 'FE Group B Admin', 'ACTIVE', '2025-01-01', 'FEBB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'fe200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fe200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fe200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fe200000-0000-0000-0000-000000000004', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fe200000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fe200000-0000-0000-0000-000000000098', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to 'fe000000-0000-0000-0000-000000000001';

create temporary table t_acct1 as
select public.rpc_create_financial_account('fe100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH', 20000, '2026-01-01') as result;
select (result->>'id')::uuid as account1_id from t_acct1 \gset

create temporary table t_acct2 as
select public.rpc_create_financial_account('fe100000-0000-0000-0000-000000000001', 'Bank NMB', 'BANK', 30000, '2026-01-01') as result;
select (result->>'id')::uuid as account2_id from t_acct2 \gset

create temporary table t_cat as
select public.rpc_create_financial_category('fe100000-0000-0000-0000-000000000001', 'Donation', 'INCOME') as result;
select (result->>'id')::uuid as cat_id from t_cat \gset

create temporary table t_exp_cat as
select public.rpc_create_financial_category('fe100000-0000-0000-0000-000000000001', 'Transport', 'EXPENSE') as result;
select (result->>'id')::uuid as exp_cat_id from t_exp_cat \gset

select public.rpc_record_manual_income('fe100000-0000-0000-0000-000000000001', :'account1_id'::uuid, :'cat_id'::uuid, 15000, '2026-03-01', 'March donation');
select public.rpc_record_expense('fe100000-0000-0000-0000-000000000001', :'account1_id'::uuid, :'exp_cat_id'::uuid, 4000, '2026-03-02', 'March transport');
-- A payment falling OUTSIDE the reporting period tested below.
select public.rpc_record_manual_income('fe100000-0000-0000-0000-000000000001', :'account1_id'::uuid, :'cat_id'::uuid, 7000, '2026-05-01', 'May donation, outside period');

-- ---------------------------------------------------------------------
-- AD. sum account balances correct.
-- ---------------------------------------------------------------------

create temporary table t_position_all as
select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) as result;

select is(
  (select (result->>'total_financial_account_balance')::numeric from t_position_all),
  68000.00::numeric,
  'AD: total balance = 20000 + 30000 opening + 15000 + 7000 income - 4000 expense = 68000'
);

-- ---------------------------------------------------------------------
-- AE. transfers do not change group total.
-- ---------------------------------------------------------------------

select public.rpc_record_financial_account_transfer('fe100000-0000-0000-0000-000000000001', :'account1_id'::uuid, :'account2_id'::uuid, 10000, '2026-03-03');

create temporary table t_position_after_transfer as
select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) as result;

select is(
  (select (result->>'total_financial_account_balance')::numeric from t_position_after_transfer),
  68000.00::numeric,
  'AE: the group total is unchanged by an internal transfer'
);

-- ---------------------------------------------------------------------
-- AF/AG. period income/expense correct — filtered to March only.
-- ---------------------------------------------------------------------

create temporary table t_position_march as
select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', '2026-03-01', '2026-03-31') as result;

select is(
  (select (result->>'group_income')::numeric from t_position_march),
  15000.00::numeric,
  'AF: period income for March excludes the May donation (15000, not 22000)'
);
select is(
  (select (result->>'expenses')::numeric from t_position_march),
  4000.00::numeric,
  'AG: period expense for March is exactly the March transport expense'
);

-- ---------------------------------------------------------------------
-- AH. wallet liability correct.
-- ---------------------------------------------------------------------

create temporary table t_type as
select public.rpc_create_contribution_type('fe100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset
create temporary table t_setup as
select public.rpc_create_contribution_setup('fe100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset
create temporary table t_period as
select public.rpc_create_contribution_period('fe100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15') as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('fe100000-0000-0000-0000-000000000001', :'period_id'::uuid);

select public.rpc_post_payment('fe100000-0000-0000-0000-000000000001', 'fe200000-0000-0000-0000-000000000005', :'account1_id'::uuid, 30000, '2026-07-20', 'CASH');

create temporary table t_position_wallet as
select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) as result;

select is(
  (select (result->>'member_wallet_liability')::numeric from t_position_wallet),
  10000.00::numeric,
  'AH: wallet liability correctly reflects the 10000 overpayment credit (30000 paid - 20000 charged)'
);

-- ---------------------------------------------------------------------
-- AI. outstanding member obligations correct.
-- ---------------------------------------------------------------------

create temporary table t_period2 as
select public.rpc_create_contribution_period('fe100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Agosti 2026', '2026-08-01', '2026-08-31', p_due_date => '2026-08-15') as result;
select (result->>'id')::uuid as period2_id from t_period2 \gset
select public.rpc_open_contribution_period('fe100000-0000-0000-0000-000000000001', :'period2_id'::uuid);

create temporary table t_position_outstanding as
select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) as result;

-- Opening a period charges every ACTIVE membership in the group, not
-- just the one member paying (a well-known behavior across every
-- contribution test suite in this repo) — this group has 5 ACTIVE
-- memberships (Admin/Treasurer/Chairperson/Secretary/Member), so July
-- charged 5*20000=100000 and August charges another 5*20000=100000;
-- only the Member's own July charge (20000) was ever paid. Expected
-- outstanding = 200000 - 20000 = 180000.
select is(
  (select (result->>'total_outstanding_member_obligations')::numeric from t_position_outstanding),
  180000.00::numeric,
  'AI: outstanding member obligations correctly sums every unpaid charge across every member (200000 charged - 20000 paid)'
);

-- ---------------------------------------------------------------------
-- AJ/AK. ADMIN/TREASURER intended access to financial_report.view.
-- ---------------------------------------------------------------------

select lives_ok(
  $sql$ select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) $sql$,
  'AJ: ADMIN can view the financial position report'
);

set local request.jwt.claim.sub to 'fe000000-0000-0000-0000-000000000002';
select lives_ok(
  $sql$ select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) $sql$,
  'AK: TREASURER can view the financial position report'
);

-- ---------------------------------------------------------------------
-- AL. unauthorized roles denied posting (SECRETARY has no
-- financial_income.create; MEMBER has neither).
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'fe000000-0000-0000-0000-000000000004';
select throws_ok(
  $sql$ select public.rpc_record_manual_income(
    'fe100000-0000-0000-0000-000000000001',
    (select id from public.financial_accounts where group_id = 'fe100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    (select id from public.financial_categories where group_id = 'fe100000-0000-0000-0000-000000000001' and name = 'Donation'),
    500, '2026-03-04'
  ) $sql$,
  '42501', null,
  'AL: SECRETARY (view/report only) cannot post manual income'
);

set local request.jwt.claim.sub to 'fe000000-0000-0000-0000-000000000005';
select throws_ok(
  $sql$ select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000001', null, null) $sql$,
  '42501', null,
  'AL: MEMBER (no Phase 08B operational access) cannot view the financial position report'
);

-- ---------------------------------------------------------------------
-- AM. cross-tenant reads denied — even a real ADMIN of a DIFFERENT
-- group (fe000000...001 is legitimately ADMIN of both A and B) gets
-- ONLY Group B's own (empty) data when passing Group B's id, never a
-- leaked view of Group A's accounts/income/expense.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'fe000000-0000-0000-0000-000000000001';
create temporary table t_position_group_b as
select public.rpc_get_financial_position('fe100000-0000-0000-0000-000000000002', null, null) as result;

select is(
  (select jsonb_array_length(result->'accounts') from t_position_group_b),
  0,
  'AM: Group B''s report shows zero accounts — none of Group A''s financial_accounts leak through'
);
select is(
  (select (result->>'total_financial_account_balance')::numeric from t_position_group_b),
  0.00::numeric,
  'AM: Group B''s total balance is 0, never Group A''s 68000+'
);
select is(
  (select (result->>'group_income')::numeric from t_position_group_b),
  0.00::numeric,
  'AM: Group B''s group_income is 0, never Group A''s income leaking across tenants'
);

select * from finish();
rollback;
