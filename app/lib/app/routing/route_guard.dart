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
String? computeRedirect({
  required AuthSessionStatus sessionStatus,
  required AsyncValue<AppContext?> appContext,
  required SelectedGroupState selectedGroup,
  required String currentLocation,
}) {
  if (sessionStatus == AuthSessionStatus.configMissing) {
    // Rendered directly at '/' — nothing else is reachable without
    // configuration, so there is nowhere useful to redirect to.
    return null;
  }

  if (sessionStatus == AuthSessionStatus.signedOut) {
    return _authRoutes.contains(currentLocation) ? null : AppRoutes.authPhone;
  }

  // From here on, sessionStatus == signedIn.
  if (_authRoutes.contains(currentLocation)) {
    // Already authenticated; leave the login flow.
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
      location == AppRoutes.membersList ||
      location.startsWith('${AppRoutes.membersList}/');
}
