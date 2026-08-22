/// Coarse, user-presentable classification of an authentication
/// failure. UI code should switch on [AuthFailure.type] to decide what
/// to show rather than pattern-matching [AuthFailure.message] strings.
enum AuthFailureType {
  invalidPhone,
  invalidOtp,
  otpExpired,
  tooManyRequests,
  network,
  unexpected,

  /// Prompt 05E: phone-or-PIN login failed — deliberately the single,
  /// generic outcome for an unknown phone, a wrong PIN, or a phone
  /// with no PIN configured yet, so `pin-login` never reveals which
  /// (see `docs/product/authentication.md`, "no account enumeration").
  invalidCredentials,

  /// Prompt 05E: the account is temporarily locked after repeated
  /// failed PIN attempts — deliberately distinct from
  /// [invalidCredentials] (the user is told to wait, not to recheck
  /// their PIN).
  pinLocked,
}

/// A safe-to-display authentication failure. Never wraps a raw
/// stack trace or internal exception text into [message] — technical
/// details are logged separately via [AppLogger], not shown to users.
class AuthFailure implements Exception {
  const AuthFailure(this.type, this.message);

  final AuthFailureType type;
  final String message;

  @override
  String toString() => message;
}
