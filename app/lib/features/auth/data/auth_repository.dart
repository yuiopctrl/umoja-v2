/// Abstraction over phone-OTP authentication. UI/controllers depend on
/// this interface, never on the Supabase SDK directly, so tests can
/// inject a fake and so the concrete provider (Supabase Auth) can be
/// swapped later without touching UI code.
///
/// Implementations must throw [AuthFailure] (never raw SDK exceptions)
/// for anything that should be shown to the user.
abstract class AuthRepository {
  /// Requests an OTP be sent to [e164Phone] (already normalized).
  /// Self-service account creation is allowed: an unknown phone number
  /// creates a new Supabase-authenticated user through this flow.
  Future<void> sendOtp(String e164Phone);

  /// Verifies [otp] for [e164Phone]. On success, Supabase Auth persists
  /// the session itself — callers must not store tokens separately.
  Future<void> verifyOtp({required String e164Phone, required String otp});

  /// Signs the current user out. Supabase Auth owns clearing its own
  /// session storage; callers are responsible for clearing any
  /// user-scoped application state (see auth_session_provider.dart).
  Future<void> signOut();
}
