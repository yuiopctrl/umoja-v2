-- Prompt 03: SUSPENDED/EXITED memberships and SUSPENDED/CLOSED groups
-- must not be treated as active operational context by the backend
-- authorization primitives, and rpc_get_my_context() must faithfully
-- report each membership's real group/membership status so Flutter can
-- apply its own eligibility filtering (ACTIVE membership + ACTIVE
-- group) rather than the backend silently normalizing anything.
begin;

select plan(8);

insert into auth.users (id, email) values
  ('b0000000-0000-0000-0000-000000000001', 'user@example.com');

insert into public.groups (id, name, status, created_by, code) values
  ('b1000000-0000-0000-0000-000000000001', 'Active Group', 'ACTIVE', 'b0000000-0000-0000-0000-000000000001', 'OPC1'),
  ('b1000000-0000-0000-0000-000000000002', 'Suspended Group', 'SUSPENDED', 'b0000000-0000-0000-0000-000000000001', 'OPC2'),
  ('b1000000-0000-0000-0000-000000000003', 'Closed Group', 'CLOSED', 'b0000000-0000-0000-0000-000000000001', 'OPC3');

-- SUSPENDED membership in an otherwise ACTIVE group.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('b2000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'User', 'SUSPENDED', 'OPC1-2026-0001');

-- EXITED membership in an otherwise ACTIVE group (a second, separate
-- group so it does not collide with the SUSPENDED membership above).
insert into public.groups (id, name, status, created_by, code) values
  ('b1000000-0000-0000-0000-000000000004', 'Another Active Group', 'ACTIVE', 'b0000000-0000-0000-0000-000000000001', 'OPC4');
insert into public.group_memberships (id, group_id, user_id, display_name, status, exited_at, member_number) values
  ('b2000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'User', 'EXITED', current_date, 'OPC4-2026-0001');

-- ACTIVE membership in a SUSPENDED group.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('b2000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'User', 'ACTIVE', 'OPC2-2026-0001');

-- ACTIVE membership in a CLOSED group.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('b2000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'User', 'ACTIVE', 'OPC3-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select id, (select id from public.roles where code = 'MEMBER')
from public.group_memberships
where user_id = 'b0000000-0000-0000-0000-000000000001';

set local role authenticated;
set local request.jwt.claim.sub to 'b0000000-0000-0000-0000-000000000001';

-- 7. A SUSPENDED membership is not treated as an active operational
-- membership by the authorization primitives.
select is(
  public.is_group_member('b1000000-0000-0000-0000-000000000001'),
  false,
  'is_group_member is false for a SUSPENDED membership'
);

select is(
  public.has_group_permission('b1000000-0000-0000-0000-000000000001', 'group.view'),
  false,
  'has_group_permission is false for a SUSPENDED membership'
);

-- 8. An EXITED membership is not treated as an active operational
-- membership.
select is(
  public.is_group_member('b1000000-0000-0000-0000-000000000004'),
  false,
  'is_group_member is false for an EXITED membership'
);

select is(
  public.has_group_permission('b1000000-0000-0000-0000-000000000004', 'group.view'),
  false,
  'has_group_permission is false for an EXITED membership'
);

-- 9. rpc_get_my_context() faithfully represents each group's real
-- status (SUSPENDED/CLOSED are not normalized to ACTIVE); Flutter is
-- responsible for eligibility filtering on top of this data.
create temporary table t_ctx as
select public.rpc_get_my_context() as ctx;

select is(
  (
    select m ->> 'group_status'
    from jsonb_array_elements((select ctx from t_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'b1000000-0000-0000-0000-000000000002'
  ),
  'SUSPENDED',
  'rpc_get_my_context reports the SUSPENDED group''s real status'
);

select is(
  (
    select m ->> 'group_status'
    from jsonb_array_elements((select ctx from t_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'b1000000-0000-0000-0000-000000000003'
  ),
  'CLOSED',
  'rpc_get_my_context reports the CLOSED group''s real status'
);

select is(
  (
    select m ->> 'membership_status'
    from jsonb_array_elements((select ctx from t_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'b1000000-0000-0000-0000-000000000001'
  ),
  'SUSPENDED',
  'rpc_get_my_context reports the SUSPENDED membership''s real status'
);

select is(
  (
    select m ->> 'membership_status'
    from jsonb_array_elements((select ctx from t_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'b1000000-0000-0000-0000-000000000004'
  ),
  'EXITED',
  'rpc_get_my_context reports the EXITED membership''s real status'
);

select * from finish();

rollback;
