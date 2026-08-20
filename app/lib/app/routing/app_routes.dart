/// Centralized route paths. Screens and redirect logic should always
/// reference these constants rather than string literals, so the route
/// map stays a single source of truth.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';

  static const authPhone = '/auth/phone';
  static const authVerify = '/auth/verify';

  static const onboardingProfile = '/onboarding/profile';
  static const onboardingGroup = '/onboarding/group';

  static const selectGroup = '/select-group';

  static const accessAccountDisabled = '/access/account-disabled';
  static const accessMembershipRestricted = '/access/membership-restricted';
  static const accessGroupSuspended = '/access/group-suspended';
  static const accessGroupClosed = '/access/group-closed';

  /// Not one of the prompt's suggested routes, but required by the
  /// "distinguish auth failure from context-loading failure" behavior:
  /// shown when `rpc_get_my_context()` fails for a signed-in user
  /// (network/server error), offering Retry/Sign Out without treating
  /// it as an authentication failure.
  static const contextError = '/access/context-error';

  static const home = '/home';

  static const membersList = '/members';
  static const memberNew = '/members/new';

  /// Path template; use [memberDetailPath] to build a concrete URL.
  static const memberDetail = '/members/:membershipId';

  /// Path template; use [memberEditPath] to build a concrete URL.
  static const memberEdit = '/members/:membershipId/edit';

  static String memberDetailPath(String membershipId) =>
      '/members/$membershipId';
  static String memberEditPath(String membershipId) =>
      '/members/$membershipId/edit';
}
