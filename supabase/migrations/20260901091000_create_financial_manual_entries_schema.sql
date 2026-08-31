-- Prompt 08B: manual group income/expense — permissions + schema.
--
-- One unified table (financial_manual_entries) for both INCOME and
-- EXPENSE postings, mirroring how financial_account_entries itself
-- already handles two directions (INFLOW/OUTFLOW) in one table rather
-- than two near-identical tables — entry_kind carries which one this
-- row is. This is the "posting" record (mirrors payments from Prompt
-- 07): one financial_manual_entries row always creates exactly one
-- financial_account_entries cashbook row via financial_account_post_entry
-- (source_type = 'MANUAL_INCOME' | 'EXPENSE'), and a reversal flips
-- status to REVERSED and posts exactly one compensating cashbook entry
-- (source_type = 'MANUAL_INCOME_REVERSAL' | 'EXPENSE_REVERSAL') — the
-- exact same pattern Prompt 07's rpc_reverse_payment already
-- established for payments.

-- ---------------------------------------------------------------------
-- Permissions (section 26). Conservative mapping:
--   ADMIN: every Phase 08B permission.
--   TREASURER: the full operational set (view/income/expense/reverse/
--     reconciliation/adjustment/report) — the same role that already
--     holds payment.create/payment.reverse/wallet.allocate from Prompt
--     07; financial_adjustment.create is granted here too since
--     TREASURER is the role that actually performs reconciliation in
--     practice, not just ADMIN.
--   CHAIRPERSON: view/report/reconciliation visibility only — no
--     posting/reversal/adjustment (matches CHAIRPERSON's existing
--     payment.view/wallet.view-only posture from Prompt 07).
--   SECRETARY: view/report only (matches their existing payment.view-
--     only posture).
--   MEMBER: none of the below.
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('financial_entry.view', 'View financial entries', 'View manual income/expense entries and the full cashbook classification.'),
  ('financial_income.create', 'Record group income', 'Post manual group income not originating from a member contribution payment.'),
  ('financial_expense.create', 'Record group expense', 'Post a manual group expense against a financial account.'),
  ('financial_entry.reverse', 'Reverse financial entries', 'Reverse a posted manual income/expense entry.'),
  ('financial_reconciliation.view', 'View reconciliations', 'View a financial account''s reconciliation history.'),
  ('financial_reconciliation.create', 'Create reconciliations', 'Record a financial account reconciliation against a bank/mobile/cash statement.'),
  ('financial_adjustment.create', 'Record financial adjustments', 'Post a controlled financial-account adjustment to resolve a verified discrepancy.'),
  ('financial_report.view', 'View financial reports', 'View the group''s financial position / overview report.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in (
    'financial_entry.view', 'financial_income.create', 'financial_expense.create',
    'financial_entry.reverse', 'financial_reconciliation.view', 'financial_reconciliation.create',
    'financial_adjustment.create', 'financial_report.view'
  )
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'financial_entry.view', 'financial_income.create', 'financial_expense.create',
    'financial_entry.reverse', 'financial_reconciliation.view', 'financial_reconciliation.create',
    'financial_adjustment.create', 'financial_report.view'
  )
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('financial_entry.view', 'financial_reconciliation.view', 'financial_report.view')
where r.code = 'CHAIRPERSON';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('financial_entry.view', 'financial_report.view')
where r.code = 'SECRETARY';

-- MEMBER intentionally gets none of the above — same posture as every
-- other Phase 08A/Prompt 07 treasury permission.

-- ---------------------------------------------------------------------
-- financial_manual_entries
-- ---------------------------------------------------------------------

create type public.financial_manual_entry_kind as enum (
  'INCOME',
  'EXPENSE'
);

create type public.financial_manual_entry_status as enum (
  'POSTED',
  'REVERSED'
);

create table public.financial_manual_entries (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  financial_account_id uuid not null references public.financial_accounts (id),
  category_id uuid not null references public.financial_categories (id),
  entry_kind public.financial_manual_entry_kind not null,
  amount numeric(14, 2) not null,
  effective_at date not null,
  description text,
  reference text,
  status public.financial_manual_entry_status not null default 'POSTED',
  reversed_at timestamptz,
  reversed_by uuid references auth.users (id),
  reversal_reason text,
  idempotency_key text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint financial_manual_entries_amount_positive check (amount > 0),
  constraint financial_manual_entries_reversal_fields_together check (
    (status = 'POSTED' and reversed_at is null and reversed_by is null and reversal_reason is null)
    or (status = 'REVERSED' and reversed_at is not null and reversed_by is not null and reversal_reason is not null)
  )
);

comment on table public.financial_manual_entries is
  'One manual group INCOME or EXPENSE posting (Prompt 08B) — the
  "posting" record mirroring payments from Prompt 07. Always creates
  exactly one financial_account_entries cashbook row (source_type =
  ''MANUAL_INCOME'' | ''EXPENSE'', source_id = this row''s id). Never
  edited after posting; a wrong entry is reversed (status -> REVERSED,
  one compensating cashbook entry posted) then a correct one is posted
  separately — there is no in-place correction path.';

create index financial_manual_entries_group_id_idx on public.financial_manual_entries (group_id);
create index financial_manual_entries_account_id_idx on public.financial_manual_entries (financial_account_id);
create index financial_manual_entries_category_id_idx on public.financial_manual_entries (category_id);
create unique index financial_manual_entries_idempotency_key_unique
  on public.financial_manual_entries (financial_account_id, idempotency_key)
  where idempotency_key is not null;

alter table public.financial_manual_entries enable row level security;
revoke all on public.financial_manual_entries from anon, authenticated;

grant select on public.financial_manual_entries to authenticated;

create policy financial_manual_entries_select
  on public.financial_manual_entries
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'financial_entry.view'));
