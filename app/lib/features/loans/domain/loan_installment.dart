/// One scheduled repayment obligation (Prompt 09A) — PLANNED only,
/// never collectible debt until a later phase disburses/activates the
/// loan. `totalDue` always equals `principalDue + interestDue` (a
/// database GENERATED column server-side, never independently
/// editable).
class LoanInstallment {
  const LoanInstallment({
    required this.installmentNumber,
    required this.dueDate,
    required this.principalDue,
    required this.interestDue,
    required this.totalDue,
  });

  factory LoanInstallment.fromJson(Map<String, dynamic> json) {
    return LoanInstallment(
      installmentNumber: json['installment_number'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      principalDue: (json['principal_due'] as num).toDouble(),
      interestDue: (json['interest_due'] as num).toDouble(),
      totalDue: json['total_due'] != null
          ? (json['total_due'] as num).toDouble()
          : (json['principal_due'] as num).toDouble() +
                (json['interest_due'] as num).toDouble(),
    );
  }

  final int installmentNumber;
  final DateTime dueDate;
  final double principalDue;
  final double interestDue;
  final double totalDue;
}
