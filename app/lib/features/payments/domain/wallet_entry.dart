/// One row of a member's wallet ledger (`rpc_list_member_wallet_entries`).
class WalletEntry {
  const WalletEntry({
    required this.entryId,
    required this.entryType,
    required this.amount,
    required this.effectiveAt,
    this.sourceType,
    this.sourceId,
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
  final DateTime createdAt;

  bool get isCredit => entryType == 'PAYMENT_CREDIT';
}
