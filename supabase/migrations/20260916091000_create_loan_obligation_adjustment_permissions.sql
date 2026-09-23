-- Prompt 09F-A section 3 (locked): three permissions, following the
-- exact ADMIN(+TREASURER) posture already established for loan.disburse/
-- loan.settle_early/loan.prepay_principal/loan.restructure — except
-- correction is deliberately ADMIN-only (never TREASURER), unlike those
-- precedents, per the explicit locked policy below.

insert into public.permissions (code, name, description) values
  ('loan.waive', 'Waive loan obligations', 'Waive an assessed loan penalty or currently earned/payable interest, reducing effective outstanding with zero cash impact.'),
  ('loan.correct', 'Correct loan obligations', 'Post an append-only correction (decrease or increase) against an existing loan penalty/interest assessment.'),
  ('loan.correct_increase', 'Increase loan obligation corrections', 'Post a correction that increases a loan penalty''s effective assessed amount (ADMIN-only; never available for interest).');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in ('loan.waive', 'loan.correct', 'loan.correct_increase')
on conflict do nothing;

-- TREASURER receives loan.waive ONLY — loan.correct/loan.correct_increase
-- are deliberately withheld (locked policy, section 3): a correction
-- rewrites the effective value of a posted assessment (even though the
-- original row stays immutable) and is reserved for ADMIN.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code = 'loan.waive'
where r.code = 'TREASURER';

-- CHAIRPERSON/SECRETARY/MEMBER get none of these by default; they still
-- see the resulting state via their existing loan.view grant.
