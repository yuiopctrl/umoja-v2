-- Prompt 07 UAT-FIX-04: "ADMIN cannot reverse payment / permission
-- denied" — a physical UAT blocker. Full diagnosis found the database
-- role matrix and `rpc_reverse_payment`'s authorization check were
-- already correct (ADMIN/TREASURER hold `payment.reverse` in
-- `role_permissions`, `has_group_permission` uses the exact same
-- canonical key every other payment RPC uses). The real defect was in
-- Flutter: `PaymentReversalScreen` was calling
-- `rpc_reverse_payment(p_group_id, ...)` with the paying member's
-- `membershipId` instead of the actual group id — see
-- `payment_reversal_widget_test.dart`'s new groupId assertion for the
-- Flutter-side regression coverage. This file proves the backend side
-- of the locked role matrix directly against the real RPC (not a
-- permission-helper unit test), so a future regression on either side
-- is caught independently.
begin;

select plan(11);

insert into auth.users (id, email) values
  ('f8000000-0000-0000-0000-000000000001', 'uatfix4-admin@example.com'),
  ('f8000000-0000-0000-0000-000000000002', 'uatfix4-treasurer@example.com'),
  ('f8000000-0000-0000-0000-000000000003', 'uatfix4-chairperson@example.com'),
  ('f8000000-0000-0000-0000-000000000004', 'uatfix4-secretary@example.com'),
  ('f8000000-0000-0000-0000-000000000005', 'uatfix4-member@example.com'),
  ('f8000000-0000-0000-0000-000000000006', 'uatfix4-payer@example.com');

insert into public.groups (id, name, created_by, code) values
  ('f8100000-0000-0000-0000-000000000001', 'UATFIX4 Group A', 'f8000000-0000-0000-0000-000000000001', 'F8AA'),
  ('f8100000-0000-0000-0000-000000000002', 'UATFIX4 Group B', 'f8000000-0000-0000-0000-000000000001', 'F8BB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('f8200000-0000-0000-0000-000000000001', 'f8100000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000001', 'F8 Admin', 'ACTIVE', '2025-01-01', 'F8AA-2026-0001'),
  ('f8200000-0000-0000-0000-000000000002', 'f8100000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000002', 'F8 Treasurer', 'ACTIVE', '2025-01-01', 'F8AA-2026-0002'),
  ('f8200000-0000-0000-0000-000000000003', 'f8100000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000003', 'F8 Chairperson', 'ACTIVE', '2025-01-01', 'F8AA-2026-0003'),
  ('f8200000-0000-0000-0000-000000000004', 'f8100000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000004', 'F8 Secretary', 'ACTIVE', '2025-01-01', 'F8AA-2026-0004'),
  ('f8200000-0000-0000-0000-000000000005', 'f8100000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000005', 'F8 Member', 'ACTIVE', '2025-01-01', 'F8AA-2026-0005'),
  ('f8200000-0000-0000-0000-000000000006', 'f8100000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000006', 'F8 Payer', 'ACTIVE', '2025-01-01', 'F8AA-2026-0006'),
  ('f8200000-0000-0000-0000-000000000098', 'f8100000-0000-0000-0000-000000000002', 'f8000000-0000-0000-0000-000000000006', 'F8B Admin', 'ACTIVE', '2025-01-01', 'F8BB-2026-0001'),
  ('f8200000-0000-0000-0000-000000000099', 'f8100000-0000-0000-0000-000000000002', null, 'F8B Other Group Payer', 'ACTIVE', '2025-01-01', 'F8BB-2026-0002');

insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000004', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000006', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f8200000-0000-0000-0000-000000000098', id from public.roles where code = 'ADMIN';

-- ---------------------------------------------------------------------
-- Explicit proof (section 2/4): the ADMIN role really does carry
-- payment.reverse in role_permissions — never assumed from the seed.
-- ---------------------------------------------------------------------

select ok(
  exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.id = rp.permission_id
    where r.code = 'ADMIN' and p.code = 'payment.reverse'
  ),
  'the ADMIN role actually owns a role_permissions row for payment.reverse'
);
select ok(
  exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.id = rp.permission_id
    where r.code = 'TREASURER' and p.code = 'payment.reverse'
  ),
  'the TREASURER role actually owns a role_permissions row for payment.reverse'
);
select is(
  (select count(*)::int from public.permissions where code ilike 'payment%revers%' and code <> 'payment.reverse'),
  0,
  'section 3: there is exactly one canonical PAYMENT reversal permission '
  'key — no ''payment.reversal''/''payments.reverse''/etc variant exists '
  'in the catalog (a differently-scoped permission like '
  'financial_entry.reverse from a later phase is not a variant of this '
  'one and must not be flagged)'
);

set local role authenticated;
set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000001';

