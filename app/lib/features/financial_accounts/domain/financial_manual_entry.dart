/// Result of `rpc_record_manual_income()` / `rpc_record_expense()` /
/// `rpc_reverse_financial_manual_entry()` (Prompt 08B) — the posting
/// confirmation, mirroring `PaymentPostResult` from Prompt 07.
class FinancialManualEntryPostResult {
  const FinancialManualEntryPostResult({
    required this.entryId,
    required this.entryKind,
    required this.financialAccountId,
    this.categoryId,
    this.amount,
    required this.alreadyPosted,
    required this.financialAccountBalance,
  });

  factory FinancialManualEntryPostResult.fromJson(Map<String, dynamic> json) {
    return FinancialManualEntryPostResult(
      entryId: json['entry_id'] as String,
      entryKind: json['entry_kind'] as String,
      financialAccountId: json['financial_account_id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      alreadyPosted: json['already_posted'] as bool,
      financialAccountBalance: (json['financial_account_balance'] as num)
          .toDouble(),
    );
  }

  final String entryId;

  /// 'INCOME' or 'EXPENSE'.
  final String entryKind;
  final String financialAccountId;
  final String? categoryId;
  final double? amount;
  final bool alreadyPosted;

  /// The account's server-derived balance immediately after this
  /// posting — never recomputed client-side.
  final double financialAccountBalance;
}

/// Full detail of one manual income/expense entry, as returned by
/// `rpc_get_financial_manual_entry()`.
class FinancialManualEntryDetail {
  const FinancialManualEntryDetail({
    required this.entryId,
    required this.financialAccountId,
    required this.financialAccountName,
    required this.categoryId,
    required this.categoryName,
    required this.entryKind,
    required this.amount,
    required this.effectiveAt,
    this.description,
    this.reference,
    required this.status,
    this.reversedAt,
    this.reversedBy,
    this.reversalReason,
    required this.createdAt,
  });

  factory FinancialManualEntryDetail.fromJson(Map<String, dynamic> json) {
    return FinancialManualEntryDetail(
      entryId: json['entry_id'] as String,
      financialAccountId: json['financial_account_id'] as String,
      financialAccountName: json['financial_account_name'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      entryKind: json['entry_kind'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      description: json['description'] as String?,
      reference: json['reference'] as String?,
      status: json['status'] as String,
      reversedAt: json['reversed_at'] == null
          ? null
          : DateTime.parse(json['reversed_at'] as String),
      reversedBy: json['reversed_by'] as String?,
      reversalReason: json['reversal_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String entryId;
  final String financialAccountId;
  final String financialAccountName;
  final String categoryId;
  final String categoryName;

  /// 'INCOME' or 'EXPENSE'.
  final String entryKind;
  final double amount;
  final DateTime effectiveAt;
  final String? description;
  final String? reference;

  /// 'POSTED' or 'REVERSED'.
  final String status;
  final DateTime? reversedAt;
  final String? reversedBy;
  final String? reversalReason;
  final DateTime createdAt;

  bool get isIncome => entryKind == 'INCOME';
  bool get isReversed => status == 'REVERSED';
}
