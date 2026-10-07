-- Prompt 09G-B5-B.1: linked membership MEMBER baseline (append-only).
--
-- Locked decision: MEMBER is the baseline role of every group membership
-- linked to an authenticated user (group_memberships.user_id IS NOT NULL).
-- Officer/admin roles are additive on top of it. A roster-only membership
-- (user_id IS NULL) need not hold MEMBER.
--
-- Every sanctioned path that links a membership writes user_id through a
-- plain UPDATE or INSERT on group_memberships:
--   * rpc_create_group            (founder, INSERT with user_id)
--   * rpc_accept_membership_invitation       (legacy token, UPDATE)
--   * rpc_accept_membership_phone_invitation (phone invitation, UPDATE)
--   * rpc_approve_membership_claim           (claim approval, UPDATE)
-- Rather than patch each path, one AFTER trigger enforces the invariant
-- for all current and future linking paths, in the same transaction.
-- It never writes user_id, so the existing user_id mutation guard
-- (prevent_membership_user_id_change) is untouched.
--
-- Idempotent: group_membership_roles(group_membership_id, role_id) is
-- unique, so an invitation that already requests MEMBER does not produce a
-- duplicate. Existing roles are never removed or replaced.
--
-- Financial business data is not touched.

-- ---------------------------------------------------------------------------
-- 1. Trigger function (internal; not client-executable).
-- ---------------------------------------------------------------------------

create or replace function public.ensure_linked_membership_member_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_member_role_id uuid;
begin
  if new.user_id is null then
    return new;
  end if;

  select r.id
  into v_member_role_id
  from public.roles r
  where r.code = 'MEMBER';

  if v_member_role_id is null then
    raise exception 'MEMBER role is not defined' using errcode = 'P0001';
  end if;

  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  values (new.id, v_member_role_id, auth.uid())
  on conflict (group_membership_id, role_id) do nothing;

  return new;
end;
$function$;

revoke all on function public.ensure_linked_membership_member_role() from public, anon, authenticated;

comment on function public.ensure_linked_membership_member_role() is
  'Trigger: every user-linked group membership holds the MEMBER baseline role '
  '(09G-B5-B.1). Additive and idempotent; never removes or replaces officer roles.';

-- ---------------------------------------------------------------------------
-- 2. Trigger. Fires whenever a membership row is inserted with, or updated to
--    have, a linked user_id.
-- ---------------------------------------------------------------------------

create trigger group_memberships_ensure_member_role
after insert or update of user_id on public.group_memberships
for each row
when (new.user_id is not null)
execute function public.ensure_linked_membership_member_role();

-- ---------------------------------------------------------------------------
-- 3. Backfill: every EXISTING user-linked membership without MEMBER gets it.
--    Role resolved server-side from roles.code; no client-supplied values.
--    Officer and other roles are untouched; no membership row is modified.
-- ---------------------------------------------------------------------------

insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select gm.id, r.id, null
from public.group_memberships gm
join public.roles r on r.code = 'MEMBER'
where gm.user_id is not null
on conflict (group_membership_id, role_id) do nothing;
