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
  // Prompt 09G-B1-F-UAT-FIX-03: Members is no longer a standalone flat
  // destination — it is the first child of the "Member Management"
  // navigation group (see [memberManagementChildren]), shown as an
  // expandable sidebar section on desktop/tablet and as its own
  // dedicated screen reached from More on mobile. Removing it here
  // (rather than keeping it AND adding the group) is deliberate — one
  // destination reachable two structurally different ways would be
  // the "duplicate destination" this refactor explicitly avoids.
  if (membership?.hasPermission('contribution.view') ?? false)
    ShellDestination(
      path: AppRoutes.contributionsHome,
      label: l10n.contributionsTitle,
      icon: Icons.volunteer_activism_outlined,
      selectedIcon: Icons.volunteer_activism,
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

/// One entry inside the "Member Management" navigation group — the
/// desktop/tablet expandable sidebar section, and the mobile dedicated
/// screen reached from More (Prompt 09G-B1-F-UAT-FIX-03). Unlike
/// [ShellDestination], never appears in the mobile bottom bar directly.
class MemberManagementChild {
  const MemberManagementChild({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;

  bool isSelected(String location) =>
      location == path || location.startsWith('$path/');
}

/// The Member Management group's children, permission-gated
/// individually — never by role name. Members (the directory itself)
/// requires `member.view` (Prompt 09G-B2 §F — an ordinary member
/// without it must not see the Members directory anywhere); Invite
/// Member and Sent Invitations require `member.invite`; Membership
/// Requests requires `member.claim.approve`. May be EMPTY when
/// [membership] holds none of those permissions — callers must check
/// `.isEmpty` before rendering an entry point to this group at all
/// (see `app_shell.dart`'s `memberManagementChildren.isNotEmpty` guard
/// and the equivalent checks in `more_screen.dart`/`more_sheet.dart`),
/// never showing an empty Member Management container/menu.
List<MemberManagementChild> memberManagementChildren(
  AppLocalizations l10n, {
  MembershipContext? membership,
}) {
  if (membership == null) return const [];

  final canView = membership.hasPermission('member.view');
  final canInvite = membership.hasPermission('member.invite');
  final canReviewClaims = membership.hasPermission('member.claim.approve');

  return [
    // Prompt 09G-B2 §F: an ordinary member without member.view must
    // not see the Members directory anywhere, including here — this
    // list is the single source every Member Management surface
    // (desktop sidebar, mobile screen, More sheet) renders from, so
    // gating it here is sufficient for all of them at once.
    if (canView)
      MemberManagementChild(
        path: AppRoutes.membersList,
        label: l10n.membersTitle,
        icon: Icons.people_alt_outlined,
      ),
    if (canInvite)
      MemberManagementChild(
        path: AppRoutes.membershipInvite,
        label: l10n.inviteMemberAction,
        icon: Icons.person_add_outlined,
      ),
    if (canInvite)
      MemberManagementChild(
        path: AppRoutes.membershipInvitationsList,
        label: l10n.sentInvitationsTitle,
        icon: Icons.mail_outline,
      ),
    if (canReviewClaims)
      MemberManagementChild(
        path: AppRoutes.membershipRequestsList,
        label: l10n.membershipRequestsTitle,
        icon: Icons.assignment_ind_outlined,
      ),
  ];
}

/// Whether [location] is on any Member Management child route — used to
/// keep the desktop sidebar group expanded/highlighted while the user
/// is anywhere inside it (Prompt 09G-B1-F-UAT-FIX-03 §D7).
bool isMemberManagementLocation(String location) =>
    location == AppRoutes.membersList ||
    location.startsWith('${AppRoutes.membersList}/') ||
    location == AppRoutes.membershipInvite ||
    location == AppRoutes.membershipInvitationsList ||
    location == AppRoutes.membershipRequestsList ||
    location.startsWith('${AppRoutes.membershipRequestsList}/');
