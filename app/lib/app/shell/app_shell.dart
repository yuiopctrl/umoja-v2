import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/umoja_brand_mark.dart';
import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_breakpoints.dart';
import '../../core/theme/umoja_spacing.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../routing/app_routes.dart';
import 'app_top_bar.dart';
import 'more_sheet.dart';
import 'shell_destination.dart';

/// The authenticated application shell. Wraps every operational route
/// (`/home`, `/members`, `/more`, ...) with responsive navigation
/// chrome:
/// - Every breakpoint: a persistent [AppTopBar] (current group name on
///   the left, profile menu on the right).
/// - < 700px: a bottom [NavigationBar] below the top bar.
/// - 700–1199px: a compact [NavigationRail] below the top bar.
/// - >= 1200px: an extended [NavigationRail] below the top bar.
///
/// [child] is the routed screen for the current location — each screen
/// remains a self-contained [Scaffold] (via `UmojaPage`); this shell
/// only adds the surrounding navigation, so it never needs to know
/// anything about an individual screen's content. A shell-root screen
/// (Home/Members/...) relies on this top bar for its persistent chrome
/// and renders its own title inline instead of in a second app bar —
/// see `UmojaPage`.
///
/// On mobile, tapping "More" never navigates — it opens a modal
/// listing the demoted modules (Contributions/Loans/Finance) plus a
/// single account-settings entry instead, so the bottom bar itself
/// never leaves whatever screen it was tapped from (see
/// `more_sheet.dart`). Desktop/tablet's [NavigationRail] already shows
/// every destination directly, so "More" there still navigates to the
/// full account page as before.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int _selectedIndex(List<ShellDestination> destinations) {
    final index = destinations.indexWhere((d) => d.isSelected(location));
    return index == -1 ? 0 : index;
  }

  void _onSelect(
    BuildContext context,
    List<ShellDestination> destinations,
    int index,
  ) {
    final destination = destinations[index];
    if (!destination.isSelected(location)) {
      context.go(destination.path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    // Rebuilt from `context.l10n` (not a top-level const) so nav labels
    // switch immediately with the active language (prompt 05C §10).
    final destinations = shellDestinations(
      context.l10n,
      membership: membership,
    );

    if (UmojaBreakpoints.isMobile(width)) {
      // Material Design caps a bottom bar at 3-5 destinations before it
      // reads as congested — this app can have up to 7. The curated
      // mobile subset (Home/Members/Payments/More) never loses the
      // remaining destinations; they surface as quick-link cards inside
      // the More screen instead (see shell_destination.dart).
      final mobileDestinations = mobilePrimaryDestinations(destinations);
      final selectedIndex = _selectedIndex(mobileDestinations);
      return Scaffold(
        appBar: const AppTopBar(),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            final destination = mobileDestinations[index];
            // More never navigates on mobile — it opens a modal
            // listing the demoted modules plus account settings
            // instead, so the bar never leaves whatever screen was
            // already showing underneath (see more_sheet.dart).
            if (destination.path == AppRoutes.more) {
              showMoreSheet(
                context,
                overflowDestinations: mobileOverflowDestinations(destinations),
              );
              return;
            }
            _onSelect(context, mobileDestinations, index);
          },
          destinations: [
            for (final destination in mobileDestinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    final selectedIndex = _selectedIndex(destinations);
    final extended = UmojaBreakpoints.isDesktop(width);

    return Scaffold(
      appBar: const AppTopBar(),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                _onSelect(context, destinations, index),
            extended: extended,
            minExtendedWidth: 240,
            labelType: extended ? null : NavigationRailLabelType.all,
            leading: Padding(
              padding: EdgeInsets.symmetric(
                vertical: UmojaSpacing.lg,
                horizontal: extended ? UmojaSpacing.lg : 0,
              ),
              child: extended
                  ? const UmojaBrandMark.sidebarLockup(wordmarkHeight: 44)
                  : const UmojaBrandMark.symbol(size: 36),
            ),
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
