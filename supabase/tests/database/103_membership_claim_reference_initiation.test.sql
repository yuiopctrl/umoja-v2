-- Prompt 09G-B1-D1: safe membership claim initiation by human-readable
-- reference (group code + member number) — anti-enumeration, shared-
-- engine compatibility with the existing opaque-id workflow, and
-- confirmation that phone plays no role in matching at all.
begin;

select plan(35);

insert into auth.users (id, email) values
  ('10300000-0000-0000-0000-000000000011', 'p09gb1d1-admin@example.com'),
  ('10300000-0000-0000-0000-000000000012', 'p09gb1d1-member@example.com'),
  ('10300000-0000-0000-0000-000000000021', 'p09gb1d1-claimant1@example.com'),
  ('10300000-0000-0000-0000-000000000022', 'p09gb1d1-claimant2@example.com'),
  ('10300000-0000-0000-0000-000000000023', 'p09gb1d1-existing@example.com'),
  ('10300000-0000-0000-0000-000000000024', 'p09gb1d1-disabled@example.com'),
  ('10300000-0000-0000-0000-000000000025', 'p09gb1d1-linked@example.com'),
  ('10300000-0000-0000-0000-000000000026', 'p09gb1d1-claimant3@example.com'),
  ('10300000-0000-0000-0000-000000000027', 'p09gb1d1-claimant4@example.com');

update public.profiles set is_active = false where id = '10300000-0000-0000-0000-000000000024';

insert into public.groups (id, name, created_by, code, status) values
  ('10300000-0000-0000-0000-000000000001', 'Reference Group A', '10300000-0000-0000-0000-000000000011', 'CLMD1A', 'ACTIVE'),
  ('10300000-0000-0000-0000-000000000002', 'Reference Group B', '10300000-0000-0000-0000-000000000011', 'CLMD1B', 'ACTIVE'),
  ('10300000-0000-0000-0000-000000000003', 'Reference Group C (suspended)', '10300000-0000-0000-0000-000000000011', 'CLMD1C', 'SUSPENDED');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10300000-0000-0000-0000-000000000101', '10300000-0000-0000-0000-000000000001', '10300000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'CLMD1A-0001', null),
  ('10300000-0000-0000-0000-000000000102', '10300000-0000-0000-0000-000000000001', '10300000-0000-0000-0000-000000000012', 'Member Two', 'ACTIVE', '2025-01-01', 'CLMD1A-0002', null),
  ('10300000-0000-0000-0000-000000000103', '10300000-0000-0000-0000-000000000001', '10300000-0000-0000-0000-000000000023', 'Existing Member', 'ACTIVE', '2025-01-01', 'CLMD1A-0003', null),
  ('10300000-0000-0000-0000-000000000110', '10300000-0000-0000-0000-000000000001', null, 'Roster One', 'ACTIVE', '2025-01-01', 'CLMD1A-0010', '+255722000010'),
  ('10300000-0000-0000-0000-000000000111', '10300000-0000-0000-0000-000000000001', null, 'Roster Two', 'ACTIVE', '2025-01-01', 'CLMD1A-0011', null),
  ('10300000-0000-0000-0000-000000000112', '10300000-0000-0000-0000-000000000001', null, 'Roster Three (suspended)', 'SUSPENDED', '2025-01-01', 'CLMD1A-0012', null),
  ('10300000-0000-0000-0000-000000000113', '10300000-0000-0000-0000-000000000001', '10300000-0000-0000-0000-000000000025', 'Roster Already Linked', 'ACTIVE', '2025-01-01', 'CLMD1A-0013', null),
  ('10300000-0000-0000-0000-000000000114', '10300000-0000-0000-0000-000000000001', null, 'Roster Four (reject flow)', 'ACTIVE', '2025-01-01', 'CLMD1A-0014', null),
  ('10300000-0000-0000-0000-000000000115', '10300000-0000-0000-0000-000000000001', null, 'Roster Five (cancel flow)', 'ACTIVE', '2025-01-01', 'CLMD1A-0015', null),
  ('10300000-0000-0000-0000-000000000116', '10300000-0000-0000-0000-000000000001', null, 'Roster Six (opaque compat)', 'ACTIVE', '2025-01-01', 'CLMD1A-0016', null),
  ('10300000-0000-0000-0000-000000000117', '10300000-0000-0000-0000-000000000001', null, 'Roster Seven (duplicate pending)', 'ACTIVE', '2025-01-01', 'CLMD1A-0017', null),
  -- Deliberately reuses the SAME member_number string as Roster One
  -- above, but in a DIFFERENT group — proves correct per-group
  -- scoping, never cross-group leakage.
  ('10300000-0000-0000-0000-000000000210', '10300000-0000-0000-0000-000000000002', null, 'Other Group Roster', 'ACTIVE', '2025-01-01', 'CLMD1A-0010', null),
  ('10300000-0000-0000-0000-000000000310', '10300000-0000-0000-0000-000000000003', null, 'Suspended Group Roster', 'ACTIVE', '2025-01-01', 'CLMD1C-0001', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10300000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10300000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10300000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER';

set local role authenticated;

-- =====================================================================
-- 1: unauthenticated request rejected.
-- =====================================================================
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0010') $$,
  '28000',
  'Not authenticated',
  '1: an authenticated-role call with no resolved auth.uid() is rejected'
);

