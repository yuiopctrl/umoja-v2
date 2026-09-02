-- Prompt 09D: ONCE and RECURRING_MONTHLY penalty frequency behavior
-- (sections 42-43, items 19-29).
begin;

select plan(13);

insert into auth.users (id, email) values
  ('64000000-0000-0000-0000-000000000001', 'p09d-freq-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('64100000-0000-0000-0000-000000000001', 'P09D Frequency Group', '64000000-0000-0000-0000-000000000001', 'PENF');

-- Each scenario below gets its OWN borrower membership. A shared
-- borrower would pool every loan's obligations into ONE combined
-- allocation plan (oldest due_date first) whenever a payment is
-- posted, silently diverting a payment intended for one loan onto an
-- unrelated loan's still-outstanding balance — never a realistic
-- confound worth introducing into these isolated scenarios.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('64200000-0000-0000-0000-000000000001', '64100000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000001', 'PF Admin', 'ACTIVE', '2025-01-01', 'PENF-2026-0001'),
  ('64200000-0000-0000-0000-000000000005', '64100000-0000-0000-0000-000000000001', null, 'PF Borrower Once', 'ACTIVE', '2025-01-01', 'PENF-2026-0005'),
  ('64200000-0000-0000-0000-000000000006', '64100000-0000-0000-0000-000000000001', null, 'PF Borrower Recurring', 'ACTIVE', '2025-01-01', 'PENF-2026-0006'),
  ('64200000-0000-0000-0000-000000000007', '64100000-0000-0000-0000-000000000001', null, 'PF Borrower Stop', 'ACTIVE', '2025-01-01', 'PENF-2026-0007'),
  ('64200000-0000-0000-0000-000000000008', '64100000-0000-0000-0000-000000000001', null, 'PF Borrower Partial', 'ACTIVE', '2025-01-01', 'PENF-2026-0008');

insert into public.group_membership_roles (group_membership_id, role_id) select '64200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '64000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '64100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- ---------------------------------------------------------------------
-- 19/20/21/22: FIXED/ONCE.
-- ---------------------------------------------------------------------

create temporary table t_product_once as
select public.rpc_create_loan_product(
  '64100000-0000-0000-0000-000000000001', 'ONCEFX', 'Once Fixed Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 5, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_once_id from t_product_once \gset

create temporary table t_loan_once as
select public.rpc_create_draft_loan_account(
  '64100000-0000-0000-0000-000000000001', '64200000-0000-0000-0000-000000000005'::uuid,
  :'product_once_id'::uuid, 200000, 2, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_once_id from t_loan_once \gset
select public.rpc_submit_loan_account('64100000-0000-0000-0000-000000000001', :'loan_once_id'::uuid);
select public.rpc_approve_loan_account('64100000-0000-0000-0000-000000000001', :'loan_once_id'::uuid);
select public.rpc_disburse_loan_account('64100000-0000-0000-0000-000000000001', :'loan_once_id'::uuid, :'account_id'::uuid, current_date);
select id as once_installment_id from public.loan_installments where loan_account_id = :'loan_once_id'::uuid and installment_number = 1 \gset

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', current_date, :'loan_once_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'once_installment_id'::uuid),
  1::bigint,
  '19: ONCE creates exactly one charge'
);

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', current_date, :'loan_once_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'once_installment_id'::uuid),
  1::bigint,
  '20: retrying the SAME assessment date creates no duplicate'
);

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', (current_date + 30), :'loan_once_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'once_installment_id'::uuid),
  1::bigint,
  '21: a LATER assessment date also creates no duplicate (ONCE is truly once)'
);

reset role;
select throws_ok(
  format($sql$ insert into public.loan_penalty_charges (
    group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
    penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
    basis_amount, fixed_amount, penalty_amount
  ) values (
    '64100000-0000-0000-0000-000000000001', %L, %L, current_date, 1,
    'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 5, 100000, 20000, 20000
  ) $sql$, :'loan_once_id', :'once_installment_id'),
  '23505',
  null,
  '22: a direct duplicate (installment_id, sequence_number) insert is structurally blocked by the unique index'
);
set local role authenticated;
set local request.jwt.claim.sub to '64000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 23/24/25/26/29: PERCENTAGE/RECURRING_MONTHLY, month-safe anchoring.
-- Fixed historical due_date (2024-01-31, grace_days=0) so occurrence
-- anchors land on Jan 31 -> Feb 29 (2024 is a leap year) -> Mar 31 —
-- a fixed-30-day-drift model would instead give Mar 1 / Mar 31 (item
-- 26 fails to match a 30-day model at occurrence 2 specifically).
-- ---------------------------------------------------------------------

create temporary table t_product_recurring as
select public.rpc_create_loan_product(
  '64100000-0000-0000-0000-000000000001', 'RECPCT', 'Recurring Percentage Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'RECURRING_MONTHLY',
  p_penalty_grace_days => 0, p_penalty_rate => 5.0
) as result;
select (result->>'id')::uuid as product_recurring_id from t_product_recurring \gset

