/// Coarse, user-presentable classification of a Member Statement
/// failure (Prompt 09G-B3-C). UI code should switch on
/// [MemberStatementFailureType], never pattern-match
/// [MemberStatementFailure.message] strings.
enum MemberStatementFailureType {
  /// 42501 — the caller either has no ACTIVE membership in an ACTIVE
  /// group for the requested group, or lacks
  /// `financial_report.self_view`.
  notAuthorized,

  /// 22023 — p_from_date after p_to_date.
  invalidDateRange,

  /// Network error. Check your connection and try again.
  network,

  /// Something went wrong. Please try again.
  unexpected,
}

/// A safe-to-display Member Statement failure. Never wraps a raw
/// PostgREST/Postgres exception message, SQLSTATE, RPC name, or stack
/// trace for display.
class MemberStatementFailure implements Exception {
  const MemberStatementFailure(this.type, this.message);

  final MemberStatementFailureType type;
  final String message;

  @override
  String toString() => message;
}
