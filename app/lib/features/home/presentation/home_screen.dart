import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/title_case.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/models/membership_context.dart';
import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../member_profile/providers/my_member_profile_provider.dart';
import '../../member_statement/presentation/widgets/statement_last_payment_card.dart';
import '../../member_statement/presentation/widgets/statement_position_cards.dart';
import '../../member_statement/providers/home_financial_summary_provider.dart';
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
      // Prompt 09G-B3-UX-01-FIX-01 §A: on mobile, Home's own greeting
      // ("Hi, Frederick") is the page's real opening content — the
      // inline "Home"/"Member Home" title above it was a redundant
      // second heading (the shell's bottom nav already shows "Home"
      // as the active tab). Tablet/desktop keep the title unchanged —
      // it remains their only heading there, and the sidebar's own
      // selected-tab highlight doesn't duplicate it the way the mobile
      // bottom nav label does.
      showTitleOnMobile: false,
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
          // Prompt 09G-B3-UX-01 §C1: one compact identity block —
          // group name + status on the first row, role(s) and member
          // number combined onto a SECOND (not third) line, rather
          // than three stacked rows for what is really one identity
          // fact.
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        membership.roleCodes.isEmpty
                            ? l10n.rolesNone
                            : l10n.rolesList(
                                membership.roleCodes
                                    .map((code) => memberRoleLabel(l10n, code))
                                    .join(', '),
                              ),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (memberNumber != null) ...[
                      Text(
                        '  •  ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Flexible(
                        child: Text(
                          memberNumber,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          // Prompt 09G-B3-C/B3-D §F/§G/§N: self-scoped, gated on
          // financial_report.self_view (never loan.view/payment.view/
          // contribution.view/an officer permission, and never a role
          // name) — a member feature, discoverable from Home exactly
          // like My Profile, never buried inside officer-only Member
          // Management. A dual-role officer sees exactly this same
          // section (their OWN position), never a group-wide total.
          if (membership.hasPermission('financial_report.self_view')) ...[
            const _HomeFinancialSummarySection(),
            const SizedBox(height: UmojaSpacing.xxl),
          ],
          _HomeQuickActions(
            membership: membership,
            hasOperationalCapability: hasOperationalCapability,
          ),
        ],
      ),
    );
  }
}

/// Prompt 09G-B3-UX-01 §D: splits Home's navigation into two tiers —
/// personal shortcuts (My Profile; Claim History for an ordinary
/// member with no operational capability) as a compact grid, and, only
/// when [membership] actually has at least one operational permission,
/// a separate "Manage Group" list for the group-management modules
/// (Members/Contributions/Payments/Finance/Loans). Visibility is
/// derived entirely from the EXISTING permission checks (same
/// predicates `_HomeShortcutsCard` used before this redesign) — never
/// a role name — so an ordinary member never sees an officer action,
/// and a dual-role officer keeps both tiers exactly as before.
class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.membership,
    required this.hasOperationalCapability,
  });

  final MembershipContext membership;
  final bool hasOperationalCapability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final quickActions = <_ActionItem>[
      _ActionItem(
        key: const Key('homeMyProfileShortcut'),
        icon: Icons.account_circle_outlined,
        label: l10n.homeMyProfileLinkTitle,
        onTap: () => context.push(AppRoutes.myProfile),
      ),
      // Prompt 09G-B4-C §T: the member's own contributions — a member
      // self-service entry, never placed under officer-only Manage Group.
      // Gated on the effective contribution.self_view permission only.
      if (membership.hasPermission('contribution.self_view'))
        _ActionItem(
          key: const Key('homeMyContributionsShortcut'),
          icon: Icons.request_page_outlined,
          label: l10n.myContributionsTitle,
          subtitle: l10n.myContributionsShortcutSubtitle,
          onTap: () => context.push(AppRoutes.myContributions),
        ),
      // Prompt 09G-B5-C.2 §H: the member's own loans, gated on the
      // effective loan.self_view permission — never member.view, never
      // a role name. More remains the complete self-service hub; this
      // is a complementary shortcut, not the only way to reach it.
      if (membership.hasPermission('loan.self_view'))
        _ActionItem(
          key: const Key('homeMyLoansShortcut'),
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.myLoansNavAction,
          onTap: () => context.push(AppRoutes.myLoans),
        ),
      // Prompt 09G-B1-D4 §F/§J: an ordinary linked member's own Quick
      // Access — only a real, already-implemented feature (their own
      // claim history, secondary/informational once linked).
      // Deliberately never shown alongside the officer/admin modules
      // below, and never a placeholder for My Contributions/My
      // Loans/My Statement (not built yet).
      if (!hasOperationalCapability)
        _ActionItem(
          key: const Key('memberHomeClaimHistoryShortcut'),
          icon: Icons.history_outlined,
          label: l10n.membershipClaimHistoryQuickAccessTitle,
          onTap: () => context.push(AppRoutes.membershipClaims),
        ),
    ];

    final manageGroupItems = <_ActionItem>[
      if (membership.hasPermission('member.view'))
        _ActionItem(
          key: const Key('homeMembersShortcut'),
          icon: Icons.people_outline,
          label: l10n.membersTitle,
          subtitle: l10n.homeMembersShortcutSubtitle,
          // Prompt 09G-B1-F-UAT-FIX-01: Members is a primaryOnMobile
          // shell tab (shell_destination.dart), reached from the
          // bottom nav via context.go — never context.push. Pushing
          // it left it poppable, which made UmojaPage's isShellRoot
          // false and hid its inline header (and every officer action
          // inside it — Invite Member/Invitations/Membership
          // Requests) on mobile whenever a user reached Members from
          // this Home shortcut instead of the bottom tab, the exact
          // physical-UAT defect this fixes.
          onTap: () => context.go(AppRoutes.membersList),
        ),
      if (membership.hasPermission('contribution.view'))
        _ActionItem(
          key: const Key('homeContributionsShortcut'),
          icon: Icons.volunteer_activism_outlined,
          label: l10n.contributionsTitle,
          subtitle: l10n.homeContributionsShortcutSubtitle,
          onTap: () => context.push(AppRoutes.contributionsHome),
        ),
      if (membership.hasPermission('payment.view') ||
          membership.hasPermission('payment.create'))
        _ActionItem(
          key: const Key('homePaymentsShortcut'),
          icon: Icons.add_card_outlined,
          label: l10n.paymentsTitle,
          subtitle: l10n.homePaymentsShortcutSubtitle,
          onTap: () => context.push(AppRoutes.paymentsList),
        ),
      if (membership.hasPermission('financial_account.view'))
        _ActionItem(
          key: const Key('homeFinanceShortcut'),
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.financeTitle,
          subtitle: l10n.homeFinancialAccountsShortcutSubtitle,
          onTap: () => context.push(AppRoutes.financeHome),
        ),
      if (membership.hasPermission('loan.view') ||
          membership.hasPermission('loan_product.view'))
        _ActionItem(
          key: const Key('homeLoansShortcut'),
          icon: Icons.request_quote_outlined,
          label: l10n.loansTitle,
          subtitle: l10n.homeLoansShortcutSubtitle,
          onTap: () => context.push(AppRoutes.loansHome),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeQuickActionsSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.md),
        _QuickActionsGrid(items: quickActions),
        // No empty heading: "Manage Group" only renders when at least
        // one operational module is actually visible to this member.
        if (manageGroupItems.isNotEmpty) ...[
          const SizedBox(height: UmojaSpacing.xxl),
          Text(
            l10n.homeManageGroupSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: UmojaSpacing.md),
          _ActionList(items: manageGroupItems),
        ],
      ],
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final Key key;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