create temporary table t_loan_recurring as
select public.rpc_create_draft_loan_account(
  '64100000-0000-0000-0000-000000000001', '64200000-0000-0000-0000-000000000006'::uuid,
  :'product_recurring_id'::uuid, 200000, 1, '2024-01-31'::date
) as result;
select (result->>'id')::uuid as loan_recurring_id from t_loan_recurring \gset
select public.rpc_submit_loan_account('64100000-0000-0000-0000-000000000001', :'loan_recurring_id'::uuid);
select public.rpc_approve_loan_account('64100000-0000-0000-0000-000000000001', :'loan_recurring_id'::uuid);
select public.rpc_disburse_loan_account('64100000-0000-0000-0000-000000000001', :'loan_recurring_id'::uuid, :'account_id'::uuid, current_date);
select id as recurring_installment_id from public.loan_installments where loan_account_id = :'loan_recurring_id'::uuid \gset

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', '2024-02-05'::date, :'loan_recurring_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid),
  1::bigint,
  '23: recurring occurrence 1 is assessed once grace expires'
);
select is(
  (select assessment_date from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid and sequence_number = 1),
  '2024-01-31'::date,
  '23b: occurrence 1 is anchored to due_date + grace_days exactly'
);

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', '2024-02-05'::date, :'loan_recurring_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid),
  1::bigint,
  '24: retrying the same occurrence''s window creates no duplicate'
);

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', '2024-03-05'::date, :'loan_recurring_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid),
  2::bigint,
  '25: the next monthly occurrence is assessed once its own window arrives'
);
select is(
  (select assessment_date from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid and sequence_number = 2),
  '2024-02-29'::date,
  '26: occurrence 2 anchors to Jan 31 + 1 calendar month = Feb 29 (2024 leap year) — NOT a fixed-30-day drift (which would land on Mar 1)'
);

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', '2024-04-05'::date, :'loan_recurring_id'::uuid);
select is(
  (select assessment_date from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid and sequence_number = 3),
  '2024-03-31'::date,
  '26b: occurrence 3 anchors to Jan 31 + 2 calendar months = Mar 31, confirming month-safe (non-cumulative-drift) anchoring'
);
select is(
  (select array_agg(sequence_number order by assessment_date) from public.loan_penalty_charges where loan_installment_id = :'recurring_installment_id'::uuid),
  array[1, 2, 3],
  '29: recurring occurrence sequence numbers are deterministic (1, 2, 3 — no gaps, no duplicates)'
);

-- ---------------------------------------------------------------------
-- 27: a fully-paid installment stops all further recurring occurrences.
-- ---------------------------------------------------------------------

create temporary table t_loan_stop as
select public.rpc_create_draft_loan_account(
  '64100000-0000-0000-0000-000000000001', '64200000-0000-0000-0000-000000000007'::uuid,
  :'product_recurring_id'::uuid, 200000, 1, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_stop_id from t_loan_stop \gset
select public.rpc_submit_loan_account('64100000-0000-0000-0000-000000000001', :'loan_stop_id'::uuid);
select public.rpc_approve_loan_account('64100000-0000-0000-0000-000000000001', :'loan_stop_id'::uuid);
select public.rpc_disburse_loan_account('64100000-0000-0000-0000-000000000001', :'loan_stop_id'::uuid, :'account_id'::uuid, current_date);
select id as stop_installment_id, (principal_due + interest_due) as stop_total
  from public.loan_installments where loan_account_id = :'loan_stop_id'::uuid \gset

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', current_date, :'loan_stop_id'::uuid);
select coalesce(sum(penalty_amount), 0) as stop_penalty_total
  from public.loan_penalty_charges where loan_installment_id = :'stop_installment_id'::uuid \gset
-- Priority is PENALTY -> INTEREST -> PRINCIPAL, so the payment must
-- cover the ALREADY-ASSESSED penalties too, not merely the contractual
-- principal+interest, in order to genuinely drive basis_amount to zero.
select public.rpc_post_payment(
  '64100000-0000-0000-0000-000000000001', '64200000-0000-0000-0000-000000000007'::uuid, :'account_id'::uuid,
  (:'stop_total'::numeric + :'stop_penalty_total'::numeric), current_date, 'CASH'
);
select count(*) as stop_count_before from public.loan_penalty_charges where loan_installment_id = :'stop_installment_id'::uuid \gset
select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', (current_date + 60), :'loan_stop_id'::uuid);

select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'stop_installment_id'::uuid),
  :'stop_count_before'::bigint,
  '27: once principal+interest are fully settled, no FURTHER recurring occurrence is ever created'
);

-- ---------------------------------------------------------------------
-- 28: a partially-paid installment continues to accrue recurring
-- occurrences.
-- ---------------------------------------------------------------------

create temporary table t_loan_partial as
select public.rpc_create_draft_loan_account(
  '64100000-0000-0000-0000-000000000001', '64200000-0000-0000-0000-000000000008'::uuid,
  :'product_recurring_id'::uuid, 200000, 1, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_partial_id from t_loan_partial \gset
select public.rpc_submit_loan_account('64100000-0000-0000-0000-000000000001', :'loan_partial_id'::uuid);
select public.rpc_approve_loan_account('64100000-0000-0000-0000-000000000001', :'loan_partial_id'::uuid);
select public.rpc_disburse_loan_account('64100000-0000-0000-0000-000000000001', :'loan_partial_id'::uuid, :'account_id'::uuid, current_date);
select id as partial_installment_id from public.loan_installments where loan_account_id = :'loan_partial_id'::uuid \gset

select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', current_date, :'loan_partial_id'::uuid);
select public.rpc_post_payment(
  '64100000-0000-0000-0000-000000000001', '64200000-0000-0000-0000-000000000008'::uuid, :'account_id'::uuid,
  1000, current_date, 'CASH'
);
select public.rpc_assess_loan_penalties('64100000-0000-0000-0000-000000000001', (current_date + 32), :'loan_partial_id'::uuid);

select ok(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'partial_installment_id'::uuid) >= 2,
  '28: a partially-paid, still-overdue installment continues to accrue further recurring occurrences'
);

select * from finish();
rollback;
