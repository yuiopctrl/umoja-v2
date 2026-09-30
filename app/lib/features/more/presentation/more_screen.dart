import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/shell/shell_destination.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_breakpoints.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/title_case.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_language_selector.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/auth_controller_provider.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../../members/presentation/widgets/member_status_badge.dart';
import '../../membership_invitations/providers/my_membership_invitations_provider.dart';

/// `/more`: account information, current group, security, and
/// account-level actions (switch group) — moved off Home so the
/// primary operational screen isn't dominated by foundation/account
/// chrome. Never shows auth internals (UUID, JWT, a raw permission
/// count) — those belong to debugging/tests, not production UI.
///
/// Prompt 05E §14: only ONE exit action is exposed here — "Toka" — and
/// it is now always a real Supabase sign-out (there is no more local-
/// only "lock" concept to distinguish it from). The next entry is
/// always the phone + PIN login screen, never an automatic OTP.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContextAsync = ref.watch(appContextProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);
    // Prompt 09G-B1-F2 §L/§M: the SAME already-fetched personal inbox
    // result Home's own banner reads — never a second query.
    final pendingInvitationCount =
        ref
            .watch(myMembershipInvitationsProvider)
            .value
            ?.pendingActionableCount ??
        0;
    final profile = appContextAsync.value?.profile;
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final l10n = context.l10n;

    final eligibleMemberships = (appContextAsync.value?.memberships ?? const [])
        .where((m) => m.isEligibleOperational)
        .toList(growable: false);
    final canSwitchGroup = eligibleMemberships.length > 1;

    // Mobile's bottom bar only has room for Home/Members/Payments/More
    // (Material Design caps a bottom bar at 3-5 destinations) — every
    // other module stays one tap away here instead of disappearing.
    // Desktop/tablet's NavigationRail already shows every destination
    // directly, so this section would just duplicate it there.
    final width = MediaQuery.sizeOf(context).width;
    final overflowDestinations = UmojaBreakpoints.isMobile(width)
        ? mobileOverflowDestinations(
            shellDestinations(l10n, membership: membership),
          )
        : const <ShellDestination>[];
    // Prompt 09G-B2 §F2: an empty Member Management (no member.view/
    // member.invite/member.claim.approve) must not show as a container
    // with nothing in it — the entry point itself is gated on this,
    // not just its own contents.
    final memberManagement = memberManagementChildren(
      l10n,
      membership: membership,
    );

    return UmojaPage(
      title: l10n.moreTitle,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt 09G-B1-F2 §L: "My Invitations" — invitations
          // addressed TO the authenticated person, never gated on the
          // currently selected group's permissions (unlike every other
          // destination on this screen, which IS group-scoped).
          UmojaCard(
            key: const Key('moreMyInvitationsLink'),
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('moreMyInvitationsAction'),
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.myInvitationsTitle),
              trailing: pendingInvitationCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingInvitationCount',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.myInvitations),
            ),
          ),
          const SizedBox(height: UmojaSpacing.xxl),
          // Prompt 09G-B2: "My Profile" — self-service, reachable once
          // a group is selected, never gated on any permission (it is
          // inherently the caller's own data, matching route_guard's
          // treatment of `/me/profile`).
          if (membership != null) ...[
            UmojaCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const Key('moreMyProfileAction'),
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(l10n.myProfileAction),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.myProfile),
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
          ],
          // Prompt 09G-B1-F-UAT-FIX-03 §E/§H, 09G-B2 §F2: the mobile
          // entry point for Members/Invite Member/Sent Invitations/
          // Membership Requests — group-scoped, so only offered once a
          // group is actually selected AND the caller holds at least
          // one of the underlying permissions (an ordinary member with
          // none of them must not see an empty container). Desktop/
          // tablet shows the same children as an expandable sidebar
          // group instead (`app_shell.dart`) rather than this link.
          if (membership != null && memberManagement.isNotEmpty) ...[
            UmojaCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const Key('moreMemberManagementAction'),
                leading: const Icon(Icons.people_alt_outlined),
                title: Text(l10n.memberManagementTitle),
                subtitle: Text(l10n.memberManagementSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.memberManagement),
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
          ],
          if (overflowDestinations.isNotEmpty) ...[
            UmojaSection(
              title: l10n.modulesSectionTitle,
              child: UmojaCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, destination)
                        in overflowDestinations.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        key: Key('moreModuleLink_${destination.path}'),
                        leading: Icon(destination.icon),
                        title: Text(destination.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(destination.path),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
          ],
          UmojaSection(
            title: l10n.accountSectionTitle,
            child: UmojaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.displayName == null
                        ? 'Umoja'
                        : toTitleCase(profile!.displayName),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (profile?.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile!.phone!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: UmojaSpacing.xxl),
          if (membership != null)
            UmojaSection(
              title: l10n.currentGroupSectionTitle,
              child: UmojaCard(
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
                  ],
                ),
              ),
            ),
          const SizedBox(height: UmojaSpacing.xxl),
          UmojaSection(
            title: l10n.languageSelectorLabel,
            child: const UmojaLanguageSelector(),
          ),
          const SizedBox(height: UmojaSpacing.xxl),
          if (canSwitchGroup) ...[
            UmojaSection(
              title: l10n.actionsSectionTitle,
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(selectedGroupProvider.notifier)
                    .requireReselection(eligibleMemberships),
                icon: const Icon(Icons.swap_horiz),
                label: Text(l10n.switchGroupAction),
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
          ],
          UmojaSection(
            title: l10n.securitySectionTitle,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authControllerProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: Text(l10n.signOutButtonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
