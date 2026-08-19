-- Authorization helper functions.
--
-- All three functions take auth.uid() as the identity, never a
-- caller-supplied user_id. They are SECURITY DEFINER so they can be used
-- inside RLS policies on public.group_memberships /public.groups without
-- causing RLS-policy recursion (a security-invoker function evaluating a
-- query against an RLS-protected table would re-trigger that table's own
-- policies). An explicit search_path prevents search-path hijacking, and
-- EXECUTE is restricted to the authenticated role only.

create or replace function public.get_my_membership(p_group_id uuid)
returns public.group_memberships
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select gm.*
  from public.group_memberships gm
  where gm.group_id = p_group_id
    and gm.user_id = auth.uid()
    and gm.status = 'ACTIVE'
  limit 1;
$$;

comment on function public.get_my_membership(uuid) is
  'Returns the caller''s own ACTIVE membership row in the given group, '
  'or no row if none exists. Identity is always auth.uid().';

create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_memberships gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'ACTIVE'
  );
$$;

comment on function public.is_group_member(uuid) is
  'Whether the caller (auth.uid()) has an ACTIVE membership in the group.';

create or replace function public.has_group_permission(p_group_id uuid, p_permission_code text)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_memberships gm
    join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
    join public.role_permissions rp on rp.role_id = gmr.role_id
    join public.permissions p on p.id = rp.permission_id
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'ACTIVE'
      and p.code = p_permission_code
  );
$$;

comment on function public.has_group_permission(uuid, text) is
  'Whether the caller (auth.uid()) holds the given permission code in '
  'the group, via any role assigned to their ACTIVE membership.';

revoke all on function public.get_my_membership(uuid) from public;
revoke all on function public.is_group_member(uuid) from public;
revoke all on function public.has_group_permission(uuid, text) from public;

grant execute on function public.get_my_membership(uuid) to authenticated;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.has_group_permission(uuid, text) to authenticated;
