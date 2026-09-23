-- Prompt 09F-A section 23: adjustment-history read RPC — a separate,
-- paginated RPC (mirrors rpc_list_loan_penalty_charges''s posture of
-- being its own call rather than being folded into rpc_get_loan_account)
-- so Loan Detail stays fast regardless of how long a loan''s adjustment
-- history grows. Every reversal relationship is surfaced explicitly
-- (reverses_adjustment_id / is_reversed / reversed_by_adjustment_id) so
-- the UI can render reversed history without a second round trip.

create or replace function public.rpc_list_loan_obligation_adjustments(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb;
  v_total_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loan obligations in this group' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.loan_accounts where id = p_loan_account_id and group_id = p_group_id
  ) then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  select count(*) into v_total_count
  from public.loan_obligation_adjustments
  where loan_account_id = p_loan_account_id and group_id = p_group_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', oa.id,
    'target_type', oa.target_type,
    'loan_penalty_charge_id', oa.loan_penalty_charge_id,
    'loan_installment_id', oa.loan_installment_id,
    'installment_number', li.installment_number,
    'adjustment_type', oa.adjustment_type,
    'amount', oa.amount,
    'reason_code', oa.reason_code,
    'note', oa.note,
    'effective_date', oa.effective_date,
    'created_at', oa.created_at,
    'created_by', oa.created_by,
    'reverses_adjustment_id', oa.reverses_adjustment_id,
    'is_reversed', exists (select 1 from public.loan_obligation_adjustments r where r.reverses_adjustment_id = oa.id),
    'reversed_by_adjustment_id', (select r.id from public.loan_obligation_adjustments r where r.reverses_adjustment_id = oa.id)
  ) order by oa.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select *
    from public.loan_obligation_adjustments
    where loan_account_id = p_loan_account_id and group_id = p_group_id
    order by created_at desc
    limit greatest(p_limit, 0) offset greatest(p_offset, 0)
  ) oa
  left join public.loan_installments li
    on li.id = coalesce(oa.loan_installment_id, (
      select c.loan_installment_id from public.loan_penalty_charges c where c.id = oa.loan_penalty_charge_id
    ));

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'total_count', v_total_count,
    'limit', p_limit,
    'offset', p_offset,
    'items', v_items
  );
end;
$$;

revoke all on function public.rpc_list_loan_obligation_adjustments(uuid, uuid, integer, integer) from public;
grant execute on function public.rpc_list_loan_obligation_adjustments(uuid, uuid, integer, integer) to authenticated;
revoke execute on function public.rpc_list_loan_obligation_adjustments(uuid, uuid, integer, integer) from anon;

comment on function public.rpc_list_loan_obligation_adjustments(uuid, uuid, integer, integer) is
  'Prompt 09F-A: paginated, authoritative adjustment/waiver history for
  one loan, newest first. Surfaces reversal relationships explicitly so
  the UI never has to infer them.';
