-- Prompt 09D: server-authoritative loan penalty assessment (section
-- 24-26) and penalty history read model (section 32).
--
-- Eligibility (section 9-10): a loan installment qualifies only when
-- its loan is ACTIVE, its current principal+interest outstanding
-- (basis_amount, NEVER including existing penalty — no
-- penalty-on-penalty, section 12) is positive, and p_assessment_date
-- is strictly after due_date + grace_days. "First day after grace" is
-- therefore due_date + grace_days + 1 (item 15); due_date + grace_days
-- itself is still inside grace and excluded (item 14).
--
-- Occurrence model (section 14, month-safe, no fixed-30-day drift):
-- occurrence N's eligible date is (due_date + grace_days) advanced by
-- (N-1) CALENDAR months via `+ make_interval(months => N-1)`, anchored
-- to the SAME threshold date every time (never cumulative from the
-- previous occurrence) — the exact anchoring discipline already
-- locked for loan schedule due-date generation (section: "anchor to
-- the loan's own first_repayment_date... never cumulatively added").
-- ONCE only ever computes occurrence 1's date.
--
-- Concurrency/idempotency (section 29-30): `for update` on the
-- selected loan_accounts rows serializes any two concurrent assessment
-- runs against the SAME loan; the loan_penalty_charges unique
-- (loan_installment_id, sequence_number) index is the hard structural
-- backstop regardless. Re-running with the same p_assessment_date
-- creates zero additional charges; advancing the date only creates the
-- newly-due occurrences — mirrors 06B's
-- rpc_assess_contribution_penalties precedent exactly.

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
    -- Penalty-disabled loans (or products) never qualify at all —
    -- section 40 item 1 / section 9 (only ACTIVE + enabled).
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

      -- Fully settled contractual obligation: never penalized, and
      -- this is exactly what stops further RECURRING_MONTHLY
      -- occurrences once an installment is paid off (item 27).
      continue when v_basis_amount <= 0;

      v_threshold_date := v_installment.due_date + v_loan.penalty_grace_days;

      -- Not yet due, or still inside grace (items 13/14) — also
      -- structurally excludes any future UPCOMING installment, since
      -- its due_date (and therefore threshold_date) is necessarily
      -- after p_assessment_date.
      continue when p_assessment_date <= v_threshold_date;

      v_eligible_installment_count := v_eligible_installment_count + 1;

      select count(*) into v_existing_count
      from public.loan_penalty_charges
      where loan_installment_id = v_installment.id;

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
          penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
          basis_amount, rate, fixed_amount, penalty_amount, created_by
        ) values (
          p_group_id, v_loan.id, v_installment.id, v_occurrence_eligible_date, v_occurrence,
          v_loan.penalty_type, v_loan.penalty_frequency, v_loan.penalty_basis, v_loan.penalty_grace_days,
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

revoke all on function public.rpc_assess_loan_penalties(uuid, date, uuid) from public;
grant execute on function public.rpc_assess_loan_penalties(uuid, date, uuid) to authenticated;
revoke execute on function public.rpc_assess_loan_penalties(uuid, date, uuid) from anon;

comment on function public.rpc_assess_loan_penalties(uuid, date, uuid) is
  'Prompt 09D: atomic, idempotent, server-authoritative loan penalty
  assessment as of an explicit p_assessment_date (never bare
  current_timestamp), optionally scoped to one loan account. Creates
  ONLY missing/newly-due occurrences; Flutter never computes or posts a
  penalty amount directly.';

-- ---------------------------------------------------------------------
-- rpc_list_loan_penalty_charges — authoritative penalty history for one
-- loan (optionally one installment), section 32. paid_amount/
-- outstanding_amount are always derived (loan_penalty_charge_states),
-- never a stored counter.
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_loan_penalty_charges(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_loan_installment_id uuid default null
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
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_penalty.view') then
    raise exception 'Not authorized to view loan penalties in this group' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.loan_accounts where id = p_loan_account_id and group_id = p_group_id
  ) then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'loan_account_id', c.loan_account_id,
    'loan_installment_id', c.loan_installment_id,
    'installment_number', li.installment_number,
    'assessment_date', c.assessment_date,
    'sequence_number', c.sequence_number,
    'penalty_type', c.penalty_type,
    'penalty_frequency', c.penalty_frequency,
    'basis_amount', c.basis_amount,
    'rate', c.rate,
    'fixed_amount', c.fixed_amount,
    'penalty_amount', c.penalty_amount,
    'paid_amount', s.allocated,
    'outstanding_amount', s.outstanding,
    'created_at', c.created_at
  ) order by c.assessment_date, c.sequence_number), '[]'::jsonb)
  into v_items
  from public.loan_penalty_charges c
  join public.loan_installments li on li.id = c.loan_installment_id
  cross join lateral (
    select * from public.loan_penalty_charge_states(c.loan_installment_id) s2
    where s2.charge_id = c.id
  ) s
  where c.loan_account_id = p_loan_account_id
    and c.group_id = p_group_id
    and (p_loan_installment_id is null or c.loan_installment_id = p_loan_installment_id);

  return jsonb_build_object('loan_account_id', p_loan_account_id, 'items', v_items);
end;
$$;

revoke all on function public.rpc_list_loan_penalty_charges(uuid, uuid, uuid) from public;
grant execute on function public.rpc_list_loan_penalty_charges(uuid, uuid, uuid) to authenticated;
revoke execute on function public.rpc_list_loan_penalty_charges(uuid, uuid, uuid) from anon;
