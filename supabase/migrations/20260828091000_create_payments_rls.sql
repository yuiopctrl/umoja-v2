-- Prompt 07: RLS for payments/allocations/wallet — SELECT-only for the
-- matching view permission, exactly matching the 08A convention. No
-- INSERT/UPDATE/DELETE grant to any client role: every mutation goes
-- through a SECURITY DEFINER RPC.

create policy payments_select on public.payments
for select
to authenticated
using (public.has_group_permission(group_id, 'payment.view'));

create policy payment_allocations_select on public.payment_allocations
for select
to authenticated
using (public.has_group_permission(group_id, 'payment.view'));

create policy member_wallet_entries_select on public.member_wallet_entries
for select
to authenticated
using (public.has_group_permission(group_id, 'wallet.view'));

grant select on public.payments to authenticated;
grant select on public.payment_allocations to authenticated;
grant select on public.member_wallet_entries to authenticated;
