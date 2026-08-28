-- Financial Accounts RLS policies and read grants (Prompt 08A).
--
-- Both tables got RLS enabled + all client grants revoked in
-- 20260826090000_create_financial_accounts_schema.sql (default deny).
-- This migration adds SELECT-only grants plus policies. There is no
-- direct client INSERT/UPDATE/DELETE grant on either table — all
-- mutation goes through SECURITY DEFINER RPCs, matching the
-- Contribution Engine precedent. No policy here uses USING (true).

grant select on public.financial_accounts to authenticated;

create policy financial_accounts_select
  on public.financial_accounts
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'financial_account.view'));

grant select on public.financial_account_entries to authenticated;

create policy financial_account_entries_select
  on public.financial_account_entries
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'financial_account.view'));
