-- Prompt 09A: Loan Accounts — items 11-21.
begin;

select plan(12);

insert into auth.users (id, email) values
  ('2a000000-0000-0000-0000-000000000001', 'p09a-la-admin@example.com'),
  ('2a000000-0000-0000-0000-000000000002', 'p09a-la-member@example.com'),
  ('2a000000-0000-0000-0000-000000000003', 'p09a-la-suspended@example.com');

insert into public.groups (id, name, created_by, code) values
  ('2a100000-0000-0000-0000-000000000001', 'P09A LA Group A', '2a000000-0000-0000-0000-000000000001', 'LNAA'),
  ('2a100000-0000-0000-0000-000000000002', 'P09A LA Group B', '2a000000-0000-0000-0000-000000000001', 'LNBB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('2a200000-0000-0000-0000-000000000001', '2a100000-0000-0000-0000-000000000001', '2a000000-0000-0000-0000-000000000001', 'LA Admin', 'ACTIVE', '2025-01-01', 'LNAA-2026-0001'),
  ('2a200000-0000-0000-0000-000000000002', '2a100000-0000-0000-0000-000000000001', '2a000000-0000-0000-0000-000000000002', 'LA Member', 'ACTIVE', '2025-01-01', 'LNAA-2026-0002'),
  ('2a200000-0000-0000-0000-000000000003', '2a100000-0000-0000-0000-000000000001', '2a000000-0000-0000-0000-000000000003', 'LA Suspended', 'SUSPENDED', '2025-01-01', 'LNAA-2026-0003'),
  ('2a200000-0000-0000-0000-000000000098', '2a100000-0000-0000-0000-000000000002', '2a000000-0000-0000-0000-000000000002', 'LA Group B Member', 'ACTIVE', '2025-01-01', 'LNBB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '2a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '2a200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '2a200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to '2a000000-0000-0000-0000-000000000001';

create temporary table t_product as
select public.rpc_create_loan_product(
  '2a100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  10000, 1, 12, 12.0000, 'ANNUAL', 'FLAT', 500000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- 11. create draft loan
create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000002',
  :'product_id'::uuid, 50000, 6, '2026-06-01'
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset

select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'DRAFT',
  '11: creating a draft loan account succeeds with status DRAFT'
);

-- 12. server-generated loan number, in the expected <CODE>-LN-<YEAR>-<SEQ> shape
select ok(
  (select loan_number ~ '^LNAA-LN-\d{4}-\d{4}$' from public.loan_accounts where id = :'loan_id'::uuid),
  '12: the loan number is server-generated in the <GROUP_CODE>-LN-<YEAR>-<SEQUENCE> shape'
);

-- 13. sequential, non-colliding numbering across repeated calls (the
-- practical, testable proxy for the underlying atomic-upsert
-- concurrency safety already proven for member numbers).
create temporary table t_loan2 as
select public.rpc_create_draft_loan_account(
  '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000002',
  :'product_id'::uuid, 30000, 6, '2026-06-01'
) as result;
select (result->>'id')::uuid as loan2_id from t_loan2 \gset

select isnt(
  (select loan_number from public.loan_accounts where id = :'loan_id'::uuid),
  (select loan_number from public.loan_accounts where id = :'loan2_id'::uuid),
  '13: two loans created in the same group/year never collide on loan_number'
);

-- 14. borrower must belong to group
select throws_ok(
  $sql$ select public.rpc_create_draft_loan_account(
    '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000098',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '2a100000-0000-0000-0000-000000000001'),
    30000, 6, '2026-06-01'
  ) $sql$,
  '22023', null,
  '14: a Group B membership cannot be used as the borrower for a Group A loan'
);

-- 15/16. principal below/above product bounds rejected
select throws_ok(
  $sql$ select public.rpc_create_draft_loan_account(
    '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000002',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '2a100000-0000-0000-0000-000000000001'),
    5000, 6, '2026-06-01'
  ) $sql$,
  '22023', null,
  '15: a principal below the product minimum is rejected'
);
select throws_ok(
  $sql$ select public.rpc_create_draft_loan_account(
    '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000002',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '2a100000-0000-0000-0000-000000000001'),
    999999, 6, '2026-06-01'
  ) $sql$,
  '22023', null,
  '16: a principal above the product maximum is rejected'
);

-- 17. invalid term rejected
select throws_ok(
  $sql$ select public.rpc_create_draft_loan_account(
    '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000002',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '2a100000-0000-0000-0000-000000000001'),
    30000, 24, '2026-06-01'
  ) $sql$,
  '22023', null,
  '17: a term outside the product''s min/max range is rejected'
);

-- 18. inactive (SUSPENDED) membership cannot be a borrower
select throws_ok(
  $sql$ select public.rpc_create_draft_loan_account(
    '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000003',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '2a100000-0000-0000-0000-000000000001'),
    30000, 6, '2026-06-01'
  ) $sql$,
  'P0001', null,
  '18: a SUSPENDED membership cannot be used as the borrower'
);

-- 19. unauthorized creation rejected (permission key, not role name)
set local request.jwt.claim.sub to '2a000000-0000-0000-0000-000000000002';
select throws_ok(
  $sql$ select public.rpc_create_draft_loan_account(
    '2a100000-0000-0000-0000-000000000001', '2a200000-0000-0000-0000-000000000002',
    (select id from public.loan_products where code = 'NORMAL' and group_id = '2a100000-0000-0000-0000-000000000001'),
    30000, 6, '2026-06-01'
  ) $sql$,
  '42501', null,
  '19: a MEMBER (no loan.create) cannot create a draft loan'
);

-- 20. draft edit allowed
set local request.jwt.claim.sub to '2a000000-0000-0000-0000-000000000001';
select public.rpc_update_draft_loan_terms(
  '2a100000-0000-0000-0000-000000000001', :'loan_id'::uuid, p_principal_amount => 40000
);
select is(
  (select principal_amount from public.loan_accounts where id = :'loan_id'::uuid),
  40000.00::numeric,
  '20: editing a DRAFT loan''s terms is allowed and persists'
);

-- 21. once no longer DRAFT (only CANCELLED is reachable in 09A's
-- implemented lifecycle scope), terms/schedule are protected.
select public.rpc_cancel_draft_loan_account('2a100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select throws_ok(
  format(
    $sql$ select public.rpc_update_draft_loan_terms('2a100000-0000-0000-0000-000000000001', %L, p_principal_amount => 45000) $sql$,
    :'loan_id'::uuid
  ),
  'P0001', null,
  '21a: a CANCELLED loan''s terms can no longer be edited'
);
select throws_ok(
  format(
    $sql$ select public.rpc_regenerate_loan_schedule('2a100000-0000-0000-0000-000000000001', %L) $sql$,
    :'loan_id'::uuid
  ),
  'P0001', null,
  '21b: a CANCELLED loan''s schedule can no longer be regenerated'
);

select * from finish();
rollback;
