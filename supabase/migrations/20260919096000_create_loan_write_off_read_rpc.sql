-- Prompt 09F-B section F: a dedicated read RPC for Loan Detail's
-- write-off summary + recovery history — kept separate from
-- rpc_get_loan_account (which already returns `status`, so a
-- WRITTEN_OFF loan is trivially distinguishable there) rather than
-- bloating it further, matching 09F-A's identical "separate RPC"
-- precedent for adjustment history.

create or replace function public.rpc_get_loan_write_off_summary(
  p_group_id uuid,
  p_loan_account_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_write_off record;
  v_remaining record;
  v_recoveries jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select id, group_id, status into v_loan
  from public.loan_accounts
  where id = p_loan_account_id and group_id = p_group_id;

  if v_loan.id is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  select * into v_write_off
  from public.loan_write_off_events
  where loan_account_id = p_loan_account_id and event_type = 'WRITE_OFF'
  order by entry_no desc
  limit 1;

  if v_write_off.id is null then
    return jsonb_build_object(
      'loan_account_id', p_loan_account_id,
      'loan_status', v_loan.status,
      'write_off', null,
      'remaining_recoverable', null,
      'recoveries', '[]'::jsonb
    );
  end if;

  select * into v_remaining
  from public.loan_recovery_remaining_balance(v_write_off.id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', re.id,
    'payment_id', re.payment_id,
    'receipt_number', p.receipt_number,
    'principal_recovered', re.principal_recovered,
    'interest_recovered', re.interest_recovered,
    'penalty_recovered', re.penalty_recovered,
    'total_recovered', re.principal_recovered + re.interest_recovered + re.penalty_recovered,
    'effective_at', p.effective_at,
    'payment_status', p.status,
    'created_by', re.created_by,
    'created_at', re.created_at
  ) order by re.entry_no asc), '[]'::jsonb)
  into v_recoveries
  from public.loan_recovery_events re
  join public.payments p on p.id = re.payment_id
  where re.write_off_event_id = v_write_off.id;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'loan_status', v_loan.status,
    'write_off', jsonb_build_object(
      'id', v_write_off.id,
      'principal_amount', v_write_off.principal_amount,
      'interest_amount', v_write_off.interest_amount,
      'penalty_amount', v_write_off.penalty_amount,
      'total_amount', v_write_off.principal_amount + v_write_off.interest_amount + v_write_off.penalty_amount,
      'reason_code', v_write_off.reason_code,
      'note', v_write_off.note,
      'effective_date', v_write_off.effective_date,
      'created_by', v_write_off.created_by,
      'created_at', v_write_off.created_at,
      'is_reversed', exists (
        select 1 from public.loan_write_off_events r where r.reverses_write_off_id = v_write_off.id
      )
    ),
    'remaining_recoverable', jsonb_build_object(
      'principal', v_remaining.principal_remaining,
      'interest', v_remaining.interest_remaining,
      'penalty', v_remaining.penalty_remaining,
      'total', v_remaining.principal_remaining + v_remaining.interest_remaining + v_remaining.penalty_remaining
    ),
    'recoveries', v_recoveries
  );
end;
$$;

revoke all on function public.rpc_get_loan_write_off_summary(uuid, uuid) from public;
grant execute on function public.rpc_get_loan_write_off_summary(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_loan_write_off_summary(uuid, uuid) from anon;

comment on function public.rpc_get_loan_write_off_summary(uuid, uuid) is
  'Prompt 09F-B: the most recent write-off event (if any — null fields
  when the loan has never been written off), its live remaining
  recoverable balance per component, and full recovery history for
  Loan Detail. Gated on loan.view, same as every other loan read RPC.';
