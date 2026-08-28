import 'package:umoja/features/financial_accounts/data/financial_account_repository.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry_page.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_transfer_result.dart';

FinancialAccount fakeFinancialAccount({
  String id = 'account-1',
  String groupId = 'g1',
  String name = 'Main Cash',
  String accountType = 'CASH',
  bool isActive = true,
  double balance = 50000,
}) {
  return FinancialAccount(
    id: id,
    groupId: groupId,
    name: name,
    accountType: accountType,
    isActive: isActive,
    balance: balance,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

FinancialAccountEntry fakeFinancialAccountEntry({
  String entryId = 'entry-1',
  String entryType = 'INFLOW',
  double amount = 50000,
  DateTime? effectiveAt,
  String? description,
  String? reference,
  String? transferReference,
  String? sourceType,
  String? counterpartyAccountId,
  String? counterpartyAccountName,
}) {
  return FinancialAccountEntry(
    entryId: entryId,
    entryType: entryType,
    amount: amount,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 1),
    description: description,
    reference: reference,
    transferReference: transferReference,
    sourceType: sourceType,
    createdAt: DateTime.utc(2026, 1, 1),
    counterpartyAccountId: counterpartyAccountId,
    counterpartyAccountName: counterpartyAccountName,
  );
}

FinancialAccountTransferResult fakeFinancialAccountTransferResult({
  String transferReference = 'transfer-1',
  String fromAccountId = 'account-1',
  String toAccountId = 'account-2',
  double amount = 20000,
  bool alreadyPosted = false,
  double fromBalance = 30000,
  double toBalance = 20000,
}) {
  return FinancialAccountTransferResult(
    transferReference: transferReference,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amount: amount,
    alreadyPosted: alreadyPosted,
    fromBalance: fromBalance,
    toBalance: toBalance,
  );
}

/// In-memory [FinancialAccountRepository] fake for tests. Records
/// every call so tests can assert controllers/widgets call the right
/// repository method with the right arguments, and can be configured
/// to throw a specific failure to test error-surfacing. Mirrors
/// `FakeContributionRepository`'s pattern.
class FakeFinancialAccountRepository implements FinancialAccountRepository {
  Object? failure;

  FinancialAccountPage nextAccountsPage = FinancialAccountPage.empty;
  FinancialAccount nextAccount = fakeFinancialAccount();
  FinancialAccountTransferResult nextTransferResult =
      fakeFinancialAccountTransferResult();
  FinancialAccountEntryPage nextEntriesPage = FinancialAccountEntryPage.empty;

  final List<({String groupId, bool? isActive, String? search})>
  listFinancialAccountsCalls = [];
  final List<({String groupId, String accountId})> getFinancialAccountCalls =
      [];
  final List<
    ({String groupId, String name, String accountType, double? openingBalance})
  >
  createFinancialAccountCalls = [];
  final List<({String groupId, String accountId, String? name, bool? isActive})>
  updateFinancialAccountCalls = [];
  final List<
    ({
      String groupId,
      String fromAccountId,
      String toAccountId,
      double amount,
      DateTime? effectiveAt,
      String? idempotencyKey,
    })
  >
  recordFinancialAccountTransferCalls = [];
  final List<({String groupId, String accountId})>
  listFinancialAccountEntriesCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<FinancialAccountPage> listFinancialAccounts({
    required String groupId,
    bool? isActive,
    String? search,
    int limit = 10,
    int offset = 0,
  }) async {
    listFinancialAccountsCalls.add((
      groupId: groupId,
      isActive: isActive,
      search: search,
    ));
    _maybeThrow();
    return nextAccountsPage;
  }

  @override
  Future<FinancialAccount> getFinancialAccount({
    required String groupId,
    required String accountId,
  }) async {
    getFinancialAccountCalls.add((groupId: groupId, accountId: accountId));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<FinancialAccount> createFinancialAccount({
    required String groupId,
    required String name,
    required String accountType,
    double? openingBalance,
    DateTime? openingBalanceDate,
  }) async {
    createFinancialAccountCalls.add((
      groupId: groupId,
      name: name,
      accountType: accountType,
      openingBalance: openingBalance,
    ));
    _maybeThrow();
    // Mimics a real backend so a test proves invalidation actually
    // refetches, rather than the fake always returning "the latest
    // thing created" regardless of caching.
    nextAccountsPage = FinancialAccountPage(
      items: [...nextAccountsPage.items, nextAccount],
      totalCount: nextAccountsPage.totalCount + 1,
      limit: nextAccountsPage.limit,
      offset: nextAccountsPage.offset,
    );
    return nextAccount;
  }

  @override
  Future<FinancialAccount> updateFinancialAccount({
    required String groupId,
    required String accountId,
    String? name,
    bool? isActive,
  }) async {
    updateFinancialAccountCalls.add((
      groupId: groupId,
      accountId: accountId,
      name: name,
      isActive: isActive,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<FinancialAccountTransferResult> recordFinancialAccountTransfer({
    required String groupId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    DateTime? effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    recordFinancialAccountTransferCalls.add((
      groupId: groupId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      effectiveAt: effectiveAt,
      idempotencyKey: idempotencyKey,
    ));
    _maybeThrow();
    return nextTransferResult;
  }

  @override
  Future<FinancialAccountEntryPage> listFinancialAccountEntries({
    required String groupId,
    required String accountId,
    int limit = 10,
    int offset = 0,
  }) async {
    listFinancialAccountEntriesCalls.add((
      groupId: groupId,
      accountId: accountId,
    ));
    _maybeThrow();
    return nextEntriesPage;
  }
}
