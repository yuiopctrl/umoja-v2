/// The immutable opening financial position captured when a loan is
/// onboarded as MIGRATED (Prompt 09D-UAT-BLOCKER-01) — "these are the
/// balances that existed as at [openingAsOfDate]". Never mutable after
/// posting; every "current outstanding" figure is still derived
/// server-side from the loan's own installments/penalty charges, never
/// read from here.
class LoanOpeningPosition {
  const LoanOpeningPosition({
    required this.openingAsOfDate,
    required this.originalDisbursementDate,
    this.originalLoanNumber,
    required this.originalPrincipal,
    required this.openingPrincipalOutstanding,
    required this.openingPrincipalArrears,
    required this.openingInterestArrears,
    required this.openingPenaltyArrears,
    required this.futureScheduledPrincipal,
    required this.futureScheduledInterest,
    this.arrearsDueDate,
    required this.remainingInstallmentCount,
    this.nextDueDate,
    this.notes,
    required this.createdAt,
  });

  factory LoanOpeningPosition.fromJson(Map<String, dynamic> json) {
    return LoanOpeningPosition(
      openingAsOfDate: DateTime.parse(json['opening_as_of_date'] as String),
      originalDisbursementDate: DateTime.parse(
        json['original_disbursement_date'] as String,
      ),
      originalLoanNumber: json['original_loan_number'] as String?,
      originalPrincipal: (json['original_principal'] as num).toDouble(),
      openingPrincipalOutstanding:
          (json['opening_principal_outstanding'] as num).toDouble(),
      openingPrincipalArrears: (json['opening_principal_arrears'] as num)
          .toDouble(),
      openingInterestArrears: (json['opening_interest_arrears'] as num)
          .toDouble(),
      openingPenaltyArrears: (json['opening_penalty_arrears'] as num)
          .toDouble(),
      futureScheduledPrincipal: (json['future_scheduled_principal'] as num)
          .toDouble(),
      futureScheduledInterest: (json['future_scheduled_interest'] as num)
          .toDouble(),
      arrearsDueDate: json['arrears_due_date'] == null
          ? null
          : DateTime.parse(json['arrears_due_date'] as String),
      remainingInstallmentCount: json['remaining_installment_count'] as int,
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final DateTime openingAsOfDate;

  /// May be arbitrarily far in the past — never subject to the normal
  /// NEW-loan backdate restriction, since this never creates a
  /// cashbook transaction.
  final DateTime originalDisbursementDate;
  final String? originalLoanNumber;
  final double originalPrincipal;
  final double openingPrincipalOutstanding;
  final double openingPrincipalArrears;
  final double openingInterestArrears;
  final double openingPenaltyArrears;
  final double futureScheduledPrincipal;
  final double futureScheduledInterest;
  final DateTime? arrearsDueDate;
  final int remainingInstallmentCount;
  final DateTime? nextDueDate;
  final String? notes;
  final DateTime createdAt;

  bool get hasArrears =>
      openingPrincipalArrears > 0 ||
      openingInterestArrears > 0 ||
      openingPenaltyArrears > 0;
}
