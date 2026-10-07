-- Prompt 09G-B5-B.1: linked membership MEMBER baseline.
--
-- Proves the invariant "a membership linked to an authenticated user holds
-- MEMBER", enforced by ensure_linked_membership_member_role() for every
-- linking path. Officer roles are additive; roster-only memberships
-- (user_id IS NULL) need no MEMBER; duplicates are impossible; the founder
-- path is exercised through the real rpc_create_group; linking uses the
-- same transaction markers the sanctioned RPCs set, so the user_id guard is
-- exercised honestly.
begin;

select plan(33);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('12000000-0000-0000-0000-000000000201', 'p09gb5b1-founder@example.com'),
  ('12000000-0000-0000-0000-000000000202', 'p09gb5b1-member@example.com'),
  ('12000000-0000-0000-0000-000000000203', 'p09gb5b1-treasurer@example.com'),
  ('12000000-0000-0000-0000-000000000204', 'p09gb5b1-secretary@example.com'),
  ('12000000-0000-0000-0000-000000000205', 'p09gb5b1-chair@example.com'),
  ('12000000-0000-0000-0000-000000000207', 'p09gb5b1-suspended@example.com'),
  ('12000000-0000-0000-0000-000000000208', 'p09gb5b1-invitee@example.com'),
  ('12000000-0000-0000-0000-000000000209', 'p09gb5b1-claimant@example.com'),
  ('12000000-0000-0000-0000-000000000210', 'p09gb5b1-legacy@example.com'),
  ('12000000-0000-0000-0000-000000000211', 'p09gb5b1-invitee-treasurer@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('12000000-0000-0000-0000-000000000001', 'B5B1 Group', '12000000-0000-0000-0000-000000000201', 'B5B1G', 'ACTIVE');

-- 301: roster-only (no account). Must NOT receive MEMBER.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('12000000-0000-0000-0000-000000000301', '12000000-0000-0000-0000-000000000001', null, 'Roster Only', 'ACTIVE', '2025-01-01', 'B5B1G-0001', null);

-- 302: ordinary linked member. Inserted linked, so the trigger must add MEMBER.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('12000000-0000-0000-0000-000000000302', '12000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000202', 'Ordinary', 'ACTIVE', '2025-01-02', 'B5B1G-0002', null);

-- 303 treasurer, 304 secretary, 305 chairperson: linked with an officer role.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('12000000-0000-0000-0000-000000000303', '12000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000203', 'Treasurer', 'ACTIVE', '2025-01-03', 'B5B1G-0003', null),
  ('12000000-0000-0000-0000-000000000304', '12000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000204', 'Secretary', 'ACTIVE', '2025-01-04', 'B5B1G-0004', null),
  ('12000000-0000-0000-0000-000000000305', '12000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000205', 'Chair', 'ACTIVE', '2025-01-05', 'B5B1G-0005', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '12000000-0000-0000-0000-000000000303', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '12000000-0000-0000-0000-000000000304', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select '12000000-0000-0000-0000-000000000305', id from public.roles where code = 'CHAIRPERSON';

-- 306: linked but SUSPENDED. Still linked, so MEMBER is held; access is still gated by status.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('12000000-0000-0000-0000-000000000306', '12000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000207', 'Suspended', 'SUSPENDED', '2025-01-06', 'B5B1G-0006', null);

-- 307 (invitation, explicit MEMBER requested), 308 (invitation, TREASURER requested), 309 (claim), 310 (legacy token):
-- all roster-only before linking.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('12000000-0000-0000-0000-000000000307', '12000000-0000-0000-0000-000000000001', null, 'Invitee Member', 'ACTIVE', '2025-02-01', 'B5B1G-0007', null),
  ('12000000-0000-0000-0000-000000000308', '12000000-0000-0000-0000-000000000001', null, 'Invitee Treasurer', 'ACTIVE', '2025-02-02', 'B5B1G-0008', null),
  ('12000000-0000-0000-0000-000000000309', '12000000-0000-0000-0000-000000000001', null, 'Claimed', 'ACTIVE', '2025-02-03', 'B5B1G-0009', null),
  ('12000000-0000-0000-0000-000000000310', '12000000-0000-0000-0000-000000000001', null, 'Legacy', 'ACTIVE', '2025-02-04', 'B5B1G-0010', null);

-- =====================================================================
-- 1-2. Roster-only versus linked
-- =====================================================================

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000301' and r.code = 'MEMBER'),
  0,
  '1: roster-only membership (user_id NULL) may hold no MEMBER role and that is not a defect'
);

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000302' and r.code = 'MEMBER'),
  1,
  '2: linked ordinary membership has exactly one MEMBER role'
);

