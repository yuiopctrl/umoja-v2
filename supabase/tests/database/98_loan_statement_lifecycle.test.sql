-- Prompt 09G-02: rpc_get_loan_statement — ordinary lifecycle coverage
-- (test matrix scenarios 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
-- 15, 16).
begin;

select plan(32);

insert into auth.users (id, email) values
  ('98000000-0000-0000-0000-000000000001', 'p09g-stmt-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('98100000-0000-0000-0000-000000000001', 'Statement Group', '98000000-0000-0000-0000-000000000001', 'STMT');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('98200000-0000-0000-0000-000000000001', '98100000-0000-0000-0000-000000000001', '98000000-0000-0000-0000-000000000001', 'Statement Admin', 'ACTIVE', '2025-01-01', 'STMT-2026-0001'),
  ('98200000-0000-0000-0000-000000000011', '98100000-0000-0000-0000-000000000001', null, 'Statement Borrower A', 'ACTIVE', '2025-01-01', 'STMT-2026-0011'),
  ('98200000-0000-0000-0000-000000000012', '98100000-0000-0000-0000-000000000001', null, 'Statement Borrower B', 'ACTIVE', '2025-01-01', 'STMT-2026-0012'),
  ('98200000-0000-0000-0000-000000000013', '98100000-0000-0000-0000-000000000001', null, 'Statement Borrower C', 'ACTIVE', '2025-01-01', 'STMT-2026-0013'),
  ('98200000-0000-0000-0000-000000000014', '98100000-0000-0000-0000-000000000001', null, 'Statement Borrower D', 'ACTIVE', '2025-01-01', 'STMT-2026-0014'),
  ('98200000-0000-0000-0000-000000000015', '98100000-0000-0000-0000-000000000001', null, 'Statement Borrower E', 'ACTIVE', '2025-01-01', 'STMT-2026-0015'),
  ('98200000-0000-0000-0000-000000000016', '98100000-0000-0000-0000-000000000001', null, 'Statement Borrower F', 'ACTIVE', '2025-01-01', 'STMT-2026-0016');

insert into public.group_membership_roles (group_membership_id, role_id) select '98200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '98000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '98100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-04-01'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '98100000-0000-0000-0000-000000000001', 'STMTP', 'Statement Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- =====================================================================
-- LOAN A: full ordinary lifecycle + servicing (scenarios 1,3,5,6,7,8,9,10)
-- =====================================================================

create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset
select public.rpc_submit_loan_account('98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_approve_loan_account('98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_disburse_loan_account('98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);
create temporary table t_payment_a as
select public.rpc_post_payment('98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid, 50000, '2026-04-20'::date, 'CASH') as result;
select (result->>'payment_id')::uuid as payment_a_id from t_payment_a \gset

select public.rpc_assess_loan_penalties('98100000-0000-0000-0000-000000000001', '2026-05-16'::date, :'loan_a_id'::uuid);

select id as installment_a1_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 1 \gset

reset role;
select c.id as charge_a1_id, greatest(1, floor(pc.outstanding / 4))::numeric as correction_dec_amount_a
from public.loan_penalty_charges c
cross join lateral public.loan_installment_component_states(c.loan_installment_id) pc
where c.loan_account_id = :'loan_a_id'::uuid and pc.component_type = 'PENALTY' and pc.outstanding > 0
order by c.assessment_date desc
limit 1 \gset
set local role authenticated;
set local request.jwt.claim.sub to '98000000-0000-0000-0000-000000000001';

create temporary table t_correction_dec_a as
select public.rpc_post_loan_obligation_correction(
  '98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 'LOAN_PENALTY', :'charge_a1_id'::uuid,
  'CORRECTION_DECREASE', :correction_dec_amount_a, 'ASSESSMENT_ERROR'
) as result;

create temporary table t_correction_inc_a as
select public.rpc_post_loan_obligation_correction(
  '98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 'LOAN_PENALTY', :'charge_a1_id'::uuid,
  'CORRECTION_INCREASE', :correction_dec_amount_a, 'ASSESSMENT_ERROR'
) as result;
select (result->>'adjustment_id')::uuid as correction_inc_a_id from t_correction_inc_a \gset

select public.rpc_reverse_loan_obligation_adjustment(
  '98100000-0000-0000-0000-000000000001', :'correction_inc_a_id'::uuid, 'Entered in error'
);

-- Clear every remaining overdue penalty/interest across the whole loan
-- so the prepayment below is never blocked by
-- rpc_prepay_loan_principal's overdue-penalty/interest guard; the
-- charge_a1 waiver below also doubles as the waiver coverage for
-- scenario 6.
create temporary table t_waiver_a as
select public.rpc_post_loan_obligation_waiver(
  '98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 'LOAN_PENALTY', :'charge_a1_id'::uuid, :correction_dec_amount_a, 'GOODWILL'
) as result;
select (result->>'adjustment_id')::uuid as waiver_a_id from t_waiver_a \gset

reset role;
create temporary table t_remaining_penalty_a as
select c.id as charge_id, pc.outstanding as outstanding
from public.loan_penalty_charges c
cross join lateral public.loan_installment_component_states(c.loan_installment_id) pc
where c.loan_account_id = :'loan_a_id'::uuid and pc.component_type = 'PENALTY' and pc.outstanding > 0;
create temporary table t_remaining_interest_a as
select li.id as installment_id, ic.outstanding as outstanding
from public.loan_installments li
cross join lateral public.loan_installment_component_states(li.id) ic
where li.loan_account_id = :'loan_a_id'::uuid and li.cancelled_at is null
  and ic.component_type = 'INTEREST' and ic.outstanding > 0 and li.due_date < '2026-05-20'::date;
grant select on t_remaining_penalty_a, t_remaining_interest_a to authenticated;
set local role authenticated;
set local request.jwt.claim.sub to '98000000-0000-0000-0000-000000000001';
set local umoja.tmp_loan_a_id to :'loan_a_id';

do $$
declare
  v_row record;
  v_loan_id uuid := current_setting('umoja.tmp_loan_a_id')::uuid;
begin
  for v_row in select charge_id, outstanding from t_remaining_penalty_a loop
    perform public.rpc_post_loan_obligation_waiver(
      '98100000-0000-0000-0000-000000000001'::uuid, v_loan_id, 'LOAN_PENALTY', v_row.charge_id, v_row.outstanding, 'GOODWILL'
    );
  end loop;
  for v_row in select installment_id, outstanding from t_remaining_interest_a loop
    perform public.rpc_post_loan_obligation_waiver(
      '98100000-0000-0000-0000-000000000001'::uuid, v_loan_id, 'LOAN_INTEREST', v_row.installment_id, v_row.outstanding, 'GOODWILL'
    );
  end loop;
end $$;

create temporary table t_prepay_a as
select public.rpc_prepay_loan_principal(
  '98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 50000, 'REDUCE_TERM',
  :'account_id'::uuid, 'CASH', '2026-05-20'::date
) as result;

create temporary table t_stmt_a as
select public.rpc_get_loan_statement('98100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

-- 1: normal originated lifecycle
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_CREATED'),
  '1a: LOAN_CREATED present'
);
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_SUBMITTED'),
  '1b: LOAN_SUBMITTED present'
);
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_APPROVED'),
  '1c: LOAN_APPROVED present'
);
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_DISBURSED'),
  '1d: LOAN_DISBURSED present'
);
select is(
  (select result->'header'->>'loan_number' from t_stmt_a),
  (select loan_number from public.loan_accounts where id = :'loan_a_id'::uuid),
  '1e: header.loan_number matches the real loan'
);

-- 3: repayment — exactly one PAYMENT_POSTED for the ordinary payment
select is(
  (select count(*)::integer from t_stmt_a, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PAYMENT_POSTED' and e->'references'->>'payment_id' = :'payment_a_id'::text),
  1,
  '3: exactly one PAYMENT_POSTED for the ordinary repayment'
);

-- 5: penalty assessment
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'PENALTY_ASSESSED'),
  '5: PENALTY_ASSESSED present'
);

