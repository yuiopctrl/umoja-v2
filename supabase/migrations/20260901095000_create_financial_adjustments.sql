-- Prompt 08B: financial adjustments (section 18) — Marekebisho ya
-- Fedha. A highly-permissioned, explicit correction for a REAL,
-- verified discrepancy (cash shortage/overage, migration correction,
-- investigated bank posting discrepancy) — never an ordinary income or
-- expense, and dedicated its own table/permission/source_type so it
-- can never be confused with either in reporting. Optionally linked to
-- the financial_reconciliation that surfaced the discrepancy, purely
-- for audit traceability — creating a reconciliation itself never
-- posts a cashbook entry (previous migration); only an adjustment
-- does, and only when a human explicitly decides to post one.
--
-- Correction model: an adjustment is not reversible in this phase (no
-- test in section 37 asks for it, and a wrong adjustment is corrected
-- by posting an adjustment in the opposite direction — the same
-- "reverse-then-repost" spirit as section 14, just expressed as a
-- second adjustment rather than a formal reversal record, since an
-- adjustment already IS a correction primitive).

create type public.financial_adjustment_direction as enum (
  'INCREASE',
  'DECREASE'
);

create table public.financial_adjustments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  financial_account_id uuid not null references public.financial_accounts (id),
  direction public.financial_adjustment_direction not null,
  amount numeric(14, 2) not null,
  reason text not null,
  effective_at date not null,
  financial_reconciliation_id uuid references public.financial_reconciliations (id),
  idempotency_key text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint financial_adjustments_amount_positive check (amount > 0),
  constraint financial_adjustments_reason_not_blank check (btrim(reason) <> '')
);

comment on table public.financial_adjustments is
  'A controlled, explicit financial-account adjustment for a verified
  real-world discrepancy (Prompt 08B) — never an ordinary income or
  expense, and excluded from both in financial reporting. Immutable
  after posting, same as every other posted financial record.';

create index financial_adjustments_group_id_idx on public.financial_adjustments (group_id);
create index financial_adjustments_account_id_idx on public.financial_adjustments (financial_account_id);
create unique index financial_adjustments_idempotency_key_unique
  on public.financial_adjustments (financial_account_id, idempotency_key)
  where idempotency_key is not null;

alter table public.financial_adjustments enable row level security;
revoke all on public.financial_adjustments from anon, authenticated;

grant select on public.financial_adjustments to authenticated;

create policy financial_adjustments_select
  on public.financial_adjustments
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'financial_entry.view'));

-- ---------------------------------------------------------------------
-- rpc_record_financial_adjustment
-- ---------------------------------------------------------------------

create or replace function public.rpc_record_financial_adjustment(
  p_group_id uuid,
  p_financial_account_id uuid,
  p_direction public.financial_adjustment_direction,
  p_amount numeric,
  p_reason text,
  p_effective_at date default current_date,
  p_financial_reconciliation_id uuid default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account record;
  v_reconciliation_group_id uuid;
  v_existing record;
  v_id uuid;
  v_cashbook_entry_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_adjustment.create') then
    raise exception 'Not authorized to record financial adjustments in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'FINANCIAL_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'FINANCIAL_ADJUSTMENT_REASON_REQUIRED' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select id, group_id, is_active into v_account
  from public.financial_accounts
  where id = p_financial_account_id
  for update;

  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;
  if not v_account.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_financial_reconciliation_id is not null then
    select group_id into v_reconciliation_group_id
    from public.financial_reconciliations
    where id = p_financial_reconciliation_id;

    if v_reconciliation_group_id is null or v_reconciliation_group_id <> p_group_id then
      raise exception 'Financial reconciliation not found in group' using errcode = '22023';
    end if;
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.financial_adjustments
    where financial_account_id = p_financial_account_id and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      if v_existing.direction <> p_direction
        or v_existing.amount <> p_amount
        or v_existing.effective_at <> p_effective_at
        or v_existing.reason <> btrim(p_reason) then
        raise exception 'FINANCIAL_ADJUSTMENT_IDEMPOTENCY_KEY_CONFLICT' using errcode = 'P0001';
      end if;

      return jsonb_build_object(
        'adjustment_id', v_existing.id,
        'financial_account_id', v_existing.financial_account_id,
        'direction', v_existing.direction,
        'amount', v_existing.amount,
        'already_posted', true,
        'financial_account_balance', public.financial_account_balance(v_existing.financial_account_id)
      );
    end if;
  end if;

  -- A DECREASE adjustment must never take the account negative — same
  -- "never negative" default policy as an ordinary expense.
  if p_direction = 'DECREASE' and p_amount > public.financial_account_balance(p_financial_account_id) then
    raise exception 'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  insert into public.financial_adjustments (
    group_id, financial_account_id, direction, amount, reason, effective_at,
    financial_reconciliation_id, idempotency_key, created_by
  ) values (
    p_group_id, p_financial_account_id, p_direction, p_amount, btrim(p_reason), p_effective_at,
    p_financial_reconciliation_id, p_idempotency_key, v_uid
  )
  returning id into v_id;

  v_cashbook_entry_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => (case when p_direction = 'INCREASE' then 'INFLOW' else 'OUTFLOW' end)::public.financial_account_entry_type,
    p_amount => p_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => p_reason,
    p_source_type => 'FINANCIAL_ADJUSTMENT',
    p_source_id => v_id
  );

  return jsonb_build_object(
    'adjustment_id', v_id,
    'financial_account_id', p_financial_account_id,
    'direction', p_direction,
    'amount', p_amount,
    'already_posted', false,
    'cashbook_entry_id', v_cashbook_entry_id,
    'financial_account_balance', public.financial_account_balance(p_financial_account_id)
  );
end;
$$;

revoke all on function public.rpc_record_financial_adjustment(uuid, uuid, public.financial_adjustment_direction, numeric, text, date, uuid, text) from public;
grant execute on function public.rpc_record_financial_adjustment(uuid, uuid, public.financial_adjustment_direction, numeric, text, date, uuid, text) to authenticated;
revoke execute on function public.rpc_record_financial_adjustment(uuid, uuid, public.financial_adjustment_direction, numeric, text, date, uuid, text) from anon;
