/// One `financial_account_entries` row (Prompt 08A) — one line of the
/// immutable cashbook for a single account, as returned by
/// `rpc_list_financial_account_entries()`. [amount] is always
/// positive; [entryType] carries the sign meaning.
class FinancialAccountEntry {
  const FinancialAccountEntry({
    required this.entryId,
    required this.entryType,
    required this.amount,
    required this.effectiveAt,
    this.description,
    this.reference,
    this.transferReference,
    this.sourceType,
    this.sourceId,
    this.reversesEntryId,
    required this.createdAt,
    this.createdBy,
    this.counterpartyAccountId,
    this.counterpartyAccountName,
  });

  factory FinancialAccountEntry.fromJson(Map<String, dynamic> json) {
    return FinancialAccountEntry(
      entryId: json['entry_id'] as String,
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      description: json['description'] as String?,
      reference: json['reference'] as String?,
      transferReference: json['transfer_reference'] as String?,
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as String?,
      reversesEntryId: json['reverses_entry_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      counterpartyAccountId: json['counterparty_account_id'] as String?,
      counterpartyAccountName: json['counterparty_account_name'] as String?,
    );
  }

  final String entryId;

  /// One of INFLOW / OUTFLOW / TRANSFER_IN / TRANSFER_OUT.
  final String entryType;
  final double amount;
  final DateTime effectiveAt;
  final String? description;
  final String? reference;
  final String? transferReference;
  final String? sourceType;
  final String? sourceId;
  final String? reversesEntryId;
  final DateTime createdAt;
  final String? createdBy;

  /// For TRANSFER_OUT, the destination account; for TRANSFER_IN, the
  /// source account — resolved server-side from the paired entry
  /// sharing [transferReference], never fabricated client-side. Both
  /// null for every non-transfer entry (INFLOW/OUTFLOW, including
  /// opening balances).
  final String? counterpartyAccountId;
  final String? counterpartyAccountName;

  bool get isCredit => entryType == 'INFLOW' || entryType == 'TRANSFER_IN';
}
