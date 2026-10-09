import 'package:flutter/material.dart';

import '../../features/auth/models/membership_context.dart';
import '../../l10n/app_localizations.dart';
import 'app_routes.dart';

/// Member self-service child routes (`/me/...`), shared by
/// [route_guard.dart] (the authorization boundary's UX guidance) and
/// [app_shell.dart] (navigation chrome and bottom-bar selection), so the
/// two can never drift apart — Prompt 09G-B5-C.2 §G: "More navigation
/// and RouteGuard must derive from the same effective permission state
/// so an item cannot be visible but route-blocked, or route-allowed but
/// invisible."
bool isMyProfileRoute(String location) => location == AppRoutes.myProfile;

bool isMyStatementRoute(String location) => location == AppRoutes.myStatement;

bool isMyContributionsRoute(String location) =>
    location == AppRoutes.myContributions ||
    location.startsWith('${AppRoutes.myContributions}/');

bool isMyLoansRoute(String location) =>
    location == AppRoutes.myLoans ||
    location.startsWith('${AppRoutes.myLoans}/');

/// Prompt 09G-B6-C: the caller's OWN payments/receipts — never the
/// officer `/payments` workspace (gated separately on payment.view).
bool isMyPaymentsRoute(String location) =>
    location == AppRoutes.myPayments ||
    location.startsWith('${AppRoutes.myPayments}/');

/// Any member self-service child route — the set that shares one
/// compact header and that the bottom/sidebar navigation treats as
/// "within More", never as Home (Prompt 09G-B5-C.2 §I).
bool isMemberSelfServiceChildRoute(String location) =>
    isMyProfileRoute(location) ||
    isMyStatementRoute(location) ||
    isMyContributionsRoute(location) ||
    isMyLoansRoute(location) ||
    isMyPaymentsRoute(location);

/// Prompt 09G-B6-C §E: the single canonical definition of a member
/// self-service destination (My Profile, My Financial Statement, My
/// Contributions, My Loans, My Payments, ...), consumed by every
/// surface that must list them (mobile More sheet, desktop MoreScreen,
/// Home quick actions) instead of each surface hand-maintaining its own
/// copy of "if membership has permission X, show tile Y" — the
/// duplication that caused the B5 My Loans visibility defect (one
/// surface updated, another forgotten).
///
/// Visibility is driven ONLY by [requiredPermission] (never a role
/// name, never an officer permission) — `null` means always visible
/// once a group is selected (e.g. My Profile, which is inherently
/// self-scoped).
class MemberSelfServiceDestination {
  const MemberSelfServiceDestination({
    required this.id,
    required this.path,
    required this.icon,
    required this.label,
    this.requiredPermission,
    this.homeLabel,
    this.homeQuickActionSubtitle,
    this.showAsHomeQuickAction = false,
    required this.moreKey,
    required this.sheetKey,
    this.homeKey,
  });

  /// Stable id — not itself used as a widget key (each surface already
  /// has its own established key convention, kept via [moreKey]/
  /// [sheetKey]/[homeKey] below so existing automated tests keep
  /// matching the exact keys they were written against).
  final String id;

  final String path;
  final IconData icon;

  /// The label shown on the desktop MoreScreen tile and the mobile More
  /// sheet's ListTile.
  final String label;

  /// `null` means always visible (once a group is selected) — never
  /// gated on a role name or an officer-only permission.
  final String? requiredPermission;

  /// Home's own quick-action label, when it differs from [label] (My
  /// Profile's Home shortcut historically reads "My Profile" via a
  /// dedicated key, same text as [label] here — kept distinct only
  /// where a real established difference exists). Defaults to [label].
  final String? homeLabel;

  final String? homeQuickActionSubtitle;

  /// Whether this destination also earns a Home quick-action tile.
  final bool showAsHomeQuickAction;

  final String moreKey;
  final String sheetKey;
  final String? homeKey;

  bool isVisible(MembershipContext? membership) {
    if (membership == null) return false;
    final permission = requiredPermission;
    return permission == null || membership.hasPermission(permission);
  }

  String effectiveHomeLabel() => homeLabel ?? label;
}

/// The complete, ordered registry. Order here is the order every
/// consuming surface renders these destinations in.
List<MemberSelfServiceDestination> memberSelfServiceDestinations(
  AppLocalizations l10n,
) => [
  MemberSelfServiceDestination(
    id: 'myProfile',
    path: AppRoutes.myProfile,
    icon: Icons.account_circle_outlined,
    label: l10n.myProfileAction,
    homeLabel: l10n.homeMyProfileLinkTitle,
    showAsHomeQuickAction: true,
    moreKey: 'moreMyProfileAction',
    sheetKey: 'moreSheetMyProfile',
    homeKey: 'homeMyProfileShortcut',
  ),
  MemberSelfServiceDestination(
    id: 'myStatement',
    path: AppRoutes.myStatement,
    icon: Icons.receipt_long_outlined,
    label: l10n.moreFinancialStatementAction,
    requiredPermission: 'financial_report.self_view',
    moreKey: 'moreFinancialStatementAction',
    sheetKey: 'moreSheetFinancialStatement',
  ),
  MemberSelfServiceDestination(
    id: 'myContributions',
    path: AppRoutes.myContributions,
    icon: Icons.request_page_outlined,
    label: l10n.myContributionsTitle,
    requiredPermission: 'contribution.self_view',
    homeQuickActionSubtitle: l10n.myContributionsShortcutSubtitle,
    showAsHomeQuickAction: true,
    moreKey: 'moreMyContributionsAction',
    sheetKey: 'moreSheetMyContributions',
    homeKey: 'homeMyContributionsShortcut',
  ),
  MemberSelfServiceDestination(
    id: 'myLoans',
    path: AppRoutes.myLoans,
    icon: Icons.account_balance_wallet_outlined,
    label: l10n.myLoansNavAction,
    requiredPermission: 'loan.self_view',
    showAsHomeQuickAction: true,
    moreKey: 'moreMyLoansAction',
    sheetKey: 'moreSheetMyLoans',
    homeKey: 'homeMyLoansShortcut',
  ),
  // Prompt 09G-B6-C §H: payment.self_view only — never member.view,
  // payment.view (the officer workspace, unchanged at /payments), or a
  // role name.
  MemberSelfServiceDestination(
    id: 'myPayments',
    path: AppRoutes.myPayments,
    icon: Icons.payments_outlined,
    label: l10n.myPaymentsTitle,
    requiredPermission: 'payment.self_view',
    homeQuickActionSubtitle: l10n.myPaymentsShortcutSubtitle,
    showAsHomeQuickAction: true,
    moreKey: 'moreMyPaymentsAction',
    sheetKey: 'moreSheetMyPayments',
    homeKey: 'homeMyPaymentsShortcut',
  ),
];

/// The subset of [memberSelfServiceDestinations] visible for
/// [membership] — the single filtered list every consuming surface
/// (More screen, More sheet, Home quick actions) renders from.
List<MemberSelfServiceDestination> visibleMemberSelfServiceDestinations(
  AppLocalizations l10n, {
  MembershipContext? membership,
}) =>
    memberSelfServiceDestinations(l10n)
        .where((d) => d.isVisible(membership))
        .toList(growable: false);
