-- Prompt 09G-02: rpc_get_loan_statement — write-off/recovery coverage
-- (test matrix scenarios 17, 18, 19, 20, 21, 22, 23) plus the
-- rpc_get_loan_account regression matrix A-G.
begin;

select plan(34);

insert into auth.users (id, email) values
  ('99000000-0000-0000-0000-000000000001', 'p09g-stmt-wo-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('99100000-0000-0000-0000-000000000001', 'Statement WO Group', '99000000-0000-0000-0000-000000000001', 'STMTWO');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('99200000-0000-0000-0000-000000000001', '99100000-0000-0000-0000-000000000001', '99000000-0000-0000-0000-000000000001', 'Statement WO Admin', 'ACTIVE', '2025-01-01', 'STMTWO-2026-0001'),
  ('99200000-0000-0000-0000-000000000011', '99100000-0000-0000-0000-000000000001', null, 'Statement WO Borrower', 'ACTIVE', '2025-01-01', 'STMTWO-2026-0011'),
  ('99200000-0000-0000-0000-000000000012', '99100000-0000-0000-0000-000000000001', null, 'Statement WO Borrower B', 'ACTIVE', '2025-01-01', 'STMTWO-2026-0012'),
  ('99200000-0000-0000-0000-000000000013', '99100000-0000-0000-0000-000000000001', null, 'Statement WO Borrower C', 'ACTIVE', '2025-01-01', 'STMTWO-2026-0013');

insert into public.group_membership_roles (group_membership_id, role_id) select '99200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '99000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '99100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '99100000-0000-0000-0000-000000000001', 'STMTWOP', 'Statement WO Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- =====================================================================
-- LOAN A: write-off -> partial recovery -> recovery reversal ->
-- write-off reversal -> re-write-off -> full recovery
-- (scenarios 17, 18, 19, 20, 21, 22, 23; regressions C, D, E, F)
-- =====================================================================

create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '99100000-0000-0000-0000-000000000001', '99200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset
select public.rpc_submit_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_approve_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_disburse_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

select public.rpc_assess_loan_penalties('99100000-0000-0000-0000-000000000001', '2026-06-15'::date, :'loan_a_id'::uuid);

-- 17: write-off
create temporary table t_write_off_a as
select public.rpc_post_loan_write_off(
  '99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 'PROLONGED_DEFAULT', null, '2026-05-15'::date
) as result;
select (result->>'write_off_event_id')::uuid as write_off_a_id from t_write_off_a \gset
select (result->>'principal_amount')::numeric as wo_a_principal from t_write_off_a \gset
select (result->>'interest_amount')::numeric as wo_a_interest from t_write_off_a \gset
select (result->>'penalty_amount')::numeric as wo_a_penalty from t_write_off_a \gset

create temporary table t_stmt_a1 as
select public.rpc_get_loan_statement('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;
create temporary table t_account_a1 as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_a1, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'WRITE_OFF'),
  '17a: WRITE_OFF present in the timeline'
);
select is(
  (select (result->'current_state'->'write_off'->>'is_active')::boolean from t_stmt_a1),
  true,
  '17b: current_state.write_off.is_active is true right after posting'
);
select is(
  (select (result->'current_state'->>'total_outstanding')::numeric from t_stmt_a1),
  0.00::numeric,
  '17c: current_state.total_outstanding is 0 for a freshly WRITTEN_OFF loan (schedule fields never conflated with write-off exposure)'
);

-- Regression C: rpc_get_loan_account schedule outstanding fields are 0
select is((select (result->>'principal_outstanding')::numeric from t_account_a1), 0.00::numeric, 'C1: rpc_get_loan_account principal_outstanding is 0 for WRITTEN_OFF');
select is((select (result->>'interest_outstanding')::numeric from t_account_a1), 0.00::numeric, 'C2: rpc_get_loan_account interest_outstanding is 0 for WRITTEN_OFF');
select is((select (result->>'penalty_outstanding')::numeric from t_account_a1), 0.00::numeric, 'C3: rpc_get_loan_account penalty_outstanding is 0 for WRITTEN_OFF');
select is((select (result->>'total_outstanding')::numeric from t_account_a1), 0.00::numeric, 'C4: rpc_get_loan_account total_outstanding is 0 for WRITTEN_OFF');
select is((select result->>'next_due_date' from t_account_a1), null::text, 'C5: rpc_get_loan_account next_due_date is null for WRITTEN_OFF');
select is(
  (select (result->>'remaining_recoverable_total')::numeric from t_account_a1),
  (:wo_a_principal + :wo_a_interest + :wo_a_penalty)::numeric,
  'C6: rpc_get_loan_account remaining_recoverable_total equals the full frozen write-off amount before any recovery'
);