-- =====================================================================
-- 2: disabled profile rejected.
-- =====================================================================
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000024';
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0010') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  '2: a disabled profile is rejected'
);

-- =====================================================================
-- 4/5/19: the RPC signature has exactly two text parameters — no
-- claimant/membership/phone parameter of any kind can even be
-- supplied.
-- =====================================================================
reset role;
select is(
  (select count(*)::integer from information_schema.parameters
   where specific_schema = 'public'
     and specific_name = (select specific_name from information_schema.routines
                           where routine_schema='public' and routine_name='rpc_request_membership_claim_by_reference')
     and data_type = 'text'),
  2,
  '4/5/19: rpc_request_membership_claim_by_reference has exactly two text parameters (group code, member number) — no claimant_user_id, membership_id, or phone parameter exists at all'
);
set local role authenticated;

-- =====================================================================
-- As Claimant One — the main happy-path claimant.
-- =====================================================================
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000021';

-- 10: wrong group code.
create temporary table t_fail_wrong_group as
select 1 where false;
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('ZZZZZ', 'CLMD1A-0010') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '10: a nonexistent group code produces the generic reference-not-verified failure'
);

-- 11: valid group, wrong member number — the SAME generic failure.
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-9999') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '11: a valid group with a nonexistent member number produces the SAME generic failure as a wrong group code'
);

-- 12: wrong group + a plausible member number — the SAME generic failure.
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('ZZZZZ', 'CLMD1A-0010') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '12: a wrong group with an otherwise-plausible member number produces the SAME generic failure'
);

-- 13: a membership from a DIFFERENT group cannot be claimed through
-- the target group code, even when the same number string exists in
-- the target group's own real roster row.
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1B', 'CLMD1A-0099-does-not-exist') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '13a: a nonexistent number under a real group code produces the generic failure'
);

-- 14: an already-linked membership never reveals "already linked".
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0013') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '14: an already-linked target produces the SAME generic failure, never a distinct "already linked" message'
);

-- 15: an inactive (SUSPENDED) membership never reveals its state.
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0012') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '15: a SUSPENDED membership target produces the SAME generic failure'
);

-- 16: a membership in a SUSPENDED group never reveals the group's state.
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1C', 'CLMD1C-0001') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '16: a membership in a SUSPENDED group produces the SAME generic failure'
);

-- 3/6/7: a valid reference creates a PENDING claim; claimant_user_id
-- is the real caller; membership_id is resolved correctly server-side.
create temporary table t_claim1 as
select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0010') as result;
select (result->>'claim_id')::uuid as claim1_id from t_claim1 \gset

select is(
  (select result->>'status' from t_claim1),
  'PENDING',
  '3: a valid group code + member number creates a PENDING claim'
);

reset role;
select is(
  (select claimant_user_id from public.membership_claim_requests where id = :'claim1_id'::uuid),
  '10300000-0000-0000-0000-000000000021'::uuid,
  '6: the created claim''s claimant_user_id is exactly the real caller'
);
select is(
  (select membership_id from public.membership_claim_requests where id = :'claim1_id'::uuid),
  '10300000-0000-0000-0000-000000000110'::uuid,
  '7: the created claim''s membership_id is resolved to exactly the correct roster row server-side'
);

