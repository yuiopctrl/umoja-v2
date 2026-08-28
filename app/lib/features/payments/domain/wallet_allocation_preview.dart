import 'payment_allocation_line.dart';

/// Result of `rpc_preview_wallet_allocation` — non-posting preview for
/// manually applying wallet balance against outstanding obligations.
class WalletAllocationPreview {
  const WalletAllocationPreview({
    required this.membershipId,
    required this.walletBalance,
    required this.amount,
    required this.allocations,
    required this.totalAllocated,
  });

  factory WalletAllocationPreview.fromJson(Map<String, dynamic> json) {
    return WalletAllocationPreview(
      membershipId: json['membership_id'] as String,
      walletBalance: (json['wallet_balance'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      allocations: (json['allocations'] as List<dynamic>)
          .map(
            (item) => PaymentAllocationLine.fromPreviewJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      totalAllocated: (json['total_allocated'] as num).toDouble(),
    );
  }

  final String membershipId;
  final double walletBalance;
  final double amount;
  final List<PaymentAllocationLine> allocations;
  final double totalAllocated;
}
