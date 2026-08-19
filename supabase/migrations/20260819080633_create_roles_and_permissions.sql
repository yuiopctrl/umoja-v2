-- Role and permission foundation.
--
-- Roles/permissions are system-defined reference data seeded here (not
-- via seed.sql, so they exist in every environment through migrations).
-- Mappings are data-driven (role_permissions) so they can evolve without
-- schema changes.

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_system boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.roles is
  'A role that may be assigned to a group membership. System roles '
  '(is_system = true) are seeded by migrations, not created by users.';

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

comment on table public.permissions is
  'A single, fine-grained authorization capability, referenced by code '
  '(e.g. member.create). Granted to roles via role_permissions.';

create table public.group_membership_roles (
  id uuid primary key default gen_random_uuid(),
  group_membership_id uuid not null references public.group_memberships (id) on delete cascade,
  role_id uuid not null references public.roles (id),
  assigned_at timestamptz not null default now(),
  assigned_by uuid references auth.users (id),
  unique (group_membership_id, role_id)
);

comment on table public.group_membership_roles is
  'Roles assigned to a specific group membership. A membership may hold '
  'more than one role.';

create table public.role_permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.roles (id) on delete cascade,
  permission_id uuid not null references public.permissions (id) on delete cascade,
  unique (role_id, permission_id)
);

comment on table public.role_permissions is
  'Data-driven mapping of which permissions each role grants.';

create index group_membership_roles_membership_idx
  on public.group_membership_roles (group_membership_id);
create index role_permissions_role_id_idx on public.role_permissions (role_id);

-- Seed system roles.
insert into public.roles (code, name, description, is_system) values
  ('MEMBER', 'Member', 'Ordinary group member.', true),
  ('TREASURER', 'Treasurer', 'Manages group finances.', true),
  ('SECRETARY', 'Secretary', 'Manages group records and membership.', true),
  ('CHAIRPERSON', 'Chairperson', 'Chairs the group and its governance.', true),
  ('ADMIN', 'Administrator', 'Full administrative access to the group.', true);

-- Seed foundation permissions (identity/group management only — no
-- contribution/payment/loan permissions belong in this migration).
insert into public.permissions (code, name, description) values
  ('group.view', 'View group', 'View group details.'),
  ('group.manage', 'Manage group', 'Edit group details/settings.'),
  ('member.view', 'View members', 'View group membership records.'),
  ('member.create', 'Create members', 'Register new group members.'),
  ('member.edit', 'Edit members', 'Edit group member records.'),
  ('member.change_status', 'Change member status', 'Suspend/exit/reactivate a member.'),
  ('role.view', 'View roles', 'View role assignments.'),
  ('role.assign', 'Assign roles', 'Assign or revoke roles on a membership.');

-- Seed initial role -> permission mappings.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'group.view',
    'member.view',
    'member.create',
    'member.edit',
    'member.change_status',
    'role.view',
    'role.assign'
  )
where r.code = 'CHAIRPERSON';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('group.view', 'member.view', 'member.create', 'member.edit')
where r.code = 'SECRETARY';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('group.view', 'member.view')
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('group.view', 'member.view')
where r.code = 'MEMBER';