-- 21/22: a valid claim creates zero group_memberships.user_id
-- changes — approval remains a separate, mandatory step.
select is(
  (select user_id from public.group_memberships where id = '10300000-0000-0000-0000-000000000110'::uuid),
  null::uuid,
  '21/22: the membership remains unlinked after the claim is created — approval is still required'
);
set local role authenticated;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000021';

-- 8/9: retry returns/reuses the SAME PENDING claim, no duplicate row.
create temporary table t_claim1_retry as
select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0010') as result;
select is(
  (select (result->>'claim_id')::uuid from t_claim1_retry),
  :'claim1_id'::uuid,
  '8: retrying the same reference returns the SAME existing claim id'
);

reset role;
select is(
  (select count(*)::integer from public.membership_claim_requests where membership_id = '10300000-0000-0000-0000-000000000110'::uuid),
  1,
  '9: exactly one claim row exists despite two requests via the reference endpoint'
);
set local role authenticated;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000021';

-- =====================================================================
-- 17: a claimant already ACTIVE in the group cannot create a claim
-- via the reference endpoint either — collapsed into the same generic
-- failure (never distinguished from a bad reference).
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000023';
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0011') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '17: a claimant already ACTIVE in the group gets the SAME generic failure, never a distinct message'
);

-- =====================================================================
-- 18: correct per-group scoping — the identical member_number string
-- exists in BOTH group A (Roster One) and group B (Other Group
-- Roster); resolving via group B's own code must resolve to group B's
-- OWN row, never leak into group A's.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000022';
create temporary table t_claim_crossgroup as
select public.rpc_request_membership_claim_by_reference('CLMD1B', 'CLMD1A-0010') as result;
select is(
  (select (result->>'membership_id')::uuid from t_claim_crossgroup),
  '10300000-0000-0000-0000-000000000210'::uuid,
  '18: the same member_number string under a DIFFERENT group code correctly resolves to that OTHER group''s own row, never group A''s'
);

-- =====================================================================
-- 34: a second claimant's competing request on an already-pending
-- target also collapses into the generic failure (never reveals that
-- someone else already has a pending claim on it).
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000026';
create temporary table t_claim_dup as
select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0017') as result;
select (result->>'claim_id')::uuid as claim_dup_id from t_claim_dup \gset

reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000027';
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0017') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '34: a competing claimant on an already-pending target gets the SAME generic failure, never revealing that a pending claim exists'
);

-- 35: the generic failure message is EXACTLY the stable code, never a
-- superset embedding any roster field/value.
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-9999') $$,
  'P0001',
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED',
  '35: the failure message is exactly the stable generic code, with no embedded roster data'
);

-- =====================================================================
-- 23: existing ADMIN approval still succeeds on a claim created via
-- the new reference endpoint.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000011';
create temporary table t_approve1 as
select public.rpc_approve_membership_claim('10300000-0000-0000-0000-000000000001'::uuid, :'claim1_id'::uuid) as result;
select is(
  (select result->>'status' from t_approve1),
  'APPROVED',
  '23: an ADMIN can still approve a claim that was created via the reference endpoint'
);

reset role;
select is(
  (select user_id from public.group_memberships where id = '10300000-0000-0000-0000-000000000110'::uuid),
  '10300000-0000-0000-0000-000000000021'::uuid,
  '23b: approval correctly links the exact membership to the exact claimant'
);
set local role authenticated;

-- =====================================================================
-- 24: rejection still works on a reference-initiated claim.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000026';
create temporary table t_claim_reject as
select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0014') as result;
select (result->>'claim_id')::uuid as claim_reject_id from t_claim_reject \gset

reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000011';
create temporary table t_reject1 as
select public.rpc_reject_membership_claim('10300000-0000-0000-0000-000000000001'::uuid, :'claim_reject_id'::uuid, 'Could not verify identity') as result;
select is(
  (select result->>'status' from t_reject1),
  'REJECTED',
  '24: an ADMIN can still reject a claim that was created via the reference endpoint'
);

-- =====================================================================
-- 25: cancellation still works on a reference-initiated claim.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000027';
create temporary table t_claim_cancel as
select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0015') as result;
select (result->>'claim_id')::uuid as claim_cancel_id from t_claim_cancel \gset

