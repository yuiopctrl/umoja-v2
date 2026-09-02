/// One scheduled repayment obligation (Prompt 09A). PLANNED only until
/// disbursement (09B); once the loan is ACTIVE it also becomes a valid
/// Payment Engine allocation target (09C). `totalDue` always equals
/// `principalDue + interestDue` (a database GENERATED column
/// server-side, never independently editable). The
/// `*Paid`/`*Outstanding`/[status] fields are all read-model figures
/// derived server-side from allocations on every read — never a stored
/// counter, and never computed here.
class LoanInstallment {
  const LoanInstallment({
    required this.installmentNumber,
    required this.dueDate,
    required this.principalDue,
    required this.interestDue,
    required this.totalDue,
    this.principalPaid = 0,
    this.principalOutstanding,
    this.interestPaid = 0,
    this.interestOutstanding,
    this.penaltyPaid = 0,
    this.penaltyOutstanding,
    this.totalOutstanding,
    this.status,
  });

  factory LoanInstallment.fromJson(Map<String, dynamic> json) {
    final principalDue = (json['principal_due'] as num).toDouble();
    final interestDue = (json['interest_due'] as num).toDouble();
    return LoanInstallment(
      installmentNumber: json['installment_number'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      principalDue: principalDue,
      interestDue: interestDue,
      totalDue: json['total_due'] != null
          ? (json['total_due'] as num).toDouble()
          : principalDue + interestDue,
      principalPaid: json['principal_paid'] == null
          ? 0
          : (json['principal_paid'] as num).toDouble(),
      principalOutstanding: json['principal_outstanding'] == null
          ? null
          : (json['principal_outstanding'] as num).toDouble(),
      interestPaid: json['interest_paid'] == null
          ? 0
          : (json['interest_paid'] as num).toDouble(),
      interestOutstanding: json['interest_outstanding'] == null
          ? null
          : (json['interest_outstanding'] as num).toDouble(),
      penaltyPaid: json['penalty_paid'] == null
          ? 0
          : (json['penalty_paid'] as num).toDouble(),
      penaltyOutstanding: json['penalty_outstanding'] == null
          ? null
          : (json['penalty_outstanding'] as num).toDouble(),
      totalOutstanding: json['total_outstanding'] == null
          ? null
          : (json['total_outstanding'] as num).toDouble(),
      status: json['status'] as String?,
    );
  }

  final int installmentNumber;
  final DateTime dueDate;
  final double principalDue;
  final double interestDue;
  final double totalDue;

  /// Prompt 09C — always derived from allocations, never null once the
  /// loan is ACTIVE/CLOSED (null only for a pre-09C read, e.g. a still
  /// DRAFT/SUBMITTED/APPROVED loan's planned schedule).
  final double principalPaid;
  final double? principalOutstanding;
  final double interestPaid;
  final double? interestOutstanding;

  /// Prompt 09D — always derived from `loan_penalty_charges` minus
  /// active allocations, never a stored counter.
  final double penaltyPaid;
  final double? penaltyOutstanding;
  final double? totalOutstanding;

  /// UPCOMING | DUE | PARTIALLY_PAID | PAID | OVERDUE — null for a
  /// pre-disbursement schedule.
  final String? status;
}
