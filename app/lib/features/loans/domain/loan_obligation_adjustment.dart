// Prompt 09F-A: Loan Waivers & Corrections — read-only, server-computed
// domain models. Flutter never computes an authoritative waived/
// corrected amount itself; it only renders what the server returns and
// always re-previews before confirming (same discipline as Prompt 09E's
// early settlement/prepayment/restructure models).

/// Waiver reason codes (locked, section 7). OTHER requires a non-blank
/// note.
const waiverReasonCodes = [
  'HARDSHIP',
  'COMMITTEE_DECISION',
  'GOODWILL',
  'SETTLEMENT_CONCESSION',
  'OTHER',
];

/// Correction reason codes (locked, section 7). OTHER requires a
/// non-blank note.
const correctionReasonCodes = [
  'ASSESSMENT_ERROR',
  'DATA_ENTRY_ERROR',
  'MIGRATION_ERROR',
  'OTHER',
];

/// `rpc_preview_loan_obligation_waiver`'s preview (no writes).
/// `rpc_post_loan_obligation_waiver` always re-validates/recomputes
/// independently, never trusting this preview as authoritative input.
class LoanObligationWaiverPreview {
  const LoanObligationWaiverPreview({
    required this.targetType,
    required this.targetId,
    required this.currentOutstanding,
    required this.waiverAmount,
    required this.remainingOutstanding,
    required this.cashImpact,
    required this.paymentCreated,
    required this.receiptCreated,
  });

  factory LoanObligationWaiverPreview.fromJson(Map<String, dynamic> json) {
    return LoanObligationWaiverPreview(
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      currentOutstanding: (json['current_outstanding'] as num).toDouble(),
      waiverAmount: (json['waiver_amount'] as num).toDouble(),
      remainingOutstanding: (json['remaining_outstanding'] as num).toDouble(),
      cashImpact: (json['cash_impact'] as num).toDouble(),
      paymentCreated: json['payment_created'] as bool,
      receiptCreated: json['receipt_created'] as bool,
    );
  }

  /// 'LOAN_PENALTY' or 'LOAN_INTEREST'.
  final String targetType;
  final String targetId;
  final double currentOutstanding;
  final double waiverAmount;
  final double remainingOutstanding;

  /// Always 0 — a waiver never moves cash.
  final double cashImpact;

  /// Always false — a waiver never creates a payment.
  final bool paymentCreated;

  /// Always false — a waiver never creates a receipt.
  final bool receiptCreated;
}

/// `rpc_preview_loan_obligation_correction`'s preview (no writes).
/// `rpc_post_loan_obligation_correction` always re-validates/recomputes
/// independently.
class LoanObligationCorrectionPreview {
  const LoanObligationCorrectionPreview({
    required this.targetType,
    required this.targetId,
    required this.adjustmentType,
    required this.sourceOriginalAmount,
    required this.priorNetCorrections,
    required this.currentEffectiveAmount,
    required this.proposedCorrection,
    required this.newEffectiveAmount,
    required this.outstandingBefore,
    required this.outstandingAfter,
    required this.cashImpact,
    required this.paymentCreated,
    required this.receiptCreated,
  });

  factory LoanObligationCorrectionPreview.fromJson(Map<String, dynamic> json) {
    return LoanObligationCorrectionPreview(
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      adjustmentType: json['adjustment_type'] as String,
      sourceOriginalAmount: (json['source_original_amount'] as num).toDouble(),
      priorNetCorrections: (json['prior_net_corrections'] as num).toDouble(),
      currentEffectiveAmount: (json['current_effective_amount'] as num)
          .toDouble(),
      proposedCorrection: (json['proposed_correction'] as num).toDouble(),
      newEffectiveAmount: (json['new_effective_amount'] as num).toDouble(),
      outstandingBefore: (json['outstanding_before'] as num).toDouble(),
      outstandingAfter: (json['outstanding_after'] as num).toDouble(),
      cashImpact: (json['cash_impact'] as num).toDouble(),
      paymentCreated: json['payment_created'] as bool,
      receiptCreated: json['receipt_created'] as bool,
    );
  }

  final String targetType;
  final String targetId;

  /// 'CORRECTION_DECREASE' or 'CORRECTION_INCREASE'.
  final String adjustmentType;

  /// The original, immutable, never-rewritten assessment amount.
  final double sourceOriginalAmount;

  /// The net effect of every prior waiver/correction on this target,
  /// before this one.
  final double priorNetCorrections;
  final double currentEffectiveAmount;

  /// Signed: negative for a decrease, positive for an increase.
  final double proposedCorrection;
  final double newEffectiveAmount;
  final double outstandingBefore;
  final double outstandingAfter;

  /// Always 0 — a correction never moves cash merely by being posted.
  final double cashImpact;
  final bool paymentCreated;
  final bool receiptCreated;
}

/// The result of a confirmed `rpc_post_loan_obligation_waiver` /
/// `rpc_post_loan_obligation_correction` post.
class LoanObligationAdjustmentPostResult {
  const LoanObligationAdjustmentPostResult({
    required this.adjustmentId,
    required this.targetType,
    required this.adjustmentType,
    required this.amount,
    required this.outstandingAfter,
    required this.alreadyPosted,
    required this.loanStatus,
  });

  factory LoanObligationAdjustmentPostResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return LoanObligationAdjustmentPostResult(
      adjustmentId: json['adjustment_id'] as String,
      targetType: json['target_type'] as String,
      adjustmentType: json['adjustment_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      outstandingAfter: json['outstanding_after'] == null
          ? null
          : (json['outstanding_after'] as num).toDouble(),
      alreadyPosted: json['already_posted'] as bool,
      loanStatus: json['loan_status'] as String,
    );
  }

  final String adjustmentId;
  final String targetType;

  /// 'WAIVER', 'CORRECTION_DECREASE', or 'CORRECTION_INCREASE'.
  final String adjustmentType;

  /// Signed accounting effect (negative for waiver/decrease, positive
  /// for increase).
  final double amount;
  final double? outstandingAfter;
  final bool alreadyPosted;
  final String loanStatus;
}

/// The result of a confirmed `rpc_reverse_loan_obligation_adjustment`
/// post.
class LoanObligationAdjustmentReversalResult {
  const LoanObligationAdjustmentReversalResult({
    required this.reversalId,
    required this.reversedAdjustmentId,
    required this.targetType,
    required this.reversedAmount,
    required this.outstandingAfter,
    required this.loanStatus,
  });

  factory LoanObligationAdjustmentReversalResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return LoanObligationAdjustmentReversalResult(
      reversalId: json['reversal_id'] as String,
      reversedAdjustmentId: json['reversed_adjustment_id'] as String,
      targetType: json['target_type'] as String,
      reversedAmount: (json['reversed_amount'] as num).toDouble(),
      outstandingAfter: (json['outstanding_after'] as num).toDouble(),
      loanStatus: json['loan_status'] as String,
    );
  }

  final String reversalId;
  final String reversedAdjustmentId;
  final String targetType;
  final double reversedAmount;
  final double outstandingAfter;
  final String loanStatus;
}

/// One immutable row from `rpc_list_loan_obligation_adjustments` — the
/// authoritative "Adjustments & Waivers" history for a loan. Never
/// editable/deletable from the UI; only [isReversed]/[reversedByAdjustmentId]
/// distinguish a still-live effect from a reversed one.
class LoanObligationAdjustment {
  const LoanObligationAdjustment({
    required this.id,
    required this.targetType,
    this.loanPenaltyChargeId,
    this.loanInstallmentId,
    this.installmentNumber,
    required this.adjustmentType,
    required this.amount,
    required this.reasonCode,
    this.note,
    required this.effectiveDate,
    required this.createdAt,
    this.createdBy,
    this.reversesAdjustmentId,
    required this.isReversed,
    this.reversedByAdjustmentId,
  });

  factory LoanObligationAdjustment.fromJson(Map<String, dynamic> json) {
    return LoanObligationAdjustment(
      id: json['id'] as String,
      targetType: json['target_type'] as String,
      loanPenaltyChargeId: json['loan_penalty_charge_id'] as String?,
      loanInstallmentId: json['loan_installment_id'] as String?,
      installmentNumber: json['installment_number'] as int?,
      adjustmentType: json['adjustment_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      reasonCode: json['reason_code'] as String,
      note: json['note'] as String?,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      reversesAdjustmentId: json['reverses_adjustment_id'] as String?,
      isReversed: json['is_reversed'] as bool,
      reversedByAdjustmentId: json['reversed_by_adjustment_id'] as String?,
    );
  }

  final String id;
  final String targetType;
  final String? loanPenaltyChargeId;
  final String? loanInstallmentId;
  final int? installmentNumber;

  /// 'WAIVER', 'CORRECTION_DECREASE', 'CORRECTION_INCREASE', or
  /// 'REVERSAL'.
  final String adjustmentType;
  final double amount;
  final String reasonCode;
  final String? note;
  final DateTime effectiveDate;
  final DateTime createdAt;
  final String? createdBy;
  final String? reversesAdjustmentId;
  final bool isReversed;
  final String? reversedByAdjustmentId;

  bool get isReversal => adjustmentType == 'REVERSAL';

  /// Client-side UX hint only — the server makes the final decision on
  /// whether a reversal is actually safe (section 26: "Server still
  /// makes final decision").
  bool get isReversalCandidate => !isReversal && !isReversed;
}

/// One page of `rpc_list_loan_obligation_adjustments`.
class LoanObligationAdjustmentPage {
  const LoanObligationAdjustmentPage({
    required this.totalCount,
    required this.items,
  });

  factory LoanObligationAdjustmentPage.fromJson(Map<String, dynamic> json) {
    return LoanObligationAdjustmentPage(
      totalCount: json['total_count'] as int,
      items: (json['items'] as List<dynamic>)
          .map(
            (item) =>
                LoanObligationAdjustment.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final int totalCount;
  final List<LoanObligationAdjustment> items;
}
