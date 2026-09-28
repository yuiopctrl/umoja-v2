-- Prompt 09G-DEPLOY-03: privilege hardening only.
--
-- 20260921090000_create_member_self_service_ownership_helpers.sql
-- revoked PUBLIC and granted authenticated on these three functions,
-- but never explicitly revoked anon. On a hosted Supabase project,
-- `ALTER DEFAULT PRIVILEGES ... GRANT EXECUTE ON FUNCTIONS TO anon,
-- authenticated` (standard project scaffolding) grants anon EXECUTE
-- directly at CREATE FUNCTION time, and `revoke all ... from public`
-- does not remove a grant recorded directly against a named role.
-- Local `supabase db reset` (Docker) does not carry that default-
-- privilege rule, which is why the existing pgTAP suite passed
-- locally while production carried a live anon EXECUTE grant on all
-- three functions.
--
-- This migration only changes privileges. It does not touch function
-- bodies, ownership logic, RLS, tables, the claim state machine, or
-- any permission/business data.
revoke execute on function public.current_membership_id(uuid) from anon;
revoke execute on function public.is_own_membership(uuid, uuid) from anon;
revoke execute on function public.assert_self_or_permission(uuid, uuid, text) from anon;

grant execute on function public.current_membership_id(uuid) to authenticated;
grant execute on function public.is_own_membership(uuid, uuid) to authenticated;
grant execute on function public.assert_self_or_permission(uuid, uuid, text) to authenticated;
