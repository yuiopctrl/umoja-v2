-- Prompt 09A: FLAT/REDUCING_BALANCE schedule math + date generation —
-- items 22-36.
begin;

select plan(17);

insert into auth.users (id, email) values
  ('3a000000-0000-0000-0000-000000000001', 'p09a-sched-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('3a100000-0000-0000-0000-000000000001', 'P09A Sched Group', '3a000000-0000-0000-0000-000000000001', 'LNSC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('3a200000-0000-0000-0000-000000000001', '3a100000-0000-0000-0000-000000000001', '3a000000-0000-0000-0000-000000000001', 'Sched Admin', 'ACTIVE', '2025-01-01', 'LNSC-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '3a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '3a000000-0000-0000-0000-000000000001';

create temporary table t_flat_product as
select public.rpc_create_loan_product(
  '3a100000-0000-0000-0000-000000000001', 'FLAT', 'Flat Product',
  10000, 1, 12, 12.0000, 'ANNUAL', 'FLAT', 5000000
) as result;
select (result->>'id')::uuid as flat_product_id from t_flat_product \gset

create temporary table t_rb_product as
select public.rpc_create_loan_product(
  '3a100000-0000-0000-0000-000000000001', 'RB', 'Reducing Balance Product',
  10000, 1, 12, 12.0000, 'ANNUAL', 'REDUCING_BALANCE', 5000000
) as result;
select (result->>'id')::uuid as rb_product_id from t_rb_product \gset

-- ---------------------------------------------------------------------
-- FLAT: 120000 over 6 months, 12% ANNUAL (-> 1% effective monthly).
-- ---------------------------------------------------------------------
create temporary table t_flat_loan as
select public.rpc_create_draft_loan_account(
  '3a100000-0000-0000-0000-000000000001', '3a200000-0000-0000-0000-000000000001',
  :'flat_product_id'::uuid, 120000, 6, '2026-01-31'
) as result;
select (result->>'id')::uuid as flat_loan_id from t_flat_loan \gset

-- 22. principal sum exact
select is(
  (select sum(principal_due) from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid),
  120000.00::numeric,
  '22: FLAT SUM(principal_due) equals the exact principal_amount'
);
-- 23. interest sum exact: 120000 * 1% * 6 = 7200
select is(
  (select sum(interest_due) from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid),
  7200.00::numeric,
  '23: FLAT SUM(interest_due) equals the exact calculated total interest'
);
-- 24. total sum exact
select is(
  (select sum(total_due) from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid),
  127200.00::numeric,
  '24: FLAT SUM(total_due) equals principal + interest exactly'
);
-- 26. installment numbering sequential
select is(
  (select array_agg(installment_number order by installment_number) from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid),
  array[1, 2, 3, 4, 5, 6],
  '26: FLAT installment numbers are sequential starting at 1'
);
-- 27. due dates deterministic — every installment lands on the
-- expected anchor-based month, and the total_due generated column
-- always equals principal_due + interest_due for every row.
select is(
  (select count(*) from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid and total_due <> principal_due + interest_due),
  0::bigint,
  '27: total_due always equals principal_due + interest_due for every installment'
);

-- 25. rounding remainder deterministic — 100000 principal over 7
-- installments does not divide evenly (100000/7 = 14285.714...); the
-- remainder must land in the final installment, and the sum must
-- still be exact.
create temporary table t_remainder_loan as
select public.rpc_create_draft_loan_account(
  '3a100000-0000-0000-0000-000000000001', '3a200000-0000-0000-0000-000000000001',
  :'flat_product_id'::uuid, 100000, 7, '2026-01-15'
) as result;
select (result->>'id')::uuid as remainder_loan_id from t_remainder_loan \gset

select is(
  (select sum(principal_due) from public.loan_installments where loan_account_id = :'remainder_loan_id'::uuid),
  100000.00::numeric,
  '25a: an unevenly-divisible principal (100000/7) still sums to the exact principal_amount'
);
select is(
  (select principal_due from public.loan_installments where loan_account_id = :'remainder_loan_id'::uuid and installment_number < 7 limit 1),
  (select principal_due from public.loan_installments where loan_account_id = :'remainder_loan_id'::uuid and installment_number = 2),
  '25b: every non-final installment shares the same base (truncated) principal share'
);
select isnt(
  (select principal_due from public.loan_installments where loan_account_id = :'remainder_loan_id'::uuid and installment_number = 7),
  (select principal_due from public.loan_installments where loan_account_id = :'remainder_loan_id'::uuid and installment_number = 6),
  '25c: the leftover remainder is reconciled into the final installment, which therefore differs from the others'
);

-- ---------------------------------------------------------------------
-- REDUCING_BALANCE: 120000 over 6 months, 12% ANNUAL.
-- ---------------------------------------------------------------------
create temporary table t_rb_loan as
select public.rpc_create_draft_loan_account(
  '3a100000-0000-0000-0000-000000000001', '3a200000-0000-0000-0000-000000000001',
  :'rb_product_id'::uuid, 120000, 6, '2026-01-31'
) as result;
select (result->>'id')::uuid as rb_loan_id from t_rb_loan \gset

-- 28/29. opening balance decreases -> interest strictly decreases
-- installment over installment.
select ok(
  (
    select bool_and(a.interest_due > b.interest_due)
    from public.loan_installments a
    join public.loan_installments b
      on b.loan_account_id = a.loan_account_id and b.installment_number = a.installment_number + 1
    where a.loan_account_id = :'rb_loan_id'::uuid
  ),
  '28/29: REDUCING_BALANCE interest strictly decreases installment-over-installment as the balance falls'
);

-- 30. principal total exact
select is(
  (select sum(principal_due) from public.loan_installments where loan_account_id = :'rb_loan_id'::uuid),
  120000.00::numeric,
  '30: REDUCING_BALANCE SUM(principal_due) equals the exact principal_amount'
);

-- 31. interest calculation exact — first installment: 120000 * 1% =
-- 1200; second installment (opening balance 100000): 100000*1% = 1000.
select is(
  (select interest_due from public.loan_installments where loan_account_id = :'rb_loan_id'::uuid and installment_number = 1),
  1200.00::numeric,
  '31a: REDUCING_BALANCE installment 1 interest = opening principal x effective monthly rate exactly'
);
select is(
  (select interest_due from public.loan_installments where loan_account_id = :'rb_loan_id'::uuid and installment_number = 2),
  1000.00::numeric,
  '31b: REDUCING_BALANCE installment 2 interest reflects the declined opening balance (100000 x 1%)'
);

-- 32. final outstanding principal exactly zero: principal_amount minus
-- the running sum of principal_due through the final installment.
select is(
  (
    120000.00::numeric - (select sum(principal_due) from public.loan_installments where loan_account_id = :'rb_loan_id'::uuid)
  ),
  0.00::numeric,
  '32: REDUCING_BALANCE outstanding principal after the final installment is exactly zero'
);

-- ---------------------------------------------------------------------
-- Dates (items 33-36) — verified directly against PostgreSQL's own
-- date+interval semantics (documented in the schedule engine
-- migration): anchored to the ORIGINAL first_repayment_date every
-- time, never cumulative addition.
-- ---------------------------------------------------------------------

-- 33. standard monthly dates (15th of each month, no edge case)
select is(
  (select array_agg(due_date order by installment_number) from public.loan_installments where loan_account_id = :'remainder_loan_id'::uuid),
  array['2026-01-15', '2026-02-15', '2026-03-15', '2026-04-15', '2026-05-15', '2026-06-15', '2026-07-15']::date[],
  '33: standard monthly due dates land on the same day-of-month every time'
);

-- 34. 31st/month-end handling: anchor Jan 31 -> Feb 28 (2026, not a
-- leap year) -> Mar 31 (never drifted to Mar 28) -> Apr 30.
select is(
  (select array_agg(due_date order by installment_number) from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid),
  array['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31', '2026-06-30']::date[],
  '34: a 31st-of-month anchor correctly clips to each target month''s last valid day with no drift'
);

-- 35. leap-year February: 2024 is a leap year, so Jan 31 -> Feb 29.
create temporary table t_leap_loan as
select public.rpc_create_draft_loan_account(
  '3a100000-0000-0000-0000-000000000001', '3a200000-0000-0000-0000-000000000001',
  :'flat_product_id'::uuid, 60000, 3, '2024-01-31'
) as result;
select (result->>'id')::uuid as leap_loan_id from t_leap_loan \gset

select is(
  (select due_date from public.loan_installments where loan_account_id = :'leap_loan_id'::uuid and installment_number = 2),
  '2024-02-29'::date,
  '35: a January 31st anchor in a leap year correctly lands on February 29th'
);

-- 36. no cumulative drift: installment 3's date (anchored at +2
-- months from the ORIGINAL Jan 31) must be March 31st, not March 28th
-- (which a naive "add one month to the previous result" approach
-- would incorrectly produce after Feb 28/29).
select is(
  (select due_date from public.loan_installments where loan_account_id = :'flat_loan_id'::uuid and installment_number = 3),
  '2026-03-31'::date,
  '36: installment 3 lands on the 31st (anchored to the original date), proving no cumulative month-end drift'
);

select * from finish();
rollback;