-- =====================================================================
-- 3-5. Officer memberships are additive to MEMBER
-- =====================================================================

select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000303'),
  array['MEMBER', 'TREASURER'],
  '3: treasurer-linked membership is MEMBER + TREASURER (officer role preserved)'
);

select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000304'),
  array['MEMBER', 'SECRETARY'],
  '4: secretary-linked membership is MEMBER + SECRETARY'
);

select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000305'),
  array['CHAIRPERSON', 'MEMBER'],
  '5: chairperson-linked membership is CHAIRPERSON + MEMBER'
);

-- =====================================================================
-- 6. Founder path: real rpc_create_group, as the authenticated founder.
-- =====================================================================

set local role authenticated;
set local request.jwt.claim.sub to '12000000-0000-0000-0000-000000000201';
select lives_ok(
  $$ select public.rpc_create_group('B5B1 Founder Group', null) $$,
  '6a: founder can create a group through the real RPC'
);
reset role;

select is(
  (select array_agg(r.code order by r.code) from public.group_memberships gm
   join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
   join public.roles r on r.id = gmr.role_id
   join public.groups g on g.id = gm.group_id
   where gm.user_id = '12000000-0000-0000-0000-000000000201' and g.name = 'B5B1 Founder Group'),
  array['ADMIN', 'MEMBER'],
  '6b: founder ends with ADMIN + MEMBER, not ADMIN alone'
);

-- =====================================================================
-- 7-9. Linking through each sanctioned path (same markers as the RPCs).
-- =====================================================================

-- 7. Phone invitation requesting MEMBER explicitly: no duplicate.
select set_config('umoja.membership_invitation_acceptance', 'true', true);
update public.group_memberships set user_id = '12000000-0000-0000-0000-000000000208' where id = '12000000-0000-0000-0000-000000000307';
insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select '12000000-0000-0000-0000-000000000307', id, null from public.roles where code = 'MEMBER'
on conflict (group_membership_id, role_id) do nothing;
select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000307' and r.code = 'MEMBER'),
  1,
  '7: invitation that also requests MEMBER leaves exactly one MEMBER assignment'
);

-- 8. Phone invitation requesting TREASURER: MEMBER + TREASURER.
update public.group_memberships set user_id = '12000000-0000-0000-0000-000000000211' where id = '12000000-0000-0000-0000-000000000308';
insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select '12000000-0000-0000-0000-000000000308', id, null from public.roles where code = 'TREASURER'
on conflict (group_membership_id, role_id) do nothing;
select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000308'),
  array['MEMBER', 'TREASURER'],
  '8: invitation requesting TREASURER produces MEMBER + TREASURER, not TREASURER alone'
);

-- 9. Claim approval links the membership: MEMBER must exist.
select set_config('umoja.membership_invitation_acceptance', 'false', true);
select set_config('umoja.membership_claim_approval', 'true', true);
update public.group_memberships set user_id = '12000000-0000-0000-0000-000000000209' where id = '12000000-0000-0000-0000-000000000309';
select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000309' and r.code = 'MEMBER'),
  1,
  '9: claim approval linking produces MEMBER'
);

