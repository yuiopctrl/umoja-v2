-- Prompt 09B: atomic loan disbursement (sections 13-21).
--
-- Reuses the exact 08A/08B cashbook posting infrastructure
-- (`financial_account_post_entry`) that every other cash-moving RPC
-- already uses — no second ledger. The whole function body is one
-- Postgres transaction (a PL/pgSQL function call is never partially
-- committed), so "if ANY step fails, ZERO partial financial state"
-- (section 13) is automatic: an exception anywhere below rolls back
-- every write already made in this call, including the loan_accounts
-- row lock, the loan_disbursements insert, and the cashbook entry.
--
-- DISBURSED is a transactional pass-through, not a durable resting
-- status (section 3, "document the chosen semantics"): this function
-- moves a loan straight from APPROVED to ACTIVE within the same call,
-- recording the transition event as event_type = 'DISBURSED',
-- from_status = 'APPROVED', to_status = 'ACTIVE'. A separately
-- observable DISBURSED status would be a meaningless extra state for
-- 09B, since nothing in this phase ever inspects or acts on it
-- between disbursement and activation — they are the same instant.
create or replace function public.rpc_disburse_loan_account(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_financial_account_id uuid,
  p_effective_at date,
  p_reference text default null,
  p_notes text default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_account record;
  v_existing record;
  v_disbursement_id uuid;
  v_entry_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.disburse') then
    raise exception 'Not authorized to disburse loans in this group' using errcode = '42501';
  end if;

  select * into v_loan from public.loan_accounts where id = p_loan_account_id for update;
  if v_loan.group_id is null or v_loan.group_id <> p_group_id then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  -- Idempotent retry (section 19): a loan already ACTIVE with a
  -- matching idempotency_key on its one (unique) disbursement row is a
  -- safe no-op — return the original result instead of erroring or
  -- posting a second time. Any other repeat attempt against an
  -- already-disbursed loan is a genuine error, never a silent retry.
  if v_loan.status in ('DISBURSED', 'ACTIVE') then
    select * into v_existing
    from public.loan_disbursements
    where loan_account_id = p_loan_account_id;

    if p_idempotency_key is not null
      and v_existing.idempotency_key is not null
      and v_existing.idempotency_key = p_idempotency_key
    then
      select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
      return v_result || jsonb_build_object('already_posted', true);
    end if;

    raise exception 'LOAN_ACCOUNT_ALREADY_DISBURSED' using errcode = 'P0001';
  end if;

  if v_loan.status <> 'APPROVED' then
    raise exception 'LOAN_ACCOUNT_NOT_APPROVED' using errcode = 'P0001';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select * into v_account
  from public.financial_accounts
  where id = p_financial_account_id
  for update;
  if v_account.group_id is null or v_account.group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;
  if not v_account.is_active then
    raise exception 'FINANCIAL_ACCOUNT_INACTIVE' using errcode = 'P0001';
  end if;

  if v_loan.principal_amount > public.financial_account_balance(p_financial_account_id) then
    raise exception 'LOAN_DISBURSEMENT_INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  insert into public.loan_disbursements (
    group_id, loan_account_id, financial_account_id, amount, effective_at,
    reference, notes, idempotency_key, created_by
  ) values (
    p_group_id, p_loan_account_id, p_financial_account_id, v_loan.principal_amount, p_effective_at,
    p_reference, p_notes, p_idempotency_key, v_uid
  )
  returning id into v_disbursement_id;

  v_entry_id := public.financial_account_post_entry(
    p_group_id => p_group_id,
    p_financial_account_id => p_financial_account_id,
    p_entry_type => 'OUTFLOW',
    p_amount => v_loan.principal_amount,
    p_effective_at => p_effective_at,
    p_uid => v_uid,
    p_description => p_notes,
    p_reference => p_reference,
    p_source_type => 'LOAN_DISBURSEMENT',
    p_source_id => v_disbursement_id,
    p_idempotency_key => p_idempotency_key
  );

  update public.loan_disbursements
  set financial_account_entry_id = v_entry_id
  where id = v_disbursement_id;

  update public.loan_accounts
  set status = 'ACTIVE', updated_by = v_uid
  where id = p_loan_account_id;

  insert into public.loan_account_events (
    group_id, loan_account_id, event_type, from_status, to_status, metadata, created_by
  ) values (
    p_group_id, p_loan_account_id, 'DISBURSED', v_loan.status, 'ACTIVE',
    jsonb_build_object('loan_disbursement_id', v_disbursement_id), v_uid
  );

  select public.rpc_get_loan_account(p_group_id, p_loan_account_id) into v_result;
  return v_result || jsonb_build_object('already_posted', false);
end;
$$;

revoke all on function public.rpc_disburse_loan_account(
  uuid, uuid, uuid, date, text, text, text
) from public;
grant execute on function public.rpc_disburse_loan_account(
  uuid, uuid, uuid, date, text, text, text
) to authenticated;
revoke execute on function public.rpc_disburse_loan_account(
  uuid, uuid, uuid, date, text, text, text
) from anon;
