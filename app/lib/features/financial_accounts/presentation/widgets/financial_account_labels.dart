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

/// A ledger row's full display label (Prompt 08A-UAT-FIX-03, extended
/// Prompt 08B) — every row explains what actually happened, never a
/// raw enum:
///   - a TRANSFER_OUT/TRANSFER_IN entry with a resolved counterparty
///     names WHERE the money went/came from (e.g. "Uhamisho kwenda
///     Cash Box"), never the bare "Transfer Out"/"Transfer In".
///   - a PAYMENT/PAYMENT_REVERSAL entry cites its receipt number.
///   - a MANUAL_INCOME/EXPENSE (or their reversals) entry cites its
///     category name.
///   - a FINANCIAL_ADJUSTMENT entry cites its reason.
/// Falls back to the plain entry-type label whenever the expected
/// joined context (counterparty/receipt/category/reason) failed to
/// resolve — never fabricates one.
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

  switch (entry.sourceType) {
    case 'PAYMENT':
      final receipt = entry.paymentReceiptNumber;
      if (receipt != null) {
        return l10n.financialAccountPaymentLedgerLabel(receipt);
      }
    case 'PAYMENT_REVERSAL':
      final receipt = entry.paymentReceiptNumber;
      if (receipt != null) {
        return l10n.financialAccountPaymentReversalLedgerLabel(receipt);
      }
    case 'MANUAL_INCOME':
      final category = entry.manualEntryCategoryName;
      if (category != null) {
        return l10n.financialAccountManualIncomeLedgerLabel(category);
      }
    case 'EXPENSE':
      final category = entry.manualEntryCategoryName;
      if (category != null) {
        return l10n.financialAccountExpenseLedgerLabel(category);
      }
    case 'MANUAL_INCOME_REVERSAL':
      final category = entry.manualEntryCategoryName;
      if (category != null) {
        return l10n.financialAccountManualIncomeReversalLedgerLabel(category);
      }
    case 'EXPENSE_REVERSAL':
      final category = entry.manualEntryCategoryName;
      if (category != null) {
        return l10n.financialAccountExpenseReversalLedgerLabel(category);
      }
    case 'FINANCIAL_ADJUSTMENT':
      final reason = entry.adjustmentReason;
      if (reason != null) {
        return l10n.financialAccountAdjustmentLedgerLabel(reason);
      }
    case 'LOAN_DISBURSEMENT':
      final loanNumber = entry.loanDisbursementLoanNumber;
      final borrower = entry.loanDisbursementBorrowerDisplayName;
      if (loanNumber != null && borrower != null) {
        return l10n.financialAccountLoanDisbursementLedgerLabel(
          loanNumber,
          borrower,
        );
      }
  }

  return financialAccountEntryTypeLabel(l10n, entry.entryType);
}

/// Centralized mapping from a `financial_categories.category_type`
/// value to its localized display label.
String financialCategoryTypeLabel(AppLocalizations l10n, String categoryType) {
  return switch (categoryType) {
    'INCOME' => l10n.financialCategoryTypeIncome,
    'EXPENSE' => l10n.financialCategoryTypeExpense,
    _ => categoryType,
  };
}
