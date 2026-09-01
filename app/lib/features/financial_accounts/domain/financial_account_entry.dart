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
    this.paymentReceiptNumber,
    this.manualEntryCategoryId,
    this.manualEntryCategoryName,
    this.manualEntryStatus,
    this.adjustmentReason,
    this.loanDisbursementLoanAccountId,
    this.loanDisbursementLoanNumber,
    this.loanDisbursementBorrowerDisplayName,
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
      paymentReceiptNumber: json['payment_receipt_number'] as String?,
      manualEntryCategoryId: json['manual_entry_category_id'] as String?,
      manualEntryCategoryName: json['manual_entry_category_name'] as String?,
      manualEntryStatus: json['manual_entry_status'] as String?,
      adjustmentReason: json['adjustment_reason'] as String?,
      loanDisbursementLoanAccountId:
          json['loan_disbursement_loan_account_id'] as String?,
      loanDisbursementLoanNumber:
          json['loan_disbursement_loan_number'] as String?,
      loanDisbursementBorrowerDisplayName:
          json['loan_disbursement_borrower_display_name'] as String?,
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

  /// Set only when [sourceType] is 'PAYMENT' or 'PAYMENT_REVERSAL'.
  final String? paymentReceiptNumber;

  /// Set only when [sourceType] is 'MANUAL_INCOME', 'EXPENSE',
  /// 'MANUAL_INCOME_REVERSAL', or 'EXPENSE_REVERSAL'.
  final String? manualEntryCategoryId;
  final String? manualEntryCategoryName;

  /// 'POSTED' or 'REVERSED' — the underlying financial_manual_entries
  /// row's current status, so a cashbook row can tell whether it (or
  /// its reversal) is still active without a second round-trip.
  final String? manualEntryStatus;

  /// Set only when [sourceType] is 'FINANCIAL_ADJUSTMENT'.
  final String? adjustmentReason;

  /// Set only when [sourceType] is 'LOAN_DISBURSEMENT' (Prompt 09B).
  final String? loanDisbursementLoanAccountId;
  final String? loanDisbursementLoanNumber;
  final String? loanDisbursementBorrowerDisplayName;

  bool get isCredit => entryType == 'INFLOW' || entryType == 'TRANSFER_IN';
  bool get isTransfer =>
      entryType == 'TRANSFER_IN' || entryType == 'TRANSFER_OUT';
}
