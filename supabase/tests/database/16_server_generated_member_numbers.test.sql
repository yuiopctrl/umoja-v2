-- Prompt 05B §30-36: server-generated, concurrency-safe member numbers
-- (<groups.code>-<year>-<sequence>), and groups.code itself becoming
-- an immutable, unique, format-checked prefix.
--
-- Tests 5-6 updated by the hardening correction migration
-- 20260821110000_harden_rejoin_and_member_number_functions.sql: the
-- manual p_member_number override this suite originally asserted was
-- *honored* is now rejected outright (MANUAL_MEMBER_NUMBER_NOT_ALLOWED)
-- — see that migration and docs/product/members.md. This is a
-- deliberate behavior correction, not a fixture adjustment.
begin;

select plan(13);

insert into auth.users (id, email) values
  ('a3000000-0000-0000-0000-000000000001', 'numgen-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('a4000000-0000-0000-0000-000000000001', 'Umoja Wamama Test', 'a3000000-0000-0000-0000-000000000001', 'UMJT'),
  ('a4000000-0000-0000-0000-000000000002', 'Second Group', 'a3000000-0000-0000-0000-000000000001', 'SECG');

-- Deliberately obvious, non-colliding test-only numbers (never
-- <groups.code>-prefixed) for the caller fixtures below — this file's
-- own assertions depend on the *real* generator producing exactly
-- UMJT-YYYY-0001/SECG-YYYY-0001 for the first member created in each
-- group, which a same-prefixed fixture number would shift.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('a5000000-0000-0000-0000-000000000001', 'a4000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'Numgen Admin', 'ACTIVE', 'TESTA-2026-0001'),
  ('a5000000-0000-0000-0000-000000000002', 'a4000000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'Numgen Admin 2', 'ACTIVE', 'TESTB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select id_, r.id from (values
  ('a5000000-0000-0000-0000-000000000001'::uuid),
  ('a5000000-0000-0000-0000-000000000002'::uuid)
) as m(id_), public.roles r
where r.code = 'ADMIN';

-- A pre-existing member with a legacy-style number, inserted directly
-- (as if from before this migration) — proves the migration does not
-- touch/regenerate existing rows.
insert into public.group_memberships (id, group_id, display_name, status, member_number) values
  ('a5000000-0000-0000-0000-000000000099', 'a4000000-0000-0000-0000-000000000001', 'Legacy Member', 'ACTIVE', 'LEGACY-001');

set local role authenticated;
set local request.jwt.claim.sub to 'a3000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 1-2. Creating a member without p_member_number auto-generates one in
-- the CODE-YYYY-0001 format, using the group's own code.
-- ---------------------------------------------------------------------
create temporary table t_member_1 as
select public.rpc_create_group_member(
  'a4000000-0000-0000-0000-000000000001', 'First Auto Member'
) as result;

select is(
  (select result ->> 'member_number' from t_member_1),
  'UMJT-' || extract(year from current_date)::text || '-0001',
  'the first auto-generated member number is CODE-YYYY-0001'
);

-- ---------------------------------------------------------------------
-- 3. The sequence increments for the next member in the *same* group.
-- ---------------------------------------------------------------------
create temporary table t_member_2 as
select public.rpc_create_group_member(
  'a4000000-0000-0000-0000-000000000001', 'Second Auto Member'
) as result;

select is(
  (select result ->> 'member_number' from t_member_2),
  'UMJT-' || extract(year from current_date)::text || '-0002',
  'the next member in the same group gets sequence 0002'
);

-- ---------------------------------------------------------------------
-- 4. A different group has its own independent sequence (starts at
-- 0001 again, using its own code) — the counter is per-group. The
-- caller already holds ADMIN on this second group too (fixture above).
-- ---------------------------------------------------------------------
create temporary table t_member_3 as
select public.rpc_create_group_member(
  'a4000000-0000-0000-0000-000000000002', 'Other Group First Member'
) as result;

select is(
  (select result ->> 'member_number' from t_member_3),
  'SECG-' || extract(year from current_date)::text || '-0001',
  'a different group has its own independent per-group sequence'
);

-- ---------------------------------------------------------------------
-- 5. Hardening correction
-- (20260821110000_harden_rejoin_and_member_number_functions.sql): an
-- explicitly-supplied member_number is no longer honored as an
-- override at all — normal creation is unconditionally
-- server-authoritative for member numbers.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_create_group_member('a4000000-0000-0000-0000-000000000001', 'Manually Numbered Member', null, 'CUSTOM-007') $$,
  '22023',
  'MANUAL_MEMBER_NUMBER_NOT_ALLOWED',
  'an explicitly-supplied member_number is rejected outright'
);

-- ---------------------------------------------------------------------
-- 6. The rejection is unconditional on the supplied value being a
-- duplicate — a value that would otherwise be perfectly unique is
-- still rejected, proving this is a "manual numbers are not allowed"
-- rule rather than a side effect of the uniqueness check.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_create_group_member('a4000000-0000-0000-0000-000000000001', 'Another Manually Numbered Member', null, 'UNIQUE-999') $$,
  '22023',
  'MANUAL_MEMBER_NUMBER_NOT_ALLOWED',
  'an explicitly-supplied member_number is rejected even when it would otherwise be unique'
);

-- ---------------------------------------------------------------------
-- 7. A pre-existing (pre-migration-style) member number is completely
-- unaffected by this migration.
-- ---------------------------------------------------------------------
select is(
  (select member_number from public.group_memberships where id = 'a5000000-0000-0000-0000-000000000099'),
  'LEGACY-001',
  'an existing legacy member number is never regenerated/touched'
);

-- ---------------------------------------------------------------------
-- 8. groups.code is immutable once set. authenticated has no UPDATE
-- grant on the column at all (the primary guard — caught first, as
-- "permission denied"); the prevent_group_code_change trigger is
-- defense in depth for any direct-table-access path that did have the
-- column grant (there is none for authenticated today).
-- ---------------------------------------------------------------------
select throws_ok(
  $$ update public.groups set code = 'CHNG' where id = 'a4000000-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'a group''s code cannot be changed once set'
);

-- ---------------------------------------------------------------------
-- 9. The prevent_group_code_change trigger itself (defense in depth,
-- independent of the grant checked above) rejects any code change even
-- for a role that bypasses ordinary grants/RLS.
-- ---------------------------------------------------------------------
reset role;

select throws_ok(
  $$ update public.groups set code = 'CHNG' where id = 'a4000000-0000-0000-0000-000000000001' $$,
  '42501',
  'groups.code cannot be changed by update',
  'the prevent_group_code_change trigger independently rejects a code change'
);

-- ---------------------------------------------------------------------
-- 10. groups.code enforces its format (uppercase alphanumeric, 2-10
-- chars) at the database level.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into public.groups (name, created_by, code) values ('Bad Code Group', 'a3000000-0000-0000-0000-000000000001', 'bad code!') $$,
  '23514',
  null,
  'an invalid code format is rejected by the check constraint'
);

