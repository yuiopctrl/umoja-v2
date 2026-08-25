-- Contribution Engine RLS policies and read grants.
--
-- Every table here got RLS enabled + all client grants revoked in
-- 20260823120000_create_contribution_engine_schema.sql (default deny).
-- This migration adds SELECT-only grants plus policies. There is no
-- direct client INSERT/UPDATE/DELETE grant on any of these tables —
-- all mutation goes through SECURITY DEFINER RPCs (added in later
-- migrations), matching the group_memberships/member_number precedent.
-- No policy here uses USING (true).

-- ---------------------------------------------------------------------
-- contribution_types
-- ---------------------------------------------------------------------

grant select on public.contribution_types to authenticated;

create policy contribution_types_select
  on public.contribution_types
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'contribution.view'));

-- ---------------------------------------------------------------------
-- contribution_setups
-- ---------------------------------------------------------------------

grant select on public.contribution_setups to authenticated;

create policy contribution_setups_select
  on public.contribution_setups
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'contribution.view'));

-- ---------------------------------------------------------------------
-- contribution_periods
-- ---------------------------------------------------------------------

grant select on public.contribution_periods to authenticated;

create policy contribution_periods_select
  on public.contribution_periods
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'contribution.view'));

-- ---------------------------------------------------------------------
-- contribution_period_member_amounts
-- ---------------------------------------------------------------------

grant select on public.contribution_period_member_amounts to authenticated;

create policy contribution_period_member_amounts_select
  on public.contribution_period_member_amounts
  for select
  to authenticated
  using (
    public.has_group_permission(group_id, 'contribution.view')
    or public.has_group_permission(group_id, 'contribution.member_amount.manage')
  );

-- ---------------------------------------------------------------------
-- contribution_period_member_exclusions
-- ---------------------------------------------------------------------

grant select on public.contribution_period_member_exclusions to authenticated;

create policy contribution_period_member_exclusions_select
  on public.contribution_period_member_exclusions
  for select
  to authenticated
  using (
    public.has_group_permission(group_id, 'contribution.view')
    or public.has_group_permission(group_id, 'contribution.member_exclude')
  );

-- ---------------------------------------------------------------------
-- member_contribution_charges
-- ---------------------------------------------------------------------

grant select on public.member_contribution_charges to authenticated;

create policy member_contribution_charges_select
  on public.member_contribution_charges
  for select
  to authenticated
  using (
    public.has_group_permission(group_id, 'contribution.view')
    or (
      public.has_group_permission(group_id, 'contribution.self_view')
      and exists (
        select 1
        from public.group_memberships gm
        where gm.id = member_contribution_charges.membership_id
          and gm.user_id = auth.uid()
      )
    )
  );

-- ---------------------------------------------------------------------
-- contribution_charge_components
-- ---------------------------------------------------------------------

grant select on public.contribution_charge_components to authenticated;

create policy contribution_charge_components_select
  on public.contribution_charge_components
  for select
  to authenticated
  using (
    public.has_group_permission(group_id, 'contribution.view')
    or (
      public.has_group_permission(group_id, 'contribution.self_view')
      and exists (
        select 1
        from public.member_contribution_charges c
        join public.group_memberships gm on gm.id = c.membership_id
        where c.id = contribution_charge_components.charge_id
          and gm.user_id = auth.uid()
      )
    )
  );
