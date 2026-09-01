import '../domain/loan_account.dart';
import '../domain/loan_product.dart';
import '../domain/loan_schedule_preview.dart';

/// Server-authoritative access to the Loans module (Prompt 09A —
/// products, draft loan accounts, and repayment schedules only; no
/// approval/disbursement/repayment exists yet). Every calculation
/// (schedule preview or persisted) is computed on the server; Flutter
/// only ever renders what the server returns.
abstract class LoanRepository {
  // -- Loan products ----------------------------------------------------

  Future<LoanProductPage> listLoanProducts({
    required String groupId,
    bool? isActive,
    int limit = 20,
    int offset = 0,
  });

  Future<LoanProduct> getLoanProduct({
    required String groupId,
    required String productId,
  });

  Future<LoanProduct> createLoanProduct({
    required String groupId,
    required String code,
    required String name,
    required double minimumPrincipal,
    required int minimumTerm,
    required int maximumTerm,
    required double interestRate,
    required String interestRateBasis,
    required String interestMethod,
    double? maximumPrincipal,
    String? description,
  });

  Future<LoanProduct> updateLoanProduct({
    required String groupId,
    required String productId,
    String? name,
    String? description,
    double? minimumPrincipal,
    double? maximumPrincipal,
    int? minimumTerm,
    int? maximumTerm,
    double? interestRate,
    String? interestRateBasis,
    String? interestMethod,
    bool? isActive,
  });

  // -- Loan accounts ------------------------------------------------------

  Future<LoanAccountPage> listLoanAccounts({
    required String groupId,
    String? membershipId,
    String? loanProductId,
    String? status,
    int limit = 20,
    int offset = 0,
  });

  Future<LoanAccount> getLoanAccount({
    required String groupId,
    required String loanAccountId,
  });

  Future<LoanSchedulePreview> previewLoanSchedule({
    required String groupId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
  });

  Future<LoanAccount> createDraftLoanAccount({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  });

  Future<LoanAccount> updateDraftLoanTerms({
    required String groupId,
    required String loanAccountId,
    double? principalAmount,
    int? term,
    DateTime? firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  });

  Future<LoanAccount> regenerateLoanSchedule({
    required String groupId,
    required String loanAccountId,
  });

  Future<LoanAccount> cancelDraftLoanAccount({
    required String groupId,
    required String loanAccountId,
  });
}
