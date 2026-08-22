/// Abstraction over local device-scoped PIN storage. Implementations
/// must never store the PIN itself (plaintext or reversible) — only a
/// salted, one-way hash suitable for local comparison — and must key
/// storage by the authenticated Supabase user id, so one user's PIN
/// can never unlock another user's session on a shared device.
///
/// The PIN is device-local application-unlock UX layered over an
/// already-established Supabase session; it is never sent to Supabase
/// and never replaces Supabase authentication as the backend's trust
/// boundary (RLS/RPCs still only trust the Supabase JWT).
abstract class PinRepository {
  Future<bool> hasPin(String userId);

  /// Stores a new PIN for [userId], replacing any existing one.
  Future<void> setPin({required String userId, required String pin});

  /// Returns whether [pin] matches the stored PIN for [userId] (`false`
  /// if none is configured).
  Future<bool> verifyPin({required String userId, required String pin});

  /// Clears the stored PIN for [userId] — used by "Toka kabisa" (full
  /// sign out) and "Umesahau PIN?" (forgot PIN), both of which require
  /// OTP re-verification before a new PIN can be created.
  Future<void> clearPin(String userId);
}
