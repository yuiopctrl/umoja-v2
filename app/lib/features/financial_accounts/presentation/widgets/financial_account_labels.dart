import '../../../../l10n/app_localizations.dart';
import '../../domain/financial_account_entry.dart';

/// Centralized mapping from a `financial_accounts.account_type` value
/// to its localized display label — the only place this mapping is
/// implemented.
String financialAccountTypeLabel(AppLocalizations l10n, String accountType) {
  return switch (accountType) {
    'CASH' => l10n.financialAccountTypeCash,
    'BANK' => l10n.financialAccountTypeBank,
    'MOBILE_MONEY' => l10n.financialAccountTypeMobileMoney,
    _ => accountType,
  };
}

const financialAccountTypeOptions = ['CASH', 'BANK', 'MOBILE_MONEY'];

/// Centralized mapping from a
/// `financial_account_entries.entry_type` value to its localized
/// display label — never a raw enum name shown in the ledger UI.
String financialAccountEntryTypeLabel(AppLocalizations l10n, String entryType) {
  return switch (entryType) {
    'INFLOW' => l10n.financialAccountEntryTypeInflow,
    'OUTFLOW' => l10n.financialAccountEntryTypeOutflow,
    'TRANSFER_IN' => l10n.financialAccountEntryTypeTransferIn,
    'TRANSFER_OUT' => l10n.financialAccountEntryTypeTransferOut,
    _ => entryType,
  };
}

/// A ledger row's full display label (Prompt 08A-UAT-FIX-03) — for a
/// TRANSFER_OUT/TRANSFER_IN entry with a resolved counterparty, names
/// WHERE the money went/came from (e.g. "Uhamisho kwenda Cash Box"),
/// never the bare "Transfer Out"/"Transfer In". Falls back to the
/// plain entry-type label for every non-transfer entry, and for the
/// (should-never-happen) case of a transfer entry whose counterparty
/// failed to resolve — never fabricates a counterparty name.
String financialAccountEntryDisplayLabel(
  AppLocalizations l10n,
  FinancialAccountEntry entry,
) {
  final counterpartyName = entry.counterpartyAccountName;
  if (counterpartyName != null) {
    if (entry.entryType == 'TRANSFER_OUT') {
      return l10n.financialAccountTransferToLedgerLabel(counterpartyName);
    }
    if (entry.entryType == 'TRANSFER_IN') {
      return l10n.financialAccountTransferFromLedgerLabel(counterpartyName);
    }
  }
  return financialAccountEntryTypeLabel(l10n, entry.entryType);
}
