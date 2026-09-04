-- Prompt 09E: dedicated security audit for the loan-servicing
-- foundation — tenant isolation, helper privilege checks, direct-
-- table-write protection, controlled SECURITY DEFINER search_path.
begin;

select plan(15);

insert into auth.users (id, email) values
  ('77000000-0000-0000-0000-000000000001', 'p09e-security-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('77100000-0000-0000-0000-000000000001', 'Servicing Security Group', '77000000-0000-0000-0000-000000000001', 'SSEC'),
  ('77100000-0000-0000-0000-000000000002', 'Servicing Security Other Group', '77000000-0000-0000-0000-000000000001', 'SSECB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('77200000-0000-0000-0000-000000000001', '77100000-0000-0000-0000-000000000001', '77000000-0000-0000-0000-000000000001', 'SS Admin', 'ACTIVE', '2025-01-01', 'SSEC-2026-0001'),
  ('77200000-0000-0000-0000-000000000002', '77100000-0000-0000-0000-000000000001', null, 'SS Borrower', 'ACTIVE', '2025-01-01', 'SSEC-2026-0002');

insert into public.group_membership_roles (group_membership_id, role_id) select '77200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

-- ---------------------------------------------------------------------
-- Direct-table-write protection (as the unauthenticated/table-grant
-- level, independent of any RPC) — pure schema/ACL facts.
-- ---------------------------------------------------------------------

select is(
  has_table_privilege('authenticated', 'public.loan_prepayment_events', 'INSERT'),
  false,
  '1: authenticated cannot INSERT into loan_prepayment_events directly'
);
select is(
  has_table_privilege('authenticated', 'public.loan_prepayment_events', 'UPDATE'),
  false,
  '2: authenticated cannot UPDATE loan_prepayment_events directly'
);
select is(
  has_table_privilege('authenticated', 'public.loan_prepayment_events', 'DELETE'),
  false,
  '3: authenticated cannot DELETE loan_prepayment_events directly'
);
select is(
  has_table_privilege('authenticated', 'public.loan_restructure_events', 'INSERT'),
  false,
  '4: authenticated cannot INSERT into loan_restructure_events directly'
);
select is(
  has_table_privilege('authenticated', 'public.loan_restructure_events', 'UPDATE'),
  false,
  '5: authenticated cannot UPDATE loan_restructure_events directly'
);
select is(
  has_table_privilege('authenticated', 'public.loan_installments', 'UPDATE'),
  false,
  '6: authenticated cannot UPDATE loan_installments directly (cancellation only via RPC)'
);
select is(
  has_table_privilege('anon', 'public.loan_prepayment_events', 'SELECT'),
  false,
  '7: anon has no read access to loan_prepayment_events'
);

-- ---------------------------------------------------------------------
-- Helper privilege checks — internal helpers must never be directly
-- executable by authenticated/anon.
-- ---------------------------------------------------------------------

select is(
  has_function_privilege('authenticated', 'public.loan_compute_early_settlement_plan(uuid, date)', 'execute'),
  false,
  '8: loan_compute_early_settlement_plan is not directly executable by authenticated'
);
select is(
  has_function_privilege('authenticated', 'public.loan_prepayment_eligibility(uuid, date)', 'execute'),
  false,
  '9: loan_prepayment_eligibility is not directly executable by authenticated'
);
select is(
  has_function_privilege('authenticated', 'public.loan_schedule_compute_fixed_principal(numeric, numeric, numeric, public.loan_interest_rate_basis, public.loan_interest_method, date)', 'execute'),
  false,
  '10: loan_schedule_compute_fixed_principal is not directly executable by authenticated'
);
select is(
  has_function_privilege('anon', 'public.loan_compute_early_settlement_plan(uuid, date)', 'execute'),
  false,
  '11: loan_compute_early_settlement_plan is not directly executable by anon'
);

-- ---------------------------------------------------------------------
-- Public RPC grants + controlled SECURITY DEFINER search_path.
-- ---------------------------------------------------------------------

select is(
  has_function_privilege('authenticated', 'public.rpc_settle_loan_early(uuid, uuid, uuid, public.payment_method, date, text, text, text)', 'execute'),
  true,
  '12: rpc_settle_loan_early is executable by authenticated'
);
select is(
  has_function_privilege('anon', 'public.rpc_prepay_loan_principal(uuid, uuid, numeric, public.loan_reschedule_treatment, uuid, public.payment_method, date, text, text, text)', 'execute'),
  false,
  '13: rpc_prepay_loan_principal is never executable by anon'
);
select ok(
  (
    select proconfig @> array['search_path=""']
    from pg_proc
    where oid = 'public.rpc_restructure_loan(uuid, uuid, text, integer, date, numeric, date)'::regprocedure
  ),
  '14: rpc_restructure_loan runs with a controlled empty search_path'
);

-- ---------------------------------------------------------------------
-- Tenant isolation — a group-2 admin (with the servicing permissions)
-- cannot reach a loan that belongs to group 1.
-- ---------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claim.sub to '77000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '77100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '77100000-0000-0000-0000-000000000001', 'SSP', 'Security Product', 100000, 1, 12, 2.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '77100000-0000-0000-0000-000000000001', '77200000-0000-0000-0000-000000000002'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('77100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('77100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('77100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

-- Give the same admin an ADMIN membership in group 2 too, so the
-- following calls fail on TENANT ISOLATION (loan not found in group),
-- never merely on missing permission.
reset role;
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('77200000-0000-0000-0000-000000000010', '77100000-0000-0000-0000-000000000002', '77000000-0000-0000-0000-000000000001', 'SS Admin in Other Group', 'ACTIVE', '2025-01-01', 'SSECB-2026-0010');
insert into public.group_membership_roles (group_membership_id, role_id) select '77200000-0000-0000-0000-000000000010', id from public.roles where code = 'ADMIN';
set local role authenticated;
set local request.jwt.claim.sub to '77000000-0000-0000-0000-000000000001';

select throws_ok(
  format($sql$ select public.rpc_settle_loan_early(%L::uuid, %L::uuid, %L::uuid, 'CASH') $sql$,
    '77100000-0000-0000-0000-000000000002', :'loan_id', :'account_id'),
  '22023',
  'Loan account not found in group',
  '15: settling a loan under a mismatched (but authorized) group_id is rejected by tenant isolation'
);

select * from finish();
rollback;
