import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/loan_statement.dart';

/// Centralized mapping from a `loan_products.interest_rate_basis`
/// value to its localized display label.
String loanInterestRateBasisLabel(AppLocalizations l10n, String basis) {
  return switch (basis) {
    'MONTHLY' => l10n.loanInterestRateBasisMonthly,
    'ANNUAL' => l10n.loanInterestRateBasisAnnual,
    _ => basis,
  };
}

const loanInterestRateBasisOptions = ['MONTHLY', 'ANNUAL'];

/// Centralized mapping from a `loan_products.interest_method` value
/// to its localized display label.
String loanInterestMethodLabel(AppLocalizations l10n, String method) {
  return switch (method) {
    'FLAT' => l10n.loanInterestMethodFlat,
    'REDUCING_BALANCE' => l10n.loanInterestMethodReducingBalance,
    _ => method,
  };
}

const loanInterestMethodOptions = ['FLAT', 'REDUCING_BALANCE'];

/// Centralized mapping from a `loan_accounts.status` value to its
/// localized display label. Only DRAFT and CANCELLED are reachable in
/// Prompt 09A; the rest are reserved for later phases but mapped here
/// too so the UI never shows a raw enum value.
String loanAccountStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'DRAFT' => l10n.loanStatusDraft,
    'SUBMITTED' => l10n.loanStatusSubmitted,
    'APPROVED' => l10n.loanStatusApproved,
    'REJECTED' => l10n.loanStatusRejected,
    'CANCELLED' => l10n.loanStatusCancelled,
    'DISBURSED' => l10n.loanStatusDisbursed,
    'ACTIVE' => l10n.loanStatusActive,
    'CLOSED' => l10n.loanStatusClosed,
    'WRITTEN_OFF' => l10n.loanStatusWrittenOff,
    _ => status,
  };
}

/// Centralized mapping from a `loan_accounts.status` value to the
/// badge's visual semantic (Prompt 09B, refined 09C-UAT-FIX-02) — the
/// ONE place a loan status maps to a color; never assigned ad hoc in
/// an individual screen. Distinct treatment per lifecycle stage:
///
/// - `DRAFT`: neutral — unfinished, still editable.
/// - `SUBMITTED`: info (blue) — waiting for a decision.
/// - `APPROVED`: warning (amber) — approved but not yet funded.
/// - `ACTIVE`: success (green) — funded and running. The only status
///   that reads as a strong "running" success state.
/// - `CLOSED`: neutral — completed, deliberately NOT the same strong
///   green as ACTIVE (a finished loan is not "currently running").
/// - `REJECTED`: danger (red) — a decided negative outcome.
/// - `CANCELLED`: neutral — a muted, non-alarming terminal state,
///   deliberately distinct from REJECTED's stronger red (withdrawing a
///   loan is not the same severity as having it rejected).
/// - `DISBURSED`: success — reserved for a lifecycle EVENT/timeline
///   entry only (the transactional instant a loan is funded); this
///   value is never actually observed as a resting `loan_accounts.status`
///   (disbursement moves a loan straight to ACTIVE — see
///   docs/product/loans.md), so this case is defensive, not reachable.
/// - `WRITTEN_OFF` (Prompt 09F-B): danger — a definitively negative
///   outcome (uncollectible bad debt), distinct from CLOSED/CANCELLED's
///   neutral "nothing more to see here" treatment; unlike REJECTED
///   (also danger), a written-off loan can still gain a "Reverse
///   Write-Off" action, so the color alone never implies finality here.
///
/// Every one of these six colors already exists in [UmojaStatusSemantic]
/// — no new tokens/hex values were added for this mapping.
UmojaStatusSemantic loanAccountStatusSemantic(String status) {
  return switch (status) {
    'SUBMITTED' => UmojaStatusSemantic.info,
    'APPROVED' => UmojaStatusSemantic.warning,
    'ACTIVE' || 'DISBURSED' => UmojaStatusSemantic.success,
    'REJECTED' || 'WRITTEN_OFF' => UmojaStatusSemantic.danger,
    'CLOSED' || 'CANCELLED' => UmojaStatusSemantic.neutral,
    _ => UmojaStatusSemantic.neutral, // DRAFT and any future/unknown value.
  };
}

/// Centralized mapping from a `loan_installments` component type
/// (INTEREST/PRINCIPAL/PENALTY, Prompt 09C/09D) to its localized
/// display label — shared by the loan schedule and every payment
/// allocation/receipt line that targets a loan.
String loanComponentTypeLabel(AppLocalizations l10n, String componentType) {
  return switch (componentType) {
    'INTEREST' ||
    'LOAN_INTEREST' ||
    'LOAN_RECOVERY_INTEREST' => l10n.loanComponentInterest,
    'PRINCIPAL' ||
    'LOAN_PRINCIPAL' ||
    'LOAN_PRINCIPAL_PREPAYMENT' ||
    'LOAN_RECOVERY_PRINCIPAL' => l10n.loanComponentPrincipal,
    'PENALTY' ||
    'LOAN_PENALTY' ||
    'LOAN_RECOVERY_PENALTY' => l10n.loanComponentPenalty,
    _ => componentType,
  };
}

/// Centralized mapping from `loan_products`/`loan_accounts`
/// `penalty_type` to its localized label (Prompt 09D).
String loanPenaltyTypeLabel(AppLocalizations l10n, String penaltyType) {
  return switch (penaltyType) {
    'FIXED' => l10n.loanPenaltyTypeFixed,
    'PERCENTAGE' => l10n.loanPenaltyTypePercentage,
    _ => penaltyType,
  };
}

const loanPenaltyTypeOptions = ['FIXED', 'PERCENTAGE'];

