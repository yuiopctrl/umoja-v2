import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/shell_destination.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../../app/routing/app_routes.dart';

/// `/member-management`: the mobile entry point for Members/Invite
/// Member/Sent Invitations/Membership Requests (Prompt
/// 09G-B1-F-UAT-FIX-03 §E) — reached from More, never a bottom-bar
/// destination of its own. Desktop/tablet shows the same children as
/// an expandable sidebar group instead (`app_shell.dart`'s
/// `_MemberManagementGroupTile`); this screen exists only because that
/// space isn't available on a narrow viewport.
///
/// A clean grouped list, not a dashboard of oversized cards — each row
/// is icon + title + chevron (never icon-only), matching the same
/// [MemberManagementChild] set the desktop sidebar reads from, so the
/// two surfaces can never drift apart.
class MemberManagementScreen extends ConsumerWidget {
  const MemberManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final children = memberManagementChildren(l10n, membership: membership);

    return UmojaPage(
      backTo: AppRoutes.more,
      backLabel: l10n.moreTitle,
      title: l10n.memberManagementTitle,
      body: UmojaCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const Divider(height: 1),
              UmojaListTile(
                key: Key('memberManagementRow_${child.path}'),
                leading: Icon(child.icon),
                title: child.label,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(child.path),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
