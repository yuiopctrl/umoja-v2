/// Coarse, user-presentable classification of a My Profile failure
/// (Prompt 09G-B2). UI code should switch on
/// [MemberProfileFailure.type], never pattern-match
/// [MemberProfileFailure.message] strings.
enum MemberProfileFailureType {
  /// 42501 — the caller has no ACTIVE membership in an ACTIVE group
  /// for the requested `p_group_id` (also covers an inactive caller
  /// profile — see `current_membership_id()`).
  noActiveMembership,

  /// Network error. Check your connection and try again.
  network,

  /// Something went wrong. Please try again.
  unexpected,
}

/// A safe-to-display My Profile failure. Never wraps a raw
/// PostgREST/Postgres exception message, SQLSTATE, RPC name, or stack
/// trace for display — [message] is an English fallback for logging
/// only.
class MemberProfileFailure implements Exception {
  const MemberProfileFailure(this.type, this.message);

  final MemberProfileFailureType type;
  final String message;

  @override
  String toString() => message;
}
