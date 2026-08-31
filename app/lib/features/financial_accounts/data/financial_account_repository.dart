import '../domain/financial_account.dart';
import '../domain/financial_account_entry_page.dart';
import '../domain/financial_account_page.dart';
import '../domain/financial_account_transfer_result.dart';
import '../domain/financial_adjustment_result.dart';
import '../domain/financial_category.dart';
import '../domain/financial_manual_entry.dart';
import '../domain/financial_position.dart';
import '../domain/financial_reconciliation.dart';

/// Abstraction over the Financial Accounts RPCs (Prompt 08A) — the
/// minimal financial-account/cashbook dependency pulled forward ahead
/// of Prompt 07 (Payments/Wallet/Allocations/Receipts). Every mutation
/// and read goes through the SECURITY DEFINER RPCs added by the
/// `20260826*` migrations; this abstraction never performs a direct
/// table read/insert/update.
///
/// Deliberately does not implement: contribution payments, wallet,
/// receipts, payment allocations, loans, bank statement reconciliation,
/// expense management, income analytics, or full financial position
/// reporting. Those remain Prompt 07/08/09.
///
/// Implementations must throw [FinancialAccountFailure] (never a raw
/// SDK exception) for anything that should be shown to the user.
abstract class FinancialAccountRepository {
  Future<FinancialAccountPage> listFinancialAccounts({
    required String groupId,
    bool? isActive,
    String? search,
    int limit = 10,
    int offset = 0,
  });

  Future<FinancialAccount> getFinancialAccount({
    required String groupId,
    required String accountId,
  });

  /// [openingBalance] of `null` or `0` posts no opening entry at all —
  /// only a positive value creates one. A negative value is rejected
  /// server-side.
  Future<FinancialAccount> createFinancialAccount({
    required String groupId,
    required String name,
    required String accountType,
    double? openingBalance,
    DateTime? openingBalanceDate,
  });

  /// Rename and/or activate/deactivate only — never touches anything
  /// balance-affecting.
  Future<FinancialAccount> updateFinancialAccount({
    required String groupId,
    required String accountId,
    String? name,
    bool? isActive,
  });

  /// Atomic paired TRANSFER_OUT/TRANSFER_IN between two of the group's
  /// own accounts — never an external payment path; money never
  /// leaves the group. [idempotencyKey], if supplied, makes a retried
  /// submission safe to resend.
  Future<FinancialAccountTransferResult> recordFinancialAccountTransfer({
    required String groupId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    DateTime? effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  });

  Future<FinancialAccountEntryPage> listFinancialAccountEntries({
    required String groupId,
    required String accountId,
    int limit = 10,
    int offset = 0,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? entryType,
    String? sourceType,
    String? categoryId,
  });

  // -- Financial categories (Prompt 08B) ---------------------------------

  Future<List<FinancialCategory>> listFinancialCategories({
    required String groupId,
    String? categoryType,
    bool? isActive,
  });

  Future<FinancialCategory> createFinancialCategory({
    required String groupId,
    required String name,
    required String categoryType,
    String? description,
  });

  Future<FinancialCategory> updateFinancialCategory({
    required String groupId,
    required String categoryId,
    String? name,
    String? description,
    bool? isActive,
  });

  /// Idempotently populates the group with a standard starting set of
  /// categories — safe to call more than once.
  Future<int> seedDefaultFinancialCategories({required String groupId});

  // -- Manual income/expense (Prompt 08B) --------------------------------

  /// Posts group income that does NOT originate from a member
  /// contribution payment. Creates exactly one cashbook INFLOW — never
  /// a payment/allocation/wallet/contribution-charge side effect.
  Future<FinancialManualEntryPostResult> recordManualIncome({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  });

  /// Posts a manual group expense. Creates exactly one cashbook
  /// OUTFLOW; rejected server-side if it would overdraw the account.
  Future<FinancialManualEntryPostResult> recordExpense({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  });

  Future<FinancialManualEntryDetail> getFinancialManualEntry({
    required String groupId,
    required String entryId,
  });

  /// Never edits/deletes the original entry — posts one compensating
  /// cashbook entry in the opposite direction.
  Future<void> reverseFinancialManualEntry({
    required String groupId,
    required String entryId,
    required String reversalReason,
  });

  // -- Financial adjustments (Prompt 08B) ---------------------------------

  /// A controlled, explicit correction for a verified real-world
  /// discrepancy — never counted as ordinary income/expense.
  Future<FinancialAdjustmentResult> recordFinancialAdjustment({
    required String groupId,
    required String financialAccountId,
    required String direction,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? financialReconciliationId,
    String? idempotencyKey,
  });

  // -- Reconciliation (Prompt 08B) -----------------------------------------

  /// Never posts a cashbook entry — a pure comparison/audit record.
  Future<FinancialReconciliation> createFinancialReconciliation({
    required String groupId,
    required String financialAccountId,
    required double statedBalance,
    required DateTime reconciliationAt,
    DateTime? periodStart,
    String? notes,
  });

  Future<void> cancelFinancialReconciliation({
    required String groupId,
    required String reconciliationId,
    required String cancellationReason,
  });

  Future<FinancialReconciliationPage> listFinancialAccountReconciliations({
    required String groupId,
    required String financialAccountId,
    int limit = 10,
    int offset = 0,
  });

  // -- Financial position (Prompt 08B) -------------------------------------

  /// Deliberately NOT a full accounting balance sheet. `dateFrom`/
  /// `dateTo` are period-movement filters only (`null` = unbounded);
  /// no "current month" default is ever assumed server-side.
  Future<FinancialPosition> getFinancialPosition({
    required String groupId,
    DateTime? dateFrom,
    DateTime? dateTo,
  });
}
