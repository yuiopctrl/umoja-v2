import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_spacing.dart';
import '../../core/utils/title_case.dart';
import '../../core/widgets/umoja_card.dart';
import '../../core/widgets/umoja_language_selector.dart';
import '../../core/widgets/umoja_section.dart';
import '../../core/widgets/umoja_status_badge.dart';
import '../../features/auth/providers/app_context_provider.dart';
import '../../features/auth/providers/auth_controller_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../../features/members/presentation/widgets/member_role_label.dart';
import '../../features/members/presentation/widgets/member_status_badge.dart';
import 'member_avatar_button.dart';

/// The persistent shell-level top bar shown above the navigation
/// chrome (bottom bar on mobile, [NavigationRail] on desktop/tablet)
/// on every operational screen: the current group's name on the left,
/// and a profile avatar on the right that opens a modal sheet with
/// the account details also found in full on the More screen (Account,
/// Current Group, Language, Switch Group, Sign Out) — without having
/// to leave the current page. Uses the same surface color as the
/// bottom bar/rail rather than the app-wide `AppBarTheme` default, so
/// it reads as one continuous piece of navigation chrome with them.
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      automaticallyImplyLeading: false,
      centerTitle: false,
      title: Text(
        membership?.group.groupName ?? 'Umoja',
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      actions: [
        // Prompt 09G-B5-C.2 §A/§N.6: `appContextProvider` only
        // refetches on a sign-in identity change or a fresh app launch
        // (see its own doc comment) — a permission granted to an
        // already-signed-in user (e.g. the B5-B MEMBER baseline
        // backfill) would otherwise stay stale for the rest of that
        // session. This gives every operational screen one explicit,
        // discoverable way to pick up a newly effective permission
        // without reinstalling or signing out.
        IconButton(
          key: const Key('refreshPermissionsButton'),
          tooltip: context.l10n.refreshAction,
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(appContextProvider),
        ),
        const Padding(
          padding: EdgeInsets.only(right: UmojaSpacing.md),
          child: MemberAvatarButton(),
        ),
      ],
    );
  }
}

/// Opens the account details modal — the same Account/Current
/// Group/Language/Sign Out content as the full More screen (minus its
/// module quick-links, which stay specific to that screen). Shared by
/// [AppTopBar]'s profile avatar and the mobile bottom bar's More sheet
/// (see `more_sheet.dart`), so account settings live in exactly one
/// place rather than two separately maintained copies.
void showProfileSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContextAsync = ref.watch(appContextProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final profile = appContextAsync.value?.profile;
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final eligibleMemberships = (appContextAsync.value?.memberships ?? const [])
        .where((m) => m.isEligibleOperational)
        .toList(growable: false);
    final canSwitchGroup = eligibleMemberships.length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UmojaSpacing.lg,
          UmojaSpacing.sm,
          UmojaSpacing.lg,
          UmojaSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (membership != null) ...[
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
                                      .map(
                                        (code) => memberRoleLabel(l10n, code),
                                      )
                                      .join(', '),
                                ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: UmojaSpacing.xxl),
              ],
              UmojaSection(
                title: l10n.languageSelectorLabel,
                child: const UmojaLanguageSelector(),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              if (canSwitchGroup) ...[
                UmojaSection(
                  title: l10n.actionsSectionTitle,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref
                          .read(selectedGroupProvider.notifier)
                          .requireReselection(eligibleMemberships);
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.switchGroupAction),
                  ),
                ),
                const SizedBox(height: UmojaSpacing.xxl),
              ],
              UmojaSection(
                title: l10n.securitySectionTitle,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(authControllerProvider).signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.signOutButtonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
