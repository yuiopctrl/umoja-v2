-- Prompt 09D-UAT-BLOCKER-01: a migrated loan's OPENING penalty charge
-- (sequence_number 0, origin = 'OPENING') represents historical debt
-- already owed before Umoja — it must never consume a ONCE-frequency
-- installment's only assessable occurrence, nor shift ASSESSED
-- occurrence numbering. rpc_assess_loan_penalties's existing-count
-- query now counts only origin = 'ASSESSED' charges, so a migrated
-- overdue installment remains fully assessable under its policy
-- exactly like any other overdue installment (section 33) — the
-- OPENING charge is separate historical debt, tracked but never
-- counted as "Umoja's own first occurrence". Same signature — plain
-- create or replace, no drop needed.

create or replace function public.rpc_assess_loan_penalties(
  p_group_id uuid,
  p_assessment_date date default current_date,
  p_loan_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_loan record;
  v_installment record;
  v_existing_count integer;
  v_basis_amount numeric;
  v_threshold_date date;
  v_occurrence integer;
  v_occurrence_eligible_date date;
  v_raw_amount numeric;
  v_eligible_installment_count integer := 0;
  v_created_count integer := 0;
  v_skipped_count integer := 0;
  v_failed_count integer := 0;
  v_total_penalty_amount numeric := 0;
  v_details jsonb := '[]'::jsonb;
  v_installment_created boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_penalty.assess') then
    raise exception 'Not authorized to assess loan penalties in this group' using errcode = '42501';
  end if;

  if p_assessment_date is null then
    raise exception 'Assessment date is required' using errcode = '22023';
  end if;

  if p_loan_account_id is not null and not exists (
    select 1 from public.loan_accounts where id = p_loan_account_id and group_id = p_group_id
  ) then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  for v_loan in
    select * from public.loan_accounts
    where group_id = p_group_id
      and status = 'ACTIVE'
      and (p_loan_account_id is null or id = p_loan_account_id)
    order by id
    for update
  loop
    continue when not v_loan.penalty_enabled;

    for v_installment in
      select * from public.loan_installments
      where loan_account_id = v_loan.id
      order by installment_number
    loop
      select coalesce(sum(s.outstanding), 0)
      into v_basis_amount
      from public.loan_installment_component_states(v_installment.id) s
      where s.component_type in ('INTEREST', 'PRINCIPAL');

      continue when v_basis_amount <= 0;

      v_threshold_date := v_installment.due_date + v_loan.penalty_grace_days;

      continue when p_assessment_date <= v_threshold_date;

      v_eligible_installment_count := v_eligible_installment_count + 1;

      -- Prompt 09D-UAT-BLOCKER-01: only ASSESSED occurrences count
      -- toward ONCE/RECURRING_MONTHLY numbering. An OPENING charge
      -- (sequence_number 0) is historical debt, never "Umoja's own
      -- first occurrence".
      select count(*) into v_existing_count
      from public.loan_penalty_charges
      where loan_installment_id = v_installment.id and origin = 'ASSESSED';

      v_installment_created := false;

      loop
        exit when v_loan.penalty_frequency = 'ONCE' and v_existing_count >= 1;

        v_occurrence := v_existing_count + 1;
        v_occurrence_eligible_date := case v_loan.penalty_frequency
          when 'ONCE' then v_threshold_date
          else (v_threshold_date + make_interval(months => v_occurrence - 1))::date
        end;

        exit when p_assessment_date <= v_occurrence_eligible_date;

        v_raw_amount := case v_loan.penalty_type
          when 'FIXED' then v_loan.penalty_fixed_amount
          when 'PERCENTAGE' then round(v_basis_amount * v_loan.penalty_rate / 100, 2)
        end;

        exit when v_raw_amount is null or v_raw_amount <= 0;

        insert into public.loan_penalty_charges (
          group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
          origin, penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
          basis_amount, rate, fixed_amount, penalty_amount, created_by
        ) values (
          p_group_id, v_loan.id, v_installment.id, v_occurrence_eligible_date, v_occurrence,
          'ASSESSED', v_loan.penalty_type, v_loan.penalty_frequency, v_loan.penalty_basis, v_loan.penalty_grace_days,
          v_basis_amount,
          case when v_loan.penalty_type = 'PERCENTAGE' then v_loan.penalty_rate else null end,
          case when v_loan.penalty_type = 'FIXED' then v_loan.penalty_fixed_amount else null end,
          v_raw_amount, v_uid
        );

        v_existing_count := v_existing_count + 1;
        v_created_count := v_created_count + 1;
        v_total_penalty_amount := v_total_penalty_amount + v_raw_amount;
        v_installment_created := true;

        v_details := v_details || jsonb_build_object(
          'loan_account_id', v_loan.id,
          'loan_number', v_loan.loan_number,
          'loan_installment_id', v_installment.id,
          'installment_number', v_installment.installment_number,
          'sequence_number', v_occurrence,
          'assessment_date', v_occurrence_eligible_date,
          'penalty_amount', v_raw_amount
        );

        exit when v_loan.penalty_frequency = 'ONCE';
      end loop;

      if not v_installment_created then
        v_skipped_count := v_skipped_count + 1;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'group_id', p_group_id,
    'assessment_date', p_assessment_date,
    'loan_account_id', p_loan_account_id,
    'eligible_installment_count', v_eligible_installment_count,
    'assessed_count', v_created_count,
    'skipped_count', v_skipped_count,
    'failed_count', v_failed_count,
    'total_penalty_amount', v_total_penalty_amount,
    'details', v_details
  );
end;
$$;

comment on function public.rpc_assess_loan_penalties(uuid, date, uuid) is
  'Prompt 09D, extended 09D-UAT-BLOCKER-01: atomic, idempotent,
  server-authoritative loan penalty assessment as of an explicit
  p_assessment_date, optionally scoped to one loan account. Counts only
  origin = ASSESSED charges toward ONCE/RECURRING_MONTHLY numbering —
  an OPENING (migrated) penalty charge is separate historical debt and
  never blocks a fresh assessment on the same installment.';
