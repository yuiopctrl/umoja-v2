-- Prompt 09F-A-05: security hardening regression — anon/authenticated
-- can no longer touch the entry_no identity sequence directly, the
-- table remains structurally closed to direct client mutation, and
-- every entry_no-dependent behavior (monotonic ordering, the reversal
-- dependency guard, idempotency) still works correctly through the
-- authorized SECURITY DEFINER RPCs.
begin;

select plan(14);

insert into auth.users (id, email) values
  ('91000000-0000-0000-0000-000000000001', 'p09fa05-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('91100000-0000-0000-0000-000000000001', 'Sequence Hardening Group', '91000000-0000-0000-0000-000000000001', 'SEQH');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('91200000-0000-0000-0000-000000000001', '91100000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'Hardening Admin', 'ACTIVE', '2025-01-01', 'SEQH-2026-0001'),
  ('91200000-0000-0000-0000-000000000011', '91100000-0000-0000-0000-000000000001', null, 'Borrower', 'ACTIVE', '2025-01-01', 'SEQH-2026-0011');

insert into public.group_membership_roles (group_membership_id, role_id) select '91200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

-- ---------------------------------------------------------------------
-- Items A/B: neither anon nor authenticated may use the sequence
-- directly — checked both structurally (has_sequence_privilege) and
-- behaviorally (a real nextval() attempt as each role is rejected).
-- ---------------------------------------------------------------------

select ok(
  not has_sequence_privilege('anon', 'public.loan_obligation_adjustments_entry_no_seq', 'USAGE'),
  'A1: anon has no USAGE privilege on the entry_no sequence'
);
select ok(
  not has_sequence_privilege('anon', 'public.loan_obligation_adjustments_entry_no_seq', 'UPDATE'),
  'A2: anon has no UPDATE (setval/nextval) privilege on the entry_no sequence'
);
select ok(
  not has_sequence_privilege('authenticated', 'public.loan_obligation_adjustments_entry_no_seq', 'USAGE'),
  'B1: authenticated has no USAGE privilege on the entry_no sequence'
);
select ok(
  not has_sequence_privilege('authenticated', 'public.loan_obligation_adjustments_entry_no_seq', 'UPDATE'),
  'B2: authenticated has no UPDATE (setval/nextval) privilege on the entry_no sequence'
);

set local role authenticated;
set local request.jwt.claim.sub to '91000000-0000-0000-0000-000000000001';

select throws_ok(
  $$ select nextval('public.loan_obligation_adjustments_entry_no_seq') $$,
  '42501',
  null,
  'B3: a real nextval() attempt as authenticated is rejected with permission denied'
);
select throws_ok(
  $$ select setval('public.loan_obligation_adjustments_entry_no_seq', 999999) $$,
  '42501',
  null,
  'B4: a real setval() attempt as authenticated is rejected with permission denied'
);

-- ---------------------------------------------------------------------
-- Item C: authenticated cannot directly INSERT into
-- loan_obligation_adjustments — re-confirmed after the sequence
-- hardening (table-level grants are unrelated to sequence grants, but
-- this proves the fix did not accidentally loosen or tighten table
-- access either).
-- ---------------------------------------------------------------------

select throws_ok(
  $$ insert into public.loan_obligation_adjustments (
       group_id, loan_account_id, target_type, loan_penalty_charge_id,
       adjustment_type, amount, reason_code, created_by
     ) values (
       '91100000-0000-0000-0000-000000000001', '91100000-0000-0000-0000-000000000001',
       'LOAN_PENALTY', '91100000-0000-0000-0000-000000000001',
       'WAIVER', -1, 'HARDSHIP', '91000000-0000-0000-0000-000000000001'
     ) $$,
  '42501',
  null,
  'C: authenticated cannot directly INSERT into loan_obligation_adjustments'
);

-- ---------------------------------------------------------------------
-- Items D/E/F: the authorized SECURITY DEFINER RPC still creates
-- adjustments normally, entry_no is generated (never null), and it is
-- monotonically increasing across successive authorized posts.
-- ---------------------------------------------------------------------

create temporary table t_account as
select public.rpc_create_financial_account(
  '91100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '91100000-0000-0000-0000-000000000001', 'SEQHP', 'Sequence Hardening Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 40000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '91100000-0000-0000-0000-000000000001', '91200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('91100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('91100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('91100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select public.rpc_assess_loan_penalties('91100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);
select id as charge_id from public.loan_penalty_charges where loan_installment_id = :'installment_id'::uuid \gset

create temporary table t_waiver_1 as
select public.rpc_post_loan_obligation_waiver(
  '91100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid, 10000, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_1_id from t_waiver_1 \gset

select is(
  (result->>'adjustment_type')::text,
  'WAIVER',
  'D: the authorized SECURITY DEFINER RPC still creates an adjustment successfully'
) from t_waiver_1;

create temporary table t_waiver_2 as
select public.rpc_post_loan_obligation_waiver(
  '91100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid, 10000, 'GOODWILL'
) as result;
select (result->>'adjustment_id')::uuid as waiver_2_id from t_waiver_2 \gset

reset role;
select entry_no as entry_no_1 from public.loan_obligation_adjustments where id = :'waiver_1_id'::uuid \gset
select entry_no as entry_no_2 from public.loan_obligation_adjustments where id = :'waiver_2_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '91000000-0000-0000-0000-000000000001';

select ok(
  :entry_no_1 is not null and :entry_no_2 is not null,
  'E: entry_no is generated normally (never null) through the authorized RPC'
);
select ok(
  :entry_no_2 > :entry_no_1,
  'F: entry_no is monotonically increasing across successive authorized adjustment posts'
);

-- ---------------------------------------------------------------------
-- Item G: the entry_no-dependent reversal guard still functions — a
-- later adjustment on the same target blocks reversing an earlier one.
-- ---------------------------------------------------------------------

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('91100000-0000-0000-0000-000000000001', %L::uuid, 'blocked by later waiver') $sql$,
    :'waiver_1_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  'G: the entry_no-based reversal dependency guard still blocks reversing a superseded adjustment'
);

select public.rpc_reverse_loan_obligation_adjustment('91100000-0000-0000-0000-000000000001', :'waiver_2_id'::uuid, 'no later activity');

select ok(
  (select count(*)::integer from public.loan_obligation_adjustments where reverses_adjustment_id = :'waiver_2_id'::uuid) = 1,
  'G2: reversing the LATEST (unsuperseded) adjustment still succeeds normally'
);

-- ---------------------------------------------------------------------
-- Item H: idempotent retry behavior is unaffected.
-- ---------------------------------------------------------------------

create temporary table t_idem_1 as
select public.rpc_post_loan_obligation_waiver(
  '91100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid,
  5000, 'HARDSHIP', null, current_date, 'seq-hardening-idem-key-01'
) as result;

create temporary table t_idem_2 as
select public.rpc_post_loan_obligation_waiver(
  '91100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid,
  5000, 'HARDSHIP', null, current_date, 'seq-hardening-idem-key-01'
) as result;

select is(
  (select (t_idem_1.result->>'adjustment_id')::uuid) = (select (t_idem_2.result->>'adjustment_id')::uuid),
  true,
  'H: idempotent retry still returns the same adjustment id after the sequence hardening'
) from t_idem_1, t_idem_2;
select is(
  (t_idem_2.result->>'already_posted')::boolean,
  true,
  'H2: the retry is correctly reported as already_posted'
) from t_idem_2;

select * from finish();
rollback;
