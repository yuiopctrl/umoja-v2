/// Coarse, user-presentable classification of a My Contributions
/// failure (Prompt 09G-B4-C). UI code switches on
/// [MyContributionsFailureType] and maps it to localized copy; raw
/// PostgREST messages, SQLSTATEs, and RPC names are never displayed.
enum MyContributionsFailureType {
  /// 42501 / 28000 — no ACTIVE membership in this group, or the caller
  /// lacks `contribution.self_view`.
  notAuthorized,

  /// 22023 on the list RPC for a non-date reason (e.g. invalid status).
  invalidRequest,

  /// 22023 on the list RPC — `p_from_date` after `p_to_date`.
  invalidDateRange,

  /// 22023 on the detail RPC — the charge is not visible to the caller
  /// in this group (missing, another member's, or another group's).
  notFound,

  /// Network error.
  network,

  /// Anything else, including a response that does not match the model.
  unexpected,
}

class MyContributionsFailure implements Exception {
  const MyContributionsFailure(this.type);

  final MyContributionsFailureType type;

  @override
  String toString() => 'MyContributionsFailure(${type.name})';
}
