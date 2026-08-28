import 'payment_allocation_line.dart';

/// Result of `rpc_get_receipt` — the always-exactly-one-per-payment
/// receipt projection. Remains valid after later debt changes; it
/// reflects what was true and posted at payment time.
class Receipt {
  const Receipt({
    required this.receiptNumber,
    required this.paymentId,
    required this.memberDisplayName,
    this.memberNumber,
    required this.financialAccountName,
    required this.amount,
    required this.effectiveAt,
    required this.paymentMethod,
    required this.status,
    required this.allocations,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      receiptNumber: json['receipt_number'] as String,
      paymentId: json['payment_id'] as String,
      memberDisplayName: json['member_display_name'] as String,
      memberNumber: json['member_number'] as String?,
      financialAccountName: json['financial_account_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      allocations: (json['allocations'] as List<dynamic>)
          .map(
            (item) => PaymentAllocationLine.fromReceiptJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  final String receiptNumber;
  final String paymentId;
  final String memberDisplayName;
  final String? memberNumber;
  final String financialAccountName;
  final double amount;
  final DateTime effectiveAt;
  final String paymentMethod;

  /// One of POSTED / REVERSED — a reversed payment's receipt still
  /// renders, clearly labeled, never hidden or deleted.
  final String status;
  final List<PaymentAllocationLine> allocations;

  bool get isReversed => status == 'REVERSED';
}
