-- Prompt 09A: Loan Products — items 1-10.
begin;

select plan(16);

insert into auth.users (id, email) values
  ('1a000000-0000-0000-0000-000000000001', 'p09a-admin@example.com'),
  ('1a000000-0000-0000-0000-000000000002', 'p09a-chairperson@example.com'),
  ('1a000000-0000-0000-0000-000000000003', 'p09a-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('1a100000-0000-0000-0000-000000000001', 'P09A Group A', '1a000000-0000-0000-0000-000000000001', 'LAAA'),
  ('1a100000-0000-0000-0000-000000000002', 'P09A Group B', '1a000000-0000-0000-0000-000000000001', 'LABB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('1a200000-0000-0000-0000-000000000001', '1a100000-0000-0000-0000-000000000001', '1a000000-0000-0000-0000-000000000001', 'LA Admin', 'ACTIVE', '2025-01-01', 'LAAA-2026-0001'),
  ('1a200000-0000-0000-0000-000000000002', '1a100000-0000-0000-0000-000000000001', '1a000000-0000-0000-0000-000000000002', 'LA Chairperson', 'ACTIVE', '2025-01-01', 'LAAA-2026-0002'),
  ('1a200000-0000-0000-0000-000000000003', '1a100000-0000-0000-0000-000000000001', '1a000000-0000-0000-0000-000000000003', 'LA Member', 'ACTIVE', '2025-01-01', 'LAAA-2026-0003'),
  ('1a200000-0000-0000-0000-000000000098', '1a100000-0000-0000-0000-000000000002', '1a000000-0000-0000-0000-000000000001', 'LA Group B Admin', 'ACTIVE', '2025-01-01', 'LABB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '1a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '1a200000-0000-0000-0000-000000000002', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select '1a200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '1a200000-0000-0000-0000-000000000098', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '1a000000-0000-0000-0000-000000000001';

-- 1. create product
create temporary table t_product as
select public.rpc_create_loan_product(
  '1a100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  10000, 1, 12, 12.0000, 'ANNUAL', 'FLAT', 1000000, 'Standard loan product'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

select is(
  (select code from public.loan_products where id = :'product_id'::uuid),
  'NORMAL',
  '1: create product succeeds and stores the exact code'
);

-- 2/3. same-group unique code, duplicate rejected (case-insensitive)
select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000001', 'normal', 'Duplicate Product',
    10000, 1, 12, 5.0000, 'ANNUAL', 'FLAT'
  ) $sql$,
  '23505', null,
  '2/3: duplicate code (case-insensitive) within the same group is rejected'
);

-- code IS allowed to repeat across a DIFFERENT group
set local request.jwt.claim.sub to '1a000000-0000-0000-0000-000000000001';
select lives_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000002', 'NORMAL', 'Same code, different group',
    10000, 1, 12, 5.0000, 'ANNUAL', 'FLAT'
  ) $sql$,
  '3: the same product code is fine in a different group — codes are group-scoped, never globally unique'
);

-- 4. min/max principal validation
select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000001', 'BADPRINCIPAL', 'Bad Principal',
    0, 1, 12, 5.0000, 'ANNUAL', 'FLAT'
  ) $sql$,
  '22023', null,
  '4a: zero/non-positive minimum_principal is rejected'
);
select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000001', 'BADMAXPRINCIPAL', 'Bad Max Principal',
    50000, 1, 12, 5.0000, 'ANNUAL', 'FLAT', 10000
  ) $sql$,
  '22023', null,
  '4b: maximum_principal below minimum_principal is rejected'
);

-- 5. term validation
select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000001', 'BADTERM', 'Bad Term',
    10000, 12, 6, 5.0000, 'ANNUAL', 'FLAT'
  ) $sql$,
  '22023', null,
  '5: maximum_term below minimum_term is rejected'
);

-- 6. rate validation
select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000001', 'BADRATE', 'Bad Rate',
    10000, 1, 12, -1.0000, 'ANNUAL', 'FLAT'
  ) $sql$,
  '22023', null,
  '6: a negative interest_rate is rejected'
);

