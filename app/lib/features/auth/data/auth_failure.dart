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