select throws_ok(
  $$ insert into public.groups (name, created_by, code) values ('Dup Code Group', 'a3000000-0000-0000-0000-000000000001', 'UMJT') $$,
  '23505',
  null,
  'a duplicate group code is rejected by the unique index'
);

-- ---------------------------------------------------------------------
-- 10-11. The counter/number-generation helpers are internal only — no
-- direct client execute privilege.
-- ---------------------------------------------------------------------
select is(
  has_function_privilege('authenticated', 'public.next_group_member_number(uuid, integer)', 'execute'),
  false,
  'authenticated has no direct execute privilege on next_group_member_number'
);

select is(
  has_function_privilege('authenticated', 'public.generate_member_number(uuid, integer)', 'execute'),
  false,
  'authenticated has no direct execute privilege on generate_member_number'
);

-- ---------------------------------------------------------------------
-- 12. The counter uses the atomic INSERT ... ON CONFLICT ... DO UPDATE
-- pattern (concurrency-safe by construction — two concurrent inserts
-- for the same (group_id, year) serialize on the row's own upsert
-- rather than racing a read-then-write, so they can never compute the
-- same next value). True concurrent-transaction testing is not
-- practical within pgTAP's single-session model — see test 10's
-- identical rationale for the last-admin guard's FOR UPDATE lock.
-- ---------------------------------------------------------------------
select ok(
  pg_get_functiondef('public.next_group_member_number(uuid, integer)'::regprocedure) ~* 'on conflict.*do update',
  'the member-number counter increments via an atomic INSERT ... ON CONFLICT ... DO UPDATE'
);

select * from finish();

rollback;
