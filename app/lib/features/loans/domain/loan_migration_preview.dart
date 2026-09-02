/// One installment row in a migrated-loan schedule preview (Prompt
/// 09D-UAT-BLOCKER-03) — read-only, server-computed, never persisted.
class LoanMigrationPreviewInstallment {
  const LoanMigrationPreviewInstallment({
    required this.dueDate,
    required this.principalOutstanding,
    required this.interestOutstanding,
    required this.openingPenaltyOutstanding,
    required this.totalContractualAmount,
    required this.status,
  });

  factory LoanMigrationPreviewInstallment.fromJson(Map<String, dynamic> json) {
    return LoanMigrationPreviewInstallment(
      dueDate: DateTime.parse(json['due_date'] as String),
      principalOutstanding: (json['principal_outstanding'] as num).toDouble(),
      interestOutstanding: (json['interest_outstanding'] as num).toDouble(),
      openingPenaltyOutstanding: (json['opening_penalty_outstanding'] as num)
          .toDouble(),
      totalContractualAmount: (json['total_contractual_amount'] as num)
          .toDouble(),
      status: json['status'] as String,
    );
  }

  final DateTime dueDate;
  final double principalOutstanding;
  final double interestOutstanding;
  final double openingPenaltyOutstanding;
  final double totalContractualAmount;

  /// 'OVERDUE' (historical) or 'UPCOMING' (future) — informational only,
  /// never itself a payability signal (see docs/product/loans.md).
  final String status;
}

/// The full server-authoritative preview of a migrated loan import
/// (Prompt 09D-UAT-BLOCKER-03) — returned by `rpc_preview_migrated_loan`
/// WITHOUT persisting anything. Posting (`rpc_create_migrated_loan`)
/// always recomputes these figures itself from the raw contract
/// inputs; this preview is never submitted back as authoritative input.
class LoanMigrationPreview {
  const LoanMigrationPreview({
    required this.mode,
    this.paidBeforeUmojaCount,
    required this.historicalInstallments,
    required this.futureInstallments,
    this.contractualHistoricalArrears,
    this.legacyPenaltyTotal,
    required this.historicalPrincipalTotal,
    required this.historicalInterestTotal,
    required this.historicalPenaltyTotal,
    required this.totalHistoricalArrears,
    required this.openingPrincipalOutstanding,
    required this.futureScheduledPrincipal,
    required this.futureScheduledInterest,
    required this.futureContractualTotal,
  });

  factory LoanMigrationPreview.fromJson(Map<String, dynamic> json) {
    return LoanMigrationPreview(
      mode: json['mode'] as String,
      paidBeforeUmojaCount: json['paid_before_umoja_count'] as int?,
      historicalInstallments: (json['historical_installments'] as List<dynamic>)
          .map(
            (item) => LoanMigrationPreviewInstallment.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      futureInstallments: (json['future_installments'] as List<dynamic>)
          .map(
            (item) => LoanMigrationPreviewInstallment.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      contractualHistoricalArrears:
          (json['contractual_historical_arrears'] as num?)?.toDouble(),
      legacyPenaltyTotal: (json['legacy_penalty_total'] as num?)?.toDouble(),
      historicalPrincipalTotal: (json['historical_principal_total'] as num)
          .toDouble(),
      historicalInterestTotal: (json['historical_interest_total'] as num)
          .toDouble(),
      historicalPenaltyTotal: (json['historical_penalty_total'] as num)
          .toDouble(),
      totalHistoricalArrears: (json['total_historical_arrears'] as num)
          .toDouble(),
      openingPrincipalOutstanding:
          (json['opening_principal_outstanding'] as num).toDouble(),
      futureScheduledPrincipal: (json['future_scheduled_principal'] as num)
          .toDouble(),
      futureScheduledInterest: (json['future_scheduled_interest'] as num)
          .toDouble(),
      futureContractualTotal: (json['future_contractual_total'] as num)
          .toDouble(),
    );
  }

  /// 'SIMPLE' or 'DETAILED'.
  final String mode;

  /// Non-null only in SIMPLE mode (Prompt 09D-UAT-BLOCKER-04) —
  /// `original_term - historical_unpaid_count - remaining_future_count`.
  /// These installments are historical contract context only: never
  /// persisted as `loan_installments` rows, never a fake payment/
  /// receipt/cashbook entry.
  final int? paidBeforeUmojaCount;
  final List<LoanMigrationPreviewInstallment> historicalInstallments;
  final List<LoanMigrationPreviewInstallment> futureInstallments;

  /// Non-null only in SIMPLE mode — unpaid_count x monthly_installment.
  final double? contractualHistoricalArrears;

  /// Non-null only in SIMPLE mode — the brought-forward opening/legacy
  /// penalty balance (total_historical_arrears minus
  /// [contractualHistoricalArrears]), never a reconstruction of actual
  /// historical penalty assessment history.
  final double? legacyPenaltyTotal;

  final double historicalPrincipalTotal;
  final double historicalInterestTotal;
  final double historicalPenaltyTotal;
  final double totalHistoricalArrears;
  final double openingPrincipalOutstanding;
  final double futureScheduledPrincipal;
  final double futureScheduledInterest;

  /// Informational only (SIMPLE mode: remaining_count x
  /// monthly_installment_amount) — distinct from
  /// [futureScheduledPrincipal] + [futureScheduledInterest], which is
  /// the exact accounting complement that actually gets persisted.
  final double futureContractualTotal;
}
