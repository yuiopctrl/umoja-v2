-- Coverage for the hardening correction migration
-- 20260821110000_harden_rejoin_and_member_number_functions.sql, on top
-- of (not a replacement for) 15_member_rejoin_workflow.test.sql and
-- 16_server_generated_member_numbers.test.sql, which already cover the
-- base behavior of the two migrations being corrected.
--
-- Known gap intentionally NOT exercised here: rpc_update_group_member
-- (from 20260819083321_create_group_member_management_rpcs.sql, not
-- one of the two migrations in scope for this correction) still
-- accepts and applies a non-null p_member_number, so a member number
-- is not actually immutable through every RPC today. Fixing that is
-- out of scope for this migration (it targets only
-- rpc_rejoin_group_member, generate_group_code, rpc_create_group,
-- next_group_member_number, generate_member_number, and
-- rpc_create_group_member) and is left as a follow-up.
begin;

select plan(20);

insert into auth.users (id, email) values
  ('b1000000-0000-0000-0000-000000000001', 'hardening-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('b2000000-0000-0000-0000-000000000001', 'Hardening Group A', 'b1000000-0000-0000-0000-000000000001', 'HRDA'),
  ('b2000000-0000-0000-0000-000000000002', 'Hardening Group B', 'b1000000-0000-0000-0000-000000000001', 'HRDB');

-- Deliberately obvious, non-colliding test-only numbers (never
-- HRDA-/HRDB-prefixed) — the member-number section below depends on
-- the *real* generator producing exactly HRDB-2020-0001/
-- HRDB-YYYY-0001, which a same-prefixed fixture number would shift.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('b3000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Hardening Admin', 'ACTIVE', 'TESTA-2026-0001'),
  ('b3000000-0000-0000-0000-000000000006', 'b2000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'Hardening Admin B', 'ACTIVE', 'TESTB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select id_, r.id from (values
  ('b3000000-0000-0000-0000-000000000001'::uuid),
  ('b3000000-0000-0000-0000-000000000006'::uuid)
) as m(id_), public.roles r
where r.code = 'ADMIN';

-- A SUSPENDED membership, to prove rejoin rejects it (distinct from
-- the ACTIVE case already covered by test 15).
insert into public.group_memberships (id, group_id, display_name, status, member_number) values
  ('b3000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001', 'Hardening Suspended Member', 'SUSPENDED', 'TESTA-2026-0002');

-- EXITED fixtures for effective-date validation. b3...003 is reused
-- across the two rejection tests (12,13) before the boundary-date
-- success test (14) finally consumes it, since a rejected call never
-- mutates state.
insert into public.group_memberships (id, group_id, display_name, status, joined_at, exited_at, member_number) values
  ('b3000000-0000-0000-0000-000000000003', 'b2000000-0000-0000-0000-000000000001', 'Boundary Rejoin Member', 'EXITED', '2019-01-01', current_date - 10, 'TESTA-2026-0003'),
  ('b3000000-0000-0000-0000-000000000004', 'b2000000-0000-0000-0000-000000000001', 'Later Rejoin Member', 'EXITED', '2018-05-05', current_date - 20, 'TESTA-2026-0004'),
  ('b3000000-0000-0000-0000-000000000005', 'b2000000-0000-0000-0000-000000000001', 'Terminal Check Member', 'EXITED', '2021-03-03', current_date - 3, 'TESTA-2026-0005');

set local role authenticated;
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- =======================================================================
-- Group code generation: short names, punctuation, length bounds.
-- =======================================================================

-- 1-2. A one-character sanitized name still produces a code that meets
-- groups_code_format (>= 2 chars) rather than hitting the raw CHECK
-- constraint.
create temporary table t_short as
select public.rpc_create_group('A') as ctx;

select ok(
  (select (ctx -> 'memberships' -> -1 ->> 'group_id') is not null from t_short),
  'a one-character group name is accepted (no raw CHECK-constraint failure)'
);

select ok(
  (select code from public.groups
     where id = ((select ctx from t_short) -> 'memberships' -> -1 ->> 'group_id')::uuid) ~ '^[A-Z0-9]{2,10}$',
  'the derived code for a one-character name matches the required format'
);

-- 3. A punctuation-heavy name sanitizes down to a valid code.
create temporary table t_punct as
select public.rpc_create_group('!!! ---   ???') as ctx;

select ok(
  (select code from public.groups
     where id = ((select ctx from t_punct) -> 'memberships' -> -1 ->> 'group_id')::uuid) ~ '^[A-Z0-9]{2,10}$',
  'a punctuation-only group name still produces a code matching the required format'
);

-- 4-5. Two groups created with the identical name get distinct,
-- disambiguated codes, and the disambiguated code still matches the
-- required format.
create temporary table t_dup1 as
select public.rpc_create_group('Twin Group Name') as ctx;

create temporary table t_dup2 as
select public.rpc_create_group('Twin Group Name') as ctx;

select isnt(
  (select code from public.groups
     where id = ((select ctx from t_dup1) -> 'memberships' -> -1 ->> 'group_id')::uuid),
  (select code from public.groups
     where id = ((select ctx from t_dup2) -> 'memberships' -> -1 ->> 'group_id')::uuid),
  'two groups created with the identical name get distinct codes'
);

select ok(
  (select code from public.groups
     where id = ((select ctx from t_dup2) -> 'memberships' -> -1 ->> 'group_id')::uuid) ~ '^[A-Z0-9]{2,10}$',
  'the disambiguated (suffixed) code still matches the required format'
);

-- 6-7. True concurrent-transaction testing is not practical within
-- pgTAP's single-session model (same limitation test 16 already notes
-- for the member-number counter). As the closest available proxy: five
-- sequential direct calls to generate_group_code() for the identical
-- base, each followed immediately by the INSERT it guards, never
-- produce the same candidate twice — the same check-then-insert
-- sequence a lock-serialized pair of concurrent transactions would
-- each go through, one at a time, without actually opening two
-- sessions. reset role first since generate_group_code is
-- internal-only (no authenticated execute grant).
reset role;

do $$
declare
  v_codes text[] := array[]::text[];
  v_code text;
  i integer;
begin
  for i in 1..5 loop
    v_code := public.generate_group_code('Race Base');
    insert into public.groups (name, created_by, code)
      values ('Race Base Group ' || i, 'b1000000-0000-0000-0000-000000000001', v_code);
    v_codes := array_append(v_codes, v_code);
  end loop;

  if array_length(v_codes, 1) <> (select count(distinct x) from unnest(v_codes) as x) then
    raise exception 'duplicate candidate produced across sequential allocations';
  end if;
end;
$$;

select pass(
  'five sequential same-base allocations each produced a distinct code'
);

select ok(
  pg_get_functiondef('public.generate_group_code(text)'::regprocedure) ~* 'pg_advisory_xact_lock',
  'generate_group_code serializes same-base allocation via a transaction-scoped advisory lock'
);

set local role authenticated;
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- =======================================================================
-- Member numbers: per-year counter, rename immutability.
-- =======================================================================

-- 8. The counter is per-year: a backdated join starts that year's own
-- sequence at 0001.
create temporary table t_year_member as
select public.rpc_create_group_member(
  'b2000000-0000-0000-0000-000000000002', 'Backdated Member', null, null, '2020-06-15'::date
) as result;

select is(
  (select result ->> 'member_number' from t_year_member),
  'HRDB-2020-0001',
  'a backdated join gets that year''s own sequence starting at 0001'
);

-- 9. The current year's sequence for the same group is independent of
-- the 2020 sequence above (also starts at 0001).
create temporary table t_current_year_member as
select public.rpc_create_group_member(
  'b2000000-0000-0000-0000-000000000002', 'Current Year Member'
) as result;

select is(
  (select result ->> 'member_number' from t_current_year_member),
  'HRDB-' || extract(year from current_date)::text || '-0001',
  'the current year''s sequence for the same group is independent of the 2020 sequence'
);

-- 10-11. Renaming a group never changes its code or any
-- already-generated member number.
update public.groups set name = 'Hardening Group B Renamed' where id = 'b2000000-0000-0000-0000-000000000002';

select is(
  (select code from public.groups where id = 'b2000000-0000-0000-0000-000000000002'),
  'HRDB',
  'renaming a group does not change its code'
);

select is(
  (select result ->> 'member_number' from t_year_member),
  'HRDB-2020-0001',
  'a previously-generated member number is unchanged after the group is renamed'
);

-- =======================================================================
-- Rejoin: SUSPENDED rejection, effective-date validation, history.
-- =======================================================================

-- 12. SUSPENDED cannot rejoin (distinct from the ACTIVE case already
-- covered by test 15 — both are non-EXITED and share the same guard).
select throws_ok(
  $$ select public.rpc_rejoin_group_member('b2000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000002') $$,
  'P0001',
  'MEMBERSHIP_NOT_EXITED',
  'a SUSPENDED membership cannot be rejoined'
);

-- 13. A future rejoin date is rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_rejoin_group_member('b2000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000003', %L) $sql$,
    (current_date + 1)::text
  ),
  '22023',
  'REJOIN_DATE_IN_FUTURE',
  'a rejoin date in the future is rejected'
);

