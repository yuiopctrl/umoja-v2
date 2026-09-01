import 'dart:async';

import 'package:umoja/features/financial_accounts/data/financial_account_repository.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry_page.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_transfer_result.dart';
import 'package:umoja/features/financial_accounts/domain/financial_adjustment_result.dart';
import 'package:umoja/features/financial_accounts/domain/financial_category.dart';
import 'package:umoja/features/financial_accounts/domain/financial_manual_entry.dart';
import 'package:umoja/features/financial_accounts/domain/financial_position.dart';
import 'package:umoja/features/financial_accounts/domain/financial_reconciliation.dart';

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
  String? sourceId,
  String? counterpartyAccountId,
  String? counterpartyAccountName,
  String? paymentReceiptNumber,
  String? manualEntryCategoryId,
  String? manualEntryCategoryName,
  String? manualEntryStatus,
  String? adjustmentReason,
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
    sourceId: sourceId,
    createdAt: DateTime.utc(2026, 1, 1),
    counterpartyAccountId: counterpartyAccountId,
    counterpartyAccountName: counterpartyAccountName,
    paymentReceiptNumber: paymentReceiptNumber,
    manualEntryCategoryId: manualEntryCategoryId,
    manualEntryCategoryName: manualEntryCategoryName,
    manualEntryStatus: manualEntryStatus,
    adjustmentReason: adjustmentReason,
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

