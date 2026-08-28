/// Result of `rpc_record_financial_account_transfer()` — both
/// [fromBalance]/[toBalance] are the server-derived post-transfer
/// balances, never computed client-side.
class FinancialAccountTransferResult {
  const FinancialAccountTransferResult({
    required this.transferReference,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.alreadyPosted,
    required this.fromBalance,
    required this.toBalance,
  });

  factory FinancialAccountTransferResult.fromJson(Map<String, dynamic> json) {
    return FinancialAccountTransferResult(
      transferReference: json['transfer_reference'] as String,
      fromAccountId: json['from_account_id'] as String,
      toAccountId: json['to_account_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      alreadyPosted: json['already_posted'] as bool,
      fromBalance: (json['from_balance'] as num).toDouble(),
      toBalance: (json['to_balance'] as num).toDouble(),
    );
  }

  final String transferReference;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final bool alreadyPosted;
  final double fromBalance;
  final double toBalance;
}
