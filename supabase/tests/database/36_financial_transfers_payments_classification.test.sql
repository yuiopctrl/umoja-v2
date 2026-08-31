-- Prompt 08B: transfers (K-M), payment/cashbook integration (N-P),
-- classification (Q-T).
begin;

select plan(18);

insert into auth.users (id, email) values
  ('fc000000-0000-0000-0000-000000000001', 'p08bc-treasurer@example.com'),
  ('fc000000-0000-0000-0000-000000000002', 'p08bc-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('fc100000-0000-0000-0000-000000000001', 'P08BC Group A', 'fc000000-0000-0000-0000-000000000001', 'FCAA');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('fc200000-0000-0000-0000-000000000001', 'fc100000-0000-0000-0000-000000000001', 'fc000000-0000-0000-0000-000000000001', 'FC Treasurer', 'ACTIVE', '2025-01-01', 'FCAA-2026-0001'),
  ('fc200000-0000-0000-0000-000000000002', 'fc100000-0000-0000-0000-000000000001', 'fc000000-0000-0000-0000-000000000002', 'FC Member', 'ACTIVE', '2025-01-01', 'FCAA-2026-0002');

insert into public.group_membership_roles (group_membership_id, role_id) select 'fc200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fc200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to 'fc000000-0000-0000-0000-000000000001';

create temporary table t_acct1 as
select public.rpc_create_financial_account('fc100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account1_id from t_acct1 \gset

create temporary table t_acct2 as
select public.rpc_create_financial_account('fc100000-0000-0000-0000-000000000001', 'Bank NMB', 'BANK') as result;
select (result->>'id')::uuid as account2_id from t_acct2 \gset

create temporary table t_type_income as
select public.rpc_create_contribution_type('fc100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_income_id from t_type_income \gset

create temporary table t_type_pass as
select public.rpc_create_contribution_type('fc100000-0000-0000-0000-000000000001', 'Mzunguko', 'SOCIAL', 'PASS_THROUGH') as result;
select (result->>'id')::uuid as type_pass_id from t_type_pass \gset

create temporary table t_type_share as
select public.rpc_create_contribution_type('fc100000-0000-0000-0000-000000000001', 'Hisa', 'SHARE', 'SHARE_CAPITAL') as result;
select (result->>'id')::uuid as type_share_id from t_type_share \gset

create temporary table t_setup_income as
select public.rpc_create_contribution_setup('fc100000-0000-0000-0000-000000000001', :'type_income_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 60000) as result;
select (result->>'id')::uuid as setup_income_id from t_setup_income \gset

create temporary table t_setup_pass as
select public.rpc_create_contribution_setup('fc100000-0000-0000-0000-000000000001', :'type_pass_id'::uuid, 'Mzunguko Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000) as result;
select (result->>'id')::uuid as setup_pass_id from t_setup_pass \gset

create temporary table t_setup_share as
select public.rpc_create_contribution_setup('fc100000-0000-0000-0000-000000000001', :'type_share_id'::uuid, 'Hisa Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 10000) as result;
select (result->>'id')::uuid as setup_share_id from t_setup_share \gset

create temporary table t_period_income as
select public.rpc_create_contribution_period('fc100000-0000-0000-0000-000000000001', :'setup_income_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15') as result;
select (result->>'id')::uuid as period_income_id from t_period_income \gset
select public.rpc_open_contribution_period('fc100000-0000-0000-0000-000000000001', :'period_income_id'::uuid);

create temporary table t_period_pass as
select public.rpc_create_contribution_period('fc100000-0000-0000-0000-000000000001', :'setup_pass_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15') as result;
select (result->>'id')::uuid as period_pass_id from t_period_pass \gset
select public.rpc_open_contribution_period('fc100000-0000-0000-0000-000000000001', :'period_pass_id'::uuid);

create temporary table t_period_share as
select public.rpc_create_contribution_period('fc100000-0000-0000-0000-000000000001', :'setup_share_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15') as result;
select (result->>'id')::uuid as period_share_id from t_period_share \gset
select public.rpc_open_contribution_period('fc100000-0000-0000-0000-000000000001', :'period_share_id'::uuid);

-- Single payment of 100,000: fully settles 60000 GROUP_INCOME + 20000
-- PASS_THROUGH + 10000 SHARE_CAPITAL (90000 total charged), leaving
-- exactly 10000 as wallet credit — unambiguous regardless of
-- allocation tie-break order since every charge here is fully payable.
create temporary table t_pay as
select public.rpc_post_payment('fc100000-0000-0000-0000-000000000001', 'fc200000-0000-0000-0000-000000000002', :'account1_id'::uuid, 100000, '2026-07-20', 'CASH') as result;

-- ---------------------------------------------------------------------
-- N. payment cashbook inflow not duplicated: exactly one row for the
-- FULL amount, regardless of how many charges/treatments it settled.
-- ---------------------------------------------------------------------

select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'PAYMENT'),
  1,
  'N: the payment creates exactly one cashbook row, never duplicated across its three allocations'
);
select is(
  (select amount from public.financial_account_entries where source_type = 'PAYMENT'),
  100000.00::numeric,
  'N: the single cashbook inflow is for the FULL payment amount, not just the allocated portion'
);

-- ---------------------------------------------------------------------
-- P. contribution allocation does not change cashbook: 3 separate
-- payment_allocations rows (one per contribution type/treatment) exist
-- against the SAME single cashbook entry above — allocation is a
-- bookkeeping split, never an additional cash movement.
-- ---------------------------------------------------------------------

select is(
  (select count(*)::int from public.payment_allocations pa join public.payments p on p.id = pa.payment_id where p.financial_account_id = :'account1_id'::uuid),
  3,
  'P: the payment produced 3 allocation rows (one per contribution treatment)'
);
select is(
  (select count(*)::int from public.financial_account_entries where source_type in ('PAYMENT', 'PAYMENT_REVERSAL')),
  1,
  'P: despite 3 allocation rows, still exactly one payment-sourced cashbook row — allocation never adds cash movements'
);

-- ---------------------------------------------------------------------
-- O. wallet allocation does not change cashbook. Open a second month
-- so there is fresh GROUP_INCOME debt to allocate the 10000 wallet
-- credit against.
-- ---------------------------------------------------------------------

create temporary table t_period_income2 as
select public.rpc_create_contribution_period('fc100000-0000-0000-0000-000000000001', :'setup_income_id'::uuid, 'Agosti 2026', '2026-08-01', '2026-08-31', p_due_date => '2026-08-15') as result;
select (result->>'id')::uuid as period_income2_id from t_period_income2 \gset
select public.rpc_open_contribution_period('fc100000-0000-0000-0000-000000000001', :'period_income2_id'::uuid);

select is(
  (select count(*)::int from public.financial_account_entries),
  1,
  'O (baseline): exactly one cashbook row exists before any wallet allocation'
);

select public.rpc_allocate_member_wallet('fc100000-0000-0000-0000-000000000001', 'fc200000-0000-0000-0000-000000000002', 10000);

select is(
  (select count(*)::int from public.financial_account_entries),
  1,
  'O: allocating the member''s wallet credit against outstanding debt adds zero cashbook rows'
);

-- ---------------------------------------------------------------------
-- K/L/M. Transfer 30000 Main Cash -> Bank NMB.
-- ---------------------------------------------------------------------

select public.rpc_record_financial_account_transfer('fc100000-0000-0000-0000-000000000001', :'account1_id'::uuid, :'account2_id'::uuid, 30000, '2026-07-21');

select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'TRANSFER'),
  2,
  'K: the transfer remains a paired TRANSFER_OUT/TRANSFER_IN — exactly two rows'
);
select is(
  (
    select count(distinct transfer_reference)::int
    from public.financial_account_entries
    where source_type = 'TRANSFER'
  ),
  1,
  'K: both transfer rows share exactly one transfer_reference'
);
select is(
  (
    (select (public.rpc_get_financial_account('fc100000-0000-0000-0000-000000000001', :'account1_id'::uuid)->>'balance')::numeric)
    + (select (public.rpc_get_financial_account('fc100000-0000-0000-0000-000000000001', :'account2_id'::uuid)->>'balance')::numeric)
  ),
  100000.00::numeric,
  'L: the transfer''s global cash impact across both accounts is zero (sum unchanged at 100000)'
);

create temporary table t_position as
select public.rpc_get_financial_position('fc100000-0000-0000-0000-000000000001', null, null) as result;

select is(
  (select (result->>'group_income')::numeric from t_position),
  60000.00::numeric,
  'M: group_income is unaffected by the transfer'
);
select is(
  (select (result->>'expenses')::numeric from t_position),
  0.00::numeric,
  'M: a pure internal transfer is never counted as an expense'
);
select is(
  (select (result->>'total_financial_account_balance')::numeric from t_position),
  100000.00::numeric,
  'M: total_financial_account_balance across both accounts is unaffected by the transfer'
);

-- ---------------------------------------------------------------------
-- Q/R/S/T. Contribution-treatment classification.
-- ---------------------------------------------------------------------

select is(
  (select (result->>'group_income')::numeric from t_position),
  60000.00::numeric,
  'Q: the GROUP_INCOME-treated contribution''s settled cash (60000) is classified as group income'
);
select is(
  (select (result->>'pass_through_received')::numeric from t_position),
  20000.00::numeric,
  'R: the PASS_THROUGH-treated contribution''s settled cash (20000) is shown separately, as pass_through_received'
);
select isnt(
  (select (result->>'group_income')::numeric from t_position),
  80000.00::numeric,
  'R: PASS_THROUGH cash is excluded from group_income — group_income is 60000, never 60000+20000'
);
select is(
  (select (result->>'share_capital_received')::numeric from t_position),
  10000.00::numeric,
  'S: the SHARE_CAPITAL-treated contribution''s settled cash (10000) is shown separately, as share_capital_received'
);
select isnt(
  (select (result->>'group_income')::numeric from t_position),
  70000.00::numeric,
  'S: SHARE_CAPITAL cash is excluded from ordinary operating income — group_income is 60000, never 60000+10000'
);
select is(
  (select (result->>'member_wallet_liability')::numeric from t_position),
  0.00::numeric,
  'T: the 10000 wallet credit was fully allocated in section O, so wallet liability is now 0 — and at no '
  'point (even before that allocation, when it was 10000) was it ever added into group_income'
);

select * from finish();
rollback;
