/// Coarse, user-presentable classification of a My Payments & Receipts
/// failure (Prompt 09G-B6-C). UI code switches on
/// [MyPaymentsFailureType] and maps it to localized copy; raw PostgREST
/// messages, SQLSTATEs, and RPC names are never displayed.
enum MyPaymentsFailureType {
  /// 42501 / 28000 — no ACTIVE membership in this group, or the caller
  /// lacks `payment.self_view`.
  notAuthorized,

  /// 22023 on the list RPC — `p_from_date` after `p_to_date`.
  invalidDateRange,

  /// 22023 on the list RPC for a non-date reason.
  invalidRequest,

  /// 22023 on a payment-scoped RPC (detail/receipt) — the payment is
  /// not visible to the caller in this group (missing, another
  /// member's, or another group's). Deliberately the same outcome for
  /// all of them — no existence oracle.
  notFound,

  /// Network error.
  network,

  /// Anything else, including a response that does not match the model.
  unexpected,
}

class MyPaymentsFailure implements Exception {
  const MyPaymentsFailure(this.type);

  final MyPaymentsFailureType type;

  @override
  String toString() => 'MyPaymentsFailure(${type.name})';
}
