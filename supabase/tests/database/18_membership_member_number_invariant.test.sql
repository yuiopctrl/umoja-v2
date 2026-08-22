-- Prompt 05D: coverage for the membership member-number invariant
-- migration 20260821120000_enforce_membership_member_numbers.sql —
-- founder numbering, the database-level NOT NULL invariant, and
-- member_number immutability through rpc_update_group_member.
begin;

select plan(14);

insert into auth.users (id, email) values
  ('c1000000-0000-0000-0000-000000000001', 'invariant-founder@example.com');

set local role authenticated;
set local request.jwt.claim.sub to 'c1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 1-4. The founder's own group_memberships row gets a member_number at
-- creation time, in the CODE-YEAR-0001 format, is still ACTIVE, and
-- the founder still gets ADMIN.
-- ---------------------------------------------------------------------
create temporary table t_group as
select public.rpc_create_group('Invariant Group A') as ctx;

create temporary table t_founder as
select
  ((select ctx from t_group) -> 'memberships' -> -1 ->> 'group_id')::uuid as group_id,
  ((select ctx from t_group) -> 'memberships' -> -1 ->> 'membership_id')::uuid as membership_id,
  ((select ctx from t_group) -> 'memberships' -> -1 -> 'roles') as roles;

select ok(
  (select member_number from public.group_memberships where id = (select membership_id from t_founder)) is not null,
  'the group creator''s own membership receives a member number'
);

select is(
  (select status::text from public.group_memberships where id = (select membership_id from t_founder)),
  'ACTIVE',
  'the creator''s membership is ACTIVE'
);

select ok(
  (select roles from t_founder) @> '["ADMIN"]'::jsonb,
  'the creator is still assigned the ADMIN role'
);

select is(
  (select member_number from public.group_memberships where id = (select membership_id from t_founder)),
  (select code from public.groups where id = (select group_id from t_founder))
    || '-' || extract(year from current_date)::text || '-0001',
  'the founder''s member number uses the group''s code, the current year, and sequence 0001'
);

-- ---------------------------------------------------------------------
-- 5. The next member created in the same group gets the next sequence
-- (the founder already consumed 0001).
-- ---------------------------------------------------------------------
create temporary table t_second_member as
select public.rpc_create_group_member(
  (select group_id from t_founder), 'Second Member'
) as result;

select is(
  (select result ->> 'member_number' from t_second_member),
  (select code from public.groups where id = (select group_id from t_founder))
    || '-' || extract(year from current_date)::text || '-0002',
  'the next member created in the same group gets sequence 0002'
);

-- ---------------------------------------------------------------------
-- 6. Database-level invariant: member_number is NOT NULL. A direct
-- INSERT that tries to leave it null is rejected outright — reset role
-- bypasses RLS/grants, not column constraints, so this is the actual
-- schema invariant, not just an RPC-level convention.
-- ---------------------------------------------------------------------
reset role;

select throws_ok(
  format(
    $sql$ insert into public.group_memberships (group_id, display_name, status, member_number)
          values (%L, 'No Number Member', 'ACTIVE', null) $sql$,
    (select group_id from t_founder)
  ),
  '23502',
  null,
  'a group_memberships row cannot be inserted with a null member_number'
);

-- ---------------------------------------------------------------------
-- 7. An explicitly-provided member_number on a direct insert is stored
-- exactly as given — nothing server-side rewrites it.
-- ---------------------------------------------------------------------
insert into public.group_memberships (id, group_id, display_name, status, member_number) values
  ('c2000000-0000-0000-0000-000000000002', (select group_id from t_founder), 'Pre-Existing Legacy Member', 'ACTIVE', 'LEGACY-77');

select is(
  (select member_number from public.group_memberships where id = 'c2000000-0000-0000-0000-000000000002'),
  'LEGACY-77',
  'an explicitly-provided member_number is stored exactly as given'
);

-- ---------------------------------------------------------------------
-- 8. member_number uniqueness remains enforced per group (the existing
-- partial unique index from 20260819080632, not re-created here).
-- ---------------------------------------------------------------------
select throws_ok(
  format(
    $sql$ insert into public.group_memberships (group_id, display_name, status, member_number)
          values (%L, 'Duplicate Number Member', 'ACTIVE', %L) $sql$,
    (select group_id from t_founder),
    (select member_number from public.group_memberships where id = (select membership_id from t_founder))
  ),
  '23505',
  null,
  'a duplicate member_number within the same group is rejected by the existing unique index'
);

set local role authenticated;
set local request.jwt.claim.sub to 'c1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 9. rpc_update_group_member cannot change an existing member number.
-- ---------------------------------------------------------------------
select throws_ok(
  format(
    $sql$ select public.rpc_update_group_member(%L, %L, null, null, 'SOMETHING-ELSE') $sql$,
    (select group_id from t_founder),
    (select membership_id from t_founder)
  ),
  '22023',
  'MEMBER_NUMBER_IMMUTABLE',
  'rpc_update_group_member rejects an attempt to change an existing member number'
);

-- ---------------------------------------------------------------------
-- 10. Echoing the member's own current number back through
-- rpc_update_group_member is tolerated as a no-op (compatibility for
-- older clients), and the number is unchanged afterward.
-- ---------------------------------------------------------------------
select lives_ok(
  format(
    $sql$ select public.rpc_update_group_member(%L, %L, null, null, %L) $sql$,
    (select group_id from t_founder),
    (select membership_id from t_founder),
    (select member_number from public.group_memberships where id = (select membership_id from t_founder))
  ),
  'echoing the current member_number back is tolerated as a no-op'
);

select is(
  (select member_number from public.group_memberships where id = (select membership_id from t_founder)),
  (select code from public.groups where id = (select group_id from t_founder))
    || '-' || extract(year from current_date)::text || '-0001',
  'the member number is unchanged after echoing it back'
);

-- ---------------------------------------------------------------------
-- 11. A display-name edit leaves the member number unchanged.
-- ---------------------------------------------------------------------
select public.rpc_update_group_member(
  (select group_id from t_founder), (select membership_id from t_founder), 'Founder Renamed'
);

select is(
  (select member_number from public.group_memberships where id = (select membership_id from t_founder)),
  (select code from public.groups where id = (select group_id from t_founder))
    || '-' || extract(year from current_date)::text || '-0001',
  'the member number is unchanged after a display-name edit'
);

-- ---------------------------------------------------------------------
-- 12. A phone edit leaves the member number unchanged.
-- ---------------------------------------------------------------------
select public.rpc_update_group_member(
  (select group_id from t_founder), (select membership_id from t_founder), null, '+255700000001'
);

select is(
  (select member_number from public.group_memberships where id = (select membership_id from t_founder)),
  (select code from public.groups where id = (select group_id from t_founder))
    || '-' || extract(year from current_date)::text || '-0001',
  'the member number is unchanged after a phone edit'
);

-- ---------------------------------------------------------------------
-- 13. Renaming the group itself never alters an already-generated
-- member number (groups.code stays immutable, per 20260821100000).
-- ---------------------------------------------------------------------
update public.groups set name = 'Invariant Group A Renamed' where id = (select group_id from t_founder);

select is(
  (select member_number from public.group_memberships where id = (select membership_id from t_founder)),
  (select code from public.groups where id = (select group_id from t_founder))
    || '-' || extract(year from current_date)::text || '-0001',
  'the member number is unchanged after the group is renamed'
);

select * from finish();

rollback;
