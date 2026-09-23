-- Prompt 09F-B section E: dedicated permissions.
--
-- ADMIN: all three. TREASURER: loan.recovery.create only (a treasurer
-- records cash they've actually collected on a written-off loan, but
-- the decision to write a loan off — or to reverse that decision — is
-- reserved for ADMIN, matching the same posture already established
-- for loan.correct_increase in 09F-A).

insert into public.permissions (code, name, description) values
  ('loan.write_off', 'Write off loans', 'Write off the full remaining obligation of an active loan.'),
  ('loan.write_off.reverse', 'Reverse loan write-offs', 'Reverse a loan write-off while no dependent recovery activity exists.'),
  ('loan.recovery.create', 'Record loan recoveries', 'Record a cash recovery against a written-off loan.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in ('loan.write_off', 'loan.write_off.reverse', 'loan.recovery.create')
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code = 'loan.recovery.create'
where r.code = 'TREASURER'
on conflict do nothing;
