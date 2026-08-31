/// One row of a member's wallet ledger (`rpc_list_member_wallet_entries`).
class WalletEntry {
  const WalletEntry({
    required this.entryId,
    required this.entryType,
    required this.amount,
    required this.effectiveAt,
    this.sourceType,
    this.sourceId,
    this.sourceReceiptNumber,
    required this.createdAt,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> json) {
    return WalletEntry(
      entryId: json['entry_id'] as String,
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as String?,
      sourceReceiptNumber: json['source_receipt_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String entryId;

  /// One of PAYMENT_CREDIT / ALLOCATION_DEBIT / REVERSAL.
  final String entryType;
  final double amount;
  final DateTime effectiveAt;
  final String? sourceType;
  final String? sourceId;

  /// The originating payment's receipt number (UAT-FIX-02) — populated
  /// server-side only for a PAYMENT_CREDIT entry sourced from a
  /// payment (`source_type = 'PAYMENT'`). Never reconstructed
  /// client-side; null for ALLOCATION_DEBIT/REVERSAL entries.
  final String? sourceReceiptNumber;
  final DateTime createdAt;

  bool get isCredit => entryType == 'PAYMENT_CREDIT';
}
