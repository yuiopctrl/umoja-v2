-- Prompt 09F-A: Loan Waivers — core accounting behaviour (sections
-- 9/10, test matrix items 1-6, 19-23, 48).
begin;

select plan(24);

insert into auth.users (id, email) values
  ('81000000-0000-0000-0000-000000000001', 'p09fa-waiver-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('81100000-0000-0000-0000-000000000001', 'Waiver Group', '81000000-0000-0000-0000-000000000001', 'WAIV');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('81200000-0000-0000-0000-000000000001', '81100000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'Waiver Admin', 'ACTIVE', '2025-01-01', 'WAIV-2026-0001'),
  ('81200000-0000-0000-0000-000000000011', '81100000-0000-0000-0000-000000000001', null, 'Penalty Borrower', 'ACTIVE', '2025-01-01', 'WAIV-2026-0011'),
  ('81200000-0000-0000-0000-000000000012', '81100000-0000-0000-0000-000000000001', null, 'Interest Borrower', 'ACTIVE', '2025-01-01', 'WAIV-2026-0012');

insert into public.group_membership_roles (group_membership_id, role_id) select '81200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '81100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- =======================================================================
-- Penalty scenario: 100,000 assessed FIXED penalty, 60,000 already paid
-- -> 40,000 effective outstanding. Mirrors the prompt's own worked
-- example exactly.
-- =======================================================================

create temporary table t_product_penalty as
select public.rpc_create_loan_product(
  '81100000-0000-0000-0000-000000000001', 'WPEN', 'Waiver Penalty Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 100000
) as result;
select (result->>'id')::uuid as product_penalty_id from t_product_penalty \gset

create temporary table t_loan_penalty as
select public.rpc_create_draft_loan_account(
  '81100000-0000-0000-0000-000000000001', '81200000-0000-0000-0000-000000000011'::uuid,
  :'product_penalty_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_penalty_id from t_loan_penalty \gset
select public.rpc_submit_loan_account('81100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid);
select public.rpc_approve_loan_account('81100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid);
select public.rpc_disburse_loan_account('81100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, :'account_id'::uuid, current_date);
select id as penalty_installment_id from public.loan_installments where loan_account_id = :'loan_penalty_id'::uuid \gset

select public.rpc_assess_loan_penalties('81100000-0000-0000-0000-000000000001', current_date, :'loan_penalty_id'::uuid);
select id as penalty_charge_id from public.loan_penalty_charges where loan_installment_id = :'penalty_installment_id'::uuid \gset

-- Partial payment: 60,000 (penalty is priority 0, so it all lands on
-- the penalty, leaving 40,000 outstanding).
select public.rpc_post_payment(
  '81100000-0000-0000-0000-000000000001', '81200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid,
  60000, current_date, 'CASH'
);

select count(*)::integer as payments_before from public.payments \gset
select count(*)::integer as allocations_before from public.payment_allocations \gset
select count(*)::integer as wallet_entries_before from public.member_wallet_entries \gset
reset role;
select outstanding as setup_penalty_outstanding from public.loan_penalty_charge_states(:'penalty_installment_id'::uuid) where charge_id = :'penalty_charge_id'::uuid \gset
select public.financial_account_balance(:'account_id'::uuid) as cash_before \gset
select (public.rpc_get_financial_position('81100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric as penalty_income_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

select is(
  :'setup_penalty_outstanding'::numeric,
  40000.00::numeric,
  'setup: penalty outstanding is 40,000 after 60,000 already paid against a 100,000 assessment'
);

-- Item 4 / part of item 3: a waiver above the EFFECTIVE outstanding
-- (40,000) is rejected, even though it is well below the original
-- 100,000 assessment — the already-paid 60,000 can never be waived away.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 41000, 'HARDSHIP') $sql$,
    :'loan_penalty_id', :'penalty_charge_id'
  ),
  'P0001',
  'LOAN_WAIVER_EXCEEDS_OUTSTANDING',
  '3/4: a waiver above the effective (already-paid-aware) outstanding is rejected'
);

-- Item 1: partial waiver.
create temporary table t_waiver_partial as
select public.rpc_post_loan_obligation_waiver(
  '81100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid,
  15000, 'HARDSHIP'
) as result;

reset role;
select outstanding as partial_outstanding from public.loan_penalty_charge_states(:'penalty_installment_id'::uuid) where charge_id = :'penalty_charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

select is(
  :'partial_outstanding'::numeric,
  25000.00::numeric,
  '1: partial penalty waiver reduces effective outstanding from 40,000 to 25,000'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'penalty_charge_id'::uuid),
  100000.00::numeric,
  '1b: the original 100,000 assessment is untouched by the waiver'
);

-- Preview never mutates state (checked here while outstanding is still
-- 25,000, i.e. before the charge is fully waived below).
select is(
  (public.rpc_preview_loan_obligation_waiver(
    '81100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid, 1000, 'HARDSHIP'
  )->>'cash_impact')::numeric,
  0::numeric,
  'preview reports cash_impact 0 without posting anything'
);
select is(
  (select count(*)::integer from public.loan_obligation_adjustments where loan_penalty_charge_id = :'penalty_charge_id'::uuid),
  1,
  'preview created no adjustment row — exactly the 1 real waiver posted above still exists'
);

-- Item 2: full waiver of the remaining 25,000.
select public.rpc_post_loan_obligation_waiver(
  '81100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid,
  25000, 'COMMITTEE_DECISION'
);

reset role;
select outstanding as full_waived_outstanding from public.loan_penalty_charge_states(:'penalty_installment_id'::uuid) where charge_id = :'penalty_charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

select is(
  :'full_waived_outstanding'::numeric,
  0.00::numeric,
  '2: full waiver of the remainder brings effective penalty outstanding to exactly zero'
);

-- Item 48: outstanding never goes negative even after fully waiving.
select ok(
  :'full_waived_outstanding'::numeric >= 0,
  '48: effective outstanding never goes negative'
);

-- A further waiver attempt now correctly sees zero outstanding.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 1, 'GOODWILL') $sql$,
    :'loan_penalty_id', :'penalty_charge_id'
  ),
  'P0001',
  'LOAN_WAIVER_EXCEEDS_OUTSTANDING',
  '3b: any further waiver on a fully-waived charge is rejected'
);

