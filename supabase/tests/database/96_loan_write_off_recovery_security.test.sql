-- Prompt 09F-B: security posture — permissions, tenant isolation,
-- cross-group UUID injection, helper lockdown, idempotency (section E,
-- test matrix items 18-22).
begin;

select plan(25);

-- Item 18 (auth-first, before any setup exists): unauthenticated is
-- rejected before any target/permission is resolved.
select throws_ok(
  $$ select public.rpc_preview_loan_write_off(
    '00000000-0000-0000-0000-000000000000'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'PROLONGED_DEFAULT'
  ) $$,
  '28000',
  'Not authenticated',
  'an unauthenticated write-off preview is rejected before any target/permission is resolved'
);
select throws_ok(
  $$ select public.rpc_preview_loan_recovery(
    '00000000-0000-0000-0000-000000000000'::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 1000
  ) $$,
  '28000',
  'Not authenticated',
  'an unauthenticated recovery preview is rejected before any target/permission is resolved'
);

insert into auth.users (id, email) values
  ('96000000-0000-0000-0000-000000000001', 'p09fb-sec-admin@example.com'),
  ('96000000-0000-0000-0000-000000000002', 'p09fb-sec-treasurer@example.com'),
  ('96000000-0000-0000-0000-000000000003', 'p09fb-sec-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('96100000-0000-0000-0000-000000000001', 'Security Group', '96000000-0000-0000-0000-000000000001', 'WSEC'),
  ('96100000-0000-0000-0000-000000000002', 'Security Other Group', '96000000-0000-0000-0000-000000000001', 'WSEB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('96200000-0000-0000-0000-000000000001', '96100000-0000-0000-0000-000000000001', '96000000-0000-0000-0000-000000000001', 'Sec Admin', 'ACTIVE', '2025-01-01', 'WSEC-2026-0001'),
  ('96200000-0000-0000-0000-000000000002', '96100000-0000-0000-0000-000000000001', '96000000-0000-0000-0000-000000000002', 'Sec Treasurer', 'ACTIVE', '2025-01-01', 'WSEC-2026-0002'),
  ('96200000-0000-0000-0000-000000000003', '96100000-0000-0000-0000-000000000001', '96000000-0000-0000-0000-000000000003', 'Sec Member', 'ACTIVE', '2025-01-01', 'WSEC-2026-0003'),
  ('96200000-0000-0000-0000-000000000011', '96100000-0000-0000-0000-000000000001', null, 'Sec Borrower', 'ACTIVE', '2025-01-01', 'WSEC-2026-0011'),
  ('96200000-0000-0000-0000-000000000021', '96100000-0000-0000-0000-000000000002', '96000000-0000-0000-0000-000000000001', 'Sec Admin (other group)', 'ACTIVE', '2025-01-01', 'WSEB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '96200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '96200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '96200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '96200000-0000-0000-0000-000000000021', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '96100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '96100000-0000-0000-0000-000000000001', 'WSECP', 'Security Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '96100000-0000-0000-0000-000000000001', '96200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 300000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('96100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('96100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('96100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, (current_date - interval '2 months')::date);

-- Item 19: TREASURER cannot write off.
set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000002';
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('96100000-0000-0000-0000-000000000001', %L::uuid, 'PROLONGED_DEFAULT') $sql$,
    :'loan_id'
  ),
  '42501',
  'Not authorized to write off loans in this group',
  '19a: TREASURER lacks loan.write_off (ADMIN-only)'
);

-- MEMBER cannot write off or record recovery.
set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000003';
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('96100000-0000-0000-0000-000000000001', %L::uuid, 'PROLONGED_DEFAULT') $sql$,
    :'loan_id'
  ),
  '42501',
  'Not authorized to write off loans in this group',
  '19b: MEMBER lacks loan.write_off'
);
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_recovery('96100000-0000-0000-0000-000000000001', %L::uuid, 1000) $sql$,
    :'loan_id'
  ),
  '42501',
  'Not authorized to record loan recoveries in this group',
  '19c: MEMBER lacks loan.recovery.create'
);

-- ADMIN posts the write-off; then TREASURER records a recovery (allowed).
set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000001';
create temporary table t_write_off as
select public.rpc_post_loan_write_off(
  '96100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, current_date,
  'sec-woff-key-1'
) as result;
select (result->>'write_off_event_id')::uuid as write_off_id from t_write_off \gset

set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000002';
create temporary table t_treasurer_recovery as
select public.rpc_post_loan_recovery(
  '96100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 10000, :'account_id'::uuid, 'CASH', current_date,
  null, null, 'sec-recovery-key-1'
) as result;
select is((result->>'already_posted')::boolean, false, '19d: TREASURER CAN record a recovery (loan.recovery.create granted)') from t_treasurer_recovery;

-- TREASURER cannot reverse a write-off.
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_write_off('96100000-0000-0000-0000-000000000001', %L::uuid, 'attempt') $sql$,
    :'write_off_id'
  ),
  '42501',
  'Not authorized to reverse loan write-offs in this group',
  '19e: TREASURER lacks loan.write_off.reverse (ADMIN-only)'
);

