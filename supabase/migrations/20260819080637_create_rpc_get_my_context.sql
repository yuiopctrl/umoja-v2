-- rpc_get_my_context(): the current authenticated user's full
-- application context (profile + every membership, with roles and
-- effective permissions per membership).
--
-- Always keyed on auth.uid() — never accepts a user_id argument, so it
-- cannot be used to read another user's context. SECURITY DEFINER is
-- used deliberately (with an explicit search_path) so the function can
-- read across profiles/group_memberships/groups/roles/permissions in one
-- consistent pass rather than depending on layered RLS; the auth.uid()
-- filter is what keeps it safe, not RLS.
--
-- Shape (stable/documented for Flutter):
-- {
--   "user_id": uuid,
--   "profile": { "id", "full_name", "phone", "email", "avatar_url",
--                "is_active", "created_at", "updated_at" } | null,
--   "memberships": [
--     {
--       "membership_id": uuid,
--       "group_id": uuid,
--       "group_name": text,
--       "group_status": "ACTIVE" | "SUSPENDED" | "CLOSED",
--       "membership_status": "ACTIVE" | "SUSPENDED" | "EXITED",
--       "display_name": text,
--       "roles": text[]  -- role codes, e.g. ["ADMIN"]
--       "permissions": text[]  -- permission codes, e.g. ["group.view", ...]
--     },
--     ...
--   ]
-- }
create or replace function public.rpc_get_my_context()
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_profile jsonb;
  v_memberships jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select to_jsonb(p) into v_profile
  from public.profiles p
  where p.id = v_uid;

  select coalesce(jsonb_agg(m order by m.created_at), '[]'::jsonb)
  into v_memberships
  from (
    select
      gm.id as membership_id,
      gm.group_id,
      g.name as group_name,
      g.status as group_status,
      gm.status as membership_status,
      gm.display_name,
      gm.created_at,
      coalesce(
        (
          select jsonb_agg(distinct r.code)
          from public.group_membership_roles gmr
          join public.roles r on r.id = gmr.role_id
          where gmr.group_membership_id = gm.id
        ),
        '[]'::jsonb
      ) as roles,
      coalesce(
        (
          select jsonb_agg(distinct perm.code)
          from public.group_membership_roles gmr
          join public.role_permissions rp on rp.role_id = gmr.role_id
          join public.permissions perm on perm.id = rp.permission_id
          where gmr.group_membership_id = gm.id
        ),
        '[]'::jsonb
      ) as permissions
    from public.group_memberships gm
    join public.groups g on g.id = gm.group_id
    where gm.user_id = v_uid
  ) m;

  return jsonb_build_object(
    'user_id', v_uid,
    'profile', v_profile,
    'memberships', v_memberships
  );
end;
$$;

comment on function public.rpc_get_my_context() is
  'Returns the calling user''s profile and every group membership '
  '(with roles/effective permissions), keyed only on auth.uid().';

revoke all on function public.rpc_get_my_context() from public;
grant execute on function public.rpc_get_my_context() to authenticated;
