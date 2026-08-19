-- Security correction (Prompt 02A): function/RPC privilege review.
--
-- Every Prompt 02 function correctly ran `REVOKE ALL ... FROM PUBLIC`,
-- but that does not remove `anon`'s EXECUTE privilege. Supabase's own
-- bootstrap sets `ALTER DEFAULT PRIVILEGES ... GRANT EXECUTE ON
-- FUNCTIONS TO anon, authenticated, service_role`, which auto-grants
-- EXECUTE to `anon` specifically (not just via PUBLIC) on every newly
-- created function. Revoking from PUBLIC alone therefore left every
-- function in this schema directly callable by an unauthenticated
-- (anon-key) client — reaching the internal `auth.uid() is null` check
-- (raising "Not authenticated") rather than being rejected at the grant
-- level. This closes that gap for every function introduced so far.
revoke execute on function public.is_group_member(uuid) from anon;
revoke execute on function public.get_my_membership(uuid) from anon;
revoke execute on function public.has_group_permission(uuid, text) from anon;
revoke execute on function public.rpc_get_my_context() from anon;
revoke execute on function public.rpc_create_group(text, text) from anon;
revoke execute on function public.rpc_create_group_member(uuid, text, text, text, date) from anon;
revoke execute on function public.has_group_role(uuid, text) from anon;
revoke execute on function public.rpc_assign_group_role(uuid, uuid, text) from anon;
revoke execute on function public.rpc_remove_group_role(uuid, uuid, text) from anon;
revoke execute on function public.rpc_update_group_member(uuid, uuid, text, text, text, date) from anon;
revoke execute on function public.rpc_change_group_member_status(uuid, uuid, public.membership_status, date) from anon;

-- Trigger functions must never be directly callable by any client role
-- at all (they are invoked only by the trigger mechanism as the table
-- owner); belt-and-braces revoke in case a future default-privilege
-- change ever grants them.
revoke execute on function public.set_updated_at() from anon, authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated;
revoke execute on function public.prevent_membership_user_id_change() from anon, authenticated;
