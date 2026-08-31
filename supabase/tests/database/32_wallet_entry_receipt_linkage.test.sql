-- Prompt 07 UAT-FIX-02, section 10: `rpc_list_member_wallet_entries`
-- now carries `source_receipt_number` for a PAYMENT_CREDIT entry, so
-- the wallet ledger can identify its source payment without Flutter
-- reconstructing that linkage. Wallet ledger semantics/balance
-- derivation are unchanged.
begin;

select plan(6);

insert into auth.users (id, email) values
  ('f5000000-0000-0000-0000-000000000001', 'uatfix2-treasurer@example.com'),
  ('f5000000-0000-0000-0000-000000000002', 'uatfix2-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('f5100000-0000-0000-0000-000000000001', 'UATFIX2 Group A', 'f5000000-0000-0000-0000-000000000001', 'F5AA');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('f5200000-0000-0000-0000-000000000001', 'f5100000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000001', 'F5 Treasurer', 'ACTIVE', '2025-01-01', 'F5AA-2026-0001'),
  ('f5200000-0000-0000-0000-000000000002', 'f5100000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000002', 'F5 Member', 'ACTIVE', '2025-01-01', 'F5AA-2026-0002');

insert into public.group_membership_roles (group_membership_id, role_id) select 'f5200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f5200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to 'f5000000-0000-0000-0000-000000000001';

create temporary table t_acct as
select public.rpc_create_financial_account('f5100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

create temporary table t_type as
select public.rpc_create_contribution_type('f5100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  'f5100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  'f5100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15'
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('f5100000-0000-0000-0000-000000000001', :'period_id'::uuid);

-- Overpayment: 50000 against 20000 debt -> 30000 wallet credit.
create temporary table t_pay as
select public.rpc_post_payment(
  'f5100000-0000-0000-0000-000000000001', 'f5200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  50000, '2026-07-20', 'CASH'
) as result;

select is(
  (select (result->>'wallet_credit_amount')::numeric from t_pay), 30000.00::numeric,
  'overpayment creates the expected 30000 wallet credit'
);

create temporary table t_wallet as
select public.rpc_get_member_wallet(
  'f5100000-0000-0000-0000-000000000001', 'f5200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select (result->>'wallet_balance')::numeric from t_wallet), 30000.00::numeric,
  'rpc_get_member_wallet reports the correct non-zero balance'
);

create temporary table t_entries as
select public.rpc_list_member_wallet_entries(
  'f5100000-0000-0000-0000-000000000001', 'f5200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select (result->>'wallet_balance')::numeric from t_entries), 30000.00::numeric,
  'rpc_list_member_wallet_entries bundles the same correct balance'
);
select is(
  (select result->'items'->0->>'entry_type' from t_entries),
  'PAYMENT_CREDIT',
  'the ledger shows the PAYMENT_CREDIT entry'
);
select is(
  (select result->'items'->0->>'source_receipt_number' from t_entries),
  (select receipt_number from public.payments where financial_account_id = (:'account_id')::uuid),
  'the PAYMENT_CREDIT entry carries its source payment''s receipt number'
);

-- A member with zero wallet activity gets an explicit empty list and
-- an explicit zero balance — never null, never an error.
create temporary table t_period2 as
select public.rpc_create_contribution_period(
  'f5100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Agosti 2026', '2026-08-01', '2026-08-31', p_due_date => '2026-08-15'
) as result;
select (result->>'id')::uuid as period2_id from t_period2 \gset
select public.rpc_open_contribution_period('f5100000-0000-0000-0000-000000000001', :'period2_id'::uuid);

create temporary table t_entries_treasurer as
select public.rpc_list_member_wallet_entries(
  'f5100000-0000-0000-0000-000000000001', 'f5200000-0000-0000-0000-000000000001'
) as result;

select is(
  (select (result->>'wallet_balance')::numeric from t_entries_treasurer), 0.00::numeric,
  'a member with no wallet entries at all still reports an explicit 0 balance, never null'
);

select * from finish();
rollback;
