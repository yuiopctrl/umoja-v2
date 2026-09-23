-- Prompt 09F-A: explicit regression coverage (test matrix items 49, 50)
-- — contribution accounting and ordinary loan repayment must behave
-- identically after the 09F-A schema/RPC changes, for a loan/group that
-- never touches any waiver/correction at all. (The full pre-existing
-- 1,315-test suite re-passing unmodified against these migrations is
-- the broader proof; this file adds named, itemized assertions for
-- both paths specifically.)
begin;

select plan(5);

insert into auth.users (id, email) values
  ('89000000-0000-0000-0000-000000000001', 'p09fa-regression-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('89100000-0000-0000-0000-000000000001', 'Regression Group', '89000000-0000-0000-0000-000000000001', 'REGR');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('89200000-0000-0000-0000-000000000001', '89100000-0000-0000-0000-000000000001', '89000000-0000-0000-0000-000000000001', 'Regression Admin', 'ACTIVE', '2025-01-01', 'REGR-2026-0001'),
  ('89200000-0000-0000-0000-000000000011', '89100000-0000-0000-0000-000000000001', null, 'Contribution Member', 'ACTIVE', '2025-01-01', 'REGR-2026-0011'),
  ('89200000-0000-0000-0000-000000000012', '89100000-0000-0000-0000-000000000001', null, 'Loan Borrower', 'ACTIVE', '2025-01-01', 'REGR-2026-0012');

insert into public.group_membership_roles (group_membership_id, role_id) select '89200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '89000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '89100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- =======================================================================
-- Item 49: contribution accounting is completely unaffected.
-- =======================================================================

create temporary table t_type as
select public.rpc_create_contribution_type('89100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  '89100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  '89100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Regression Period', current_date, (current_date + interval '1 month')::date,
  p_due_date => current_date
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('89100000-0000-0000-0000-000000000001', :'period_id'::uuid);

select id as charge_id from public.member_contribution_charges
  where period_id = :'period_id'::uuid and membership_id = '89200000-0000-0000-0000-000000000011' \gset

select public.rpc_post_payment(
  '89100000-0000-0000-0000-000000000001', '89200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid,
  20000, current_date, 'CASH'
);

reset role;
select public.contribution_charge_net_assessed(:'charge_id'::uuid) as net_assessed \gset
select coalesce(sum(outstanding), 0) as contribution_outstanding from public.contribution_charge_component_states(:'charge_id'::uuid) \gset
set local role authenticated;
set local request.jwt.claim.sub to '89000000-0000-0000-0000-000000000001';

select is(
  :'net_assessed'::numeric,
  20000.00::numeric,
  '49a: contribution net-assessed calculation is unaffected by the 09F-A loan changes'
);

select is(
  :'contribution_outstanding'::numeric,
  0.00::numeric,
  '49b: a contribution charge paid in full still shows zero outstanding'
);

select is(
  (public.rpc_get_financial_position('89100000-0000-0000-0000-000000000001')->>'group_income')::numeric > 0,
  true,
  '49c: contribution income recognition is unaffected'
);

-- =======================================================================
-- Item 50: an ordinary loan repayment with NO penalty/interest/waiver
-- involved at all closes exactly as it did before 09F-A.
-- =======================================================================

create temporary table t_product as
select public.rpc_create_loan_product(
  '89100000-0000-0000-0000-000000000001', 'REGP', 'Regression Loan Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '89100000-0000-0000-0000-000000000001', '89200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('89100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('89100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('89100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select interest_due, principal_due from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select public.rpc_post_payment(
  '89100000-0000-0000-0000-000000000001', '89200000-0000-0000-0000-000000000012'::uuid, :'account_id'::uuid,
  :interest_due + :principal_due, current_date, 'CASH'
);

select is(
  (select status from public.loan_accounts where id = :'loan_id'::uuid),
  'CLOSED',
  '50a: an ordinary loan with no adjustments closes exactly as before once fully repaid'
);
select is(
  (select count(*)::integer from public.loan_obligation_adjustments where loan_account_id = :'loan_id'::uuid),
  0,
  '50b: zero loan_obligation_adjustments rows exist for a loan that never used the feature'
);

select * from finish();
rollback;