-- 6: waiver
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'OBLIGATION_WAIVER' and e->'references'->>'adjustment_id' = :'waiver_a_id'::text),
  '6: OBLIGATION_WAIVER present'
);

-- 7: correction decrease
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'OBLIGATION_CORRECTION_DECREASE'),
  '7: OBLIGATION_CORRECTION_DECREASE present'
);

-- 8: correction increase
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'OBLIGATION_CORRECTION_INCREASE' and e->'references'->>'adjustment_id' = :'correction_inc_a_id'::text),
  '8: OBLIGATION_CORRECTION_INCREASE present'
);

-- 9: adjustment reversal — both the original (marked reversed) and the
-- reversal row itself are present
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'OBLIGATION_ADJUSTMENT_REVERSED'),
  '9a: OBLIGATION_ADJUSTMENT_REVERSED present'
);
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'OBLIGATION_CORRECTION_INCREASE'
     and e->'references'->>'adjustment_id' = :'correction_inc_a_id'::text
     and (e->>'is_reversed')::boolean = true),
  '9b: the reversed correction-increase itself is marked is_reversed=true'
);

-- 10 / 11: principal prepayment, REDUCE_TERM
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PRINCIPAL_PREPAYMENT' and e->>'event_subtype' = 'REDUCE_TERM'),
  '10/11: PRINCIPAL_PREPAYMENT present with REDUCE_TERM subtype'
);