-- Items 19-23: zero payment/receipt/wallet/cashbook/income from the two
-- waivers posted above.
select is(
  (select count(*)::integer from public.payments),
  :payments_before::integer,
  '19: no payment row was created by either waiver'
);
select is(
  (select count(*)::integer from public.payment_allocations),
  :allocations_before::integer,
  '20 (receipt proxy): no payment_allocations row was created (no receipt line exists without a payment)'
);
select is(
  (select count(*)::integer from public.member_wallet_entries),
  :wallet_entries_before::integer,
  '21: no member_wallet_entries row (no wallet movement) was created'
);
reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before'::numeric,
  '22: cashbook balance is completely unchanged by either waiver'
);
select is(
  (public.rpc_get_financial_position('81100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  :'penalty_income_before'::numeric,
  '23: recognized penalty income is unchanged — a waiver never recognizes income'
);
set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

-- =======================================================================
-- Interest scenario: installment 1 is due (earned interest), installment
-- 2 is not yet due (future/unearned interest) — items 5/6.
-- =======================================================================

create temporary table t_product_interest as
select public.rpc_create_loan_product(
  '81100000-0000-0000-0000-000000000001', 'WINT', 'Waiver Interest Product', 100000, 1, 12, 6.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_interest_id from t_product_interest \gset

create temporary table t_loan_interest as
select public.rpc_create_draft_loan_account(
  '81100000-0000-0000-0000-000000000001', '81200000-0000-0000-0000-000000000012'::uuid,
  :'product_interest_id'::uuid, 400000, 2, current_date
) as result;
select (result->>'id')::uuid as loan_interest_id from t_loan_interest \gset
select public.rpc_submit_loan_account('81100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_approve_loan_account('81100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_disburse_loan_account('81100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, :'account_id'::uuid, current_date);

select id as due_installment_id, interest_due as due_interest from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid and installment_number = 1 \gset
select id as future_installment_id, interest_due as future_interest from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid and installment_number = 2 \gset

-- Item 6: the not-yet-due installment's interest can never be waived.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 1, 'HARDSHIP') $sql$,
    :'loan_interest_id', :'future_installment_id'
  ),
  'P0001',
  'LOAN_FUTURE_INTEREST_NOT_WAIVABLE',
  '6: future/unearned interest cannot be waived'
);

-- Item 5: the due (earned/payable) installment's interest CAN be waived,
-- up to its full currently-payable outstanding.
create temporary table t_interest_waiver as
select public.rpc_post_loan_obligation_waiver(
  '81100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'due_installment_id'::uuid,
  :due_interest, 'GOODWILL'
) as result;

reset role;
select outstanding as due_interest_outstanding from public.loan_installment_component_states(:'due_installment_id'::uuid) where component_type = 'INTEREST' \gset
set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

select is(
  :'due_interest_outstanding'::numeric,
  0.00::numeric,
  '5: the full currently earned/payable interest can be waived'
);
select is(
  (select interest_due from public.loan_installments where id = :'due_installment_id'::uuid),
  :'due_interest'::numeric,
  '5b: interest_due itself is never rewritten by the waiver'
);
select is((result->>'cash_impact')::numeric, 0::numeric, '5c: waiver response reports cash_impact 0') from t_interest_waiver;
select is((result->>'payment_created')::boolean, false, '5d: waiver response reports payment_created false') from t_interest_waiver;
select is((result->>'receipt_created')::boolean, false, '5e: waiver response reports receipt_created false') from t_interest_waiver;

-- A subsequent request exceeding the (now zero) outstanding is rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 1, 'HARDSHIP') $sql$,
    :'loan_interest_id', :'due_installment_id'
  ),
  'P0001',
  'LOAN_WAIVER_EXCEEDS_OUTSTANDING',
  '3c: a waiver on an already fully-waived installment interest is rejected'
);

-- Unrecognized target type is rejected structurally.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PRINCIPAL', %L::uuid, 1, 'HARDSHIP') $sql$,
    :'loan_interest_id', :'due_installment_id'
  ),
  'P0001',
  'LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED',
  'principal cannot be targeted by a waiver'
);

-- Blank/unrecognized reason and OTHER-without-note are both rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 1, '') $sql$,
    :'loan_interest_id', :'future_installment_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REASON_REQUIRED',
  'a blank reason is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('81100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 1, 'OTHER') $sql$,
    :'loan_interest_id', :'future_installment_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_OTHER_NOTE_REQUIRED',
  'OTHER reason requires a non-blank note'
);

select * from finish();
rollback;
