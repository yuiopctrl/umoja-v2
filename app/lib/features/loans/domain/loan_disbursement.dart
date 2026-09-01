/// The one immutable disbursement record for a loan account (Prompt
/// 09B), present only once `rpc_disburse_loan_account()` has actually
/// succeeded. A loan account can have at most one of these — 09B
/// implements a single full-principal disbursement, never partial/
/// multiple tranches.
class LoanDisbursement {
  const LoanDisbursement({
    required this.id,
    required this.financialAccountId,
    required this.financialAccountName,
    required this.amount,
    required this.effectiveAt,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory LoanDisbursement.fromJson(Map<String, dynamic> json) {
    return LoanDisbursement(
      id: json['id'] as String,
      financialAccountId: json['financial_account_id'] as String,
      financialAccountName: json['financial_account_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String financialAccountId;
  final String financialAccountName;

  /// Always exactly the loan's frozen `principal_amount` — 09B never
  /// allows an arbitrary operator-entered amount.
  final double amount;
  final DateTime effectiveAt;
  final String? reference;
  final String? notes;
  final DateTime createdAt;
}
