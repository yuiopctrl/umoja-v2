import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `payments.payment_method` value to its
/// localized display label — the only place this mapping is
/// implemented, so a payment row/detail never shows a raw enum name.
String paymentMethodLabel(AppLocalizations l10n, String method) {
  return switch (method) {
    'CASH' => l10n.paymentMethodCash,
    'BANK_TRANSFER' => l10n.paymentMethodBankTransfer,
    'MOBILE_MONEY' => l10n.paymentMethodMobileMoney,
    'OTHER' => l10n.paymentMethodOther,
    _ => method,
  };
}

/// Centralized mapping from a `payments.status` value to its localized
/// display label.
String paymentStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'POSTED' => l10n.paymentStatusPosted,
    'REVERSED' => l10n.paymentStatusReversed,
    _ => status,
  };
}

/// Centralized mapping from a `member_wallet_entries.entry_type` value
/// to its localized display label.
String walletEntryTypeLabel(AppLocalizations l10n, String entryType) {
  return switch (entryType) {
    'PAYMENT_CREDIT' => l10n.walletEntryTypePaymentCredit,
    'ALLOCATION_DEBIT' => l10n.walletEntryTypeAllocationDebit,
    'REVERSAL' => l10n.walletEntryTypeReversal,
    _ => entryType,
  };
}

/// The business-context label for one obligation/allocation line
/// (UAT-FIX-01, sections 2/5/6) — e.g. "Ada — Julai 2026" for a normal
/// recurring charge, or just "Ada" for an opening-balance charge (no
/// period suffix, matching the UAT spec's examples). Never falls back
/// to a raw component_type/enum; if [contributionTypeName] is null
/// (only possible for an allocation posted before UAT-FIX-01 shipped),
/// returns an empty string so the caller shows only the component
/// label instead.
String obligationContextLabel({
  required String? contributionTypeName,
  required String? periodLabel,
  required String? periodPurpose,
}) {
  if (contributionTypeName == null) return '';
  if (periodPurpose == 'OPENING_BALANCE' || periodLabel == null) {
    return contributionTypeName;
  }
  return '$contributionTypeName — $periodLabel';
}
