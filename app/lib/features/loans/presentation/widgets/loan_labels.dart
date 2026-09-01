import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';

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
///
/// Every one of these five colors already exists in [UmojaStatusSemantic]
/// — no new tokens/hex values were added for this mapping.
UmojaStatusSemantic loanAccountStatusSemantic(String status) {
  return switch (status) {
    'SUBMITTED' => UmojaStatusSemantic.info,
    'APPROVED' => UmojaStatusSemantic.warning,
    'ACTIVE' || 'DISBURSED' => UmojaStatusSemantic.success,
    'REJECTED' => UmojaStatusSemantic.danger,
    'CLOSED' || 'CANCELLED' => UmojaStatusSemantic.neutral,
    _ => UmojaStatusSemantic.neutral, // DRAFT and any future/unknown value.
  };
}

/// Centralized mapping from a `loan_installments` component type
/// (INTEREST/PRINCIPAL, Prompt 09C) to its localized display label —
/// shared by the loan schedule and every payment allocation/receipt
/// line that targets a loan.
String loanComponentTypeLabel(AppLocalizations l10n, String componentType) {
  return switch (componentType) {
    'INTEREST' || 'LOAN_INTEREST' => l10n.loanComponentInterest,
    'PRINCIPAL' || 'LOAN_PRINCIPAL' => l10n.loanComponentPrincipal,
    _ => componentType,
  };
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