-- 14. A rejoin date before the member's own previous exit date is
-- rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_rejoin_group_member('b2000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000003', %L) $sql$,
    (current_date - 11)::text
  ),
  '22023',
  'REJOIN_DATE_BEFORE_EXIT',
  'a rejoin date before the member''s previous exit date is rejected'
);

-- 15. A valid later historical date (after exited_at, up to and
-- including today) is accepted, on an independent EXITED row.
select lives_ok(
  format(
    $sql$ select public.rpc_rejoin_group_member('b2000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000004', %L) $sql$,
    (current_date - 5)::text
  ),
  'a valid later historical rejoin date (between exited_at and today) is accepted'
);

-- 16. The boundary date exactly equal to the member's own exited_at is
-- accepted (not exclusive) — this call finally consumes the row that
-- tests 13-14 above deliberately left EXITED.
select lives_ok(
  format(
    $sql$ select public.rpc_rejoin_group_member('b2000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000003', %L) $sql$,
    (current_date - 10)::text
  ),
  'a rejoin date exactly equal to the member''s previous exited_at is accepted'
);

-- 17. joined_at is never modified by rejoin, regardless of the
-- effective rejoin date supplied.
select is(
  (select joined_at from public.group_memberships where id = 'b3000000-0000-0000-0000-000000000003'),
  '2019-01-01'::date,
  'rejoin never modifies the membership''s original joined_at'
);

-- 18-19. previous_exited_at and effective_at are both recorded
-- correctly in the immutable history table for the boundary rejoin
-- above.
reset role;

select is(
  (select previous_exited_at from public.group_membership_status_history
     where group_membership_id = 'b3000000-0000-0000-0000-000000000003'
       and action = 'REJOIN'),
  (current_date - 10)::date,
  'previous_exited_at is preserved in history'
);

select is(
  (select effective_at from public.group_membership_status_history
     where group_membership_id = 'b3000000-0000-0000-0000-000000000003'
       and action = 'REJOIN'),
  (current_date - 10)::date,
  'the chosen effective rejoin date is recorded in history'
);

set local role authenticated;
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- 20. The generic rpc_change_group_member_status RPC still cannot
-- reactivate an EXITED membership — the hardening correction does not
-- touch or relax that separate, pre-existing terminal rule.
select throws_ok(
  $$ select public.rpc_change_group_member_status('b2000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000005', 'ACTIVE') $$,
  'P0001',
  'EXITED_MEMBERSHIP_IS_TERMINAL',
  'rpc_change_group_member_status still cannot reactivate an EXITED membership'
);

select * from finish();

rollback;
