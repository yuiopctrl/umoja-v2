/// Abstraction over safe, self-service profile edits. Only ever
/// touches columns the backend actually grants to the owning user
/// (full_name/phone/avatar_url) — never id/is_active/email/created_at.
/// See docs/database/authorization.md.
abstract class ProfileRepository {
  /// Updates the caller's own `full_name`. The backend's RLS policy
  /// and column-level grants are what actually enforce "own row,
  /// safe columns only" — this abstraction exists for testability, not
  /// as the security boundary.
  Future<void> updateFullName(String fullName);
}