-- 10. Legacy token acceptance path links the membership: MEMBER must exist.
select set_config('umoja.membership_claim_approval', 'false', true);
select set_config('umoja.membership_invitation_acceptance', 'true', true);
update public.group_memberships set user_id = '12000000-0000-0000-0000-000000000210' where id = '12000000-0000-0000-0000-000000000310';
select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000310' and r.code = 'MEMBER'),
  1,
  '10: legacy invitation linking path produces MEMBER'
);
select set_config('umoja.membership_invitation_acceptance', 'false', true);

-- The user_id guard still refuses unsanctioned changes.
select throws_ok(
  $$ update public.group_memberships set user_id = '12000000-0000-0000-0000-000000000202' where id = '12000000-0000-0000-0000-000000000301' $$,
  '42501',
  null,
  '11: the user_id mutation guard still refuses an unsanctioned link (no marker)'
);

-- =====================================================================
-- 12-14. Backfill: re-running the migration statement is safe and additive.
-- =====================================================================

-- Simulate a legacy linked, roleless membership by removing MEMBER from 302.
delete from public.group_membership_roles gmr
using public.roles r
where gmr.role_id = r.id and r.code = 'MEMBER' and gmr.group_membership_id = '12000000-0000-0000-0000-000000000302';

-- Also simulate a linked treasurer that lacks MEMBER (officer must be preserved).
delete from public.group_membership_roles gmr
using public.roles r
where gmr.role_id = r.id and r.code = 'MEMBER' and gmr.group_membership_id = '12000000-0000-0000-0000-000000000303';

insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select gm.id, r.id, null
from public.group_memberships gm
join public.roles r on r.code = 'MEMBER'
where gm.user_id is not null
on conflict (group_membership_id, role_id) do nothing;

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000302' and r.code = 'MEMBER'),
  1,
  '12: backfill adds MEMBER to an existing linked roleless membership'
);

select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000303'),
  array['MEMBER', 'TREASURER'],
  '13: backfill preserves the existing officer role and adds MEMBER beside it'
);

insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select gm.id, r.id, null
from public.group_memberships gm
join public.roles r on r.code = 'MEMBER'
where gm.user_id is not null
on conflict (group_membership_id, role_id) do nothing;

select is(
  (select count(*)::int from (
     select gmr.group_membership_id from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
     where r.code = 'MEMBER' group by gmr.group_membership_id having count(*) > 1) d),
  0,
  '14: repeated backfill never duplicates a MEMBER assignment'
);

-- =====================================================================
-- 15. Suspended but linked: MEMBER held, access still gated by status.
-- =====================================================================
select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '12000000-0000-0000-0000-000000000306' and r.code = 'MEMBER'),
  1,
  '15a: linked suspended membership still holds MEMBER (status gates access, not role membership)'
);

set local role authenticated;
set local request.jwt.claim.sub to '12000000-0000-0000-0000-000000000207';
select throws_ok(
  $$ select public.rpc_get_my_loans('12000000-0000-0000-0000-000000000001'::uuid, 20, 0) $$,
  '42501',
  null,
  '15b: suspended membership is not a current context even with MEMBER'
);
reset role;

-- =====================================================================
-- 16-18. Effective permissions through MEMBER (no role-name shortcut).
-- =====================================================================

set local role authenticated;
set local request.jwt.claim.sub to '12000000-0000-0000-0000-000000000202';
select ok(
  public.has_group_permission('12000000-0000-0000-0000-000000000001'::uuid, 'contribution.self_view'),
  '16: ordinary linked member has contribution.self_view through the MEMBER baseline'
);
select ok(
  public.has_group_permission('12000000-0000-0000-0000-000000000001'::uuid, 'loan.self_view'),
  '17: ordinary linked member has loan.self_view through the MEMBER baseline'
);
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '12000000-0000-0000-0000-000000000203';
select ok(
  public.has_group_permission('12000000-0000-0000-0000-000000000001'::uuid, 'loan.self_view')
  and public.has_group_permission('12000000-0000-0000-0000-000000000001'::uuid, 'contribution.view'),
  '18: treasurer with MEMBER baseline has loan.self_view and keeps officer contribution.view'
);
reset role;