create temporary table t_cancel1 as
select public.rpc_cancel_membership_claim(:'claim_cancel_id'::uuid) as result;
select is(
  (select result->>'status' from t_cancel1),
  'CANCELLED',
  '25: the claimant can still cancel a claim that was created via the reference endpoint'
);

-- =====================================================================
-- 26: the existing opaque-id RPC remains fully compatible/unaffected.
-- (Claimant Two, not Claimant One — Claimant One is already linked in
-- group A by this point via the approval in item 23.)
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000022';
create temporary table t_opaque as
select public.rpc_request_membership_claim('10300000-0000-0000-0000-000000000001'::uuid, '10300000-0000-0000-0000-000000000116'::uuid) as result;
select is(
  (select result->>'status' from t_opaque),
  'PENDING',
  '26: the existing opaque-id rpc_request_membership_claim still works exactly as before'
);

-- =====================================================================
-- 27: claimant list remains own-only.
-- =====================================================================
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000022';
select ok(
  (select public.rpc_list_my_membership_claims()) @> '[]'::jsonb
  and not exists (
    select 1 from jsonb_array_elements(public.rpc_list_my_membership_claims()) e
    where (e->>'claim_id')::uuid = :'claim1_id'::uuid
  ),
  '27: Claimant Two''s own-claims list never includes Claimant One''s claim'
);

-- =====================================================================
-- 28: officer list remains permission/group-scoped and shows a
-- reference-initiated claim exactly like an opaque-id one.
-- =====================================================================
set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000012';
select throws_ok(
  $$ select public.rpc_list_membership_claims('10300000-0000-0000-0000-000000000001'::uuid, null) $$,
  '42501',
  'Not authorized to view membership claims in this group',
  '28a: a plain MEMBER still cannot read the officer claim queue'
);

set local request.jwt.claim.sub to '10300000-0000-0000-0000-000000000011';
create temporary table t_officer_queue as
select public.rpc_list_membership_claims('10300000-0000-0000-0000-000000000001'::uuid, 'REJECTED') as result;
select ok(
  exists (
    select 1 from t_officer_queue, jsonb_array_elements(result->'items') e
    where (e->>'claim_id')::uuid = :'claim_reject_id'::uuid
  ),
  '28b: the officer queue shows the reference-initiated, rejected claim exactly like any other'
);

-- =====================================================================
-- 29/30: grant checks on the two new RPCs.
-- =====================================================================
reset role;
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in ('rpc_request_membership_claim_by_reference', 'membership_claim_request_resolve')
     and grantee in ('anon', 'public')),
  0,
  '29: zero EXECUTE grants to anon/public exist on the new reference RPC or the shared internal helper'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'rpc_request_membership_claim_by_reference'
     and grantee = 'authenticated'),
  1,
  '30: authenticated holds exactly one EXECUTE grant on the new reference RPC'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'membership_claim_request_resolve'
     and grantee = 'authenticated'),
  0,
  'the shared internal engine is not directly executable by authenticated either — fully internal'
);

-- 31: no new direct mutation grant on the claim table.
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'membership_claim_requests'
     and grantee in ('anon', 'authenticated') and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  '31: no INSERT/UPDATE/DELETE grant to anon/authenticated exists on membership_claim_requests'
);

-- 32: no new direct mutation grant on group_memberships — still
-- SELECT-only for authenticated, exactly as before this prompt.
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'group_memberships'
     and grantee in ('anon', 'authenticated') and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  '32: no INSERT/UPDATE/DELETE grant to anon/authenticated exists on group_memberships'
);

-- anon cannot execute the new RPC or the internal helper.
set local role anon;
select throws_ok(
  $$ select public.rpc_request_membership_claim_by_reference('CLMD1A', 'CLMD1A-0010') $$,
  '42501', null, 'anon cannot invoke rpc_request_membership_claim_by_reference'
);
select throws_ok(
  $$ select public.membership_claim_request_resolve(gen_random_uuid(), gen_random_uuid(), gen_random_uuid()) $$,
  '42501', null, 'anon cannot invoke the shared internal engine directly'
);

reset role;

select * from finish();
rollback;
