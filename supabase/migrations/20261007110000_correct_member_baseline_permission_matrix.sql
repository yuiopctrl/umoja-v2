-- Prompt 09G-B5-B.1 (permission-matrix correction): MEMBER is an identity /
-- self-service baseline. It must NOT carry member.view, so a linked member
-- does not gain the Members directory merely by being linked.
--
-- The MEMBER -> member.view mapping was seeded by the already-applied
-- migration 20260819080633_create_roles_and_permissions.sql. That file is not
-- edited. This append-only migration removes exactly that one mapping.
--
-- Unchanged: MEMBER keeps group.view and every self-service permission
-- (contribution.self_view, financial_report.self_view, loan.self_view).
-- Every other role keeps its own member.view. group_memberships_select keeps
-- the own-row branch (user_id = auth.uid()), so a member still reads their
-- own membership row.
delete from public.role_permissions rp
using public.roles r, public.permissions p
where rp.role_id = r.id
  and rp.permission_id = p.id
  and r.code = 'MEMBER'
  and p.code = 'member.view';
