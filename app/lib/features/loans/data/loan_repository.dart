import '../domain/loan_account.dart';
import '../domain/loan_historical_arrears_installment.dart';
import '../domain/loan_migration_preview.dart';
import '../domain/loan_penalty_charge.dart';
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
    bool penaltyEnabled = false,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
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
    bool? penaltyEnabled,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
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

  // -- Workflow (Prompt 09B: Submit / Approve / Reject / Cancel /
  // Disburse) -------------------------------------------------------

  Future<LoanAccount> submitLoanAccount({
    required String groupId,
    required String loanAccountId,
  });

  Future<LoanAccount> approveLoanAccount({
    required String groupId,
    required String loanAccountId,
  });

  Future<LoanAccount> rejectLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String reason,
  });

  /// SUBMITTED/APPROVED only — DRAFT cancellation stays on
  /// [cancelDraftLoanAccount].
  Future<LoanAccount> cancelLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String reason,
  });

  Future<LoanAccount> disburseLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required DateTime effectiveAt,
    String? reference,
    String? notes,
    String? idempotencyKey,
  });

  // -- Penalties (Prompt 09D) ---------------------------------------------

  /// Server-authoritative penalty assessment. Never computed/posted by
  /// Flutter — [loanAccountId] optionally scopes the run to one loan;
  /// omitted, it assesses every eligible loan in the group.
  Future<LoanPenaltyAssessmentResult> assessLoanPenalties({
    required String groupId,
    required DateTime assessmentDate,
    String? loanAccountId,
  });

  /// Authoritative penalty history for one loan (optionally one
  /// installment).
  Future<List<LoanPenaltyCharge>> listLoanPenaltyCharges({
    required String groupId,
    required String loanAccountId,
    String? loanInstallmentId,
  });

  // -- Existing/opening loan onboarding (Prompt 09D-UAT-BLOCKER-01) -------

  /// The sole, atomic way to onboard a loan already funded before the
  /// group started using Umoja. Creates zero cash movement, zero
  /// income/expense, zero payment/receipt, and zero loan_disbursements
  /// row — it recognizes an opening funded principal receivable
  /// directly. Never requires a Financial Account.
  Future<LoanAccount> createMigratedLoan({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double originalPrincipal,
    required DateTime originalDisbursementDate,
    required DateTime openingAsOfDate,
    required double openingPrincipalOutstanding,
    List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments =
        const [],
    required double futureScheduledInterest,
    required int remainingInstallmentCount,
    DateTime? nextDueDate,
    String? originalLoanNumber,
    String? notes,
    String? idempotencyKey,
    String mode = 'DETAILED',
    double? contractedInterestAmount,
    double? monthlyInstallmentAmount,
    int? historicalUnpaidCount,
    double? totalHistoricalArrears,
    int? originalTerm,
  });

  /// Server-authoritative, non-persisting preview of a migrated-loan
  /// import (Prompt 09D-UAT-BLOCKER-03) — required before
  /// [createMigratedLoan] is ever called. Touches zero tables; posting
  /// always recomputes the same figures independently.
  Future<LoanMigrationPreview> previewMigratedLoan({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double originalPrincipal,
    required DateTime openingAsOfDate,
    double? openingPrincipalOutstanding,
    List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments =
        const [],
    double futureScheduledInterest = 0,
    int remainingInstallmentCount = 0,
    DateTime? nextDueDate,
    String mode = 'DETAILED',
    double? contractedInterestAmount,
    double? monthlyInstallmentAmount,
    int? historicalUnpaidCount,
    double? totalHistoricalArrears,
    int? originalTerm,
  });
}
