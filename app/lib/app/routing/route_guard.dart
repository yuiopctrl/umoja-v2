import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/app_context.dart';
import '../../features/auth/models/membership_context.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import 'app_routes.dart';
import 'member_self_service_routes.dart';

/// Classifies why a signed-in, profile-complete user has zero eligible
/// (ACTIVE membership + ACTIVE group) operational context, so the
/// router can show the most specific relevant screen instead of
/// collapsing every case into "create a group".
///
/// Priority: an existing SUSPENDED membership is surfaced before a
/// SUSPENDED/CLOSED group, which is surfaced before the generic
/// "no group yet" onboarding case (which also covers EXITED-only
/// memberships and having no memberships at all).
String noEligibleGroupTarget(List<MembershipContext> memberships) {
  final hasSuspendedMembership = memberships.any(
    (m) => m.isSuspendedMembership,
  );
  if (hasSuspendedMembership) return AppRoutes.accessMembershipRestricted;

  final hasSuspendedGroup = memberships.any(
    (m) => m.isActiveMembership && m.group.isSuspended,
  );
  if (hasSuspendedGroup) return AppRoutes.accessGroupSuspended;

  final hasClosedGroup = memberships.any(
    (m) => m.isActiveMembership && m.group.isClosed,
  );
  if (hasClosedGroup) return AppRoutes.accessGroupClosed;

  // Prompt 09G-B1-D2: no eligible membership and no other explained
  // reason (no memberships at all, or EXITED-only) — offer BOTH
  // linking an existing roster membership and creating a new group,
  // rather than forcing group creation as the only path. See
  // MembershipEntryScreen.
  return AppRoutes.onboardingMembershipEntry;
}

const _authRoutes = {AppRoutes.authPhone, AppRoutes.authVerify};

/// Prompt 09G-B1-E3 §C: `/invite/:token` is reachable at every stage —
/// signed out (the screen itself shows a "sign in to continue" CTA),
/// mid-onboarding, or fully operational — never bounced away by the
/// signed-out->login redirect the way an ordinary route would be. Once
/// signed in, it still passes through the PIN/profile/account-disabled
/// gates below like any other route (those are genuine prerequisites,
/// not something an invitation link should let a user skip); only the
/// *destination* priority once those pass is handled separately, via
/// [pendingInvitationToken].
bool _isInvitationRoute(String location) => location.startsWith('/invite/');

/// "Umesahau PIN?" recovery sub-flow (prompt 05E §17) — reachable both
/// signed-out (before its own OTP verify) and signed-in (right after,
/// until a new PIN is confirmed). Deliberately exempt from the
/// PIN-credential gate below in both directions: the recovery flow
/// must not be redirected to `/auth/pin-setup` (it has its own
/// dedicated new-PIN step, `pinForgotNewPin`) nor away to the app
/// (the user has not replaced their PIN credential yet — the *old*
/// one still exists server-side, which would otherwise read as
/// "already configured" and skip straight past recovery).
const _pinRecoveryRoutes = {
  AppRoutes.pinForgotVerify,
  AppRoutes.pinForgotNewPin,
};

/// Prompt 09G-B1-D2: the sub-routes reached by pushing from
/// [AppRoutes.onboardingMembershipEntry] — the claim-flow screens plus
/// the pre-existing "create a new group instead" secondary path.
/// Deliberately NOT including the entry route itself, since that one
/// is already the correct `SelectedGroupNone` target and stays via
/// the ordinary `currentLocation == target` check below. Without this
/// exemption, pushing to any of these would be immediately redirected
/// back to the entry screen on the next redirect evaluation, since
/// none of them is the computed `target`.
const _membershipClaimFlowRoutes = {
  AppRoutes.membershipLink,
  AppRoutes.membershipClaims,
  AppRoutes.onboardingGroup,
};

