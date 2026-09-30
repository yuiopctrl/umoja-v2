import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/title_case.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/models/membership_context.dart';
import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../member_profile/providers/my_member_profile_provider.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../../members/presentation/widgets/member_status_badge.dart';
import '../../membership_invitations/providers/my_membership_invitations_provider.dart';

/// Permission codes that already gate one of [HomeScreen]'s own
/// operational shortcut cards below, plus `member.claim.approve` (the
/// officer claim-review permission, Prompt 09G-B1-D3 — reachable via
/// the Members list regardless of what Home shows, but included here
/// too so Home's own content stays consistent for that capability).
/// Holding none of these is exactly what distinguishes an ordinary
/// linked MEMBER (Member Home content) from an officer/admin
/// (existing operational dashboard) — Prompt 09G-B1-D4 §G/§H: a
/// capability check, never a role-name comparison, and reusing the
/// exact permissions the dashboard already keys off rather than
/// inventing a parallel signal.
const _operationalPermissions = [
  'member.view',
  'member.claim.approve',
  'contribution.view',
  'payment.view',
  'payment.create',
  'financial_account.view',
  'loan.view',
  'loan_product.view',
];

bool _hasOperationalCapability(MembershipContext membership) =>
    _operationalPermissions.any(membership.hasPermission);

/// `/home`: greeting, current group, and real operational shortcuts —
/// no fabricated financial data (see prompt 05 §40), and no exposed
/// foundation/RBAC internals (see `MoreScreen` for account details).
///
/// Doubles as Member Home (Prompt 09G-B1-D4): the SAME route and
/// screen for every resolved user — content branches on
/// [_hasOperationalCapability] rather than routing to a second
/// destination, so there is no new redirect target/loop surface and a
/// dual-role user (member + officer) keeps every existing shortcut
/// exactly as before (each already independently permission-gated).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedState = ref.watch(selectedGroupProvider);
    final appContextAsync = ref.watch(appContextProvider);
    // Prompt 09G-B1-F2 §K/§M: a lightweight, authoritative pending-
    // invitation indicator — reuses the SAME already-fetched personal
    // inbox result the count badge (More screen) also reads, never a
    // direct table query or a separate RPC call. `.value` is null
    // while loading/on error, which simply hides the banner rather
    // than showing a stale/incorrect count.
    final pendingInvitationCount =
        ref
            .watch(myMembershipInvitationsProvider)
            .value
            ?.pendingActionableCount ??
        0;
    // Prompt 09G-B2 §G: member_number isn't part of MembershipContext/
    // rpc_get_my_context (that RPC is out of this phase's scope) — the
    // already-built My Profile RPC is the authoritative source for it.
    // `.value` is null while loading/on error, which simply omits the
    // line rather than showing a stale/fabricated number.
    final memberNumber = ref.watch(myMemberProfileProvider).value?.memberNumber;
    final l10n = context.l10n;

    final membership = selectedState is SelectedGroupResolved
        ? selectedState.membership
        : null;

    if (membership == null) {
      // The router only sends here once a group is resolved; render a
      // safe fallback instead of crashing if reached transiently.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileName = appContextAsync.value?.profile?.displayName;
    final firstName = profileName?.split(' ').first;
    final hasOperationalCapability = _hasOperationalCapability(membership);

    return UmojaPage(
      title: hasOperationalCapability ? l10n.homeTitle : l10n.memberHomeTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName == null
                ? l10n.homeGreetingPlain
                : l10n.homeGreetingNamed(toTitleCase(firstName)),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (pendingInvitationCount > 0) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('homePendingInvitationBanner'),
              child: Row(
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: UmojaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pendingInvitationBannerTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          l10n.pendingInvitationBannerMessage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.myInvitations),
                    child: Text(l10n.viewInvitationsAction),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: UmojaSpacing.xxl),
          UmojaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        membership.group.groupName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    UmojaStatusBadge(
                      label: memberStatusLabel(
                        l10n,
                        membership.membershipStatus,
                      ),
                      semantic: memberStatusSemantic(
                        membership.membershipStatus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  membership.roleCodes.isEmpty
                      ? l10n.rolesNone
                      : l10n.rolesList(
                          membership.roleCodes
                              .map((code) => memberRoleLabel(l10n, code))
                              .join(', '),
                        ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (memberNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.myProfileMemberNumberLabel}: $memberNumber',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          UmojaCard(
            key: const Key('homeMyProfileShortcut'),
            padding: EdgeInsets.zero,
            child: UmojaListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: l10n.homeMyProfileLinkTitle,
              subtitle: Text(l10n.homeMyProfileLinkSubtitle),
              onTap: () => context.push(AppRoutes.myProfile),
            ),
          ),
          const SizedBox(height: UmojaSpacing.xxl),
          if (membership.hasPermission('member.view'))
            UmojaCard(
              key: const Key('homeMembersShortcut'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.people_outline),
                title: l10n.membersTitle,
                subtitle: Text(l10n.homeMembersShortcutSubtitle),
                // Prompt 09G-B1-F-UAT-FIX-01: Members is a primaryOnMobile
                // shell tab (shell_destination.dart), reached from the
                // bottom nav via context.go — never context.push. Pushing
                // it left it poppable, which made UmojaPage's
                // isShellRoot false and hid its inline header (and every
                // officer action inside it — Invite Member/Invitations/
                // Membership Requests) on mobile whenever a user reached
                // Members from this Home shortcut instead of the bottom
                // tab, the exact physical-UAT defect this fixes.
                onTap: () => context.go(AppRoutes.membersList),
              ),
            ),
          if (membership.hasPermission('contribution.view')) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('homeContributionsShortcut'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: l10n.contributionsTitle,
                subtitle: Text(l10n.homeContributionsShortcutSubtitle),
                onTap: () => context.push(AppRoutes.contributionsHome),
              ),
            ),
          ],
          if (membership.hasPermission('payment.view') ||
              membership.hasPermission('payment.create')) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('homePaymentsShortcut'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.add_card_outlined),
                title: l10n.paymentsTitle,
                subtitle: Text(l10n.homePaymentsShortcutSubtitle),
                onTap: () => context.push(AppRoutes.paymentsList),
              ),
            ),
          ],
          if (membership.hasPermission('financial_account.view')) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('homeFinanceShortcut'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: l10n.financeTitle,
                subtitle: Text(l10n.homeFinancialAccountsShortcutSubtitle),
                onTap: () => context.push(AppRoutes.financeHome),
              ),
            ),
          ],
          if (membership.hasPermission('loan.view') ||
              membership.hasPermission('loan_product.view')) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('homeLoansShortcut'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.request_quote_outlined),
                title: l10n.loansTitle,
                subtitle: Text(l10n.homeLoansShortcutSubtitle),
                onTap: () => context.push(AppRoutes.loansHome),
              ),
            ),
          ],
          // Prompt 09G-B1-D4 §F/§J: an ordinary linked member's own
          // Quick Access — only a real, already-implemented feature
          // (their own claim history, secondary/informational once
          // linked). Deliberately never shown alongside the
          // officer/admin shortcuts above, and never a placeholder for
          // My Contributions/My Loans/My Statement (not built yet).
          if (!hasOperationalCapability) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('memberHomeClaimHistoryShortcut'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.history_outlined),
                title: l10n.membershipClaimHistoryQuickAccessTitle,
                subtitle: Text(l10n.membershipClaimHistoryQuickAccessSubtitle),
                onTap: () => context.push(AppRoutes.membershipClaims),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
