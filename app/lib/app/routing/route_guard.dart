import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/app_context.dart';
import '../../features/auth/models/membership_context.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import 'app_routes.dart';

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

  return AppRoutes.onboardingGroup;
}

const _authRoutes = {AppRoutes.authPhone, AppRoutes.authVerify};

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

  if (selectedGroup is SelectedGroupResolved) {
    // Once resolved, the user is free to navigate within the
    // operational area (home, members, ...) — only redirect them here
    // from a pre-operational route (splash, auth, onboarding, access,
    // select-group), never pin them back to exactly /home on every
    // navigation.
    return _isOperationalRoute(currentLocation) ? null : AppRoutes.home;
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

/// Routes reachable once a group is resolved — the operational
/// (non-onboarding, non-auth) part of the app.
bool _isOperationalRoute(String location) {
  return location == AppRoutes.home ||
      location == AppRoutes.more ||
      location == AppRoutes.membersList ||
      location.startsWith('${AppRoutes.membersList}/') ||
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