/// A compact 2-column grid of tappable tiles — no individual outlined
/// card per item (Prompt 09G-B3-UX-01 §D/§J: "avoid a separate border
/// around every tiny element"), just a soft tonal surface. A single
/// item spans the full width rather than sitting awkwardly in a half
/// row.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.items});

  final List<_ActionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return _QuickActionTile(item: items.first);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: UmojaSpacing.md,
      crossAxisSpacing: UmojaSpacing.md,
      childAspectRatio: 2.4,
      children: [for (final item in items) _QuickActionTile(item: item)],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.item});

  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: item.key,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(UmojaSpacing.md),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(UmojaSpacing.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UmojaSpacing.lg,
            vertical: UmojaSpacing.md,
          ),
          child: Row(
            children: [
              Icon(item.icon, color: scheme.primary),
              const SizedBox(width: UmojaSpacing.md),
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Manage Group" tier — one bordered list (rows separated by thin
/// dividers) rather than each module getting its own full-width card.
class _ActionList extends StatelessWidget {
  const _ActionList({required this.items});

  final List<_ActionItem> items;

  @override
  Widget build(BuildContext context) {
    return UmojaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            UmojaListTile(
              key: items[i].key,
              leading: Icon(items[i].icon),
              title: items[i].label,
              subtitle: items[i].subtitle == null
                  ? null
                  : Text(items[i].subtitle!),
              onTap: items[i].onTap,
            ),
            if (i != items.length - 1)
              const Divider(height: 1, indent: UmojaSpacing.lg),
          ],
        ],
      ),
    );
  }
}

/// Prompt 09G-B3-D/09G-B3-UX-01: Home's financial summary — reads
/// [homeFinancialSummaryProvider] (NEVER
/// `myMemberStatementProvider`/`memberStatementQueryProvider`; see that
/// provider's own doc comment) and renders only the exact canonical
/// values `rpc_get_my_member_statement` returns, as ONE full-width
/// surface: the three independent current positions
/// ([StatementPositionMetrics] — the SAME component the Financial
/// Statement screen uses, never a second implementation), a divider,
/// then `summary.last_payment` ([StatementLastPaymentSection]). No
/// activity timeline, no opening/closing period positions (Home has
/// no date filter), and no synthetic cross-domain total — this is a
/// summary layer over the same backend derivation, never a parallel
/// accounting engine. "My Financial Position" is the only heading
/// here — no redundant "Current Position" sub-heading underneath it.
class _HomeFinancialSummarySection extends ConsumerWidget {
  const _HomeFinancialSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summaryAsync = ref.watch(homeFinancialSummaryProvider);

    return Column(
      key: const Key('homeFinancialSummarySection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeMyFinancialPositionSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.md),
        summaryAsync.when(
          loading: () =>
              const SizedBox(height: 180, child: UmojaLoadingState(rows: 3)),
          error: (error, stackTrace) => UmojaErrorState(
            message: l10n.homeFinancialSummaryLoadFailedMessage,
            retryLabel: l10n.retryButton,
            onRetry: () => ref.invalidate(homeFinancialSummaryProvider),
          ),
          data: (statement) => UmojaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatementPositionMetrics(
                  contributionsOutstanding:
                      statement.summary.contributionsCurrentOutstanding,
                  loansOutstanding: statement.summary.loansCurrentOutstanding,
                  walletBalance: statement.summary.walletCurrentBalance,
                ),
                const SizedBox(height: UmojaSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: UmojaSpacing.lg),
                StatementLastPaymentSection(
                  lastPayment: statement.summary.lastPayment,
                ),
                const SizedBox(height: UmojaSpacing.lg),
                UmojaSecondaryButton(
                  key: const Key('homeViewFinancialStatementAction'),
                  label: l10n.homeViewFinancialStatementAction,
                  onPressed: () => context.push(AppRoutes.myStatement),
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
