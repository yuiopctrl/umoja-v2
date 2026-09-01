-- Prompt 09B: Loan Workflow, Approval & Disbursement — lifecycle audit
-- trail and permissions foundation.
--
-- Design decision (section 6): `loan_account_events` is an append-only
-- audit trail, never a second source of current-status truth — current
-- status stays exactly where 09A put it, on `loan_accounts.status`.
-- Rather than accumulating submitted_at/submitted_by/approved_at/
-- approved_by/rejected_at/rejected_by/rejection_reason/cancelled_at/
-- cancelled_by/cancellation_reason as ever-growing columns on
-- `loan_accounts` (explicitly warned against — "consider a dedicated
-- table rather than accumulating every possible action field
-- indefinitely"), every lifecycle transition (including the original
-- DRAFT creation) is recorded as one immutable event row here:
-- event_type, from_status, to_status, an optional reason, and the
-- actor/timestamp via created_by/created_at. This is also the
-- maker/checker foundation (section 24): "who created" (CREATED),
-- "who submitted" (SUBMITTED), "who approved" (APPROVED), "who
-- disbursed" (DISBURSED) are all independently recoverable from this
-- one table without any schema change, so a future stricter
-- separation-of-duties policy (e.g. "submitter cannot approve their
-- own loan") can be enforced later purely in RPC logic.

create type public.loan_account_event_type as enum (
  'CREATED',
  'UPDATED',
  'SUBMITTED',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
  'DISBURSED'
);

create table public.loan_account_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  loan_account_id uuid not null references public.loan_accounts(id),
  event_type public.loan_account_event_type not null,
  from_status public.loan_account_status,
  to_status public.loan_account_status not null,
  reason text,
  metadata jsonb,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create index loan_account_events_loan_account_id_idx
  on public.loan_account_events (loan_account_id, created_at);
create index loan_account_events_group_id_idx
  on public.loan_account_events (group_id);

alter table public.loan_account_events enable row level security;

-- Read-only from Flutter, same lockdown posture as loan_installments/
-- loan_number_counters — every INSERT happens internally, from within
-- a SECURITY DEFINER lifecycle RPC, never directly from a client role.
create policy loan_account_events_select on public.loan_account_events
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));

revoke all on public.loan_account_events from public, anon, authenticated;
grant select on public.loan_account_events to authenticated;

-- ---------------------------------------------------------------------
-- Permissions (section 23). Separation-of-duties by design: the same
-- role that submits/disburses (TREASURER — the group's financial
-- executor) is deliberately NOT the role that approves/rejects
-- (CHAIRPERSON — the group's governance decision-maker), so approving
-- a loan is never merely automatic for whoever could create/submit it.
-- ADMIN retains full access (matches every other 09A/08B permission
-- group's posture); SECRETARY stays view-only; MEMBER gets none.
-- Cancellation is granted to both TREASURER and CHAIRPERSON since
-- either a financial or governance actor may legitimately need to
-- withdraw a loan before disbursement.
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('loan.submit', 'Submit loans', 'Submit a draft loan account for approval.'),
  ('loan.approve', 'Approve loans', 'Approve a submitted loan account.'),
  ('loan.reject', 'Reject loans', 'Reject a submitted loan account.'),
  ('loan.cancel', 'Cancel loans', 'Cancel a non-disbursed loan account.'),
  ('loan.disburse', 'Disburse loans', 'Disburse an approved loan account.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in ('loan.submit', 'loan.approve', 'loan.reject', 'loan.cancel', 'loan.disburse')
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('loan.submit', 'loan.disburse', 'loan.cancel')
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('loan.approve', 'loan.reject', 'loan.cancel')
where r.code = 'CHAIRPERSON';

-- SECRETARY stays view-only (already holds loan.view/loan_product.view/
-- loan_schedule.view from 09A); MEMBER gets none of the above.