-- 18: partial recovery
create temporary table t_recovery_a1 as
select public.rpc_post_loan_recovery(
  '99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid,
  :wo_a_penalty + 1000, :'account_id'::uuid, 'CASH', '2026-07-01'::date
) as result;
select (result->>'payment_id')::uuid as recovery_a1_payment_id from t_recovery_a1 \gset

create temporary table t_stmt_a2 as
select public.rpc_get_loan_statement('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;
create temporary table t_account_a2 as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_a2, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'RECOVERY_POSTED' and e->'references'->>'payment_id' = :'recovery_a1_payment_id'::text),
  '18: RECOVERY_POSTED present after the partial recovery'
);

-- 22: the core bug-fix regression — WRITTEN_OFF balance must reflect
-- the recovery, never the frozen pre-recovery amount.
select is(
  (select (result->'current_state'->'write_off'->>'remaining_recoverable')::numeric from t_stmt_a2),
  (:wo_a_principal + :wo_a_interest + :wo_a_penalty - (:wo_a_penalty + 1000))::numeric,
  '22: statement remaining_recoverable decreases by exactly the recovered amount, never frozen'
);

-- Regression D: rpc_get_loan_account still reports 0 schedule
-- outstanding, but a decreased remaining_recoverable_total.
select is((select (result->>'principal_outstanding')::numeric from t_account_a2), 0.00::numeric, 'D1: schedule outstanding still 0 after partial recovery');
select is(
  (select (result->>'remaining_recoverable_total')::numeric from t_account_a2),
  (:wo_a_principal + :wo_a_interest + :wo_a_penalty - (:wo_a_penalty + 1000))::numeric,
  'D2: rpc_get_loan_account remaining_recoverable_total decreases by exactly the recovered amount'
);

-- 19: recovery reversal
select public.rpc_reverse_payment('99100000-0000-0000-0000-000000000001', :'recovery_a1_payment_id'::uuid, 'Recorded in error');

create temporary table t_stmt_a3 as
select public.rpc_get_loan_statement('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;
create temporary table t_account_a3 as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_a3, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'RECOVERY_POSTED' and (e->>'is_reversed')::boolean = true),
  '19a: the recovery event is marked is_reversed=true after reversal'
);
select is(
  (select (result->'current_state'->'write_off'->>'remaining_recoverable')::numeric from t_stmt_a3),
  (:wo_a_principal + :wo_a_interest + :wo_a_penalty)::numeric,
  '19b: statement remaining_recoverable is restored to the full frozen amount after the recovery is reversed'
);
-- Regression E
select is(
  (select (result->>'remaining_recoverable_total')::numeric from t_account_a3),
  (:wo_a_principal + :wo_a_interest + :wo_a_penalty)::numeric,
  'E: rpc_get_loan_account remaining_recoverable_total is restored after recovery reversal'
);

-- 20: write-off reversal
select public.rpc_reverse_loan_write_off('99100000-0000-0000-0000-000000000001', :'write_off_a_id'::uuid, 'Borrower resumed payments');

