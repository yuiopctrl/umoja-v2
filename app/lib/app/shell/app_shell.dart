import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/umoja_brand_mark.dart';
import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_breakpoints.dart';
import '../../core/theme/umoja_spacing.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../../l10n/app_localizations.dart';
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
/// - >= 700px: a custom sidebar below the top bar (compact icon rail
///   under 1200px, an extended icon+label rail at/above it) — see
///   [_DesktopSidebar]. Not a stock [NavigationRail]: the "Member
///   Management" group (Prompt 09G-B1-F-UAT-FIX-03) needs an
///   expandable/collapsible entry interleaved with the flat
///   destinations, which [NavigationRail] cannot represent.
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
/// `more_sheet.dart`). Member Management (Prompt 09G-B1-F-UAT-FIX-03
/// §E) is reached from the full More screen instead — it is not a
/// `primaryOnMobile` bottom-bar destination and is not offered from
/// this quick modal either.
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
      // mobile subset (Home/Payments/More) never loses the remaining
      // destinations; they surface as quick-link cards inside the More
      // screen instead (see shell_destination.dart). Member Management
      // is reached from More too, not a bottom-bar slot of its own.
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
                showMyProfile: membership != null,
                // Prompt 09G-B2 §F2: an ordinary member with none of
                // member.view/member.invite/member.claim.approve must
                // not see an empty Member Management entry here either.
                showMemberManagement: memberManagementChildren(
                  context.l10n,
                  membership: membership,
                ).isNotEmpty,
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

    final extended = UmojaBreakpoints.isDesktop(width);
    final memberManagement = memberManagementChildren(
      context.l10n,
      membership: membership,
    );

    return Scaffold(
      appBar: const AppTopBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopSidebar(
            location: location,
            destinations: destinations,
            memberManagementChildren: memberManagement,
            extended: extended,
            l10n: context.l10n,
            onSelectDestination: (path) {
              if (location != path && !location.startsWith('$path/')) {
                context.go(path);
              }
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The desktop/tablet sidebar — a flat destination for Home, an
/// expandable "Member Management" group (Members/Invite Member/Sent
/// Invitations/Membership Requests), then the remaining flat
/// destinations (Contributions/Payments/Loans/Finance/More), in that
/// order — matching the position Members previously occupied.
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.location,
    required this.destinations,
    required this.memberManagementChildren,
    required this.extended,
    required this.l10n,
    required this.onSelectDestination,
  });

  final String location;
  final List<ShellDestination> destinations;
  final List<MemberManagementChild> memberManagementChildren;
  final bool extended;
  final AppLocalizations l10n;
  final ValueChanged<String> onSelectDestination;

  @override
  Widget build(BuildContext context) {
    final home = destinations.isNotEmpty ? destinations.first : null;
    final rest = destinations.isNotEmpty
        ? destinations.skip(1)
        : const <ShellDestination>[];

    return Container(
      key: const Key('desktopSidebar'),
      width: extended ? 240 : 80,
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: UmojaSpacing.lg,
                horizontal: extended ? UmojaSpacing.lg : 0,
              ),
              child: Center(
                child: extended
                    ? const UmojaBrandMark.sidebarLockup(wordmarkHeight: 44)
                    : const UmojaBrandMark.symbol(size: 36),
              ),
            ),
            if (home != null)
              _SidebarTile(
                destination: home,
                selected: home.isSelected(location),
                extended: extended,
                onTap: () => onSelectDestination(home.path),
              ),
            if (memberManagementChildren.isNotEmpty)
              _MemberManagementGroupTile(
                location: location,
                children: memberManagementChildren,
                extended: extended,
                title: l10n.memberManagementTitle,
                onSelectChild: onSelectDestination,
              ),
            for (final destination in rest)
              _SidebarTile(
                destination: destination,
                selected: destination.isSelected(location),
                extended: extended,
                onTap: () => onSelectDestination(destination.path),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      color: color,
    );

    // Matches the stock NavigationRail convention this replaced
    // (`labelType: NavigationRailLabelType.all` in compact mode): the
    // label is always visible, never icon-only — beside the icon when
    // extended, stacked below it in the compact rail otherwise.
    if (!extended) {
      return InkWell(
        key: Key('sidebarDestination_${destination.path}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.md),
          child: Column(
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      key: Key('sidebarDestination_${destination.path}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UmojaSpacing.lg,
          vertical: UmojaSpacing.md,
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: UmojaSpacing.md),
            Expanded(
              child: Text(
                destination.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The expandable/collapsible "Member Management" sidebar group.
/// Auto-expands whenever navigation lands on one of its own children
/// (Prompt 09G-B1-F-UAT-FIX-03 §D7 — the group must "remain visually
/// expanded/active appropriately"), but the user may freely
/// expand/collapse it independently of the current route otherwise —
/// a real toggle, not merely a route-driven display.
class _MemberManagementGroupTile extends StatefulWidget {
  const _MemberManagementGroupTile({
    required this.location,
    required this.children,
    required this.extended,
    required this.title,
    required this.onSelectChild,
  });

  final String location;
  final List<MemberManagementChild> children;
  final bool extended;
  final String title;
  final ValueChanged<String> onSelectChild;

  @override
  State<_MemberManagementGroupTile> createState() =>
      _MemberManagementGroupTileState();
}

class _MemberManagementGroupTileState
    extends State<_MemberManagementGroupTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = isMemberManagementLocation(widget.location);
  }

  @override
  void didUpdateWidget(covariant _MemberManagementGroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location &&
        isMemberManagementLocation(widget.location)) {
      _expanded = true;
    }
  }

  /// Whether [child] is the single most specific match for the current
  /// location. Every static child route lives under the Members path
  /// (`/members/invite`, `/members/requests`, ...), so a naive
  /// `child.isSelected` prefix check matches Members itself on EVERY
  /// other child's route too (`/members/invite`.startsWith('/members/')
  /// is true) — highlighting both Members and whichever child is
  /// actually active. Preferring the longest matching path is what
  /// keeps only the actual active child highlighted.
  bool _isSelectedChild(MemberManagementChild child) {
    if (!child.isSelected(widget.location)) return false;
    return !widget.children.any(
      (other) =>
          other.path != child.path &&
          other.path.length > child.path.length &&
          other.isSelected(widget.location),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = isMemberManagementLocation(widget.location);
    final headerColor = active ? scheme.primary : scheme.onSurfaceVariant;

    final headerIcon = Icon(Icons.people_alt_outlined, color: headerColor);

    // Matches the stock NavigationRail convention this replaced
    // (`labelType: NavigationRailLabelType.all` in compact mode): the
    // label is always visible, never icon-only — beside the icon when
    // extended, stacked below it in the compact rail otherwise. The
    // expand/collapse chevron only fits the extended layout; in
    // compact mode the whole tile is still tappable to toggle.
    final header = widget.extended
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UmojaSpacing.lg,
              vertical: UmojaSpacing.md,
            ),
            child: Row(
              children: [
                headerIcon,
                const SizedBox(width: UmojaSpacing.md),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: headerColor,
                      fontWeight: active ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: headerColor,
                  size: 20,
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.md),
            child: Column(
              children: [
                headerIcon,
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: headerColor,
                    fontWeight: active ? FontWeight.w600 : null,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('memberManagementNavGroupToggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: header,
        ),
        if (_expanded)
          for (final child in widget.children)
            InkWell(
              key: Key('memberManagementNavChild_${child.path}'),
              onTap: () => widget.onSelectChild(child.path),
              child: widget.extended
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: UmojaSpacing.xxxl,
                        right: UmojaSpacing.lg,
                        top: UmojaSpacing.sm,
                        bottom: UmojaSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            child.icon,
                            size: 20,
                            color: _isSelectedChild(child)
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: UmojaSpacing.md),
                          Expanded(
                            child: Text(
                              child.label,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _isSelectedChild(child)
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                    fontWeight: _isSelectedChild(child)
                                        ? FontWeight.w600
                                        : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UmojaSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            child.icon,
                            size: 20,
                            color: _isSelectedChild(child)
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            child.label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _isSelectedChild(child)
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  fontWeight: _isSelectedChild(child)
                                      ? FontWeight.w600
                                      : null,
                                ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
            ),
      ],
    );
  }
}
