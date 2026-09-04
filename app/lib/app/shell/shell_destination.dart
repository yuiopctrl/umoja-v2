import 'package:flutter/material.dart';

import '../../features/auth/models/membership_context.dart';
import '../../l10n/app_localizations.dart';
import '../routing/app_routes.dart';

/// One destination in the operational app shell's navigation
/// (bottom bar on mobile, rail on tablet/desktop). Only real,
/// implemented modules belong here — never a placeholder destination
/// for a module that doesn't exist yet.
class ShellDestination {
  const ShellDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.primaryOnMobile = false,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Whether this destination earns one of the few slots on the mobile
  /// bottom bar (Material Design caps a bottom bar at 3-5 destinations
  /// before it reads as congested). A destination with `false` here is
  /// never lost — it simply moves into the More screen's "Modules"
  /// quick-link section on mobile instead; desktop/tablet's
  /// [NavigationRail] has room to show every destination regardless.
  final bool primaryOnMobile;

  bool isSelected(String location) =>
      location == path || location.startsWith('$path/');
}

/// The subset of [destinations] that belongs on the mobile bottom bar,
/// order preserved. Everything else remains reachable via the More
/// screen's "Modules" section (see [mobileOverflowDestinations]).
List<ShellDestination> mobilePrimaryDestinations(
  List<ShellDestination> destinations,
) => destinations.where((d) => d.primaryOnMobile).toList(growable: false);

/// The subset of [destinations] that is demoted off the mobile bottom
/// bar — every module destination except More itself, which is never
/// listed inside its own screen.
List<ShellDestination> mobileOverflowDestinations(
  List<ShellDestination> destinations,
) => destinations
    .where((d) => !d.primaryOnMobile && d.path != AppRoutes.more)
    .toList(growable: false);

/// Built from [l10n] rather than a top-level `const` so shell
/// navigation labels react immediately to a language change (prompt
/// 05C §10) — the same localized strings used as each destination's
/// own page title (`l10n.homeTitle`/`membersTitle`/`moreTitle`).
///
/// [membership] gates each module destination on the permission that
/// module's own home screen already requires to show anything useful
/// (Contributions: `contribution.view`; Payments: `payment.view`;
/// Loans: `loan.view`; Finance/Cashbook: `financial_account.view`) —
/// unlike Home/Members/More (which every role currently holds the
/// underlying permission for). A plain MEMBER role, for example, only
/// has `contribution.self_view`, so showing "Michango" in the nav for
/// them would lead straight to a permission-denied screen. This is nav
/// visibility only, never the authorization boundary itself — RLS and
/// the RPCs remain authoritative regardless.
///
/// `primaryOnMobile` is set on only Home/Members/Payments/More —
/// Material Design's own guidance caps a bottom bar at 3-5 destinations
/// before it reads as congested, and this app can have up to 7. The
/// remaining destinations (Contributions/Loans/Finance) are never lost
/// on mobile: they surface as quick-link cards inside the More screen
/// instead (see [mobileOverflowDestinations]). Desktop/tablet's
/// [NavigationRail] has room to show every destination directly, so
/// this split only ever changes mobile's bottom bar.
List<ShellDestination> shellDestinations(
  AppLocalizations l10n, {
  MembershipContext? membership,
}) => [
  ShellDestination(
    path: AppRoutes.home,
    label: l10n.homeTitle,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    primaryOnMobile: true,
  ),
  ShellDestination(
    path: AppRoutes.membersList,
    label: l10n.membersTitle,
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt,
    primaryOnMobile: true,
  ),
  if (membership?.hasPermission('contribution.view') ?? false)
    ShellDestination(
      path: AppRoutes.contributionsHome,
      label: l10n.contributionsTitle,
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings,
    ),
  if (membership?.hasPermission('payment.view') ?? false)
    ShellDestination(
      path: AppRoutes.paymentsList,
      label: l10n.paymentsTitle,
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      primaryOnMobile: true,
    ),
  if (membership?.hasPermission('loan.view') ?? false)
    ShellDestination(
      path: AppRoutes.loansHome,
      label: l10n.loansTitle,
      icon: Icons.request_quote_outlined,
      selectedIcon: Icons.request_quote,
    ),
  if (membership?.hasPermission('financial_account.view') ?? false)
    ShellDestination(
      path: AppRoutes.financeHome,
      label: l10n.financeTitle,
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
    ),
  ShellDestination(
    path: AppRoutes.more,
    label: l10n.moreTitle,
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
    primaryOnMobile: true,
  ),
];
