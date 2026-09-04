import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_spacing.dart';
import 'app_top_bar.dart';
import 'shell_destination.dart';

/// Opens the modal sheet behind the mobile bottom bar's "More"
/// destination — every module demoted off the curated bottom bar
/// (Contributions/Loans/Finance — see [mobileOverflowDestinations]),
/// plus a single "Akaunti" entry for everything account-related
/// (profile, current group, language, sign out — see
/// [showProfileSheet]). Tapping "More" no longer navigates to a
/// dedicated page on mobile; the bar itself never moves off whatever
/// screen was already showing underneath.
void showMoreSheet(
  BuildContext context, {
  required List<ShellDestination> overflowDestinations,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _MoreSheet(overflowDestinations: overflowDestinations),
  );
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.overflowDestinations});

  final List<ShellDestination> overflowDestinations;

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
