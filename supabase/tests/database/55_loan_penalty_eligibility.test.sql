-- Prompt 09D: loan penalty ELIGIBILITY (section 41, items 8-18).
begin;

select plan(14);

insert into auth.users (id, email) values
  ('63000000-0000-0000-0000-000000000001', 'p09d-elig-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('63100000-0000-0000-0000-000000000001', 'P09D Eligibility Group', '63000000-0000-0000-0000-000000000001', 'PENE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('63200000-0000-0000-0000-000000000001', '63100000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000001', 'PE Admin', 'ACTIVE', '2025-01-01', 'PENE-2026-0001'),
  ('63200000-0000-0000-0000-000000000005', '63100000-0000-0000-0000-000000000001', null, 'PE Borrower', 'ACTIVE', '2025-01-01', 'PENE-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '63200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '63000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '63100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '63100000-0000-0000-0000-000000000001', 'PENFX2', 'Penalty Fixed Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 5, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- 8/9/10: DRAFT/SUBMITTED/APPROVED never assessed, however overdue the
-- planned schedule is.
-- ---------------------------------------------------------------------

create temporary table t_draft as
select public.rpc_create_draft_loan_account(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 2, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as draft_id from t_draft \gset

create temporary table t_assess_draft as
select public.rpc_assess_loan_penalties('63100000-0000-0000-0000-000000000001', current_date, :'draft_id'::uuid) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_draft),
  0,
  '8: a DRAFT loan is never assessed'
);

select public.rpc_submit_loan_account('63100000-0000-0000-0000-000000000001', :'draft_id'::uuid);
create temporary table t_assess_submitted as
select public.rpc_assess_loan_penalties('63100000-0000-0000-0000-000000000001', current_date, :'draft_id'::uuid) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_submitted),
  0,
  '9: a SUBMITTED loan is never assessed'
);

select public.rpc_approve_loan_account('63100000-0000-0000-0000-000000000001', :'draft_id'::uuid);
create temporary table t_assess_approved as
select public.rpc_assess_loan_penalties('63100000-0000-0000-0000-000000000001', current_date, :'draft_id'::uuid) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_approved),
  0,
  '10: an APPROVED loan is never assessed'
);

-- ---------------------------------------------------------------------
-- 11/13/14/15: ACTIVE eligible, boundary grace-day handling, future
-- installment excluded. A fresh single-installment loan due exactly
-- 10 days from now, grace_days=5: threshold = due_date + 5.
-- ---------------------------------------------------------------------

create temporary table t_boundary_loan as
select public.rpc_create_draft_loan_account(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 100000, 1, (current_date + interval '10 days')::date
) as result;
select (result->>'id')::uuid as boundary_loan_id from t_boundary_loan \gset
select public.rpc_submit_loan_account('63100000-0000-0000-0000-000000000001', :'boundary_loan_id'::uuid);
select public.rpc_approve_loan_account('63100000-0000-0000-0000-000000000001', :'boundary_loan_id'::uuid);
select public.rpc_disburse_loan_account('63100000-0000-0000-0000-000000000001', :'boundary_loan_id'::uuid, :'account_id'::uuid, current_date);
select id as boundary_installment_id, due_date as boundary_due_date
  from public.loan_installments where loan_account_id = :'boundary_loan_id'::uuid \gset

-- 13: assessing today (well before due_date) creates nothing.
create temporary table t_assess_future as
select public.rpc_assess_loan_penalties('63100000-0000-0000-0000-000000000001', current_date, :'boundary_loan_id'::uuid) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_future),
  0,
  '13: a future (not-yet-due) installment is never penalized'
);

-- 14: assessing exactly at due_date + grace_days (still inside grace,
-- inclusive boundary) creates nothing.
create temporary table t_assess_in_grace as
select public.rpc_assess_loan_penalties(
  '63100000-0000-0000-0000-000000000001', (:'boundary_due_date'::date + 5), :'boundary_loan_id'::uuid
) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_in_grace),
  0,
  '14: due_date + grace_days is still inside grace — excluded'
);

-- 15/11: the very first day after grace expires is eligible, and an
-- ACTIVE loan's installment is genuinely assessed.
create temporary table t_assess_after_grace as
select public.rpc_assess_loan_penalties(
  '63100000-0000-0000-0000-000000000001', (:'boundary_due_date'::date + 6), :'boundary_loan_id'::uuid
) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_after_grace),
  1,
  '15: due_date + grace_days + 1 is the first eligible day — assessed'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'boundary_installment_id'::uuid),
  1::bigint,
  '11: an ACTIVE loan''s installment receives exactly one penalty charge once eligible'
);

-- ---------------------------------------------------------------------
-- 12: a CLOSED loan (principal+interest+penalty all settled) is never
-- assessed again, even if somehow re-run.
-- ---------------------------------------------------------------------

create temporary table t_post_full as
select public.rpc_post_payment(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  125000, (:'boundary_due_date'::date + 6), 'CASH'
) as result;

select is(
  (select status::text from public.loan_accounts where id = :'boundary_loan_id'::uuid),
  'CLOSED',
  'setup: the boundary loan is now fully settled and CLOSED'
);

