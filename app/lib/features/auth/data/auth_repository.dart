/// Abstraction over phone-OTP and phone+PIN authentication. UI/
/// controllers depend on this interface, never on the Supabase SDK
/// directly, so tests can inject a fake and so the concrete provider
/// (Supabase Auth) can be swapped later without touching UI code.
///
/// Implementations must throw [AuthFailure] (never raw SDK exceptions)
/// for anything that should be shown to the user.
abstract class AuthRepository {
  /// Requests an OTP be sent to [e164Phone] (already normalized).
  /// Self-service account creation is allowed: an unknown phone number
  /// creates a new Supabase-authenticated user through this flow. OTP
  /// is used for first-time verification and PIN recovery only —
  /// prompt 05E — never as the normal returning-login path.
  Future<void> sendOtp(String e164Phone);

  /// Verifies [otp] for [e164Phone]. On success, Supabase Auth persists
  /// the session itself — callers must not store tokens separately.
  Future<void> verifyOtp({required String e164Phone, required String otp});

  /// Creates or replaces the current authenticated user's 4-digit PIN
  /// credential, via the `setup-pin` Edge Function (prompt 05E §6).
  /// Requires an existing valid Supabase session (right after OTP
  /// verify). Never sends the derived internal password anywhere —
  /// that derivation happens server-side.
  Future<void> setupPin(String pin);

  /// The normal returning-login mechanism (prompt 05E §8): phone +
  /// 4-digit PIN, verified server-side by the `pin-login` Edge
  /// Function against genuine Supabase Auth. On success, establishes
  /// the returned session through the official Supabase Auth client
  /// APIs (never manual token storage) — callers can treat this like
  /// any other successful sign-in; the auth-state stream flips and the
  /// router takes over.
  Future<void> pinLogin({required String e164Phone, required String pin});

  /// Signs the current user out. Supabase Auth owns clearing its own
  /// session storage; callers are responsible for clearing any
  /// user-scoped application state (see auth_session_provider.dart).
  /// Prompt 05E §13: this is always a real sign-out now — there is no
  /// separate local-only "lock" concept.
  Future<void> signOut();
}