/// Computes the redirect target for the current app state, or `null`
/// if [currentLocation] is already correct and no redirect is needed.
///
/// A pure function — no `BuildContext`/router dependency — so the
/// entire route decision tree is unit-testable without pumping a
/// widget tree. This is UX/navigation guidance only, never the
/// security boundary: RLS and the backend RPCs remain authoritative,
/// so a route reached by bypassing this logic (deep link, browser
/// back/forward, stale bookmark) still cannot read or mutate data the
/// backend would not otherwise allow. See docs/product/authentication.md.
///
/// Prompt 05E §31 deliberately simplified this: there is no local
/// device-lock concept any more. The only local/session state this
/// checks, in order, is: does a valid Supabase session exist, does the
/// signed-in user have a PIN credential configured server-side
/// (`hasPinCredential`, via `rpc_has_pin_credential()`), is a
/// recovery/setup route explicitly in progress, and — only once all of
/// that is resolved — the existing profile/group/operational routing
/// below.
String? computeRedirect({
  required AuthSessionStatus sessionStatus,
  required AsyncValue<AppContext?> appContext,
  required SelectedGroupState selectedGroup,
  required String currentLocation,
  required AsyncValue<bool> hasPinCredential,

  /// Prompt 09G-B1-E3 §C: the bearer token of an invitation the user
  /// was trying to reach before signing in / finishing onboarding
  /// (from [pendingInvitationTokenProvider]), or `null` if none is
  /// pending. Read fresh by the caller on every evaluation — this
  /// function stays pure/side-effect-free itself.
  String? pendingInvitationToken,

  /// Prompt 09G-B1-E3 §H: whether the invitation currently at
  /// [currentLocation] (if it is an invitation route) has just been
  /// successfully accepted by THIS specific token (from
  /// `MembershipInvitationAcceptanceController`). `/invite/:token`
  /// unconditionally holds the user in place while this is `false`
  /// (a zero-eligible-group user viewing an invitation must never be
  /// bounced to onboarding — accepting IS how they get their first
  /// group) — but once `true`, that hold is released so the normal
  /// selectedGroup-based routing below can take over and move them to
  /// their newly-linked destination, exactly like every other
  /// resolved-group transition.
  bool invitationJustAccepted = false,
}) {
  if (sessionStatus == AuthSessionStatus.configMissing) {
    // Rendered directly at '/' — nothing else is reachable without
    // configuration, so there is nowhere useful to redirect to.
    return null;
  }

  if (sessionStatus == AuthSessionStatus.signedOut) {
    // Prompt 05E §17: the recovery flow can start signed-out (before
    // its own OTP verify) — never bounced to the login screen while
    // it's already mid-flow.
    if (_pinRecoveryRoutes.contains(currentLocation)) return null;
    // Prompt 09G-B1-E3 §C: an invitation link must render its own
    // "sign in to continue" state rather than being redirected away —
    // otherwise the token would only ever reach this function's caller
    // (the router wrapper, which captures it into
    // pendingInvitationTokenProvider) on this one evaluation, then be
    // lost the moment the redirect fires.
    if (_isInvitationRoute(currentLocation)) return null;
    return _authRoutes.contains(currentLocation) ? null : AppRoutes.authPhone;
  }

  // From here on, sessionStatus == signedIn.
  if (_pinRecoveryRoutes.contains(currentLocation)) {
    // Recovery in progress — never redirected away by the
    // PIN-credential check below in either direction (see doc above).
    return null;
  }

  if (_authRoutes.contains(currentLocation)) {
    // Already authenticated; leave the login flow.
    return AppRoutes.splash;
  }

  // PIN-credential gate: no credential yet -> set one up. Resolved
  // before appContext (a network fetch) since this is what a fresh OTP
  // verify needs immediately, and should never wait on it.
  if (hasPinCredential.isLoading) {
    return currentLocation == AppRoutes.splash ? null : AppRoutes.splash;
  }
  final pinConfigured = hasPinCredential.value ?? false;
  if (!pinConfigured) {
    return currentLocation == AppRoutes.pinSetup ? null : AppRoutes.pinSetup;
  }
  if (currentLocation == AppRoutes.pinSetup) {
    // PIN already configured — nothing left to set up if somehow still
    // on this route (e.g. a stale deep link).
    return AppRoutes.splash;
  }

  // Never make a routing decision from a stale previous value while a
  // refetch is in flight (e.g. right after a user-identity change) —
  // this is part of what prevents User B from momentarily landing on
  // User A's leftover route.
  if (appContext.isLoading) {
    return currentLocation == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (appContext.hasError) {
    return currentLocation == AppRoutes.contextError
        ? null
        : AppRoutes.contextError;
  }

  final context = appContext.value;
  final profile = context?.profile;

  if (profile == null || !profile.isActive) {
    return currentLocation == AppRoutes.accessAccountDisabled
        ? null
        : AppRoutes.accessAccountDisabled;
  }

  if (!profile.isProfileComplete) {
    return currentLocation == AppRoutes.onboardingProfile
        ? null
        : AppRoutes.onboardingProfile;
  }

  // Prompt 09G-B1-E3 §H: every genuine account-level prerequisite
  // (auth, PIN, profile, active account) has now passed. As long as
  // this invitation has not just been accepted, `/invite/:token`
  // holds the user in place unconditionally — deliberately BEFORE the
  // pendingInvitationToken/selectedGroup logic below, and regardless
  // of [selectedGroup]'s own state: a zero-eligible-group user must
  // never be bounced to onboarding while viewing an invitation
  // (accepting it is how they get their first group), and a user who
  // already has a resolved group may still be viewing a DIFFERENT
  // invitation to a second one.
  if (_isInvitationRoute(currentLocation) && !invitationJustAccepted) {
    return null;
  }

  // Prompt 09G-B1-F2 §J/§K/§L: the personal invitation inbox is
  // reachable regardless of [selectedGroup]'s state — a brand-new,
  // zero-membership user (Case A) must be able to reach it exactly as
  // freely as a user who already has one or many resolved groups
  // (Cases B/C/D); it is never gated on the currently selected group's
  // permissions, since these invitations are addressed to the
  // authenticated PERSON, not the selected group. Same unconditional-
  // hold position/priority as the invitation-route check above.
  if (currentLocation == AppRoutes.myInvitations) {
    return null;
  }

  // A pending invitation destination takes priority over the normal
  // home/select-group/onboarding target — the user's explicit intent
  // (having opened the link, then been detoured through PIN/profile
  // setup) is followed through rather than silently dropped.
  if (pendingInvitationToken != null) {
    final target = AppRoutes.membershipInvitationAcceptPath(
      pendingInvitationToken,
    );
    return currentLocation == target ? null : target;
  }

  if (selectedGroup is SelectedGroupResolved) {
    // Prompt 09G-B2 §F1: an ordinary member without `member.view` must
    // not reach the Members DIRECTORY (the list screen itself) by any
    // path, including a direct URL/deep link/browser back-forward —
    // not just by hiding its nav entry points. Deliberately the exact
    // list route only, never every `/members/*` sub-route: member
    // detail/charges/etc. are independently reachable by an officer
    // holding a different, narrower permission (e.g. payment.view)
    // without also holding member.view — each such sub-route already
    // re-checks its own permission regardless of how it was reached
    // (see MemberDetailScreen's own Charges-entry gating), matching
    // this project's "nav guard ≠ enforcement" convention.
    if (currentLocation == AppRoutes.membersList &&
        !selectedGroup.membership.hasPermission('member.view')) {
      return AppRoutes.home;
    }

    // Prompt 09G-B4-C §V: My Contributions (list and detail) is gated by
    // the effective contribution.self_view permission — never by a role
    // name, and never by contribution.view (officer-wide). The backend
    // RPCs enforce the same permission; this is navigation guidance.
    if (isMyContributionsRoute(currentLocation) &&
        !selectedGroup.membership.hasPermission('contribution.self_view')) {
      return AppRoutes.home;
    }

    // Prompt 09G-B5-C §F: My Loans (list and detail) is gated by the
    // effective loan.self_view permission. Never by a role name, and never
    // by member.view, which is the Members directory. Backend RPCs enforce
    // the same permission. This is navigation guidance only.
    if (isMyLoansRoute(currentLocation) &&
        !selectedGroup.membership.hasPermission('loan.self_view')) {
      return AppRoutes.home;
    }

    // Once resolved, the user is free to navigate within the
    // operational area (home, members, ...) — only redirect them here
    // from a pre-operational route (splash, auth, onboarding, access,
    // select-group), never pin them back to exactly /home on every
    // navigation.
    return _isOperationalRoute(currentLocation) ? null : AppRoutes.home;
  }

  // Prompt 09G-B1-D2: while no eligible membership is resolved, the
  // membership-linking sub-flow (Group Code + Member Number form, own
  // claim status) is reached via context.push from
  // onboardingMembershipEntry and must never be bounced back to it —
  // these routes ARE the "no eligible group yet" experience, not
  // something the eligibility target-recompute below should override.
  if (selectedGroup is SelectedGroupNone &&
      _membershipClaimFlowRoutes.contains(currentLocation)) {
    return null;
  }

  final target = switch (selectedGroup) {
    SelectedGroupLoading() => AppRoutes.splash,
    SelectedGroupNone() => noEligibleGroupTarget(
      context?.memberships ?? const [],
    ),
    SelectedGroupPending() => AppRoutes.selectGroup,
    SelectedGroupResolved() => AppRoutes.home, // unreachable, handled above
  };

  return currentLocation == target ? null : target;
}

/// Whether [location] is `/members` or a sub-route of it — used by
/// the `member.view` denial check above, kept separate from
/// [_isOperationalRoute] so that check can run before the general
/// allowlist.
bool _isMembersRoute(String location) =>
    location == AppRoutes.membersList ||
    location.startsWith('${AppRoutes.membersList}/');

/// Routes reachable once a group is resolved — the operational
/// (non-onboarding, non-auth) part of the app.
bool _isOperationalRoute(String location) {
  return location == AppRoutes.home ||
      location == AppRoutes.more ||
      // Prompt 09G-B1-F-UAT-FIX-03: the mobile Member Management hub —
      // an ordinary operational, group-scoped screen, gated the same
      // way as the destinations it links to (each of which re-checks
      // its own permission regardless of how it was reached).
      location == AppRoutes.memberManagement ||
      // Prompt 09G-B2: the caller's own profile — always reachable
      // once a group is resolved, no permission gate (it is inherently
      // self-scoped, never another member's data).
      location == AppRoutes.myProfile ||
      // Prompt 09G-B3-C: the caller's own financial statement —
      // reachable once a group is resolved, same self-scoped
      // treatment as myProfile above. The backend RPC itself is the
      // real authorization boundary (financial_report.self_view) —
      // this is reachability only.
      location == AppRoutes.myStatement ||
      isMyContributionsRoute(location) ||
      isMyLoansRoute(location) ||
      // Prompt 09G-B1-D4 §J: once linked, the claimant's own claim
      // history remains reachable as secondary information (e.g. from
      // Member Home's own quick-access card) — deliberately NOT
      // extended to [AppRoutes.membershipLink] or
      // [AppRoutes.onboardingMembershipEntry], which correctly keep
      // auto-redirecting a now-linked user away (§I: "linked member
      // opening /membership/link should be redirected appropriately").
      location == AppRoutes.membershipClaims ||
      _isMembersRoute(location) ||
      location == AppRoutes.contributionsHome ||
      location.startsWith('${AppRoutes.contributionsHome}/') ||
      location == AppRoutes.financialAccountsList ||
      location.startsWith('${AppRoutes.financialAccountsList}/') ||
      location == AppRoutes.financeHome ||
      location.startsWith('${AppRoutes.financeHome}/') ||
      location == AppRoutes.paymentsList ||
      location.startsWith('${AppRoutes.paymentsList}/') ||
      location == AppRoutes.walletMemberPicker ||
      location.startsWith('${AppRoutes.walletMemberPicker}/') ||
      location == AppRoutes.loansHome ||
      location.startsWith('${AppRoutes.loansHome}/');
}
