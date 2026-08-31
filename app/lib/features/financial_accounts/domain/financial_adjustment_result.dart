/// Result of `rpc_record_financial_adjustment()` (Prompt 08B) — a
/// controlled, explicit correction for a verified real-world
/// discrepancy. Never counted as ordinary income/expense.
class FinancialAdjustmentResult {
  const FinancialAdjustmentResult({
    required this.adjustmentId,
    required this.financialAccountId,
    required this.direction,
    required this.amount,
    required this.alreadyPosted,
    required this.financialAccountBalance,
  });

  factory FinancialAdjustmentResult.fromJson(Map<String, dynamic> json) {
    return FinancialAdjustmentResult(
      adjustmentId: json['adjustment_id'] as String,
      financialAccountId: json['financial_account_id'] as String,
      direction: json['direction'] as String,
      amount: (json['amount'] as num).toDouble(),
      alreadyPosted: json['already_posted'] as bool,
      financialAccountBalance: (json['financial_account_balance'] as num)
          .toDouble(),
    );
  }

  final String adjustmentId;
  final String financialAccountId;

  /// 'INCREASE' or 'DECREASE'.
  final String direction;
  final double amount;
  final bool alreadyPosted;
  final double financialAccountBalance;
}
