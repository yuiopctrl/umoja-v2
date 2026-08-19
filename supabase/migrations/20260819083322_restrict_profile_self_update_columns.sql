-- Security correction (Prompt 02A), issue 3: profiles unsafe
-- self-update columns.
--
-- The Prompt 02 policy (profiles_update_own) restricted *which row* a
-- user can update (their own), but not *which columns* — a signed-in
-- user could directly set is_active, email, id, created_at, or
-- updated_at on their own profile via a plain UPDATE. is_active is a
-- system/administrative flag (not meant to be self-service), email is
-- meant to mirror Supabase Auth rather than be an independently
-- editable application field, and id/created_at/updated_at are
-- identity/audit columns that must never be client-writable.
--
-- Fix: column-level privileges. The row-level policy (id = auth.uid())
-- stays as-is; only full_name/phone/avatar_url are grantable for
-- UPDATE, so a statement touching any other column is rejected outright
-- (permission denied) regardless of RLS.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, avatar_url) on public.profiles to authenticated;
