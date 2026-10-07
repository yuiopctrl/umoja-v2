/// Coarse, user-presentable classification of a My Loans failure
/// (Prompt 09G-B5-C). The UI maps it to localized copy. Raw PostgREST
/// messages, SQLSTATEs, and RPC names are never displayed.
enum MemberLoansFailureType {
  /// 42501 / 28000: no ACTIVE membership in this group, or the caller
  /// lacks loan.self_view.
  notAuthorized,

  /// 22023 on a loan-scoped RPC: the loan is not visible to the caller in
  /// this group (missing, another member's, another group's, or a draft).
  /// Deliberately the same outcome for all of them.
  notFound,

  /// 22023 on the list RPC for a request reason.
  invalidRequest,

  /// Network error.
  network,

  /// Anything else, including a response that does not match the model.
  unexpected,
}

class MemberLoansFailure implements Exception {
  const MemberLoansFailure(this.type);

  final MemberLoansFailureType type;

  @override
  String toString() => 'MemberLoansFailure(${type.name})';
}
