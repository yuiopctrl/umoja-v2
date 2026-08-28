-- Prompt 07 UAT-FIX-01: the allocation read model now carries
-- contribution/period context (never a bare "BASE"/"PENALTY" enum),
-- snapshotted onto payment_allocations at posting time so a later
-- rename of the contribution type or period never rewrites history.
begin;

select plan(24);

insert into auth.users (id, email) values
  ('f3000000-0000-0000-0000-000000000001', 'uatfix1-treasurer@example.com'),
  ('f3000000-0000-0000-0000-000000000002', 'uatfix1-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('f3100000-0000-0000-0000-000000000001', 'UATFIX1 Group A', 'f3000000-0000-0000-0000-000000000001', 'F1AA');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('f3200000-0000-0000-0000-000000000001', 'f3100000-0000-0000-0000-000000000001', 'f3000000-0000-0000-0000-000000000001', 'F1 Treasurer', 'ACTIVE', '2025-01-01', 'F1AA-2026-0001'),
  ('f3200000-0000-0000-0000-000000000002', 'f3100000-0000-0000-0000-000000000001', 'f3000000-0000-0000-0000-000000000002', 'Enock Godfrey Mrema', 'ACTIVE', '2025-01-01', 'UMOJA-2026-001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'f3200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f3200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to 'f3000000-0000-0000-0000-000000000001';

create temporary table t_acct as
select public.rpc_create_financial_account('f3100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

create temporary table t_type as
select public.rpc_create_contribution_type('f3100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  'f3100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period_jul as
select public.rpc_create_contribution_period(
  'f3100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15'
) as result;
select (result->>'id')::uuid as period_jul_id from t_period_jul \gset
select public.rpc_open_contribution_period('f3100000-0000-0000-0000-000000000001', :'period_jul_id'::uuid);

select id as charge_jul from public.member_contribution_charges
where period_id = :'period_jul_id'::uuid and membership_id = 'f3200000-0000-0000-0000-000000000002' \gset

-- ---------------------------------------------------------------------
-- 1. rpc_get_member_contribution_statement — member identity + context.
-- ---------------------------------------------------------------------

create temporary table t_statement_before as
select public.rpc_get_member_contribution_statement(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select result->>'member_display_name' from t_statement_before),
  'Enock Godfrey Mrema',
  'the statement returns the member''s display name'
);
select is(
  (select result->>'member_number' from t_statement_before),
  'UMOJA-2026-001',
  'the statement returns the member number'
);
select is(
  (select result->>'membership_status' from t_statement_before),
  'ACTIVE',
  'the statement returns the membership status'
);
select is(
  (select result->'charges'->0->>'contribution_type_name' from t_statement_before),
  'Ada',
  'the outstanding-obligation entry carries the contribution type name'
);
select is(
  (select result->'charges'->0->>'period_label' from t_statement_before),
  'Julai 2026',
  'the outstanding-obligation entry carries the period label'
);
select is(
  (select result->'charges'->0->>'period_purpose' from t_statement_before),
  'NORMAL',
  'a normal recurring charge is tagged period_purpose = NORMAL'
);

-- ---------------------------------------------------------------------
-- 2. A fully-settled charge disappears from the outstanding list, but
-- total_outstanding/wallet_balance remain correct (never an error, an
-- empty array).
-- ---------------------------------------------------------------------

select public.rpc_post_payment(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  20000, '2026-07-20', 'CASH'
);

create temporary table t_statement_after as
select public.rpc_get_member_contribution_statement(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select jsonb_array_length(result->'charges') from t_statement_after),
  0,
  'a fully-settled charge is excluded from the outstanding-obligations list'
);
select is(
  (select (result->>'total_outstanding')::numeric from t_statement_after),
  0.00::numeric,
  'total_outstanding is zero once the only charge is settled'
);
select is(
  (select (result->>'wallet_balance')::numeric from t_statement_after),
  0.00::numeric,
  'wallet_balance is explicitly 0 (present, not null/missing) for an exact payment'
);

-- ---------------------------------------------------------------------
-- 3. Preview allocation lines carry the same context.
-- ---------------------------------------------------------------------

create temporary table t_period_aug as
select public.rpc_create_contribution_period(
  'f3100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Agosti 2026', '2026-08-01', '2026-08-31', p_due_date => '2026-08-15'
) as result;
select (result->>'id')::uuid as period_aug_id from t_period_aug \gset
select public.rpc_open_contribution_period('f3100000-0000-0000-0000-000000000001', :'period_aug_id'::uuid);

create temporary table t_preview as
select public.rpc_preview_payment_allocation(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid, 5000
) as result;

select is(
  (select result->'allocations'->0->>'contribution_type_name' from t_preview),
  'Ada',
  'the preview allocation line carries the contribution type name'
);
select is(
  (select result->'allocations'->0->>'period_label' from t_preview),
  'Agosti 2026',
  'the preview allocation line carries the period label'
);
select is(
  (select (result->'allocations'->0->>'component_outstanding_before')::numeric from t_preview),
  20000.00::numeric,
  'the preview allocation line reports the component''s outstanding amount before this allocation'
);

-- ---------------------------------------------------------------------
-- 4. Two BASE components from different periods are distinguishable
-- via period_label/period_id (never collapsed to identical anonymous
-- "Base" rows).
-- ---------------------------------------------------------------------

create temporary table t_period_nov as
select public.rpc_create_contribution_period(
  'f3100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Novemba 2026', '2026-11-01', '2026-11-30', p_due_date => '2026-11-15'
) as result;
select (result->>'id')::uuid as period_nov_id from t_period_nov \gset
select public.rpc_open_contribution_period('f3100000-0000-0000-0000-000000000001', :'period_nov_id'::uuid);

create temporary table t_preview_two_periods as
select public.rpc_preview_payment_allocation(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid, 40000
) as result;

select is(
  (select result->'allocations'->0->>'component_type' from t_preview_two_periods),
  'BASE',
  'the first allocation line (Agosti) is a BASE component'
);
select is(
  (select result->'allocations'->1->>'component_type' from t_preview_two_periods),
  'BASE',
  'the second allocation line (Novemba) is also a BASE component — same enum, distinguishable only via context'
);
select isnt(
  (select result->'allocations'->0->>'period_label' from t_preview_two_periods),
  (select result->'allocations'->1->>'period_label' from t_preview_two_periods),
  'two same-type BASE allocation lines from different periods carry different period_label values'
);

-- ---------------------------------------------------------------------
-- 5. Historical immutability: post a payment, then RENAME the
-- contribution type and period label. The receipt/payment detail must
-- still show the ORIGINAL names, never the renamed ones.
-- ---------------------------------------------------------------------

create temporary table t_pay_hist as
select public.rpc_post_payment(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  20000, '2026-08-20', 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_pay_hist \gset

reset role;
update public.contribution_types set name = 'Renamed Contribution' where id = (:'type_id')::uuid;
update public.contribution_periods set label = 'Renamed Period' where id = (:'period_aug_id')::uuid;
set local role authenticated;
set local request.jwt.claim.sub to 'f3000000-0000-0000-0000-000000000001';

create temporary table t_receipt_hist as
select public.rpc_get_receipt('f3100000-0000-0000-0000-000000000001', :'payment_id'::uuid) as result;

select is(
  (select result->'allocations'->0->>'contribution_type_name' from t_receipt_hist),
  'Ada',
  'the receipt still shows the ORIGINAL contribution type name after a later rename'
);
select is(
  (select result->'allocations'->0->>'period_label' from t_receipt_hist),
  'Agosti 2026',
  'the receipt still shows the ORIGINAL period label after a later rename'
);

create temporary table t_detail_hist as
select public.rpc_get_payment_detail('f3100000-0000-0000-0000-000000000001', :'payment_id'::uuid) as result;

select is(
  (select result->'allocations'->0->>'contribution_type_name' from t_detail_hist),
  'Ada',
  'payment detail also still shows the ORIGINAL contribution type name after a later rename'
);

-- ---------------------------------------------------------------------
-- 6. Opening-balance charges are tagged period_purpose = OPENING_BALANCE
-- (so Flutter can omit the period suffix for these, per the UAT spec).
-- ---------------------------------------------------------------------

select public.rpc_import_contribution_opening_balances(
  'f3100000-0000-0000-0000-000000000001', :'type_id'::uuid, '2025-12-01',
  jsonb_build_array(jsonb_build_object('membership_id', 'f3200000-0000-0000-0000-000000000002', 'amount', 5000))
);

create temporary table t_statement_ob as
select public.rpc_get_member_contribution_statement(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002'
) as result;

select is(
  (
    select entry->>'period_purpose'
    from jsonb_array_elements((select result from t_statement_ob)->'charges') entry
    where (entry->'components'->0->>'component_type') = 'OPENING_BALANCE'
  ),
  'OPENING_BALANCE',
  'an opening-balance charge is tagged period_purpose = OPENING_BALANCE'
);

-- ---------------------------------------------------------------------
-- 7. Wallet allocation also snapshots the same context. At this point
-- the member still owes the opening-balance charge (5000, test 6) and
-- Novemba (20000, test 4/5 — never actually paid, only previewed) —
-- 25000 total. Paying 35000 clears all of it and leaves exactly 10000
-- of wallet credit for the allocation below.
-- ---------------------------------------------------------------------

select public.rpc_post_payment(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  35000, '2026-08-21', 'CASH'
);

create temporary table t_period_sep as
select public.rpc_create_contribution_period(
  'f3100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Septemba 2026', '2026-09-01', '2026-09-30', p_due_date => '2026-09-15'
) as result;
select (result->>'id')::uuid as period_sep_id from t_period_sep \gset
select public.rpc_open_contribution_period('f3100000-0000-0000-0000-000000000001', :'period_sep_id'::uuid);

create temporary table t_wallet_alloc as
select public.rpc_allocate_member_wallet(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', 10000
) as result;

select id as charge_sep from public.member_contribution_charges
where period_id = :'period_sep_id'::uuid and membership_id = 'f3200000-0000-0000-0000-000000000002' \gset

reset role;
-- Note: by this point the contribution type has already been renamed
-- (section 5) — this correctly snapshots whatever the name was AT
-- POSTING TIME (now "Renamed Contribution"), not the original "Ada".
select is(
  (select contribution_type_name_snapshot from public.payment_allocations
   where wallet_entry_id is not null and charge_id = :'charge_sep'::uuid),
  'Renamed Contribution',
  'a wallet-sourced allocation also snapshots the contribution type name (as it was at this later posting time)'
);
select is(
  (select period_label_snapshot from public.payment_allocations
   where wallet_entry_id is not null and charge_id = :'charge_sep'::uuid),
  'Septemba 2026',
  'a wallet-sourced allocation also snapshots the period label'
);
set local role authenticated;
set local request.jwt.claim.sub to 'f3000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 8. Overpayment visibility (section 11): outstanding -> 0, wallet
-- balance visibly non-zero afterward. September's remaining 10000
-- (only partially covered by the wallet allocation above) is cleared
-- first so October is the member's only debt, matching the exact
-- 30000-debt / 50000-payment / 20000-wallet-credit example.
-- ---------------------------------------------------------------------

select public.rpc_post_payment(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  10000, '2026-09-20', 'CASH'
);

create temporary table t_period_oct as
select public.rpc_create_contribution_period(
  'f3100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Oktoba 2026', '2026-10-01', '2026-10-31', p_due_date => '2026-10-15'
) as result;
select (result->>'id')::uuid as period_oct_id from t_period_oct \gset
select public.rpc_open_contribution_period('f3100000-0000-0000-0000-000000000001', :'period_oct_id'::uuid);

create temporary table t_pay_over as
select public.rpc_post_payment(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  50000, '2026-10-20', 'CASH'
) as result;

select is(
  (select (result->>'wallet_credit_amount')::numeric from t_pay_over), 30000.00::numeric,
  'overpayment: 20000 settles the fresh October debt, 30000 becomes wallet credit'
);

create temporary table t_statement_final as
select public.rpc_get_member_contribution_statement(
  'f3100000-0000-0000-0000-000000000001', 'f3200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select (result->>'total_outstanding')::numeric from t_statement_final),
  0.00::numeric,
  'after the overpayment, total_outstanding is 0'
);
select is(
  (select (result->>'wallet_balance')::numeric from t_statement_final),
  30000.00::numeric,
  'after the overpayment, wallet_balance is visibly the credited amount'
);

select * from finish();
rollback;