FinancialCategory fakeFinancialCategory({
  String id = 'category-1',
  String groupId = 'g1',
  String name = 'Donation',
  String categoryType = 'INCOME',
  String? systemCode,
  bool isActive = true,
}) {
  return FinancialCategory(
    id: id,
    groupId: groupId,
    name: name,
    categoryType: categoryType,
    systemCode: systemCode,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

FinancialManualEntryPostResult fakeFinancialManualEntryPostResult({
  String entryId = 'manual-entry-1',
  String entryKind = 'INCOME',
  String financialAccountId = 'account-1',
  String? categoryId = 'category-1',
  double? amount = 20000,
  bool alreadyPosted = false,
  double financialAccountBalance = 70000,
}) {
  return FinancialManualEntryPostResult(
    entryId: entryId,
    entryKind: entryKind,
    financialAccountId: financialAccountId,
    categoryId: categoryId,
    amount: amount,
    alreadyPosted: alreadyPosted,
    financialAccountBalance: financialAccountBalance,
  );
}

FinancialManualEntryDetail fakeFinancialManualEntryDetail({
  String entryId = 'manual-entry-1',
  String financialAccountId = 'account-1',
  String financialAccountName = 'Main Cash',
  String categoryId = 'category-1',
  String categoryName = 'Donation',
  String entryKind = 'INCOME',
  double amount = 20000,
  DateTime? effectiveAt,
  String? description,
  String status = 'POSTED',
  DateTime? reversedAt,
  String? reversedBy,
  String? reversalReason,
}) {
  return FinancialManualEntryDetail(
    entryId: entryId,
    financialAccountId: financialAccountId,
    financialAccountName: financialAccountName,
    categoryId: categoryId,
    categoryName: categoryName,
    entryKind: entryKind,
    amount: amount,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 1),
    description: description,
    status: status,
    reversedAt: reversedAt,
    reversedBy: reversedBy,
    reversalReason: reversalReason,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

FinancialAdjustmentResult fakeFinancialAdjustmentResult({
  String adjustmentId = 'adjustment-1',
  String financialAccountId = 'account-1',
  String direction = 'DECREASE',
  double amount = 5000,
  bool alreadyPosted = false,
  double financialAccountBalance = 45000,
}) {
  return FinancialAdjustmentResult(
    adjustmentId: adjustmentId,
    financialAccountId: financialAccountId,
    direction: direction,
    amount: amount,
    alreadyPosted: alreadyPosted,
    financialAccountBalance: financialAccountBalance,
  );
}

FinancialReconciliation fakeFinancialReconciliation({
  String id = 'reconciliation-1',
  String financialAccountId = 'account-1',
  DateTime? reconciliationAt,
  double systemBalance = 50000,
  double statedBalance = 50000,
  String status = 'RECONCILED',
  String reconciledBy = 'u1',
}) {
  return FinancialReconciliation(
    id: id,
    financialAccountId: financialAccountId,
    reconciliationAt: reconciliationAt ?? DateTime.utc(2026, 1, 1),
    systemBalance: systemBalance,
    statedBalance: statedBalance,
    difference: statedBalance - systemBalance,
    status: status,
    reconciledBy: reconciledBy,
    reconciledAt: DateTime.utc(2026, 1, 1),
  );
}

FinancialPosition fakeFinancialPosition({
  DateTime? asOf,
  DateTime? periodFrom,
  DateTime? periodTo,
  List<FinancialPositionAccount>? accounts,
  double totalFinancialAccountBalance = 100000,
  double groupIncome = 60000,
  double expenses = 10000,
  double? netOperatingResult,
  double passThroughReceived = 20000,
  double shareCapitalReceived = 10000,
  double memberWalletLiability = 5000,
  double totalOutstandingMemberObligations = 15000,
  double fundedLoanPrincipalReceivable = 0,
  double scheduledUnearnedInterest = 0,
  double recognizedLoanInterestIncome = 0,
}) {
  return FinancialPosition(
    asOf: asOf ?? DateTime.utc(2026, 1, 1),
    periodFrom: periodFrom,
    periodTo: periodTo,
    accounts:
        accounts ??
        [
          const FinancialPositionAccount(
            id: 'account-1',
            name: 'Main Cash',
            accountType: 'CASH',
            isActive: true,
            balance: 100000,
          ),
        ],
    totalFinancialAccountBalance: totalFinancialAccountBalance,
    groupIncome: groupIncome,
    expenses: expenses,
    netOperatingResult: netOperatingResult ?? (groupIncome - expenses),
    passThroughReceived: passThroughReceived,
    shareCapitalReceived: shareCapitalReceived,
    memberWalletLiability: memberWalletLiability,
    totalOutstandingMemberObligations: totalOutstandingMemberObligations,
    fundedLoanPrincipalReceivable: fundedLoanPrincipalReceivable,
    scheduledUnearnedInterest: scheduledUnearnedInterest,
    recognizedLoanInterestIncome: recognizedLoanInterestIncome,
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
  List<FinancialCategory> nextCategories = [fakeFinancialCategory()];
  FinancialCategory nextCategory = fakeFinancialCategory();
  int nextSeedInsertedCount = 0;
  FinancialManualEntryPostResult nextManualEntryPostResult =
      fakeFinancialManualEntryPostResult();
  FinancialManualEntryDetail nextManualEntryDetail =
      fakeFinancialManualEntryDetail();
  FinancialAdjustmentResult nextAdjustmentResult =
      fakeFinancialAdjustmentResult();
  FinancialReconciliation nextReconciliation = fakeFinancialReconciliation();
  FinancialReconciliationPage nextReconciliationsPage =
      FinancialReconciliationPage.empty;
  FinancialPosition nextPosition = fakeFinancialPosition();

  /// Optional: hold `recordManualIncome`/`recordExpense` "in flight"
  /// to exercise duplicate-tap prevention while the confirm button is
  /// disabled/loading, without a real network delay — same pattern as
  /// `FakeAuthRepository`'s `pinLoginGate`.
  Completer<void>? manualEntryPostGate;

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
  final List<
    ({
      String groupId,
      String accountId,
      String? entryType,
      String? sourceType,
      String? categoryId,
    })
  >
  listFinancialAccountEntriesCalls = [];
  final List<({String groupId, String? categoryType, bool? isActive})>
  listFinancialCategoriesCalls = [];
  final List<({String groupId, String name, String categoryType})>
  createFinancialCategoryCalls = [];
  final List<({String groupId, String categoryId, bool? isActive})>
  updateFinancialCategoryCalls = [];
  final List<
    ({
      String groupId,
      String financialAccountId,
      String categoryId,
      double amount,
      DateTime effectiveAt,
      String? idempotencyKey,
    })
  >
  recordManualIncomeCalls = [];
  final List<
    ({
      String groupId,
      String financialAccountId,
      String categoryId,
      double amount,
      DateTime effectiveAt,
      String? idempotencyKey,
    })
  >
  recordExpenseCalls = [];
  final List<({String groupId, String entryId})> getFinancialManualEntryCalls =
      [];
  final List<({String groupId, String entryId, String reversalReason})>
  reverseFinancialManualEntryCalls = [];
  final List<
    ({
      String groupId,
      String financialAccountId,
      String direction,
      double amount,
      String reason,
    })
  >
  recordFinancialAdjustmentCalls = [];
  final List<
    ({String groupId, String financialAccountId, double statedBalance})
  >
  createFinancialReconciliationCalls = [];
  final List<({String groupId, String reconciliationId, String reason})>
  cancelFinancialReconciliationCalls = [];
  final List<({String groupId, String accountId})>
  listFinancialAccountReconciliationsCalls = [];
  final List<({String groupId, DateTime? dateFrom, DateTime? dateTo})>
  getFinancialPositionCalls = [];

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
    DateTime? dateFrom,
    DateTime? dateTo,
    String? entryType,
    String? sourceType,
    String? categoryId,
  }) async {
    listFinancialAccountEntriesCalls.add((
      groupId: groupId,
      accountId: accountId,
      entryType: entryType,
      sourceType: sourceType,
      categoryId: categoryId,
    ));
    _maybeThrow();
    return nextEntriesPage;
  }

  @override
  Future<List<FinancialCategory>> listFinancialCategories({
    required String groupId,
    String? categoryType,
    bool? isActive,
  }) async {
    listFinancialCategoriesCalls.add((
      groupId: groupId,
      categoryType: categoryType,
      isActive: isActive,
    ));
    _maybeThrow();
    return nextCategories;
  }

  @override
  Future<FinancialCategory> createFinancialCategory({
    required String groupId,
    required String name,
    required String categoryType,
    String? description,
  }) async {
    createFinancialCategoryCalls.add((
      groupId: groupId,
      name: name,
      categoryType: categoryType,
    ));
    _maybeThrow();
    return nextCategory;
  }

  @override
  Future<FinancialCategory> updateFinancialCategory({
    required String groupId,
    required String categoryId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    updateFinancialCategoryCalls.add((
      groupId: groupId,
      categoryId: categoryId,
      isActive: isActive,
    ));
    _maybeThrow();
    return nextCategory;
  }

  @override
  Future<int> seedDefaultFinancialCategories({required String groupId}) async {
    _maybeThrow();
    return nextSeedInsertedCount;
  }

  @override
  Future<FinancialManualEntryPostResult> recordManualIncome({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    recordManualIncomeCalls.add((
      groupId: groupId,
      financialAccountId: financialAccountId,
      categoryId: categoryId,
      amount: amount,
      effectiveAt: effectiveAt,
      idempotencyKey: idempotencyKey,
    ));
    final gate = manualEntryPostGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextManualEntryPostResult;
  }

  @override
  Future<FinancialManualEntryPostResult> recordExpense({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    recordExpenseCalls.add((
      groupId: groupId,
      financialAccountId: financialAccountId,
      categoryId: categoryId,
      amount: amount,
      effectiveAt: effectiveAt,
      idempotencyKey: idempotencyKey,
    ));
    final gate = manualEntryPostGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextManualEntryPostResult;
  }

  @override
  Future<FinancialManualEntryDetail> getFinancialManualEntry({
    required String groupId,
    required String entryId,
  }) async {
    getFinancialManualEntryCalls.add((groupId: groupId, entryId: entryId));
    _maybeThrow();
    return nextManualEntryDetail;
  }

  @override
  Future<void> reverseFinancialManualEntry({
    required String groupId,
    required String entryId,
    required String reversalReason,
  }) async {
    reverseFinancialManualEntryCalls.add((
      groupId: groupId,
      entryId: entryId,
      reversalReason: reversalReason,
    ));
    _maybeThrow();
  }

  @override
  Future<FinancialAdjustmentResult> recordFinancialAdjustment({
    required String groupId,
    required String financialAccountId,
    required String direction,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? financialReconciliationId,
    String? idempotencyKey,
  }) async {
    recordFinancialAdjustmentCalls.add((
      groupId: groupId,
      financialAccountId: financialAccountId,
      direction: direction,
      amount: amount,
      reason: reason,
    ));
    _maybeThrow();
    return nextAdjustmentResult;
  }

  @override
  Future<FinancialReconciliation> createFinancialReconciliation({
    required String groupId,
    required String financialAccountId,
    required double statedBalance,
    required DateTime reconciliationAt,
    DateTime? periodStart,
    String? notes,
  }) async {
    createFinancialReconciliationCalls.add((
      groupId: groupId,
      financialAccountId: financialAccountId,
      statedBalance: statedBalance,
    ));
    _maybeThrow();
    return nextReconciliation;
  }

  @override
  Future<void> cancelFinancialReconciliation({
    required String groupId,
    required String reconciliationId,
    required String cancellationReason,
  }) async {
    cancelFinancialReconciliationCalls.add((
      groupId: groupId,
      reconciliationId: reconciliationId,
      reason: cancellationReason,
    ));
    _maybeThrow();
  }

  @override
  Future<FinancialReconciliationPage> listFinancialAccountReconciliations({
    required String groupId,
    required String financialAccountId,
    int limit = 10,
    int offset = 0,
  }) async {
    listFinancialAccountReconciliationsCalls.add((
      groupId: groupId,
      accountId: financialAccountId,
    ));
    _maybeThrow();
    return nextReconciliationsPage;
  }

  @override
  Future<FinancialPosition> getFinancialPosition({
    required String groupId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    getFinancialPositionCalls.add((
      groupId: groupId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    ));
    _maybeThrow();
    return nextPosition;
  }
}