-- No fabricated installment id/due date for the prepayment allocation
-- line inside the payment's own event (its principal component is a
-- LOAN_PRINCIPAL_PREPAYMENT allocation, never installment-bound).
select ok(
  exists (select 1 from t_stmt_a, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PAYMENT_POSTED' and e->>'event_subtype' = 'PRINCIPAL_PREPAYMENT'
     and (e->'components'->>'principal')::numeric = 50000),
  '10b: the prepayment payment event shows the correct principal component, never fabricated'
);

-- =====================================================================
-- LOAN B: restructure (scenario 13)
-- =====================================================================

create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 200000, 4, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select public.rpc_submit_loan_account('98100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_approve_loan_account('98100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_disburse_loan_account('98100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

select count(*)::integer as installments_before_restructure from public.loan_installments where loan_account_id = :'loan_b_id'::uuid \gset
select min(due_date) - 1 as restructure_effective_date_b from public.loan_installments where loan_account_id = :'loan_b_id'::uuid \gset

create temporary table t_restructure_b as
select public.rpc_restructure_loan(
  '98100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, 'Borrower requested longer term',
  8, '2026-06-15'::date, 6.0, :'restructure_effective_date_b'::date
) as result;

create temporary table t_stmt_b as
select public.rpc_get_loan_statement('98100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_b, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_RESTRUCTURED'),
  '13a: LOAN_RESTRUCTURED present'
);
-- 28: cancelled/replaced schedule history — the pre-restructure
-- installments must appear in schedule.history, never in
-- schedule.current, and never as fabricated timeline events.
select ok(
  (select jsonb_array_length(result->'schedule'->'history') from t_stmt_b) > 0,
  '13b/28a: schedule.history is non-empty after a restructure'
);
select is(
  (select count(*)::integer from t_stmt_b, jsonb_array_elements(result->'schedule'->'current') c
   where (c->>'cancelled_at') is not null),
  0,
  '28b: schedule.current never contains a cancelled/replaced installment'
);

-- =====================================================================
-- LOAN C: principal prepayment, REDUCE_INSTALLMENT (scenario 12)
-- =====================================================================

create temporary table t_loan_c as
select public.rpc_create_draft_loan_account(
  '98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000013'::uuid,
  :'product_id'::uuid, 200000, 4, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_c_id from t_loan_c \gset
select public.rpc_submit_loan_account('98100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_approve_loan_account('98100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_disburse_loan_account('98100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);
select min(due_date) - 1 as prepay_effective_date_c from public.loan_installments where loan_account_id = :'loan_c_id'::uuid \gset

select public.rpc_prepay_loan_principal(
  '98100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid, 40000, 'REDUCE_INSTALLMENT',
  :'account_id'::uuid, 'CASH', :'prepay_effective_date_c'::date
);

create temporary table t_stmt_c as
select public.rpc_get_loan_statement('98100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_c, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PRINCIPAL_PREPAYMENT' and e->>'event_subtype' = 'REDUCE_INSTALLMENT'),
  '12: PRINCIPAL_PREPAYMENT present with REDUCE_INSTALLMENT subtype'
);

-- =====================================================================
-- LOAN D: early settlement + CLOSED (scenarios 14, 15)
-- =====================================================================

create temporary table t_loan_d as
select public.rpc_create_draft_loan_account(
  '98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000014'::uuid,
  :'product_id'::uuid, 150000, 3, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_d_id from t_loan_d \gset
select public.rpc_submit_loan_account('98100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid);
select public.rpc_approve_loan_account('98100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid);
select public.rpc_disburse_loan_account('98100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

select public.rpc_settle_loan_early(
  '98100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid, :'account_id'::uuid, 'CASH', '2026-04-20'::date
);

create temporary table t_stmt_d as
select public.rpc_get_loan_statement('98100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_d, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'EARLY_SETTLEMENT'),
  '14a: EARLY_SETTLEMENT present'
);
select ok(
  exists (select 1 from t_stmt_d, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PAYMENT_POSTED' and (e->>'amount')::numeric > 0),
  '14b: the early-settlement clearing payment appears as an ordinary PAYMENT_POSTED event'
);
select is(
  (select result->'header'->>'status' from t_stmt_d),
  'CLOSED',
  '15a: loan is CLOSED after full early settlement'
);
select ok(
  exists (select 1 from t_stmt_d, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_CLOSED'),
  '15b: LOAN_CLOSED present'
);
select is((select (result->'current_state'->>'total_outstanding')::numeric from t_stmt_d), 0.00::numeric, '15c: total_outstanding is 0 for a CLOSED loan');

-- =====================================================================
-- LOAN E: repayment reversal + payment reversal reopening CLOSED
-- (scenarios 4, 16)
-- =====================================================================

create temporary table t_product_np as
select public.rpc_create_loan_product(
  '98100000-0000-0000-0000-000000000001', 'STMTPNP', 'Statement Product No Penalty', 100000, 1, 12, 0.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_np_id from t_product_np \gset

create temporary table t_loan_e as
select public.rpc_create_draft_loan_account(
  '98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000015'::uuid,
  :'product_np_id'::uuid, 100000, 1, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_e_id from t_loan_e \gset
select public.rpc_submit_loan_account('98100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid);
select public.rpc_approve_loan_account('98100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid);
select public.rpc_disburse_loan_account('98100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

create temporary table t_payment_e as
select public.rpc_post_payment('98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000015'::uuid, :'account_id'::uuid, 100000, '2026-04-15'::date, 'CASH') as result;
select (result->>'payment_id')::uuid as payment_e_id from t_payment_e \gset

select is(
  (select status from public.loan_accounts where id = :'loan_e_id'::uuid),
  'CLOSED',
  '16a: fully repaid loan auto-closes'
);

select public.rpc_reverse_payment('98100000-0000-0000-0000-000000000001', :'payment_e_id'::uuid, 'Recorded in error');

create temporary table t_stmt_e as
select public.rpc_get_loan_statement('98100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid) as result;

-- 4: repayment reversal — same single event, marked reversed
select is(
  (select count(*)::integer from t_stmt_e, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'PAYMENT_POSTED'),
  1,
  '4a: still exactly one PAYMENT_POSTED event after reversal (never duplicated)'
);
select ok(
  exists (select 1 from t_stmt_e, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PAYMENT_POSTED' and (e->>'is_reversed')::boolean = true),
  '4b: the payment event is marked is_reversed=true'
);
-- 16: payment reversal reopening CLOSED
select is(
  (select result->'header'->>'status' from t_stmt_e),
  'ACTIVE',
  '16b: loan reopens to ACTIVE after the payment reversal'
);
select ok(
  exists (select 1 from t_stmt_e, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_REOPENED'),
  '16c: LOAN_REOPENED present'
);

-- =====================================================================
-- LOAN F: migrated loan (scenario 2)
-- =====================================================================

create temporary table t_loan_f as
select public.rpc_create_migrated_loan(
  '98100000-0000-0000-0000-000000000001', '98200000-0000-0000-0000-000000000016'::uuid, :'product_id'::uuid,
  1000000, '2026-01-15'::date, '2026-04-01'::date,
  500000,
  p_remaining_installment_count => 5, p_next_due_date => '2026-05-15'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 0,
  p_monthly_installment_amount => 100000, p_historical_unpaid_count => 0,
  p_total_historical_arrears => 0, p_original_term => 10
) as result;
select (result->>'id')::uuid as loan_f_id from t_loan_f \gset

create temporary table t_stmt_f as
select public.rpc_get_loan_statement('98100000-0000-0000-0000-000000000001', :'loan_f_id'::uuid) as result;

select is(
  (select result->'header'->>'loan_origin' from t_stmt_f),
  'MIGRATED',
  '2a: header.loan_origin is MIGRATED'
);
select ok(
  exists (select 1 from t_stmt_f, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_MIGRATED'),
  '2b: LOAN_MIGRATED present'
);
select is(
  (select count(*)::integer from t_stmt_f, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' in ('LOAN_CREATED', 'LOAN_SUBMITTED', 'LOAN_APPROVED', 'LOAN_DISBURSED')),
  0,
  '2c: no fabricated LOAN_CREATED/SUBMITTED/APPROVED/DISBURSED for a migrated loan'
);
select ok(
  (select (e->'metadata'->>'from_status') is null and (e->'metadata'->>'to_status') is not null
   from t_stmt_f, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'LOAN_MIGRATED'),
  '2d: LOAN_MIGRATED metadata reflects the real from/to status transition (never implying Umoja originated the loan)'
);

select * from finish();
rollback;
