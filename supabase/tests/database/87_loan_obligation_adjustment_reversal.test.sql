-- Prompt 09F-A: adjustment reversal — safe vs blocked (section 17, test
-- matrix items 34-40, 44). Mirrors 80_loan_prepayment_reversal_dependency's
-- own safe-vs-blocked structure, one scenario per guard condition.
begin;

select plan(13);

insert into auth.users (id, email) values
  ('87000000-0000-0000-0000-000000000001', 'p09fa-reversal-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('87100000-0000-0000-0000-000000000001', 'Reversal Group', '87000000-0000-0000-0000-000000000001', 'REVR');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('87200000-0000-0000-0000-000000000001', '87100000-0000-0000-0000-000000000001', '87000000-0000-0000-0000-000000000001', 'Reversal Admin', 'ACTIVE', '2025-01-01', 'REVR-2026-0001'),
  ('87200000-0000-0000-0000-000000000011', '87100000-0000-0000-0000-000000000001', null, 'Borrower A', 'ACTIVE', '2025-01-01', 'REVR-2026-0011'),
  ('87200000-0000-0000-0000-000000000012', '87100000-0000-0000-0000-000000000001', null, 'Borrower B', 'ACTIVE', '2025-01-01', 'REVR-2026-0012'),
  ('87200000-0000-0000-0000-000000000013', '87100000-0000-0000-0000-000000000001', null, 'Borrower C', 'ACTIVE', '2025-01-01', 'REVR-2026-0013'),
  ('87200000-0000-0000-0000-000000000014', '87100000-0000-0000-0000-000000000001', null, 'Borrower D', 'ACTIVE', '2025-01-01', 'REVR-2026-0014'),
  ('87200000-0000-0000-0000-000000000015', '87100000-0000-0000-0000-000000000001', null, 'Borrower E', 'ACTIVE', '2025-01-01', 'REVR-2026-0015');

insert into public.group_membership_roles (group_membership_id, role_id) select '87200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '87000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '87100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '87100000-0000-0000-0000-000000000001', 'REVP', 'Reversal Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 40000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- =======================================================================
-- SCENARIO A (items 34/39/40/44): immediate reversal, no later activity.
-- =======================================================================

create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset
select public.rpc_submit_loan_account('87100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_approve_loan_account('87100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_disburse_loan_account('87100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_a_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid \gset
select public.rpc_assess_loan_penalties('87100000-0000-0000-0000-000000000001', current_date, :'loan_a_id'::uuid);
select id as charge_a_id from public.loan_penalty_charges where loan_installment_id = :'installment_a_id'::uuid \gset

create temporary table t_waiver_a as
select public.rpc_post_loan_obligation_waiver(
  '87100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, 'LOAN_PENALTY', :'charge_a_id'::uuid, 15000, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_a_id from t_waiver_a \gset

select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', :'waiver_a_id'::uuid, 'test — no later activity');

reset role;
select outstanding as loan_a_outstanding_restored from public.loan_penalty_charge_states(:'installment_a_id'::uuid) where charge_id = :'charge_a_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '87000000-0000-0000-0000-000000000001';

select is(
  :'loan_a_outstanding_restored'::numeric,
  40000.00::numeric,
  '34/44: immediate reversal succeeds and fully restores the original 40,000 outstanding'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'charge_a_id'::uuid),
  40000.00::numeric,
  '39: the original penalty assessment remains immutable through post + reverse'
);
select is(
  (select amount from public.loan_obligation_adjustments where id = :'waiver_a_id'::uuid),
  -15000.00::numeric,
  '40: the original WAIVER row itself is never edited by its own reversal'
);
select is(
  (select adjustment_type from public.loan_obligation_adjustments where reverses_adjustment_id = :'waiver_a_id'::uuid),
  'REVERSAL',
  '40b: the reversal is a separate, append-only row referencing the original'
);

-- Reversing the REVERSAL itself is not required in 09F-A and is
-- rejected outright.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', %L::uuid, 'reverse the reversal') $sql$,
    (select id from public.loan_obligation_adjustments where reverses_adjustment_id = :'waiver_a_id'::uuid)
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REVERSAL_NOT_SUPPORTED',
  'a reversal of a reversal is rejected outright'
);

-- Item 38: reversing the ALREADY-reversed original again is rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', %L::uuid, 'second attempt') $sql$,
    :'waiver_a_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_ALREADY_REVERSED',
  '38: an already-reversed adjustment cannot be reversed again'
);

-- =======================================================================
-- SCENARIO B (item 35): a later adjustment on the same target blocks
-- reversal of an earlier one.
-- =======================================================================

create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select public.rpc_submit_loan_account('87100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_approve_loan_account('87100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_disburse_loan_account('87100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_b_id from public.loan_installments where loan_account_id = :'loan_b_id'::uuid \gset
select public.rpc_assess_loan_penalties('87100000-0000-0000-0000-000000000001', current_date, :'loan_b_id'::uuid);
select id as charge_b_id from public.loan_penalty_charges where loan_installment_id = :'installment_b_id'::uuid \gset

create temporary table t_waiver_b1 as
select public.rpc_post_loan_obligation_waiver(
  '87100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, 'LOAN_PENALTY', :'charge_b_id'::uuid, 10000, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_b1_id from t_waiver_b1 \gset

select public.rpc_post_loan_obligation_waiver(
  '87100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, 'LOAN_PENALTY', :'charge_b_id'::uuid, 5000, 'GOODWILL'
);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', %L::uuid, 'blocked by later waiver') $sql$,
    :'waiver_b1_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '35: reversing an adjustment is blocked once a later adjustment exists on the same target'
);

-- =======================================================================
-- SCENARIO C (item 36): a later payment allocation against the same
-- target blocks reversal.
-- =======================================================================

create temporary table t_loan_c as
select public.rpc_create_draft_loan_account(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000013'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_c_id from t_loan_c \gset
select public.rpc_submit_loan_account('87100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_approve_loan_account('87100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_disburse_loan_account('87100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_c_id from public.loan_installments where loan_account_id = :'loan_c_id'::uuid \gset
select public.rpc_assess_loan_penalties('87100000-0000-0000-0000-000000000001', current_date, :'loan_c_id'::uuid);
select id as charge_c_id from public.loan_penalty_charges where loan_installment_id = :'installment_c_id'::uuid \gset

create temporary table t_waiver_c as
select public.rpc_post_loan_obligation_waiver(
  '87100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid, 'LOAN_PENALTY', :'charge_c_id'::uuid, 10000, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_c_id from t_waiver_c \gset

-- pgTAP wraps this whole file in one transaction, so now() (which
-- created_at defaults to) is frozen for every statement in it — real,
-- separate production transactions never share this problem. Backdating
-- the waiver here simulates genuine wall-clock separation so the
-- dependency guard's created_at comparison can be exercised honestly.
reset role;
update public.loan_obligation_adjustments set created_at = created_at - interval '1 hour' where id = :'waiver_c_id'::uuid;
set local role authenticated;
set local request.jwt.claim.sub to '87000000-0000-0000-0000-000000000001';

-- Pay the remaining 30,000 (penalty is priority 0).
select public.rpc_post_payment(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000013'::uuid, :'account_id'::uuid,
  30000, current_date, 'CASH'
);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', %L::uuid, 'blocked by later payment') $sql$,
    :'waiver_c_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '36: reversing an adjustment is blocked once a later payment allocation was posted against the same target'
);

-- =======================================================================
-- SCENARIO D (item 37): the target installment being cancelled/
-- superseded (as a real prepayment/restructure/early settlement would
-- do to a FUTURE installment) after the adjustment blocks reversal.
-- 09F-A's eligibility rules mean a waiver/correction can only ever
-- target an already-DUE installment, and 09E's own fix
-- (20260915090000) means prepayment/restructure never cancel a due
-- installment — so this structural guard is exercised directly here,
-- exactly as rpc_reverse_payment's own dependency guard is (section 17:
-- "use target-specific structural checks").
-- =======================================================================

create temporary table t_loan_d as
select public.rpc_create_draft_loan_account(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000014'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_d_id from t_loan_d \gset
select public.rpc_submit_loan_account('87100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid);
select public.rpc_approve_loan_account('87100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid);
select public.rpc_disburse_loan_account('87100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_d_id, interest_due as interest_d from public.loan_installments where loan_account_id = :'loan_d_id'::uuid \gset

create temporary table t_waiver_d as
select public.rpc_post_loan_obligation_waiver(
  '87100000-0000-0000-0000-000000000001', :'loan_d_id'::uuid, 'LOAN_INTEREST', :'installment_d_id'::uuid, :interest_d, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_d_id from t_waiver_d \gset

reset role;
-- See the comment in Scenario C — cancelled_at is forced strictly ahead
-- of the (transaction-frozen) now() to simulate genuine wall-clock
-- separation from the adjustment's created_at.
update public.loan_installments set cancelled_at = now() + interval '1 hour', cancellation_reason = 'RESTRUCTURE'
  where id = :'installment_d_id'::uuid;
set local role authenticated;
set local request.jwt.claim.sub to '87000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', %L::uuid, 'blocked by supersession') $sql$,
    :'waiver_d_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '37: reversal is blocked once the target installment has been cancelled/superseded since the adjustment was posted'
);

-- =======================================================================
-- SCENARIO E: reversal reopens a CLOSED loan (item 44, the reopen half).
-- =======================================================================

create temporary table t_loan_e as
select public.rpc_create_draft_loan_account(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000015'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_e_id from t_loan_e \gset
select public.rpc_submit_loan_account('87100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid);
select public.rpc_approve_loan_account('87100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid);
select public.rpc_disburse_loan_account('87100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_e_id, interest_due as interest_e, principal_due as principal_e from public.loan_installments
  where loan_account_id = :'loan_e_id'::uuid \gset
select public.rpc_assess_loan_penalties('87100000-0000-0000-0000-000000000001', current_date, :'loan_e_id'::uuid);
select id as charge_e_id from public.loan_penalty_charges where loan_installment_id = :'installment_e_id'::uuid \gset

create temporary table t_waiver_e as
select public.rpc_post_loan_obligation_waiver(
  '87100000-0000-0000-0000-000000000001', :'loan_e_id'::uuid, 'LOAN_PENALTY', :'charge_e_id'::uuid, 40000, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_e_id from t_waiver_e \gset

select public.rpc_post_payment(
  '87100000-0000-0000-0000-000000000001', '87200000-0000-0000-0000-000000000015'::uuid, :'account_id'::uuid,
  :interest_e + :principal_e, current_date, 'CASH'
);

select is(
  (select status from public.loan_accounts where id = :'loan_e_id'::uuid),
  'CLOSED',
  'setup: the loan closes once the waived penalty + paid interest/principal all reach zero'
);

select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', :'waiver_e_id'::uuid, 'restore the waived penalty');

select is(
  (select status from public.loan_accounts where id = :'loan_e_id'::uuid),
  'ACTIVE',
  '44: reversing the waiver restores the 40,000 penalty outstanding and reopens the CLOSED loan'
);

reset role;
select outstanding as loan_e_outstanding_restored from public.loan_penalty_charge_states(:'installment_e_id'::uuid) where charge_id = :'charge_e_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '87000000-0000-0000-0000-000000000001';

select is(
  :'loan_e_outstanding_restored'::numeric,
  40000.00::numeric,
  '44b: the reopened loan''s penalty outstanding is exactly restored to 40,000'
);

-- Reversal itself requires a non-blank reason.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('87100000-0000-0000-0000-000000000001', %L::uuid, '') $sql$,
    :'waiver_b1_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REASON_REQUIRED',
  'a blank reversal reason is rejected'
);

select * from finish();
rollback;
