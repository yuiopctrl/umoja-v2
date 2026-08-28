import '../domain/financial_account.dart';
import '../domain/financial_account_entry_page.dart';
import '../domain/financial_account_page.dart';
import '../domain/financial_account_transfer_result.dart';

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
  });
}
