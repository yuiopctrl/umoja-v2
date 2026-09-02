/// One immutable assessed loan penalty occurrence (Prompt 09D), as
/// returned by `rpc_list_loan_penalty_charges()`. Never mutable —
/// [paidAmount]/[outstandingAmount] are always server-derived from
/// active payment allocations against this charge, never a stored
/// counter.
class LoanPenaltyCharge {
  const LoanPenaltyCharge({
    required this.id,
    required this.loanAccountId,
    required this.loanInstallmentId,
    required this.installmentNumber,
    required this.assessmentDate,
    required this.sequenceNumber,
    this.origin = 'ASSESSED',
    this.penaltyType,
    this.penaltyFrequency,
    this.basisAmount,
    this.rate,
    this.fixedAmount,
    required this.penaltyAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.createdAt,
  });

  factory LoanPenaltyCharge.fromJson(Map<String, dynamic> json) {
    return LoanPenaltyCharge(
      id: json['id'] as String,
      loanAccountId: json['loan_account_id'] as String,
      loanInstallmentId: json['loan_installment_id'] as String,
      installmentNumber: json['installment_number'] as int,
      assessmentDate: DateTime.parse(json['assessment_date'] as String),
      sequenceNumber: json['sequence_number'] as int,
      origin: json['origin'] as String? ?? 'ASSESSED',
      penaltyType: json['penalty_type'] as String?,
      penaltyFrequency: json['penalty_frequency'] as String?,
      basisAmount: (json['basis_amount'] as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble(),
      fixedAmount: (json['fixed_amount'] as num?)?.toDouble(),
      penaltyAmount: (json['penalty_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      outstandingAmount: (json['outstanding_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String loanAccountId;
  final String loanInstallmentId;
  final int installmentNumber;

  /// The occurrence's own economic date (never bare `current_date`) —
  /// for a recurring occurrence, this is that occurrence's own
  /// anchored eligible date, not the date the assessment RPC was run.
  final DateTime assessmentDate;
  final int sequenceNumber;

  /// 'OPENING' (historical debt captured at migration, Prompt
  /// 09D-UAT-BLOCKER-01 — sequence_number always 0) or 'ASSESSED'
  /// (created by the 09D Penalty Engine — sequence_number 1..N).
  final String origin;

  /// 'FIXED' or 'PERCENTAGE'. Null for an OPENING charge (an inherited
  /// historical amount, not a fresh Umoja calculation).
  final String? penaltyType;

  /// 'ONCE' or 'RECURRING_MONTHLY'. Null for an OPENING charge.
  final String? penaltyFrequency;
  final double? basisAmount;
  final double? rate;
  final double? fixedAmount;
  final double penaltyAmount;
  final double paidAmount;
  final double outstandingAmount;
  final DateTime createdAt;

  bool get isOpening => origin == 'OPENING';
  bool get isFullySettled => outstandingAmount <= 0;
}

/// One `rpc_assess_loan_penalties()` run result.
class LoanPenaltyAssessmentResult {
  const LoanPenaltyAssessmentResult({
    required this.assessmentDate,
    required this.eligibleInstallmentCount,
    required this.assessedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.totalPenaltyAmount,
  });

  factory LoanPenaltyAssessmentResult.fromJson(Map<String, dynamic> json) {
    return LoanPenaltyAssessmentResult(
      assessmentDate: DateTime.parse(json['assessment_date'] as String),
      eligibleInstallmentCount: json['eligible_installment_count'] as int,
      assessedCount: json['assessed_count'] as int,
      skippedCount: json['skipped_count'] as int,
      failedCount: json['failed_count'] as int,
      totalPenaltyAmount: (json['total_penalty_amount'] as num).toDouble(),
    );
  }

  final DateTime assessmentDate;
  final int eligibleInstallmentCount;
  final int assessedCount;
  final int skippedCount;
  final int failedCount;
  final double totalPenaltyAmount;
}
