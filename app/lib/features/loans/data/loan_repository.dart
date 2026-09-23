import '../domain/loan_account.dart';
import '../domain/loan_historical_arrears_installment.dart';
import '../domain/loan_migration_preview.dart';
import '../domain/loan_obligation_adjustment.dart';
import '../domain/loan_penalty_charge.dart';
import '../domain/loan_product.dart';
import '../domain/loan_schedule_preview.dart';
import '../domain/loan_servicing.dart';
import '../domain/loan_write_off_recovery.dart';

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

  // -- Loan servicing: Early Settlement, Principal Prepayment,
  // Restructure (Prompt 09E) ----------------------------------------------

  /// Server-authoritative, non-persisting quote (Prompt 09E section 1).
  /// [settleLoanEarly] always recomputes the total itself; this quote
  /// is never submitted back as authoritative input.
  Future<LoanEarlySettlementQuote> previewLoanEarlySettlement({
    required String groupId,
    required String loanAccountId,
    DateTime? effectiveDate,
  });

  /// Explicit full early settlement — pays every outstanding penalty,
  /// every currently-payable interest, and every outstanding principal
  /// (including not-yet-due), and closes the loan once every component
  /// reaches zero.
  Future<LoanServicingPaymentResult> settleLoanEarly({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  });

  /// Server-authoritative, non-persisting preview (Prompt 09E section
  /// 3/4). [prepayLoanPrincipal] always re-validates and recomputes
  /// independently.
  Future<LoanPrepaymentPreview> previewLoanPrepayment({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    DateTime? effectiveDate,
  });

  /// Explicit partial principal prepayment. Blocked while any overdue/
  /// currently-payable penalty or interest remains outstanding.
  Future<LoanServicingPaymentResult> prepayLoanPrincipal({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  });

  /// Server-authoritative, non-persisting preview (Prompt 09E section
  /// 6). [restructureLoan] always re-validates and recomputes
  /// independently. Blocked while any overdue balance of any kind
  /// remains outstanding.
  Future<LoanRestructurePreview> previewLoanRestructure({
    required String groupId,
    required String loanAccountId,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  });

  /// Explicit, permissioned restructure — changes the future
  /// contractual schedule only; already-paid history is never touched.
  Future<LoanAccount> restructureLoan({
    required String groupId,
    required String loanAccountId,
    required String reason,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  });

  // -- Waivers & Corrections (Prompt 09F-A) -------------------------------

  /// Server-authoritative, non-persisting preview (section 9/10).
  /// [postLoanObligationWaiver] always re-validates and recomputes the
  /// current effective outstanding independently, never trusting this
  /// preview.
  Future<LoanObligationWaiverPreview> previewLoanObligationWaiver({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
  });

  /// Posts exactly one immutable WAIVER row. Zero payment/receipt/
  /// wallet/cashbook/income.
  Future<LoanObligationAdjustmentPostResult> postLoanObligationWaiver({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
    String? idempotencyKey,
  });

  /// Server-authoritative, non-persisting preview (section 11/12/13).
  /// [postLoanObligationCorrection] always re-validates and recomputes
  /// independently.
  Future<LoanObligationCorrectionPreview> previewLoanObligationCorrection({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required String adjustmentType,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
  });

  /// Posts exactly one immutable CORRECTION_DECREASE/CORRECTION_INCREASE
  /// row. The original assessment/installment is never edited.
  Future<LoanObligationAdjustmentPostResult> postLoanObligationCorrection({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required String adjustmentType,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
    String? idempotencyKey,
  });

  /// Append-only reversal — the original adjustment is never edited.
  /// Blocked server-side if later dependent activity exists on the same
  /// target (section 17).
  Future<LoanObligationAdjustmentReversalResult>
  reverseLoanObligationAdjustment({
    required String groupId,
    required String adjustmentId,
    required String reversalReason,
  });

  /// Paginated, authoritative adjustment/waiver history for one loan,
  /// newest first (section 23).
  Future<LoanObligationAdjustmentPage> listLoanObligationAdjustments({
    required String groupId,
    required String loanAccountId,
    int limit = 50,
    int offset = 0,
  });

  // -- Write-off & Recovery (Prompt 09F-B) -------------------------------

  /// Server-authoritative, non-persisting preview of a FULL loan
  /// write-off (v1 — no arbitrary partial write-off). Future/unearned
  /// interest is never included. [postLoanWriteOff] always
  /// re-validates and recomputes independently, never trusting this
  /// preview.
  Future<LoanWriteOffPreview> previewLoanWriteOff({
    required String groupId,
    required String loanAccountId,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
  });

  /// Posts exactly one immutable WRITE_OFF row and flips the loan to
  /// WRITTEN_OFF. Zero payment/receipt/wallet/cashbook/income.
  Future<LoanWriteOffPostResult> postLoanWriteOff({
    required String groupId,
    required String loanAccountId,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
    String? idempotencyKey,
  });

  /// Append-only reversal — the original WRITE_OFF row is never edited.
  /// Blocked server-side once any non-reversed recovery exists against
  /// it.
  Future<LoanWriteOffReversalResult> reverseLoanWriteOff({
    required String groupId,
    required String writeOffEventId,
    required String reversalReason,
  });

  /// Server-authoritative, non-persisting preview of a recovery against
  /// a written-off loan's remaining recoverable balance. Allocation is
  /// always PENALTY -> INTEREST -> PRINCIPAL, computed server-side.
  /// [postLoanRecovery] always re-validates and recomputes
  /// independently after locking the loan/write-off rows.
  Future<LoanRecoveryPreview> previewLoanRecovery({
    required String groupId,
    required String loanAccountId,
    required double amount,
    DateTime? effectiveDate,
  });

  /// Records a real cash recovery, reusing the existing Payment Engine
  /// (payments/financial_account_post_entry/payment_allocations) —
  /// never a parallel cash mechanism. The loan is NEVER automatically
  /// reactivated by a recovery.
  Future<LoanRecoveryPostResult> postLoanRecovery({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  });

  /// The most recent write-off event (if any), its live remaining
  /// recoverable balance, and full recovery history for Loan Detail.
  Future<LoanWriteOffSummary> getLoanWriteOffSummary({
    required String groupId,
    required String loanAccountId,
  });
}