create temporary table t_acct as
select public.rpc_create_financial_account('f8100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

create temporary table t_type as
select public.rpc_create_contribution_type('f8100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  'f8100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  'f8100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15'
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('f8100000-0000-0000-0000-000000000001', :'period_id'::uuid);

-- ---------------------------------------------------------------------
-- A. ADMIN can reverse an own-group posted payment.
-- ---------------------------------------------------------------------

create temporary table t_pay_admin as
select public.rpc_post_payment(
  'f8100000-0000-0000-0000-000000000001', 'f8200000-0000-0000-0000-000000000006', :'account_id'::uuid,
  5000, '2026-07-10', 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_admin_id from t_pay_admin \gset

select lives_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'A: ADMIN reversal') $sql$,
    :'payment_admin_id'
  ),
  'A: ADMIN can reverse a posted payment in their own group'
);
select is(
  (select status::text from public.payments where id = :'payment_admin_id'::uuid),
  'REVERSED',
  'A: the ADMIN-reversed payment is actually flipped to REVERSED'
);

-- ---------------------------------------------------------------------
-- B. TREASURER can reverse an own-group posted payment.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000002';

create temporary table t_pay_treasurer as
select public.rpc_post_payment(
  'f8100000-0000-0000-0000-000000000001', 'f8200000-0000-0000-0000-000000000006', :'account_id'::uuid,
  5000, '2026-07-11', 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_treasurer_id from t_pay_treasurer \gset

select lives_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'B: TREASURER reversal') $sql$,
    :'payment_treasurer_id'
  ),
  'B: TREASURER can reverse a posted payment in their own group'
);

-- ---------------------------------------------------------------------
-- C/D/E. CHAIRPERSON/SECRETARY/MEMBER cannot reverse — explicit 42501
-- denial (section 7/10-G), never a silent no-op or a different error
-- masking the real authorization failure.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000001';
create temporary table t_pay_target as
select public.rpc_post_payment(
  'f8100000-0000-0000-0000-000000000001', 'f8200000-0000-0000-0000-000000000006', :'account_id'::uuid,
  5000, '2026-07-12', 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_target_id from t_pay_target \gset

set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000003';
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'C: chairperson attempt') $sql$,
    :'payment_target_id'
  ),
  '42501', 'Not authorized to reverse payments in this group',
  'C: CHAIRPERSON (payment.view/payment.receipt.view/wallet.view only) cannot reverse'
);

set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000004';
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'D: secretary attempt') $sql$,
    :'payment_target_id'
  ),
  '42501', 'Not authorized to reverse payments in this group',
  'D: SECRETARY (payment.view/payment.receipt.view only) cannot reverse'
);

set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000005';
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'E: member attempt') $sql$,
    :'payment_target_id'
  ),
  '42501', 'Not authorized to reverse payments in this group',
  'E: MEMBER (no Prompt 07 permissions) cannot reverse'
);

-- ---------------------------------------------------------------------
-- F. ADMIN cannot reverse another group's payment, even while
-- operating under their own (real) group context — proves cross-group
-- isolation on the reversal RPC specifically, not just posting.
-- ---------------------------------------------------------------------

-- Set up Group B's own financial account/payment as Group B's own
-- ADMIN (f8000000...006 is a completely separate membership there) —
-- Group A's ADMIN (f8000000...001) has no membership in Group B at
-- all, so they could never legitimately set this fixture up.
set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000006';
create temporary table t_acct_b as
select public.rpc_create_financial_account('f8100000-0000-0000-0000-000000000002', 'Group B Cash', 'CASH') as result;
select (result->>'id')::uuid as account_b_id from t_acct_b \gset

create temporary table t_pay_group_b as
select public.rpc_post_payment(
  'f8100000-0000-0000-0000-000000000002', 'f8200000-0000-0000-0000-000000000099', :'account_b_id'::uuid,
  5000, '2026-07-13', 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_group_b_id from t_pay_group_b \gset

set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000001';
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'F: cross-group attempt') $sql$,
    :'payment_group_b_id'
  ),
  '22023', 'Payment not found in group',
  'F: an ADMIN cannot reverse a payment belonging to a different group, even while passing their own real group id'
);

-- ---------------------------------------------------------------------
-- H. Inactive membership: even a real ADMIN role assignment is denied
-- once their own membership is SUSPENDED — matches has_group_permission
-- 's documented "ACTIVE membership only" policy, unchanged here. The
-- payment is posted while the ADMIN is still ACTIVE (posting itself
-- also requires an ACTIVE membership), then suspended before the
-- reversal attempt.
-- ---------------------------------------------------------------------

create temporary table t_pay_pre_suspend as
select public.rpc_post_payment(
  'f8100000-0000-0000-0000-000000000001', 'f8200000-0000-0000-0000-000000000006', :'account_id'::uuid,
  5000, '2026-07-14', 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_pre_suspend_id from t_pay_pre_suspend \gset

reset role;
update public.group_memberships set status = 'SUSPENDED'
where id = 'f8200000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub to 'f8000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_payment('f8100000-0000-0000-0000-000000000001', %L, 'H: suspended admin attempt') $sql$,
    :'payment_pre_suspend_id'
  ),
  '42501', 'Not authorized to reverse payments in this group',
  'H: a SUSPENDED membership is denied even with the ADMIN role assigned — status is checked, not bypassed'
);

select * from finish();
rollback;