/// Centralized mapping from `penalty_frequency` to its localized label
/// (Prompt 09D).
String loanPenaltyFrequencyLabel(AppLocalizations l10n, String frequency) {
  return switch (frequency) {
    'ONCE' => l10n.loanPenaltyFrequencyOnce,
    'RECURRING_MONTHLY' => l10n.loanPenaltyFrequencyRecurringMonthly,
    _ => frequency,
  };
}

const loanPenaltyFrequencyOptions = ['ONCE', 'RECURRING_MONTHLY'];

/// A human-readable policy description, e.g. "5% of the outstanding
/// installment balance after 5 grace days, assessed once." (section 38
/// worked examples) — never rendered when penalty is disabled.
String loanPenaltyPolicyDescription(
  AppLocalizations l10n, {
  required String penaltyType,
  required String penaltyFrequency,
  required int graceDays,
  double? fixedAmount,
  double? rate,
}) {
  final isRecurring = penaltyFrequency == 'RECURRING_MONTHLY';
  if (penaltyType == 'FIXED') {
    final amount = (fixedAmount ?? 0).toStringAsFixed(0);
    return isRecurring
        ? l10n.loanPenaltyPolicyDescriptionFixedRecurring(amount, graceDays)
        : l10n.loanPenaltyPolicyDescriptionFixedOnce(amount, graceDays);
  }
  final rateText = (rate ?? 0).toStringAsFixed(1);
  return isRecurring
      ? l10n.loanPenaltyPolicyDescriptionPercentageRecurring(
          rateText,
          graceDays,
        )
      : l10n.loanPenaltyPolicyDescriptionPercentageOnce(rateText, graceDays);
}

/// Centralized mapping from an installment's derived `status` (Prompt
/// 09C — UPCOMING/DUE/PARTIALLY_PAID/PAID/OVERDUE) to its localized
/// display label.
String loanInstallmentStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'UPCOMING' => l10n.loanInstallmentStatusUpcoming,
    'DUE' => l10n.loanInstallmentStatusDue,
    'PARTIALLY_PAID' => l10n.loanInstallmentStatusPartiallyPaid,
    'PAID' => l10n.loanInstallmentStatusPaid,
    'OVERDUE' => l10n.loanInstallmentStatusOverdue,
    _ => status,
  };
}

/// Visual semantic for an installment's derived status — OVERDUE is
/// danger, PAID is success, everything else (UPCOMING/DUE/
/// PARTIALLY_PAID) is neutral (still in progress, not yet a problem).
UmojaStatusSemantic loanInstallmentStatusSemantic(String status) {
  return switch (status) {
    'OVERDUE' => UmojaStatusSemantic.danger,
    'PAID' => UmojaStatusSemantic.success,
    _ => UmojaStatusSemantic.neutral,
  };
}

/// Centralized mapping from `loan_accounts.loan_origin` to its
/// localized display label (Prompt 09G).
String loanOriginLabel(AppLocalizations l10n, String origin) {
  return switch (origin) {
    'MIGRATED' => l10n.loanOriginMigratedLabel,
    _ => l10n.loanOriginNewLabel,
  };
}

/// Centralized mapping from a Loan Statement `timeline[].event_type`
/// to its localized title (Prompt 09G). An event type this client
/// build doesn't recognize ([LoanStatementEventType.unknown]) NEVER
/// crashes or drops the event — it renders a generic, honest fallback
/// title instead (section C/O's forward-safety requirement), while the
/// event's own date/amount/reversed state are still rendered normally
/// by the caller from the event's other fields.
String loanStatementEventTitle(
  AppLocalizations l10n,
  LoanStatementEventType eventType,
) {
  return switch (eventType) {
    LoanStatementEventType.loanCreated => l10n.statementEventLoanCreated,
    LoanStatementEventType.loanSubmitted => l10n.statementEventLoanSubmitted,
    LoanStatementEventType.loanApproved => l10n.statementEventLoanApproved,
    LoanStatementEventType.loanRejected => l10n.statementEventLoanRejected,
    LoanStatementEventType.loanCancelled => l10n.statementEventLoanCancelled,
    LoanStatementEventType.loanDisbursed => l10n.statementEventLoanDisbursed,
    LoanStatementEventType.loanClosed => l10n.statementEventLoanClosed,
    LoanStatementEventType.loanReopened => l10n.statementEventLoanReopened,
    LoanStatementEventType.loanMigrated => l10n.statementEventLoanMigrated,
    LoanStatementEventType.earlySettlement =>
      l10n.statementEventEarlySettlement,
    LoanStatementEventType.paymentPosted => l10n.statementEventPaymentPosted,
    LoanStatementEventType.penaltyAssessed =>
      l10n.statementEventPenaltyAssessed,
    LoanStatementEventType.obligationWaiver =>
      l10n.statementEventObligationWaiver,
    LoanStatementEventType.obligationCorrectionIncrease =>
      l10n.statementEventObligationCorrectionIncrease,
    LoanStatementEventType.obligationCorrectionDecrease =>
      l10n.statementEventObligationCorrectionDecrease,
    LoanStatementEventType.obligationAdjustmentReversed =>
      l10n.statementEventObligationAdjustmentReversed,
    LoanStatementEventType.principalPrepayment =>
      l10n.statementEventPrincipalPrepayment,
    LoanStatementEventType.loanRestructured =>
      l10n.statementEventLoanRestructured,
    LoanStatementEventType.writeOff => l10n.statementEventWriteOff,
    LoanStatementEventType.writeOffReversed =>
      l10n.statementEventWriteOffReversed,
    LoanStatementEventType.recoveryPosted => l10n.statementEventRecoveryPosted,
    LoanStatementEventType.unknown => l10n.statementActivityRecordedFallback,
  };
}
