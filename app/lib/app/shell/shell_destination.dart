import 'package:flutter/material.dart';

import '../../features/auth/models/membership_context.dart';
import '../../l10n/app_localizations.dart';
import '../routing/app_routes.dart';

/// One destination in the operational app shell's navigation
/// (bottom bar on mobile, rail on tablet/desktop). Only real,
/// implemented modules belong here — see docs/product/design-system.md
/// for the rule against adding placeholder destinations for modules
/// that don't exist yet (Contributions, Loans, Wallet, Reports, ...).
class ShellDestination {
  const ShellDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  bool isSelected(String location) =>
      location == path || location.startsWith('$path/');
}

/// Built from [l10n] rather than a top-level `const` so shell
/// navigation labels react immediately to a language change (prompt
/// 05C §10) — the same localized strings used as each destination's
/// own page title (`l10n.homeTitle`/`membersTitle`/`moreTitle`).
///
/// [membership] gates the Contributions destination on
/// `contribution.view` — unlike Home/Members/More (which every role
/// currently holds the underlying permission for), a plain MEMBER role
/// only has `contribution.self_view`, so showing "Michango" in the nav
/// for them would lead straight to a permission-denied screen. This is
/// nav visibility only, never the authorization boundary itself — RLS
/// and the RPCs remain authoritative regardless.
List<ShellDestination> shellDestinations(
  AppLocalizations l10n, {
  MembershipContext? membership,
}) => [
  ShellDestination(
    path: AppRoutes.home,
    label: l10n.homeTitle,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  ShellDestination(
    path: AppRoutes.membersList,
    label: l10n.membersTitle,
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt,
  ),
  if (membership?.hasPermission('contribution.view') ?? false)
    ShellDestination(
      path: AppRoutes.contributionsHome,
      label: l10n.contributionsTitle,
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings,
    ),
  ShellDestination(
    path: AppRoutes.more,
    label: l10n.moreTitle,
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
  ),
];
