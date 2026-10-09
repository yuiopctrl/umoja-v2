import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_spacing.dart';
import '../routing/app_routes.dart';
import '../routing/member_self_service_routes.dart';
import 'app_top_bar.dart';
import 'shell_destination.dart';

/// Opens the modal sheet behind the mobile bottom bar's "More"
/// destination — every module demoted off the curated bottom bar
/// (Contributions/Loans/Finance — see [mobileOverflowDestinations]),
/// the "Member Management" group entry point (Members/Invite Member/
/// Sent Invitations/Membership Requests, only once a group is
/// selected — matching [MoreScreen]'s own gating), plus a single
/// "Akaunti" entry for everything account-related (profile, current
/// group, language, sign out — see [showProfileSheet]). Tapping
/// "More" no longer navigates to a dedicated page on mobile; the bar
/// itself never moves off whatever screen was already showing
/// underneath.
///
/// Prompt 09G-B6-C §E: [memberDestinations] is the ALREADY-FILTERED
/// list from [visibleMemberSelfServiceDestinations] — one source every
/// member self-service tile here (and in [MoreScreen]/Home) renders
/// from, rather than this sheet hand-maintaining its own "show X"
/// boolean per destination (the duplication that caused the B5 My
/// Loans visibility defect: one surface updated, another forgotten).
void showMoreSheet(
  BuildContext context, {
  required List<ShellDestination> overflowDestinations,
  required bool showMemberManagement,
  required List<MemberSelfServiceDestination> memberDestinations,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MoreSheet(
      overflowDestinations: overflowDestinations,
      showMemberManagement: showMemberManagement,
      memberDestinations: memberDestinations,
    ),
  );
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.overflowDestinations,
    required this.showMemberManagement,
    required this.memberDestinations,
  });

  final List<ShellDestination> overflowDestinations;
  final bool showMemberManagement;
  final List<MemberSelfServiceDestination> memberDestinations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UmojaSpacing.lg,
                0,
                UmojaSpacing.lg,
                UmojaSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.moreTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            // Prompt 09G-B6-C §E: one canonical destination list — the
            // SAME permissions MoreScreen/RouteGuard already gate on
            // (financial_report.self_view, contribution.self_view,
            // loan.self_view, payment.self_view), never member.view,
            // never a role name.
            for (final destination in memberDestinations)
              ListTile(
                key: Key(destination.sheetKey),
                leading: Icon(destination.icon),
                title: Text(destination.label),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(destination.path);
                },
              ),
            if (showMemberManagement)
              ListTile(
                key: const Key('moreSheetMemberManagement'),
                leading: const Icon(Icons.people_alt_outlined),
                title: Text(l10n.memberManagementTitle),
                subtitle: Text(l10n.memberManagementSubtitle),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.memberManagement);
                },
              ),
            for (final destination in overflowDestinations)
              ListTile(
                key: Key('moreSheetLink_${destination.path}'),
                leading: Icon(destination.icon),
                title: Text(destination.label),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(destination.path);
                },
              ),
            if (overflowDestinations.isNotEmpty) const Divider(height: 1),
            ListTile(
              key: const Key('moreSheetAccount'),
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(l10n.accountSectionTitle),
              onTap: () {
                Navigator.of(context).pop();
                showProfileSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