-- Item 18 (idempotency): retrying the same write-off idempotency key
-- short-circuits rather than raising LOAN_NOT_ACTIVE.
set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000001';
create temporary table t_write_off_retry as
select public.rpc_post_loan_write_off(
  '96100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, current_date,
  'sec-woff-key-1'
) as result;
select is((result->>'already_posted')::boolean, true, '18a: retrying rpc_post_loan_write_off with the same idempotency_key short-circuits (already_posted)') from t_write_off_retry;
select is((result->>'write_off_event_id')::uuid, :'write_off_id'::uuid, '18b: the retried write-off returns the SAME write_off_event_id') from t_write_off_retry;

create temporary table t_recovery_retry as
select public.rpc_post_loan_recovery(
  '96100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 10000, :'account_id'::uuid, 'CASH', current_date,
  null, null, 'sec-recovery-key-1'
) as result;
select is((result->>'already_posted')::boolean, true, '18c: retrying rpc_post_loan_recovery with the same idempotency_key short-circuits (already_posted)') from t_recovery_retry;
select is(
  (select count(*)::integer from public.payments where idempotency_key = 'sec-recovery-key-1'),
  1,
  '18d: exactly one payment row exists for the recovery idempotency key despite two calls'
);

-- Item 20/21: cross-group tenant isolation / UUID injection — a
-- different group's ADMIN cannot target this group's real loan/write-off
-- via any write-off/recovery RPC (preview, post, reverse, recovery
-- preview/post, read summary).
set local request.jwt.claim.sub to '96000000-0000-0000-0000-000000000001';
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('96100000-0000-0000-0000-000000000002', %L::uuid, 'PROLONGED_DEFAULT') $sql$,
    :'loan_id'
  ),
  '22023',
  'Loan account not found in group',
  '20a: cross-group write-off preview against another group''s real loan is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_write_off('96100000-0000-0000-0000-000000000002', %L::uuid, 'PROLONGED_DEFAULT') $sql$,
    :'loan_id'
  ),
  '22023',
  'Loan account not found in group',
  '20b: cross-group write-off post against another group''s real loan is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_write_off('96100000-0000-0000-0000-000000000002', %L::uuid, 'attempt') $sql$,
    :'write_off_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_TARGET_INVALID',
  '20c: cross-group write-off reversal against another group''s real write-off event is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_recovery('96100000-0000-0000-0000-000000000002', %L::uuid, 1000) $sql$,
    :'loan_id'
  ),
  '22023',
  'Loan account not found in group',
  '20d: cross-group recovery preview against another group''s real loan is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_recovery('96100000-0000-0000-0000-000000000002', %L::uuid, 1000, %L::uuid, 'CASH') $sql$,
    :'loan_id', :'account_id'
  ),
  '22023',
  'Loan account not found in group',
  '20e: cross-group recovery post against another group''s real loan is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_get_loan_write_off_summary('96100000-0000-0000-0000-000000000002', %L::uuid) $sql$,
    :'loan_id'
  ),
  '22023',
  'Loan account not found in group',
  '20f: cross-group read of another group''s write-off summary is rejected'
);

-- Item 21: a random/fabricated UUID (never a real row anywhere) is
-- likewise rejected with the same not-found path, never a different
-- (leaky) error.
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('96100000-0000-0000-0000-000000000001', %L::uuid, 'PROLONGED_DEFAULT') $sql$,
    gen_random_uuid()
  ),
  '22023',
  'Loan account not found in group',
  '21: a fabricated/nonexistent loan UUID is rejected identically to a cross-group one'
);

-- Item 22: helper lockdown — none of the three internal helpers are
-- callable by anon or authenticated, only by the function owner.
reset role;
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'loan_write_off_compute_amounts', 'loan_recovery_remaining_balance', 'loan_recovery_compute_allocation'
     )
     and grantee in ('anon', 'authenticated', 'public')),
  0,
  '22a: zero EXECUTE grants to anon/authenticated/public exist on any of the three internal helpers'
);

-- No anon execution on any of the seven public write-off/recovery RPCs.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'rpc_preview_loan_write_off', 'rpc_post_loan_write_off', 'rpc_reverse_loan_write_off',
       'rpc_preview_loan_recovery', 'rpc_post_loan_recovery', 'rpc_get_loan_write_off_summary'
     )
     and grantee = 'anon'),
  0,
  '22b: no anon EXECUTE grant exists on any 09F-B write-off/recovery RPC'
);

-- No direct client mutation of either new table.
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'loan_write_off_events'
     and grantee = 'authenticated' and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  '22c: no direct INSERT/UPDATE/DELETE grant exists for authenticated on loan_write_off_events'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'loan_recovery_events'
     and grantee = 'authenticated' and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  '22d: no direct INSERT/UPDATE/DELETE grant exists for authenticated on loan_recovery_events'
);

-- Permission rows exist exactly as specified: ADMIN all three,
-- TREASURER recovery.create only.
select is(
  (select count(*)::integer from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where r.code = 'ADMIN' and p.code in ('loan.write_off', 'loan.write_off.reverse', 'loan.recovery.create')),
  3,
  '22e: ADMIN role is granted all three new permissions'
);
select is(
  (select count(*)::integer from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where r.code = 'TREASURER' and p.code in ('loan.write_off', 'loan.write_off.reverse')),
  0,
  '22f: TREASURER role is granted neither loan.write_off nor loan.write_off.reverse'
);
select is(
  (select count(*)::integer from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where r.code = 'TREASURER' and p.code = 'loan.recovery.create'),
  1,
  '22g: TREASURER role is granted loan.recovery.create'
);

select * from finish();
rollback;
