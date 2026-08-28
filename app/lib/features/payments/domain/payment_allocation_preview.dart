import 'payment_allocation_line.dart';

/// Result of `rpc_preview_payment_allocation` — the non-posting
/// preview shown before a payment is ever confirmed (section 41/58).
/// Computed by the exact same server-side plan `rpc_post_payment`
/// persists, so this can never diverge from what actually posts.
class PaymentAllocationPreview {
  const PaymentAllocationPreview({
    required this.membershipId,
    required this.financialAccountId,
    required this.financialAccountName,
    required this.amount,
    required this.allocations,
    required this.totalAllocated,
    required this.walletCreditAmount,
  });

  factory PaymentAllocationPreview.fromJson(Map<String, dynamic> json) {
    return PaymentAllocationPreview(
      membershipId: json['membership_id'] as String,
      financialAccountId: json['financial_account_id'] as String,
      financialAccountName: json['financial_account_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      allocations: (json['allocations'] as List<dynamic>)
          .map(
            (item) => PaymentAllocationLine.fromPreviewJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      totalAllocated: (json['total_allocated'] as num).toDouble(),
      walletCreditAmount: (json['wallet_credit_amount'] as num).toDouble(),
    );
  }

  final String membershipId;
  final String financialAccountId;
  final String financialAccountName;
  final double amount;
  final List<PaymentAllocationLine> allocations;
  final double totalAllocated;
  final double walletCreditAmount;
}
