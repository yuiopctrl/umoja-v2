/// Centralized route paths. Screens and redirect logic should always
/// reference these constants rather than string literals, so the route
/// map stays a single source of truth.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';

  /// Prompt 05E: the normal returning-login screen — phone + 4-digit
  /// PIN, server-verified (no OTP for this case). Also the entry point
  /// for "Mara ya kwanza?" (first-time OTP verification) and
  /// "Umesahau PIN?" (recovery), both reached from here.
  static const authPhone = '/auth/phone';
  static const authVerify = '/auth/verify';

  /// Shown once, right after a fresh OTP verify, when the now-signed-in
  /// user has no PIN credential yet server-side
  /// (`rpc_has_pin_credential()`). See `docs/product/authentication.md`
  /// — there is no local device PIN storage/unlock screen any more;
  /// PIN auth is entirely server-verified (prompt 05E).
  static const pinSetup = '/auth/pin-setup';

  /// "Umesahau PIN?" recovery (prompt 05E §17) — starts from
  /// [authPhone] with a phone number (typically whatever was already
  /// typed there), sends an OTP for it, and on success proceeds to
  /// [pinForgotNewPin] to set a replacement PIN credential. Both
  /// routes provide explicit Back navigation to [authPhone] — see
  /// `AuthScreenLayout.onBack`.
  static const pinForgotVerify = '/auth/pin-recover/verify';
  static const pinForgotNewPin = '/auth/pin-recover/new-pin';

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
  static const more = '/more';

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
