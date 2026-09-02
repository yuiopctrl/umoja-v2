/// One historical overdue installment entered while onboarding an
/// existing/migrated loan (Prompt 09D-UAT-BLOCKER-02) — input only,
/// never a server read model. A migrated loan may carry zero or more of
/// these; each is posted as its OWN `loan_installments` row (its own
/// due date, principal/interest/opening-penalty outstanding), never
/// collapsed into one synthetic arrears row.
class LoanHistoricalArrearsInstallmentInput {
  const LoanHistoricalArrearsInstallmentInput({
    required this.dueDate,
    required this.principalOutstanding,
    required this.interestOutstanding,
    this.openingPenaltyOutstanding = 0,
  });

  final DateTime dueDate;
  final double principalOutstanding;
  final double interestOutstanding;
  final double openingPenaltyOutstanding;

  double get total =>
      principalOutstanding + interestOutstanding + openingPenaltyOutstanding;
}
