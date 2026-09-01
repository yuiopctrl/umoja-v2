import 'loan_installment.dart';

/// The result of `rpc_preview_loan_schedule()` — computed server-side
/// before a Loan Account exists, so a member/product/terms combination
/// can be reviewed before "Save Draft" (Prompt 09A section W step 4).
/// Never authoritative on its own; the actual Loan Account creation
/// recomputes and persists the same server calculation.
class LoanSchedulePreview {
  const LoanSchedulePreview({
    required this.principalAmount,
    required this.interestRate,
    required this.interestRateBasis,
    required this.interestMethod,
    required this.term,
    required this.firstRepaymentDate,
    required this.installments,
  });

  factory LoanSchedulePreview.fromJson(Map<String, dynamic> json) {
    return LoanSchedulePreview(
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestRate: (json['interest_rate'] as num).toDouble(),
      interestRateBasis: json['interest_rate_basis'] as String,
      interestMethod: json['interest_method'] as String,
      term: json['term'] as int,
      firstRepaymentDate: DateTime.parse(
        json['first_repayment_date'] as String,
      ),
      installments: (json['installments'] as List<dynamic>)
          .map((item) => LoanInstallment.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final double principalAmount;
  final double interestRate;
  final String interestRateBasis;
  final String interestMethod;
  final int term;
  final DateTime firstRepaymentDate;
  final List<LoanInstallment> installments;

  double get totalInterest =>
      installments.fold(0.0, (sum, i) => sum + i.interestDue);
  double get totalRepayable =>
      installments.fold(0.0, (sum, i) => sum + i.totalDue);
}