create temporary table t_assess_closed as
select public.rpc_assess_loan_penalties(
  '63100000-0000-0000-0000-000000000001', (:'boundary_due_date'::date + 40), :'boundary_loan_id'::uuid
) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_closed),
  0,
  '12: a CLOSED loan is never assessed, however much time has passed'
);

-- ---------------------------------------------------------------------
-- 16/17: a multi-installment loan where installment 1 is fully settled
-- (excluded) but installment 2 is only partially paid and overdue
-- (still eligible, using the REMAINING outstanding as basis).
-- ---------------------------------------------------------------------

create temporary table t_multi_loan as
select public.rpc_create_draft_loan_account(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 2, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as multi_loan_id from t_multi_loan \gset
select public.rpc_submit_loan_account('63100000-0000-0000-0000-000000000001', :'multi_loan_id'::uuid);
select public.rpc_approve_loan_account('63100000-0000-0000-0000-000000000001', :'multi_loan_id'::uuid);
select public.rpc_disburse_loan_account('63100000-0000-0000-0000-000000000001', :'multi_loan_id'::uuid, :'account_id'::uuid, current_date);

select id as m_installment_1_id from public.loan_installments where loan_account_id = :'multi_loan_id'::uuid and installment_number = 1 \gset
select id as m_installment_2_id from public.loan_installments where loan_account_id = :'multi_loan_id'::uuid and installment_number = 2 \gset
select (principal_due + interest_due) as m_installment_1_total from public.loan_installments where id = :'m_installment_1_id'::uuid \gset

-- Fully settle installment 1 (partial payment, allocated to the OLDEST
-- obligation first — the whole amount lands on installment 1).
select public.rpc_post_payment(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  :'m_installment_1_total'::numeric, current_date, 'CASH'
);

-- Partially pay installment 2 (10,000 of its total).
select public.rpc_post_payment(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  10000, current_date, 'CASH'
);

create temporary table t_assess_multi as
select public.rpc_assess_loan_penalties(
  '63100000-0000-0000-0000-000000000001', current_date, :'multi_loan_id'::uuid
) as result;

select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'m_installment_1_id'::uuid),
  0::bigint,
  '16: a fully-settled installment is never penalized'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'m_installment_2_id'::uuid),
  1::bigint,
  '17: a partially-paid, overdue installment is still eligible'
);
reset role;
select is(
  (select basis_amount from public.loan_penalty_charges where loan_installment_id = :'m_installment_2_id'::uuid),
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'m_installment_2_id'::uuid) where component_type in ('INTEREST', 'PRINCIPAL')),
  '17b: the penalty basis is the CURRENT (post-partial-payment) outstanding, never the original scheduled amount'
);
set local role authenticated;
set local request.jwt.claim.sub to '63000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 18: existing penalty is never included in the basis of a LATER
-- occurrence. A RECURRING_MONTHLY PERCENTAGE product with a due date
-- far enough in the past that one assessment run catches up TWO
-- occurrences at once (no intervening payment, so the underlying
-- principal+interest outstanding is identical for both) — occurrence
-- 2's basis_amount must equal occurrence 1's, proving the first
-- occurrence's penalty was never folded into the second's basis.
-- ---------------------------------------------------------------------

create temporary table t_product_recurring as
select public.rpc_create_loan_product(
  '63100000-0000-0000-0000-000000000001', 'PENPCT', 'Penalty Percentage Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'RECURRING_MONTHLY',
  p_penalty_grace_days => 3, p_penalty_rate => 5.0
) as result;
select (result->>'id')::uuid as product_recurring_id from t_product_recurring \gset

create temporary table t_recurring_loan as
select public.rpc_create_draft_loan_account(
  '63100000-0000-0000-0000-000000000001', '63200000-0000-0000-0000-000000000005'::uuid,
  :'product_recurring_id'::uuid, 200000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as recurring_loan_id from t_recurring_loan \gset
select public.rpc_submit_loan_account('63100000-0000-0000-0000-000000000001', :'recurring_loan_id'::uuid);
select public.rpc_approve_loan_account('63100000-0000-0000-0000-000000000001', :'recurring_loan_id'::uuid);
select public.rpc_disburse_loan_account('63100000-0000-0000-0000-000000000001', :'recurring_loan_id'::uuid, :'account_id'::uuid, current_date);
select id as recurring_installment_id from public.loan_installments where loan_account_id = :'recurring_loan_id'::uuid \gset

select public.rpc_assess_loan_penalties('63100000-0000-0000-0000-000000000001', current_date, :'recurring_loan_id'::uuid);

select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid),
  2::bigint,
  'setup: two months elapsed since grace expired -> two recurring occurrences caught up in one run'
);
select is(
  (select basis_amount from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid and sequence_number = 1),
  (select basis_amount from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid and sequence_number = 2),
  '18: occurrence 2''s basis equals occurrence 1''s — the first occurrence''s penalty is never folded into the second''s basis (no penalty-on-penalty)'
);

select * from finish();
rollback;