-- =====================================================================
-- 19-20. Officer role never reaches another member's self-service data.
-- =====================================================================

set local role authenticated;
set local request.jwt.claim.sub to '12000000-0000-0000-0000-000000000203';
select lives_ok(
  $$ select public.rpc_get_my_contributions('12000000-0000-0000-0000-000000000001'::uuid) $$,
  '19: treasurer with MEMBER baseline reads own self-service contributions'
);
select throws_ok(
  $$ select public.rpc_get_my_loan_detail('12000000-0000-0000-0000-000000000001'::uuid, '12000000-0000-0000-0000-000000000302'::uuid) $$,
  '22023',
  'Loan account not found',
  '20: treasurer officer role does not read another member loan through self-service'
);
reset role;

-- =====================================================================
-- 21-23. No role-name authorization in the self-service RPCs.
-- =====================================================================

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('rpc_get_my_loans', 'rpc_get_my_loan_detail', 'rpc_get_my_loan_schedule', 'rpc_get_my_loan_timeline', 'rpc_get_my_contributions', 'rpc_get_my_contribution_charge_detail', 'rpc_get_my_member_statement')
      and p.prosrc ~* $re$\mcode\M\s*(=|in\s*\()\s*'(MEMBER|TREASURER|SECRETARY|CHAIRPERSON|ADMIN)'$re$
  ),
  '21: no B3/B4/B5 self-service RPC authorizes by role name'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'ensure_linked_membership_member_role'
      and p.prosrc ~* 'has_group_role|has_group_permission|group_membership_roles.*delete'
  ),
  '22: the baseline trigger performs no authorization decision and deletes no roles'
);

select is(
  (select count(*)::int from information_schema.tables
   where table_schema = 'public' and (table_name ilike '%override%' or table_name ilike '%deny%')),
  0,
  '23: no permission DENY/override table exists, so effective permission is the role-union only'
);

-- =====================================================================
-- 24-31. Invariant coverage across every linked membership.
-- =====================================================================

select is(
  (select count(*)::int from public.group_memberships gm
   where gm.user_id is not null
     and not exists (
       select 1 from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
       where gmr.group_membership_id = gm.id and r.code = 'MEMBER')),
  0,
  '24: every user-linked membership in the database holds MEMBER'
);

select is(
  (select count(*)::int from public.group_memberships gm
   where gm.user_id is null
     and exists (
       select 1 from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
       where gmr.group_membership_id = gm.id and r.code = 'MEMBER')),
  0,
  '25: roster-only memberships hold no MEMBER in this fixture (no unexpected grants)'
);

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where r.code = 'MEMBER' and gmr.group_membership_id = '12000000-0000-0000-0000-000000000302'),
  1,
  '26: MEMBER row for ordinary member is unique'
);

select is(
  (select count(*)::int from public.roles where code = 'MEMBER'),
  1,
  '27: exactly one canonical MEMBER system role exists'
);

select ok(
  (select p.prosecdef from pg_proc p where p.proname = 'ensure_linked_membership_member_role'),
  '28: baseline trigger function is SECURITY DEFINER'
);

select ok(
  not has_function_privilege('authenticated', 'public.ensure_linked_membership_member_role()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.ensure_linked_membership_member_role()', 'EXECUTE'),
  '29: baseline trigger function is not client-executable'
);

select ok(
  exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
          where c.relname = 'group_memberships' and t.tgname = 'group_memberships_ensure_member_role' and not t.tgisinternal),
  '30: baseline trigger is installed on group_memberships'
);

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where r.code = 'ADMIN' and gmr.group_membership_id = '12000000-0000-0000-0000-000000000302'),
  0,
  '31: the baseline never grants ADMIN or any officer role'
);

select * from finish();
rollback;
