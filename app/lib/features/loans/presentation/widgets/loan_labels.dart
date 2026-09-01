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
