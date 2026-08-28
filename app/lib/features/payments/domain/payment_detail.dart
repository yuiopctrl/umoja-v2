import 'payment_allocation_line.dart';

/// Result of `rpc_get_payment_detail` — the authoritative full picture
/// of one payment: metadata, allocations, wallet credit, and cashbook
/// linkage. Flutter never reconstructs these totals itself.
class PaymentDetail {
  const PaymentDetail({
    required this.paymentId,
    required this.membershipId,
    required this.memberDisplayName,
    this.memberNumber,
    required this.financialAccountId,
    required this.financialAccountName,
    required this.amount,
    required this.effectiveAt,
    required this.paymentMethod,
    this.externalReference,
    this.notes,
    required this.receiptNumber,
    required this.status,
    required this.createdAt,
    this.reversedAt,
    this.reversalReason,
    required this.allocations,
    this.walletCreditAmount,
    required this.hasCashbookEntry,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    final walletCredit = json['wallet_credit'] as Map<String, dynamic>?;
    final cashbookEntry = json['cashbook_entry'] as Map<String, dynamic>?;
    return PaymentDetail(
      paymentId: json['payment_id'] as String,
      membershipId: json['membership_id'] as String,
      memberDisplayName: json['member_display_name'] as String,
      memberNumber: json['member_number'] as String?,
      financialAccountId: json['financial_account_id'] as String,
      financialAccountName: json['financial_account_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      paymentMethod: json['payment_method'] as String,
      externalReference: json['external_reference'] as String?,
      notes: json['notes'] as String?,
      receiptNumber: json['receipt_number'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reversedAt: json['reversed_at'] == null
          ? null
          : DateTime.parse(json['reversed_at'] as String),
      reversalReason: json['reversal_reason'] as String?,
      allocations: (json['allocations'] as List<dynamic>)
          .map(
            (item) =>
                PaymentAllocationLine.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      walletCreditAmount: walletCredit == null
          ? null
          : (walletCredit['amount'] as num).toDouble(),
      hasCashbookEntry: cashbookEntry != null,
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
  final String paymentMethod;
  final String? externalReference;
  final String? notes;
  final String receiptNumber;

  /// One of POSTED / REVERSED.
  final String status;
  final DateTime createdAt;
  final DateTime? reversedAt;
  final String? reversalReason;
  final List<PaymentAllocationLine> allocations;

  /// Amount credited to the member's wallet, if this payment exceeded
  /// allocatable debt — `null` when no wallet credit was created.
  final double? walletCreditAmount;

  /// Always `true` for any payment created after this phase shipped —
  /// present for defensiveness, never something the UI branches on to
  /// hide the reversal action.
  final bool hasCashbookEntry;

  bool get isReversed => status == 'REVERSED';
}