create temporary table t_stmt_a4 as
select public.rpc_get_loan_statement('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;
create temporary table t_account_a4 as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select ok(
  exists (select 1 from t_stmt_a4, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'WRITE_OFF_REVERSED'),
  '20a: WRITE_OFF_REVERSED present in the timeline'
);
select is(
  (select result->'header'->>'status' from t_stmt_a4),
  'ACTIVE',
  '20b: loan returns to ACTIVE after write-off reversal'
);
-- Regression F: rpc_get_loan_account reports live schedule figures
-- again (never stuck at 0) and a positive principal_outstanding.
select is((select result->>'status' from t_account_a4), 'ACTIVE', 'F1: rpc_get_loan_account status is ACTIVE again');
select ok(
  (select (result->>'principal_outstanding')::numeric from t_account_a4) > 0,
  'F2: rpc_get_loan_account principal_outstanding is live/positive again, never stuck at 0'
);
select ok(
  (select result->>'next_due_date' from t_account_a4) is not null,
  'F3: rpc_get_loan_account next_due_date is populated again (no longer null)'
);

-- 21: re-write-off
create temporary table t_write_off_a2 as
select public.rpc_post_loan_write_off(
  '99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 'PROLONGED_DEFAULT', 'second write-off', '2026-08-15'::date
) as result;
select (result->>'write_off_event_id')::uuid as write_off_a2_id from t_write_off_a2 \gset
select (result->>'principal_amount')::numeric as wo_a2_principal from t_write_off_a2 \gset
select (result->>'interest_amount')::numeric as wo_a2_interest from t_write_off_a2 \gset
select (result->>'penalty_amount')::numeric as wo_a2_penalty from t_write_off_a2 \gset

create temporary table t_stmt_a5 as
select public.rpc_get_loan_statement('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select is(
  (select count(*)::integer from t_stmt_a5, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'WRITE_OFF'),
  2,
  '21a: two distinct WRITE_OFF events now present (the original, then the re-write-off)'
);
select is(
  (select (result->'current_state'->'write_off'->>'write_off_event_id')::text from t_stmt_a5),
  :'write_off_a2_id'::text,
  '21b: current_state.write_off reflects the most recent (active) write-off, not the reversed one'
);

-- 23: fully recover the second write-off
create temporary table t_recovery_a2 as
select public.rpc_post_loan_recovery(
  '99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid,
  :wo_a2_principal + :wo_a2_interest + :wo_a2_penalty, :'account_id'::uuid, 'CASH', '2026-09-01'::date
) as result;

create temporary table t_stmt_a6 as
select public.rpc_get_loan_statement('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;
create temporary table t_account_a6 as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select is(
  (select result->'header'->>'status' from t_stmt_a6),
  'WRITTEN_OFF',
  '23a: loan remains WRITTEN_OFF even after being fully recovered (recovery never auto-reactivates a loan)'
);
select is(
  (select (result->'current_state'->'write_off'->>'remaining_recoverable')::numeric from t_stmt_a6),
  0.00::numeric,
  '23b: statement remaining_recoverable is exactly 0 once fully recovered'
);
select is(
  (select (result->>'remaining_recoverable_total')::numeric from t_account_a6),
  0.00::numeric,
  '23c: rpc_get_loan_account remaining_recoverable_total is exactly 0 once fully recovered'
);

-- =====================================================================
-- LOAN B: ACTIVE, never touched by write-off (regression A, G)
-- =====================================================================

create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '99100000-0000-0000-0000-000000000001', '99200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 100000, 2, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select public.rpc_submit_loan_account('99100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_approve_loan_account('99100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_disburse_loan_account('99100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

create temporary table t_account_b as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid) as result;

select is((select result->>'status' from t_account_b), 'ACTIVE', 'A1: a never-written-off loan reports ACTIVE');
select ok(
  (select (result->>'principal_outstanding')::numeric from t_account_b) > 0,
  'A2: a never-written-off ACTIVE loan reports a live positive principal_outstanding'
);
select is((select result->>'written_off_total' from t_account_b), null::text, 'G1: written_off_total is null for a loan never written off');
select is((select result->>'remaining_recoverable_total' from t_account_b), null::text, 'G2: remaining_recoverable_total is null for a loan never written off');
select is((select result->>'remaining_recoverable_principal' from t_account_b), null::text, 'G3: remaining_recoverable_principal is null for a loan never written off');

-- =====================================================================
-- LOAN C: CLOSED, never touched by write-off (regression B)
-- =====================================================================

create temporary table t_loan_c as
select public.rpc_create_draft_loan_account(
  '99100000-0000-0000-0000-000000000001', '99200000-0000-0000-0000-000000000013'::uuid,
  :'product_id'::uuid, 100000, 1, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_c_id from t_loan_c \gset
select public.rpc_submit_loan_account('99100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_approve_loan_account('99100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_disburse_loan_account('99100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

select public.rpc_post_payment('99100000-0000-0000-0000-000000000001', '99200000-0000-0000-0000-000000000013'::uuid, :'account_id'::uuid, 105000, '2026-04-15'::date, 'CASH');

create temporary table t_account_c as
select public.rpc_get_loan_account('99100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid) as result;

select is((select result->>'status' from t_account_c), 'CLOSED', 'B1: a fully repaid loan reports CLOSED');
select is((select (result->>'total_outstanding')::numeric from t_account_c), 0.00::numeric, 'B2: a CLOSED loan reports 0 total_outstanding (unchanged pre-existing behavior)');
select is((select result->>'written_off_total' from t_account_c), null::text, 'B3: written_off_total is null for a CLOSED loan never written off');

select * from finish();
rollback;
