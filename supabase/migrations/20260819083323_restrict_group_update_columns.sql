-- Security correction (Prompt 02A), group table mutation review.
--
-- The Prompt 02 policy (groups_update_manage) gated *whether* a user
-- could update a group row on group.manage, but not *which* columns —
-- a group.manage holder could directly rewrite id, created_by, or
-- created_at (audit/identity columns that must stay stable) via a
-- plain UPDATE.
--
-- Fix: column-level privileges. Only the genuinely editable
-- settings-type columns are grantable for UPDATE; id, created_by,
-- created_at, and updated_at (trigger-maintained) are not. This does
-- not add a Group Settings feature — it only protects columns that
-- were already directly editable by group.manage holders before this
-- correction.
revoke update on public.groups from authenticated;
grant update (
  name,
  code,
  description,
  status,
  currency,
  timezone,
  accounting_cutover_date
) on public.groups to authenticated;
