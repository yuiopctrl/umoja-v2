/// Result of `rpc_post_payment` — everything the success/receipt step
/// needs without a second round-trip.
class PaymentPostResult {
  const PaymentPostResult({
    required this.paymentId,
    required this.receiptNumber,
    required this.membershipId,
    required this.financialAccountId,
    required this.amount,
    required this.totalAllocated,
    required this.walletCreditAmount,
    required this.alreadyPosted,
  });

  factory PaymentPostResult.fromJson(Map<String, dynamic> json) {
    return PaymentPostResult(
      paymentId: json['payment_id'] as String,
      receiptNumber: json['receipt_number'] as String,
      membershipId: json['membership_id'] as String,
      financialAccountId: json['financial_account_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      totalAllocated: (json['total_allocated'] as num).toDouble(),
      walletCreditAmount: (json['wallet_credit_amount'] as num).toDouble(),
      alreadyPosted: json['already_posted'] as bool,
    );
  }

  final String paymentId;
  final String receiptNumber;
  final String membershipId;
  final String financialAccountId;
  final double amount;
  final double totalAllocated;
  final double walletCreditAmount;

  /// `true` when this call was an idempotent retry that returned the
  /// original payment rather than posting a second one.
  final bool alreadyPosted;
}
