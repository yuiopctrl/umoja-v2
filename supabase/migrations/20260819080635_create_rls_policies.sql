-- Row Level Security for the identity/tenancy foundation.
--
-- Table-level grants are set explicitly (least privilege) rather than
-- relying on default privileges, and RLS policies then gate row access
-- within those grants. No policy on a tenant-owned table uses
-- `USING (true)`.

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;

revoke all on public.profiles from anon, authenticated;
grant select, update on public.profiles to authenticated;

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

-- WITH CHECK (id = auth.uid()) prevents rewriting a row to another
-- user's id, which combined with the USING clause means a user can only
-- ever update their own profile row and cannot repoint it at someone
-- else's identity.
create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- groups
-- ---------------------------------------------------------------------

alter table public.groups enable row level security;

revoke all on public.groups from anon, authenticated;
grant select, update on public.groups to authenticated;

create policy groups_select_member
  on public.groups
  for select
  to authenticated
  using (public.is_group_member(id));

create policy groups_update_manage
  on public.groups
  for update
  to authenticated
  using (public.has_group_permission(id, 'group.manage'))
  with check (public.has_group_permission(id, 'group.manage'));

-- No INSERT/DELETE policy: groups are only ever created via
-- rpc_create_group (SECURITY DEFINER), never by a direct client insert.

-- ---------------------------------------------------------------------
-- group_memberships
-- ---------------------------------------------------------------------

alter table public.group_memberships enable row level security;

revoke all on public.group_memberships from anon, authenticated;
grant select, insert, update on public.group_memberships to authenticated;

create policy group_memberships_select
  on public.group_memberships
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.has_group_permission(group_id, 'member.view')
  );

-- user_id must be null on direct client inserts: linking a membership to
-- an existing auth user is a controlled future workflow (see
-- docs/product/member-identity-model.md), not something a member.create
-- holder can do by setting an arbitrary user_id on insert. The only
-- self-user_id membership insert (a group creator's own ADMIN
-- membership) happens through rpc_create_group, which is SECURITY
-- DEFINER and therefore not subject to this policy.
create policy group_memberships_insert
  on public.group_memberships
  for insert
  to authenticated
  with check (
    user_id is null
    and public.has_group_permission(group_id, 'member.create')
  );

create policy group_memberships_update
  on public.group_memberships
  for update
  to authenticated
  using (
    public.has_group_permission(group_id, 'member.edit')
    or public.has_group_permission(group_id, 'member.change_status')
  )
  with check (
    public.has_group_permission(group_id, 'member.edit')
    or public.has_group_permission(group_id, 'member.change_status')
  );

-- ---------------------------------------------------------------------
-- roles / permissions (system-defined reference data, not tenant-owned)
-- ---------------------------------------------------------------------

alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;

revoke all on public.roles from anon, authenticated;
revoke all on public.permissions from anon, authenticated;
revoke all on public.role_permissions from anon, authenticated;

grant select on public.roles to authenticated;
grant select on public.permissions to authenticated;
grant select on public.role_permissions to authenticated;

-- These are global system definitions (not scoped to a group), so a
-- read-only `true` policy restricted to authenticated is appropriate —
-- it is not a tenant-owned table. There are intentionally no
-- insert/update/delete policies: ordinary users can never mutate role
-- or permission definitions, only migrations can.
create policy roles_select_authenticated
  on public.roles
  for select
  to authenticated
  using (true);

create policy permissions_select_authenticated
  on public.permissions
  for select
  to authenticated
  using (true);

create policy role_permissions_select_authenticated
  on public.role_permissions
  for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------
-- group_membership_roles (tenant-scoped via the referenced membership)
-- ---------------------------------------------------------------------

alter table public.group_membership_roles enable row level security;

revoke all on public.group_membership_roles from anon, authenticated;
grant select, insert, delete on public.group_membership_roles to authenticated;

create policy group_membership_roles_select
  on public.group_membership_roles
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.group_memberships gm
      where gm.id = group_membership_roles.group_membership_id
        and (
          gm.user_id = auth.uid()
          or public.has_group_permission(gm.group_id, 'role.view')
        )
    )
  );

create policy group_membership_roles_insert
  on public.group_membership_roles
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.group_memberships gm
      where gm.id = group_membership_roles.group_membership_id
        and public.has_group_permission(gm.group_id, 'role.assign')
    )
  );

create policy group_membership_roles_delete
  on public.group_membership_roles
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.group_memberships gm
      where gm.id = group_membership_roles.group_membership_id
        and public.has_group_permission(gm.group_id, 'role.assign')
    )
  );
