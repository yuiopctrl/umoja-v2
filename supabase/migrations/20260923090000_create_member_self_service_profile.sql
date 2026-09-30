-- Prompt 09G-B2: Member Profile + Member Home Foundation.
--
-- The first real self-service READ built on top of the ownership
-- primitives introduced (but not yet consumed by any RPC) in
-- 20260921090000_create_member_self_service_ownership_helpers.sql.
--
-- rpc_get_my_member_profile(p_group_id) is a MY-profile RPC, not an
-- officer "view member profile" RPC: it resolves the caller's own
-- membership via current_membership_id(p_group_id) — which already
-- enforces authenticated caller, active profile, ACTIVE membership,
-- and ACTIVE group — and returns exactly that membership's data.
-- There is no officer/permission fallback and no membership_id/user_id
-- parameter: the caller cannot ask for anyone else's profile, ever.
--
-- Deliberately reuses current_membership_id() rather than duplicating
-- its gating logic, so this RPC automatically inherits the exact same
-- "normal selected-group context" invariant as every other self-
-- service primitive (CLAUDE.md: only an ACTIVE membership in an ACTIVE
-- group is ever a normal selected-group context).
--
-- 09G-B2-FIX-01: account.phone is the caller's VERIFIED Supabase-Auth
-- phone (current_verified_auth_phone_e164(), the same one authoritative
-- primitive phone-targeted invitations already use — see
-- 20260922091500_create_phone_targeted_membership_invitations.sql),
-- never profiles.phone (editable contact data — see
-- 20260819083322_restrict_profile_self_update_columns.sql's own
-- client-writable grant on that column) and never
-- group_memberships.phone (officer-maintained roster data). Calling a
-- SECURITY DEFINER function with zero client EXECUTE grants from
-- within another SECURITY DEFINER function is safe and already the
-- established pattern in this codebase: every consumer of
-- current_verified_auth_phone_e164() (rpc_accept_membership_phone_
-- invitation/decline/create) does exactly this — the function owner's
-- implicit execute right (never revoked, only PUBLIC/anon/authenticated
-- grants are) covers the internal call regardless of the explicit
-- revoke. Returns NULL when the caller has no confirmed auth phone —
-- fails closed, per current_verified_auth_phone_e164()'s own documented
-- semantics — rather than falling back to any other phone source.
create or replace function public.rpc_get_my_member_profile(p_group_id uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_membership_id uuid;
  v_verified_phone text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  v_verified_phone := public.current_verified_auth_phone_e164();

  select jsonb_build_object(
    'account', jsonb_build_object(
      'full_name', p.full_name,
      'phone', v_verified_phone,
      'avatar_url', p.avatar_url
    ),
    'membership', jsonb_build_object(
      'membership_id', gm.id,
      'display_name', gm.display_name,
      'member_number', gm.member_number,
      'membership_status', gm.status,
      'joined_at', gm.joined_at
    ),
    'group', jsonb_build_object(
      'group_id', g.id,
      'group_name', g.name,
      'group_code', g.code
    ),
    'roles', coalesce(
      (
        select jsonb_agg(r.code order by r.name)
        from public.group_membership_roles gmr
        join public.roles r on r.id = gmr.role_id
        where gmr.group_membership_id = gm.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  join public.profiles p on p.id = auth.uid()
  where gm.id = v_membership_id;

  return v_result;
end;
$$;

comment on function public.rpc_get_my_member_profile(uuid) is
  'The caller''s own account profile + their own membership/roles in '
  'p_group_id — resolved exclusively via current_membership_id(), '
  'never by a client-supplied membership_id/user_id/phone/member_number. '
  'No officer permission ever widens this: an ADMIN calling this sees '
  'ONLY their own profile, exactly like a plain MEMBER would. Raises '
  '42501 if the caller has no ACTIVE membership in an ACTIVE group '
  'there (also covers inactive-profile callers, via '
  'current_membership_id()''s own caller_profile_is_active() check). '
  'account.phone is the verified Supabase-Auth phone '
  '(current_verified_auth_phone_e164()), NULL if unverified — never '
  'profiles.phone or group_memberships.phone.';

revoke all on function public.rpc_get_my_member_profile(uuid) from public;
revoke execute on function public.rpc_get_my_member_profile(uuid) from anon;
grant execute on function public.rpc_get_my_member_profile(uuid) to authenticated;
