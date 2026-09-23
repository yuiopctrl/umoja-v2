-- Prompt 09F-B: Write-off reversal and history preservation (section C,
-- test matrix items 14-17).
begin;

select plan(11);

insert into auth.users (id, email) values
  ('95000000-0000-0000-0000-000000000001', 'p09fb-woreversal-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('95100000-0000-0000-0000-000000000001', 'Reversal Group', '95000000-0000-0000-0000-000000000001', 'WREV');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('95200000-0000-0000-0000-000000000001', '95100000-0000-0000-0000-000000000001', '95000000-0000-0000-0000-000000000001', 'Reversal Admin', 'ACTIVE', '2025-01-01', 'WREV-2026-0001'),
  ('95200000-0000-0000-0000-000000000011', '95100000-0000-0000-0000-000000000001', null, 'Reversal Borrower', 'ACTIVE', '2025-01-01', 'WREV-2026-0011');

insert into public.group_membership_roles (group_membership_id, role_id) select '95200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '95000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '95100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '95100000-0000-0000-0000-000000000001', 'WREVP', 'Reversal Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '95100000-0000-0000-0000-000000000001', '95200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('95100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('95100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('95100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

-- Item 16: apply a 09F-A obligation adjustment (waiver) BEFORE
-- write-off, to prove its history survives a write-off + reversal
-- cycle untouched.
select id as first_installment_id from public.loan_installments
  where loan_account_id = :'loan_id'::uuid order by installment_number asc limit 1 \gset

create temporary table t_waiver as
select public.rpc_post_loan_obligation_waiver(
  '95100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_INTEREST', :'first_installment_id'::uuid,
  1000, 'GOODWILL'
) as result;
select (result->>'adjustment_id')::uuid as waiver_id from t_waiver \gset

-- Item 17: an ordinary prior payment exists before write-off.
create temporary table t_prior_payment as
select public.rpc_post_payment('95100000-0000-0000-0000-000000000001', '95200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid, 50000, '2026-05-01'::date, 'CASH') as result;
select (result->>'payment_id')::uuid as prior_payment_id from t_prior_payment \gset

select count(*)::integer as installments_before from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

-- Full write-off.
create temporary table t_write_off as
select public.rpc_post_loan_write_off(
  '95100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, '2026-06-15'::date
) as result;
select (result->>'write_off_event_id')::uuid as write_off_id from t_write_off \gset

-- Item 14: write-off reversal is allowed before any recovery activity.
create temporary table t_reversal as
select public.rpc_reverse_loan_write_off(
  '95100000-0000-0000-0000-000000000001', :'write_off_id'::uuid, 'Written off in error'
) as result;
select (result->>'loan_status') as reversed_status from t_reversal \gset

select is(:'reversed_status'::text, 'ACTIVE'::text, '14a: write-off reversal (with no dependent recovery) restores loan status to ACTIVE');
select is(
  (select status from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '14b: loan_accounts row itself reflects ACTIVE after reversal'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_id'::uuid),
  :'installments_before'::integer,
  '14c: reversal restored the pre-write-off obligation state without rewriting any installment row (row count unchanged)'
);

-- Double reversal rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_write_off('95100000-0000-0000-0000-000000000001', %L::uuid, 'Second attempt') $sql$,
    :'write_off_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_ALREADY_REVERSED',
  'a write-off already reversed cannot be reversed again'
);

-- Item 16: 09F-A adjustment history preserved verbatim across the
-- write-off + reversal cycle (append-only ledger — no status column;
-- immutability means the row's own amount/reverses_adjustment_id are
-- untouched by anything write-off related).
select is(
  (select amount from public.loan_obligation_adjustments where id = :'waiver_id'::uuid),
  -1000.00::numeric,
  '16a: the pre-existing 09F-A waiver adjustment row is untouched (amount unchanged) through write-off and reversal'
);
select is(
  (select reverses_adjustment_id from public.loan_obligation_adjustments where id = :'waiver_id'::uuid),
  null::uuid,
  '16b: the waiver was not itself reversed as a side effect of the write-off/reversal cycle'
);

-- Item 17: the prior ordinary payment remains untouched.
select is(
  (select status from public.payments where id = :'prior_payment_id'::uuid),
  'POSTED',
  '17: the prior ordinary payment remains POSTED/untouched through write-off and reversal'
);

-- Item 15: write-off reversal is BLOCKED once a recovery exists.
select public.rpc_assess_loan_penalties('95100000-0000-0000-0000-000000000001', '2026-08-15'::date, :'loan_id'::uuid);

create temporary table t_write_off2 as
select public.rpc_post_loan_write_off(
  '95100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'GROUP_DECISION', null, '2026-08-15'::date
) as result;
select (result->>'write_off_event_id')::uuid as write_off_id2 from t_write_off2 \gset

select public.rpc_post_loan_recovery(
  '95100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 5000, :'account_id'::uuid, 'CASH', '2026-08-20'::date
);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_write_off('95100000-0000-0000-0000-000000000001', %L::uuid, 'Attempt after recovery') $sql$,
    :'write_off_id2'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '15: write-off reversal is blocked once a recovery has been posted against it'
);

-- Loan remains WRITTEN_OFF (reversal correctly rejected — no partial mutation).
select is(
  (select status from public.loan_accounts where id = :'loan_id'::uuid),
  'WRITTEN_OFF',
  'the loan remains WRITTEN_OFF after the blocked reversal attempt (no partial state change)'
);

-- Reversal reason required.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_write_off('95100000-0000-0000-0000-000000000001', %L::uuid, null) $sql$,
    :'write_off_id2'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_REASON_REQUIRED',
  'write-off reversal requires a non-blank reason'
);

-- Reversal on a nonexistent/foreign write-off id is rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_write_off('95100000-0000-0000-0000-000000000001', %L::uuid, 'x') $sql$,
    gen_random_uuid()
  ),
  'P0001',
  'LOAN_ADJUSTMENT_TARGET_INVALID',
  'reversal of a nonexistent write-off event id is rejected'
);

select * from finish();
rollback;