-- 7. deactivate product
select public.rpc_update_loan_product(
  '1a100000-0000-0000-0000-000000000001', :'product_id'::uuid, p_is_active => false
);
select is(
  (select is_active from public.loan_products where id = :'product_id'::uuid),
  false,
  '7: deactivating a product sets is_active = false'
);

-- 8. inactive product cannot be used for a new loan
create temporary table t_membership as select '1a200000-0000-0000-0000-000000000001'::uuid as membership_id;
select throws_ok(
  $sql$ select public.rpc_preview_loan_schedule(
    '1a100000-0000-0000-0000-000000000001',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '1a100000-0000-0000-0000-000000000001'),
    50000, 6, '2026-06-01'
  ) $sql$,
  'P0001', null,
  '8: an inactive product cannot be previewed/used for a new loan'
);

-- reactivate for subsequent tests
select public.rpc_update_loan_product(
  '1a100000-0000-0000-0000-000000000001', :'product_id'::uuid, p_is_active => true
);

-- 9. product update does not mutate an existing loan's snapshot
create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '1a100000-0000-0000-0000-000000000001', '1a200000-0000-0000-0000-000000000001',
  :'product_id'::uuid, 60000, 6, '2026-06-01'
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset

select public.rpc_update_loan_product(
  '1a100000-0000-0000-0000-000000000001', :'product_id'::uuid, p_interest_rate => 99.0000
);

select is(
  (select interest_rate from public.loan_accounts where id = :'loan_id'::uuid),
  12.0000::numeric,
  '9: editing a product''s interest rate never changes an existing loan account''s frozen snapshot'
);

-- 10. cross-group access denied. Group B's admin membership
-- (1a200000-...-098) shares the same real auth user as Group A's
-- admin (both are legitimately '1a000000-...-0001') — a real user can
-- be an ADMIN of more than one group.
set local request.jwt.claim.sub to '1a000000-0000-0000-0000-000000000001';
select throws_ok(
  $sql$ select public.rpc_get_loan_product(
    '1a100000-0000-0000-0000-000000000002',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '1a100000-0000-0000-0000-000000000001')
  ) $sql$,
  '22023', null,
  '10: a Group B admin cannot fetch a Group A product by injecting a mismatched group_id'
);

-- Permission-key checks (loan_product.view/manage), never role-name.
set local request.jwt.claim.sub to '1a000000-0000-0000-0000-000000000002';
select lives_ok(
  $sql$ select public.rpc_list_loan_products('1a100000-0000-0000-0000-000000000001') $sql$,
  '11: CHAIRPERSON (loan_product.view only) can list products'
);
select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '1a100000-0000-0000-0000-000000000001', 'DENIED', 'Denied',
    10000, 1, 12, 5.0000, 'ANNUAL', 'FLAT'
  ) $sql$,
  '42501', null,
  '12: CHAIRPERSON (no loan_product.manage) cannot create a product'
);

set local request.jwt.claim.sub to '1a000000-0000-0000-0000-000000000003';
select throws_ok(
  $sql$ select public.rpc_list_loan_products('1a100000-0000-0000-0000-000000000001') $sql$,
  '42501', null,
  '13: MEMBER (no loan_product.view) cannot list products'
);

-- Non-existent membership rejected as authorization boundary sanity.
select ok(
  (select count(*) from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where r.code = 'ADMIN' and p.code like 'loan%') = 15,
  '14: ADMIN holds all 15 loan-module permissions (7 from Prompt 09A, '
  || '5 lifecycle permissions added in Prompt 09B, '
  || 'loan_penalty.view/loan_penalty.assess added in Prompt 09D, plus '
  || 'loan_opening.create added in 09D-UAT-BLOCKER-01)'
);
select ok(
  (select count(*) from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where r.code = 'MEMBER' and p.code like 'loan%') = 0,
  '15: MEMBER holds none of the loan-module permissions'
);

select * from finish();
rollback;
