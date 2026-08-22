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
import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../../members/presentation/widgets/member_status_badge.dart';

/// `/home`: greeting, current group, and real operational shortcuts —
/// no fabricated financial data (see prompt 05 §40), and no exposed
/// foundation/RBAC internals (see `MoreScreen` for account details).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedState = ref.watch(selectedGroupProvider);
    final appContextAsync = ref.watch(appContextProvider);
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

    return UmojaPage(
      title: l10n.homeTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName == null
                ? l10n.homeGreetingPlain
                : l10n.homeGreetingNamed(toTitleCase(firstName)),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
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
              ],
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
                onTap: () => context.push(AppRoutes.membersList),
              ),
            ),
        ],
      ),
    );
  }
}
