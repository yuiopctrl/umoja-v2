/// One row of `rpc_list_member_payments` — a payment-history list item.
/// Never carries allocation/wallet/cashbook detail; see [PaymentDetail]
/// for that.
class Payment {
  const Payment({
    required this.paymentId,
    required this.membershipId,
    required this.memberDisplayName,
    this.memberNumber,
    required this.financialAccountId,
    required this.financialAccountName,
    required this.amount,
    required this.effectiveAt,
    required this.paymentMethod,
    required this.receiptNumber,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      paymentId: json['payment_id'] as String,
      membershipId: json['membership_id'] as String,
      memberDisplayName: json['member_display_name'] as String,
      memberNumber: json['member_number'] as String?,
      financialAccountId: json['financial_account_id'] as String,
      financialAccountName: json['financial_account_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      paymentMethod: json['payment_method'] as String,
      receiptNumber: json['receipt_number'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String paymentId;
  final String membershipId;
  final String memberDisplayName;
  final String? memberNumber;
  final String financialAccountId;
  final String financialAccountName;
  final double amount;
  final DateTime effectiveAt;

  /// One of CASH / BANK_TRANSFER / MOBILE_MONEY / OTHER.
  final String paymentMethod;
  final String receiptNumber;

  /// One of POSTED / REVERSED.
  final String status;
  final DateTime createdAt;

  bool get isReversed => status == 'REVERSED';
}
