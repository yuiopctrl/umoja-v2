// Prompt 09F-B: Loan Write-Off & Recovery — read-only, server-computed
// domain models. Flutter never computes an authoritative written-off or
// recovered amount itself; every action always re-previews before
// confirming (same discipline as Prompt 09F-A's waiver/correction
// models).

/// Write-off reason codes (locked, section A). OTHER requires a
/// non-blank note.
const loanWriteOffReasonCodes = [
  'PROLONGED_DEFAULT',
  'BORROWER_DECEASED',
  'BORROWER_UNTRACEABLE',
  'UNCOLLECTIBLE_COST',
  'GROUP_DECISION',
  'OTHER',
];

/// `rpc_preview_loan_write_off`'s preview (no writes).
/// [LoanWriteOffPostResult] is always independently re-validated/
/// recomputed by `rpc_post_loan_write_off`, never trusting this
/// preview.
class LoanWriteOffPreview {
  const LoanWriteOffPreview({
    required this.loanAccountId,
    required this.reasonCode,
    this.note,
    required this.effectiveDate,
    required this.principalAmount,
    required this.interestAmount,
    required this.penaltyAmount,
    required this.totalAmount,
    required this.cashImpact,
    required this.paymentCreated,
    required this.receiptCreated,
  });

  factory LoanWriteOffPreview.fromJson(Map<String, dynamic> json) {
    return LoanWriteOffPreview(
      loanAccountId: json['loan_account_id'] as String,
      reasonCode: json['reason_code'] as String,
      note: json['note'] as String?,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestAmount: (json['interest_amount'] as num).toDouble(),
      penaltyAmount: (json['penalty_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      cashImpact: (json['cash_impact'] as num).toDouble(),
      paymentCreated: json['payment_created'] as bool,
      receiptCreated: json['receipt_created'] as bool,
    );
  }

  final String loanAccountId;
  final String reasonCode;
  final String? note;
  final DateTime effectiveDate;

  /// The full remaining principal outstanding (no earned/unearned
  /// distinction — all scheduled principal, due or not).
  final double principalAmount;

  /// Earned/payable interest only (due_date <= effectiveDate) —
  /// future/unearned interest is structurally excluded and never
  /// appears anywhere in this preview.
  final double interestAmount;
  final double penaltyAmount;
  final double totalAmount;

  /// Always 0 — a write-off never moves cash.
  final double cashImpact;

  /// Always false — a write-off never creates a payment.
  final bool paymentCreated;

  /// Always false — a write-off never creates a receipt.
  final bool receiptCreated;
}

/// The result of a confirmed `rpc_post_loan_write_off` post.
class LoanWriteOffPostResult {
  const LoanWriteOffPostResult({
    required this.writeOffEventId,
    required this.loanAccountId,
    required this.principalAmount,
    required this.interestAmount,
    required this.penaltyAmount,
    required this.totalAmount,
    required this.cashImpact,
    required this.paymentCreated,
    required this.receiptCreated,
    required this.alreadyPosted,
    required this.loanStatus,
  });

  factory LoanWriteOffPostResult.fromJson(Map<String, dynamic> json) {
    return LoanWriteOffPostResult(
      writeOffEventId: json['write_off_event_id'] as String,
      loanAccountId: json['loan_account_id'] as String,
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestAmount: (json['interest_amount'] as num).toDouble(),
      penaltyAmount: (json['penalty_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      cashImpact: (json['cash_impact'] as num).toDouble(),
      paymentCreated: json['payment_created'] as bool,
      receiptCreated: json['receipt_created'] as bool,
      alreadyPosted: json['already_posted'] as bool,
      loanStatus: json['loan_status'] as String,
    );
  }

  final String writeOffEventId;
  final String loanAccountId;
  final double principalAmount;
  final double interestAmount;
  final double penaltyAmount;
  final double totalAmount;
  final double cashImpact;
  final bool paymentCreated;
  final bool receiptCreated;
  final bool alreadyPosted;

  /// Always 'WRITTEN_OFF'.
  final String loanStatus;
}

/// The result of a confirmed `rpc_reverse_loan_write_off` post.
class LoanWriteOffReversalResult {
  const LoanWriteOffReversalResult({
    required this.reversalId,
    required this.reversedWriteOffEventId,
    required this.loanAccountId,
    required this.loanStatus,
  });

  factory LoanWriteOffReversalResult.fromJson(Map<String, dynamic> json) {
    return LoanWriteOffReversalResult(
      reversalId: json['reversal_id'] as String,
      reversedWriteOffEventId: json['reversed_write_off_event_id'] as String,
      loanAccountId: json['loan_account_id'] as String,
      loanStatus: json['loan_status'] as String,
    );
  }

  final String reversalId;
  final String reversedWriteOffEventId;
  final String loanAccountId;

  /// Always 'ACTIVE'.
  final String loanStatus;
}

/// One component's remaining recoverable balance — the shared shape of
/// `remaining_before`/`remaining_after` (preview) and
/// `remaining_recoverable` (summary read model).
class LoanRecoveryComponentAmounts {
  const LoanRecoveryComponentAmounts({
    required this.principal,
    required this.interest,
    required this.penalty,
    required this.total,
  });

  factory LoanRecoveryComponentAmounts.fromJson(Map<String, dynamic> json) {
    return LoanRecoveryComponentAmounts(
      principal: (json['principal'] as num).toDouble(),
      interest: (json['interest'] as num).toDouble(),
      penalty: (json['penalty'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  final double principal;
  final double interest;
  final double penalty;
  final double total;
}

/// One recovery's PENALTY -> INTEREST -> PRINCIPAL allocation — the
/// server-authoritative split of a recovery amount against the
/// remaining recoverable balance. Flutter never recomputes this order
/// itself; it only ever renders what the server returns.
class LoanRecoveryAllocation {
  const LoanRecoveryAllocation({
    required this.penalty,
    required this.interest,
    required this.principal,
  });

  factory LoanRecoveryAllocation.fromJson(Map<String, dynamic> json) {
    return LoanRecoveryAllocation(
      penalty: (json['penalty'] as num).toDouble(),
      interest: (json['interest'] as num).toDouble(),
      principal: (json['principal'] as num).toDouble(),
    );
  }

  final double penalty;
  final double interest;
  final double principal;
}

/// `rpc_preview_loan_recovery`'s preview (no writes).
/// [LoanRecoveryPostResult] is always independently re-validated/
/// recomputed by `rpc_post_loan_recovery` after locking the loan/
/// write-off rows, never trusting this preview.
class LoanRecoveryPreview {
  const LoanRecoveryPreview({
    required this.loanAccountId,
    required this.writeOffEventId,
    required this.writeOffTotalAmount,
    required this.remainingBefore,
    required this.recoveryAmount,
    required this.allocation,
    required this.remainingAfter,
    required this.cashImpact,
    required this.paymentCreated,
    required this.receiptCreated,
  });

  factory LoanRecoveryPreview.fromJson(Map<String, dynamic> json) {
    return LoanRecoveryPreview(
      loanAccountId: json['loan_account_id'] as String,
      writeOffEventId: json['write_off_event_id'] as String,
      writeOffTotalAmount: (json['write_off_total_amount'] as num).toDouble(),
      remainingBefore: LoanRecoveryComponentAmounts.fromJson(
        json['remaining_before'] as Map<String, dynamic>,
      ),
      recoveryAmount: (json['recovery_amount'] as num).toDouble(),
      allocation: LoanRecoveryAllocation.fromJson(
        json['allocation'] as Map<String, dynamic>,
      ),
      remainingAfter: LoanRecoveryComponentAmounts.fromJson(
        json['remaining_after'] as Map<String, dynamic>,
      ),
      cashImpact: (json['cash_impact'] as num).toDouble(),
      paymentCreated: json['payment_created'] as bool,
      receiptCreated: json['receipt_created'] as bool,
    );
  }

  final String loanAccountId;
  final String writeOffEventId;
  final double writeOffTotalAmount;
  final LoanRecoveryComponentAmounts remainingBefore;
  final double recoveryAmount;
  final LoanRecoveryAllocation allocation;
  final LoanRecoveryComponentAmounts remainingAfter;

  /// Equal to [recoveryAmount] — unlike a write-off, a recovery IS a
  /// real cash event.
  final double cashImpact;

  /// Always true — a recovery always creates a real payment, reusing
  /// the existing Payment Engine.
  final bool paymentCreated;
  final bool receiptCreated;
}

/// The result of a confirmed `rpc_post_loan_recovery` post. Same full
/// shape whether this is a fresh post or an idempotent replay
/// ([alreadyPosted] true) — every field is always present.
class LoanRecoveryPostResult {
  const LoanRecoveryPostResult({
    required this.recoveryEventId,
    required this.paymentId,
    required this.receiptNumber,
    required this.loanAccountId,
    required this.writeOffEventId,
    required this.amount,
    required this.allocation,
    required this.alreadyPosted,
    required this.loanStatus,
  });

  factory LoanRecoveryPostResult.fromJson(Map<String, dynamic> json) {
    return LoanRecoveryPostResult(
      recoveryEventId: json['recovery_event_id'] as String,
      paymentId: json['payment_id'] as String,
      receiptNumber: json['receipt_number'] as String,
      loanAccountId: json['loan_account_id'] as String,
      writeOffEventId: json['write_off_event_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      allocation: LoanRecoveryAllocation.fromJson(
        json['allocation'] as Map<String, dynamic>,
      ),
      alreadyPosted: json['already_posted'] as bool,
      loanStatus: json['loan_status'] as String,
    );
  }

  final String recoveryEventId;
  final String paymentId;
  final String receiptNumber;
  final String loanAccountId;
  final String writeOffEventId;
  final double amount;
  final LoanRecoveryAllocation allocation;
  final bool alreadyPosted;

  /// Always 'WRITTEN_OFF' — a recovery never automatically reactivates
  /// the loan, regardless of how much is recovered.
  final String loanStatus;
}

/// One immutable write-off event, as returned within
/// `rpc_get_loan_write_off_summary`'s `write_off` field. `null` when
/// the loan has never been written off.
class LoanWriteOffEvent {
  const LoanWriteOffEvent({
    required this.id,
    required this.principalAmount,
    required this.interestAmount,
    required this.penaltyAmount,
    required this.totalAmount,
    required this.reasonCode,
    this.note,
    required this.effectiveDate,
    this.createdBy,
    required this.createdAt,
    required this.isReversed,
  });

  factory LoanWriteOffEvent.fromJson(Map<String, dynamic> json) {
    return LoanWriteOffEvent(
      id: json['id'] as String,
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestAmount: (json['interest_amount'] as num).toDouble(),
      penaltyAmount: (json['penalty_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      reasonCode: json['reason_code'] as String,
      note: json['note'] as String?,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isReversed: json['is_reversed'] as bool,
    );
  }

  final String id;
  final double principalAmount;
  final double interestAmount;
  final double penaltyAmount;
  final double totalAmount;
  final String reasonCode;
  final String? note;
  final DateTime effectiveDate;
  final String? createdBy;
  final DateTime createdAt;
  final bool isReversed;
}

/// One recovery in a written-off loan's recovery history, as returned
/// within `rpc_get_loan_write_off_summary`'s `recoveries` array.
class LoanRecoveryHistoryEntry {
  const LoanRecoveryHistoryEntry({
    required this.id,
    required this.paymentId,
    required this.receiptNumber,
    required this.principalRecovered,
    required this.interestRecovered,
    required this.penaltyRecovered,
    required this.totalRecovered,
    required this.effectiveAt,
    required this.paymentStatus,
    this.createdBy,
    required this.createdAt,
  });

  factory LoanRecoveryHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoanRecoveryHistoryEntry(
      id: json['id'] as String,
      paymentId: json['payment_id'] as String,
      receiptNumber: json['receipt_number'] as String,
      principalRecovered: (json['principal_recovered'] as num).toDouble(),
      interestRecovered: (json['interest_recovered'] as num).toDouble(),
      penaltyRecovered: (json['penalty_recovered'] as num).toDouble(),
      totalRecovered: (json['total_recovered'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      paymentStatus: json['payment_status'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String paymentId;
  final String receiptNumber;
  final double principalRecovered;
  final double interestRecovered;
  final double penaltyRecovered;
  final double totalRecovered;
  final DateTime effectiveAt;

  /// 'POSTED' or 'REVERSED' — a reversed recovery is excluded from
  /// every "remaining recoverable" computation but still shown here for
  /// a full, honest audit trail.
  final String paymentStatus;
  final String? createdBy;
  final DateTime createdAt;

  bool get isReversed => paymentStatus == 'REVERSED';
}

/// `rpc_get_loan_write_off_summary`'s full read model — Loan Detail's
/// single source for a WRITTEN_OFF loan's summary + recovery history.
/// [writeOff] and [remainingRecoverable] are both `null` when the loan
/// has never been written off.
class LoanWriteOffSummary {
  const LoanWriteOffSummary({
    required this.loanAccountId,
    required this.loanStatus,
    this.writeOff,
    this.remainingRecoverable,
    required this.recoveries,
  });

  factory LoanWriteOffSummary.fromJson(Map<String, dynamic> json) {
    return LoanWriteOffSummary(
      loanAccountId: json['loan_account_id'] as String,
      loanStatus: json['loan_status'] as String,
      writeOff: json['write_off'] == null
          ? null
          : LoanWriteOffEvent.fromJson(
              json['write_off'] as Map<String, dynamic>,
            ),
      remainingRecoverable: json['remaining_recoverable'] == null
          ? null
          : LoanRecoveryComponentAmounts.fromJson(
              json['remaining_recoverable'] as Map<String, dynamic>,
            ),
      recoveries: (json['recoveries'] as List<dynamic>)
          .map(
            (item) =>
                LoanRecoveryHistoryEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String loanAccountId;
  final String loanStatus;
  final LoanWriteOffEvent? writeOff;
  final LoanRecoveryComponentAmounts? remainingRecoverable;
  final List<LoanRecoveryHistoryEntry> recoveries;

  bool get hasWriteOff => writeOff != null;

  /// Client-side UX hint only — the server makes the final decision on
  /// whether a reversal is actually safe (blocked once a non-reversed
  /// recovery exists), same discipline as 09F-A's
  /// `isReversalCandidate`.
  bool get isReversalCandidate => writeOff != null && !writeOff!.isReversed;
}
