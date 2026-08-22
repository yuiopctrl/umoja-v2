import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/umoja_brand_mark.dart';
import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_breakpoints.dart';
import '../../core/theme/umoja_spacing.dart';
import 'shell_destination.dart';

/// The authenticated application shell. Wraps every operational route
/// (`/home`, `/members`, `/more`, ...) with responsive navigation
/// chrome:
/// - < 700px: a bottom [NavigationBar].
/// - 700–1199px: a compact [NavigationRail].
/// - >= 1200px: an extended [NavigationRail].
///
/// [child] is the routed screen for the current location — each screen
/// remains a self-contained [Scaffold] (via `UmojaPage`); this shell
/// only adds the surrounding navigation, so it never needs to know
/// anything about an individual screen's content.
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Rebuilt from `context.l10n` (not a top-level const) so nav labels
    // switch immediately with the active language (prompt 05C §10).
    final destinations = shellDestinations(context.l10n);
    final selectedIndex = _selectedIndex(destinations);

    if (UmojaBreakpoints.isMobile(width)) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) =>
              _onSelect(context, destinations, index),
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    final extended = UmojaBreakpoints.isDesktop(width);

    return Scaffold(
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
                  ? const UmojaBrandMark.lockup(size: 52, wordmarkHeight: 44)
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
