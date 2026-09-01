import 'dart:async';

import 'package:umoja/features/loans/data/loan_repository.dart';
import 'package:umoja/features/loans/domain/loan_account.dart';
import 'package:umoja/features/loans/domain/loan_account_event.dart';
import 'package:umoja/features/loans/domain/loan_disbursement.dart';
import 'package:umoja/features/loans/domain/loan_installment.dart';
import 'package:umoja/features/loans/domain/loan_product.dart';
import 'package:umoja/features/loans/domain/loan_schedule_preview.dart';

LoanAccountEvent fakeLoanAccountEvent({
  String id = 'event-1',
  String eventType = 'CREATED',
  String? fromStatus,
  String toStatus = 'DRAFT',
  String? reason,
  DateTime? createdAt,
  String? createdBy = 'u1',
}) {
  return LoanAccountEvent(
    id: id,
    eventType: eventType,
    fromStatus: fromStatus,
    toStatus: toStatus,
    reason: reason,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    createdBy: createdBy,
  );
}

LoanDisbursement fakeLoanDisbursement({
  String id = 'disbursement-1',
  String financialAccountId = 'account-1',
  String financialAccountName = 'Main Cash',
  double amount = 120000,
  DateTime? effectiveAt,
  String? reference,
  String? notes,
  DateTime? createdAt,
}) {
  return LoanDisbursement(
    id: id,
    financialAccountId: financialAccountId,
    financialAccountName: financialAccountName,
    amount: amount,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 1),
    reference: reference,
    notes: notes,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

LoanProduct fakeLoanProduct({
  String id = 'product-1',
  String groupId = 'g1',
  String code = 'STD',
  String name = 'Standard Loan',
  String? description,
  bool isActive = true,
  double minimumPrincipal = 10000,
  double? maximumPrincipal = 500000,
  int minimumTerm = 1,
  int maximumTerm = 12,
  String termUnit = 'MONTH',
  double interestRate = 12,
  String interestRateBasis = 'ANNUAL',
  String interestMethod = 'FLAT',
  String repaymentFrequency = 'MONTHLY',
}) {
  return LoanProduct(
    id: id,
    groupId: groupId,
    code: code,
    name: name,
    description: description,
    isActive: isActive,
    minimumPrincipal: minimumPrincipal,
    maximumPrincipal: maximumPrincipal,
    minimumTerm: minimumTerm,
    maximumTerm: maximumTerm,
    termUnit: termUnit,
    interestRate: interestRate,
    interestRateBasis: interestRateBasis,
    interestMethod: interestMethod,
    repaymentFrequency: repaymentFrequency,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

LoanInstallment fakeLoanInstallment({
  int installmentNumber = 1,
  DateTime? dueDate,
  double principalDue = 10000,
  double interestDue = 1200,
  double? totalDue,
  double principalPaid = 0,
  double? principalOutstanding,
  double interestPaid = 0,
  double? interestOutstanding,
  double? totalOutstanding,
  String? status,
}) {
  return LoanInstallment(
    installmentNumber: installmentNumber,
    dueDate: dueDate ?? DateTime.utc(2026, 2, 1),
    principalDue: principalDue,
    interestDue: interestDue,
    totalDue: totalDue ?? (principalDue + interestDue),
    principalPaid: principalPaid,
    principalOutstanding:
        principalOutstanding ?? (principalDue - principalPaid),
    interestPaid: interestPaid,
    interestOutstanding: interestOutstanding ?? (interestDue - interestPaid),
    totalOutstanding:
        totalOutstanding ??
        (principalDue - principalPaid) + (interestDue - interestPaid),
    status: status ?? 'UPCOMING',
  );
}

LoanSchedulePreview fakeLoanSchedulePreview({
  double principalAmount = 120000,
  double interestRate = 12,
  String interestRateBasis = 'ANNUAL',
  String interestMethod = 'FLAT',
  int term = 6,
  DateTime? firstRepaymentDate,
  List<LoanInstallment>? installments,
}) {
  return LoanSchedulePreview(
    principalAmount: principalAmount,
    interestRate: interestRate,
    interestRateBasis: interestRateBasis,
    interestMethod: interestMethod,
    term: term,
    firstRepaymentDate: firstRepaymentDate ?? DateTime.utc(2026, 2, 1),
    installments:
        installments ??
        [
          fakeLoanInstallment(installmentNumber: 1),
          fakeLoanInstallment(
            installmentNumber: 2,
            dueDate: DateTime.utc(2026, 3, 1),
          ),
        ],
  );
}

LoanAccount fakeLoanAccount({
  String id = 'loan-1',
  String groupId = 'g1',
  String membershipId = 'm1',
  String borrowerDisplayName = 'Test Member',
  String? borrowerMemberNumber,
  String loanProductId = 'product-1',
  String loanProductName = 'Standard Loan',
  String loanProductCode = 'STD',
  String loanNumber = 'STD-LN-2026-0001',
  double principalAmount = 120000,
  double interestRate = 12,
  String interestRateBasis = 'ANNUAL',
  String interestMethod = 'FLAT',
  int term = 6,
  String termUnit = 'MONTH',
  String repaymentFrequency = 'MONTHLY',
  DateTime? applicationDate,
  DateTime? proposedDisbursementDate,
  DateTime? firstRepaymentDate,
  String status = 'DRAFT',
  List<LoanInstallment> installments = const [],
  List<LoanAccountEvent> events = const [],
  LoanDisbursement? disbursement,
  double principalRepaid = 0,
  double? principalOutstanding,
  double interestRecognized = 0,
  double? interestOutstanding,
  double? totalOutstanding,
  DateTime? nextDueDate,
  double overdueAmount = 0,
}) {
  return LoanAccount(
    id: id,
    groupId: groupId,
    membershipId: membershipId,
    borrowerDisplayName: borrowerDisplayName,
    borrowerMemberNumber: borrowerMemberNumber,
    loanProductId: loanProductId,
    loanProductName: loanProductName,
    loanProductCode: loanProductCode,
    loanNumber: loanNumber,
    principalAmount: principalAmount,
    interestRate: interestRate,
    interestRateBasis: interestRateBasis,
    interestMethod: interestMethod,
    term: term,
    termUnit: termUnit,
    repaymentFrequency: repaymentFrequency,
    applicationDate: applicationDate ?? DateTime.utc(2026, 1, 1),
    proposedDisbursementDate: proposedDisbursementDate,
    firstRepaymentDate: firstRepaymentDate ?? DateTime.utc(2026, 2, 1),
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    installments: installments,
    events: events,
    disbursement: disbursement,
    principalRepaid: principalRepaid,
    principalOutstanding:
        principalOutstanding ?? (principalAmount - principalRepaid),
    interestRecognized: interestRecognized,
    interestOutstanding: interestOutstanding,
    totalOutstanding: totalOutstanding,
    nextDueDate: nextDueDate,
    overdueAmount: overdueAmount,
  );
}

/// In-memory [LoanRepository] fake for tests (Prompt 09A). Records
/// every call so tests can assert controllers/widgets call the right
/// repository method with the right arguments, and can be configured
/// to throw a specific failure to test error-surfacing. Mirrors
/// `FakeFinancialAccountRepository`'s pattern.
class FakeLoanRepository implements LoanRepository {
  Object? failure;

  LoanProductPage nextProductsPage = LoanProductPage.empty;
  LoanProduct nextProduct = fakeLoanProduct();
  LoanAccountPage nextAccountsPage = LoanAccountPage.empty;
  LoanAccount nextAccount = fakeLoanAccount();
  LoanSchedulePreview nextPreview = fakeLoanSchedulePreview();

  /// Optional: hold `createDraftLoanAccount` "in flight" to exercise
  /// duplicate-tap prevention, matching `FakeFinancialAccountRepository`'s
  /// `manualEntryPostGate` pattern.
  Completer<void>? createDraftGate;

  final List<({String groupId, bool? isActive, int limit, int offset})>
  listLoanProductsCalls = [];
  final List<({String groupId, String productId})> getLoanProductCalls = [];
  final List<({String groupId, String code, String name})>
  createLoanProductCalls = [];
  final List<({String groupId, String productId, bool? isActive})>
  updateLoanProductCalls = [];
  final List<
    ({
      String groupId,
      String? membershipId,
      String? loanProductId,
      String? status,
      int limit,
      int offset,
    })
  >
  listLoanAccountsCalls = [];
  final List<({String groupId, String loanAccountId})> getLoanAccountCalls = [];
  final List<
    ({
      String groupId,
      String loanProductId,
      double principalAmount,
      int term,
      DateTime firstRepaymentDate,
    })
  >
  previewLoanScheduleCalls = [];
  final List<
    ({
      String groupId,
      String membershipId,
      String loanProductId,
      double principalAmount,
      int term,
    })
  >
  createDraftLoanAccountCalls = [];
  final List<
    ({
      String groupId,
      String loanAccountId,
      double? principalAmount,
      int? term,
      DateTime? firstRepaymentDate,
    })
  >
  updateDraftLoanTermsCalls = [];
  final List<({String groupId, String loanAccountId})>
  regenerateLoanScheduleCalls = [];
  final List<({String groupId, String loanAccountId})>
  cancelDraftLoanAccountCalls = [];
  final List<({String groupId, String loanAccountId})> submitLoanAccountCalls =
      [];
  final List<({String groupId, String loanAccountId})> approveLoanAccountCalls =
      [];
  final List<({String groupId, String loanAccountId, String reason})>
  rejectLoanAccountCalls = [];
  final List<({String groupId, String loanAccountId, String reason})>
  cancelLoanAccountCalls = [];
  final List<
    ({
      String groupId,
      String loanAccountId,
      String financialAccountId,
      DateTime effectiveAt,
      String? reference,
      String? notes,
      String? idempotencyKey,
    })
  >
  disburseLoanAccountCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<LoanProductPage> listLoanProducts({
    required String groupId,
    bool? isActive,
    int limit = 20,
    int offset = 0,
  }) async {
    listLoanProductsCalls.add((
      groupId: groupId,
      isActive: isActive,
      limit: limit,
      offset: offset,
    ));
    _maybeThrow();
    return nextProductsPage;
  }

  @override
  Future<LoanProduct> getLoanProduct({
    required String groupId,
    required String productId,
  }) async {
    getLoanProductCalls.add((groupId: groupId, productId: productId));
    _maybeThrow();
    return nextProduct;
  }

  @override
  Future<LoanProduct> createLoanProduct({
    required String groupId,
    required String code,
    required String name,
    required double minimumPrincipal,
    required int minimumTerm,
    required int maximumTerm,
    required double interestRate,
    required String interestRateBasis,
    required String interestMethod,
    double? maximumPrincipal,
    String? description,
  }) async {
    createLoanProductCalls.add((groupId: groupId, code: code, name: name));
    _maybeThrow();
    nextProductsPage = LoanProductPage(
      items: [...nextProductsPage.items, nextProduct],
      totalCount: nextProductsPage.totalCount + 1,
      limit: nextProductsPage.limit,
      offset: nextProductsPage.offset,
    );
    return nextProduct;
  }

  @override
  Future<LoanProduct> updateLoanProduct({
    required String groupId,
    required String productId,
    String? name,
    String? description,
    double? minimumPrincipal,
    double? maximumPrincipal,
    int? minimumTerm,
    int? maximumTerm,
    double? interestRate,
    String? interestRateBasis,
    String? interestMethod,
    bool? isActive,
  }) async {
    updateLoanProductCalls.add((
      groupId: groupId,
      productId: productId,
      isActive: isActive,
    ));
    _maybeThrow();
    return nextProduct;
  }

  @override
  Future<LoanAccountPage> listLoanAccounts({
    required String groupId,
    String? membershipId,
    String? loanProductId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    listLoanAccountsCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      loanProductId: loanProductId,
      status: status,
      limit: limit,
      offset: offset,
    ));
    _maybeThrow();
    return nextAccountsPage;
  }

  @override
  Future<LoanAccount> getLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    getLoanAccountCalls.add((groupId: groupId, loanAccountId: loanAccountId));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanSchedulePreview> previewLoanSchedule({
    required String groupId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
  }) async {
    previewLoanScheduleCalls.add((
      groupId: groupId,
      loanProductId: loanProductId,
      principalAmount: principalAmount,
      term: term,
      firstRepaymentDate: firstRepaymentDate,
    ));
    _maybeThrow();
    return nextPreview;
  }

  @override
  Future<LoanAccount> createDraftLoanAccount({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  }) async {
    createDraftLoanAccountCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      loanProductId: loanProductId,
      principalAmount: principalAmount,
      term: term,
    ));
    final gate = createDraftGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    nextAccountsPage = LoanAccountPage(
      items: [...nextAccountsPage.items, nextAccount],
      totalCount: nextAccountsPage.totalCount + 1,
      limit: nextAccountsPage.limit,
      offset: nextAccountsPage.offset,
    );
    return nextAccount;
  }

  @override
  Future<LoanAccount> updateDraftLoanTerms({
    required String groupId,
    required String loanAccountId,
    double? principalAmount,
    int? term,
    DateTime? firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  }) async {
    updateDraftLoanTermsCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      principalAmount: principalAmount,
      term: term,
      firstRepaymentDate: firstRepaymentDate,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> regenerateLoanSchedule({
    required String groupId,
    required String loanAccountId,
  }) async {
    regenerateLoanScheduleCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> cancelDraftLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    cancelDraftLoanAccountCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> submitLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    submitLoanAccountCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> approveLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    approveLoanAccountCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> rejectLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String reason,
  }) async {
    rejectLoanAccountCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      reason: reason,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> cancelLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String reason,
  }) async {
    cancelLoanAccountCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      reason: reason,
    ));
    _maybeThrow();
    return nextAccount;
  }

  @override
  Future<LoanAccount> disburseLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required DateTime effectiveAt,
    String? reference,
    String? notes,
    String? idempotencyKey,
  }) async {
    disburseLoanAccountCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      financialAccountId: financialAccountId,
      effectiveAt: effectiveAt,
      reference: reference,
      notes: notes,
      idempotencyKey: idempotencyKey,
    ));
    _maybeThrow();
    return nextAccount;
  }
}
