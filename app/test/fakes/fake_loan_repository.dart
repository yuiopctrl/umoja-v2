import 'dart:async';

import 'package:umoja/features/loans/data/loan_repository.dart';
import 'package:umoja/features/loans/domain/loan_account.dart';
import 'package:umoja/features/loans/domain/loan_account_event.dart';
import 'package:umoja/features/loans/domain/loan_disbursement.dart';
import 'package:umoja/features/loans/domain/loan_historical_arrears_installment.dart';
import 'package:umoja/features/loans/domain/loan_installment.dart';
import 'package:umoja/features/loans/domain/loan_migration_preview.dart';
import 'package:umoja/features/loans/domain/loan_opening_position.dart';
import 'package:umoja/features/loans/domain/loan_penalty_charge.dart';
import 'package:umoja/features/loans/domain/loan_product.dart';
import 'package:umoja/features/loans/domain/loan_schedule_preview.dart';
import 'package:umoja/features/loans/domain/loan_servicing.dart';

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
  bool penaltyEnabled = false,
  String? penaltyType,
  String? penaltyFrequency,
  int? penaltyGraceDays,
  double? penaltyFixedAmount,
  double? penaltyRate,
  String? penaltyBasis,
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
    penaltyEnabled: penaltyEnabled,
    penaltyType: penaltyType,
    penaltyFrequency: penaltyFrequency,
    penaltyGraceDays: penaltyGraceDays,
    penaltyFixedAmount: penaltyFixedAmount,
    penaltyRate: penaltyRate,
    penaltyBasis: penaltyBasis,
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
  double penaltyPaid = 0,
  double penaltyOutstanding = 0,
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
    penaltyPaid: penaltyPaid,
    penaltyOutstanding: penaltyOutstanding,
    totalOutstanding:
        totalOutstanding ??
        (principalDue - principalPaid) +
            (interestDue - interestPaid) +
            penaltyOutstanding,
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
  String loanOrigin = 'NEW',
  LoanOpeningPosition? openingPosition,
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
  double penaltyPaid = 0,
  double? penaltyOutstanding,
  double? totalOutstanding,
  DateTime? nextDueDate,
  double overdueAmount = 0,
  bool penaltyEnabled = false,
  String? penaltyType,
  String? penaltyFrequency,
  int? penaltyGraceDays,
  double? penaltyFixedAmount,
  double? penaltyRate,
  String? penaltyBasis,
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
    loanOrigin: loanOrigin,
    openingPosition: openingPosition,
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
    penaltyPaid: penaltyPaid,
    penaltyOutstanding: penaltyOutstanding,
    totalOutstanding: totalOutstanding,
    nextDueDate: nextDueDate,
    overdueAmount: overdueAmount,
    penaltyEnabled: penaltyEnabled,
    penaltyType: penaltyType,
    penaltyFrequency: penaltyFrequency,
    penaltyGraceDays: penaltyGraceDays,
    penaltyFixedAmount: penaltyFixedAmount,
    penaltyRate: penaltyRate,
    penaltyBasis: penaltyBasis,
  );
}

LoanOpeningPosition fakeLoanOpeningPosition({
  DateTime? openingAsOfDate,
  DateTime? originalDisbursementDate,
  String? originalLoanNumber,
  double originalPrincipal = 10000000,
  double openingPrincipalOutstanding = 4000000,
  double openingPrincipalArrears = 400000,
  double openingInterestArrears = 80000,
  double openingPenaltyArrears = 20000,
  double futureScheduledPrincipal = 3600000,
  double futureScheduledInterest = 600000,
  DateTime? arrearsDueDate,
  int remainingInstallmentCount = 4,
  DateTime? nextDueDate,
  String? notes,
  DateTime? createdAt,
}) {
  return LoanOpeningPosition(
    openingAsOfDate: openingAsOfDate ?? DateTime.utc(2026, 8, 31),
    originalDisbursementDate:
        originalDisbursementDate ?? DateTime.utc(2025, 11, 10),
    originalLoanNumber: originalLoanNumber,
    originalPrincipal: originalPrincipal,
    openingPrincipalOutstanding: openingPrincipalOutstanding,
    openingPrincipalArrears: openingPrincipalArrears,
    openingInterestArrears: openingInterestArrears,
    openingPenaltyArrears: openingPenaltyArrears,
    futureScheduledPrincipal: futureScheduledPrincipal,
    futureScheduledInterest: futureScheduledInterest,
    arrearsDueDate: arrearsDueDate ?? DateTime.utc(2026, 8, 1),
    remainingInstallmentCount: remainingInstallmentCount,
    nextDueDate: nextDueDate ?? DateTime.utc(2026, 9, 1),
    notes: notes,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 31),
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
  final List<({String groupId, String code, String name, bool penaltyEnabled})>
  createLoanProductCalls = [];
  final List<
    ({String groupId, String productId, bool? isActive, bool? penaltyEnabled})
  >
  updateLoanProductCalls = [];
  LoanPenaltyAssessmentResult nextAssessmentResult =
      LoanPenaltyAssessmentResult(
        assessmentDate: DateTime.utc(2026, 1, 1),
        eligibleInstallmentCount: 0,
        assessedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        totalPenaltyAmount: 0,
      );
  List<LoanPenaltyCharge> nextPenaltyCharges = const [];
  final List<({String groupId, DateTime assessmentDate, String? loanAccountId})>
  assessLoanPenaltiesCalls = [];
  final List<
    ({String groupId, String loanAccountId, String? loanInstallmentId})
  >
  listLoanPenaltyChargesCalls = [];
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
    bool penaltyEnabled = false,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
  }) async {
    createLoanProductCalls.add((
      groupId: groupId,
      code: code,
      name: name,
      penaltyEnabled: penaltyEnabled,
    ));
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
    bool? penaltyEnabled,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
  }) async {
    updateLoanProductCalls.add((
      groupId: groupId,
      productId: productId,
      isActive: isActive,
      penaltyEnabled: penaltyEnabled,
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

  @override
  Future<LoanPenaltyAssessmentResult> assessLoanPenalties({
    required String groupId,
    required DateTime assessmentDate,
    String? loanAccountId,
  }) async {
    assessLoanPenaltiesCalls.add((
      groupId: groupId,
      assessmentDate: assessmentDate,
      loanAccountId: loanAccountId,
    ));
    _maybeThrow();
    return nextAssessmentResult;
  }

  @override
  Future<List<LoanPenaltyCharge>> listLoanPenaltyCharges({
    required String groupId,
    required String loanAccountId,
    String? loanInstallmentId,
  }) async {
    listLoanPenaltyChargesCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      loanInstallmentId: loanInstallmentId,
    ));
    _maybeThrow();
    return nextPenaltyCharges;
  }

  final List<
    ({
      String groupId,
      String membershipId,
      String loanProductId,
      double originalPrincipal,
      double openingPrincipalOutstanding,
      List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments,
      String? idempotencyKey,
      String mode,
      double? contractedInterestAmount,
      double? monthlyInstallmentAmount,
      int? historicalUnpaidCount,
      double? totalHistoricalArrears,
      int? originalTerm,
    })
  >
  createMigratedLoanCalls = [];

  @override
  Future<LoanAccount> createMigratedLoan({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double originalPrincipal,
    required DateTime originalDisbursementDate,
    required DateTime openingAsOfDate,
    required double openingPrincipalOutstanding,
    List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments =
        const [],
    required double futureScheduledInterest,
    required int remainingInstallmentCount,
    DateTime? nextDueDate,
    String? originalLoanNumber,
    String? notes,
    String? idempotencyKey,
    String mode = 'DETAILED',
    double? contractedInterestAmount,
    double? monthlyInstallmentAmount,
    int? historicalUnpaidCount,
    double? totalHistoricalArrears,
    int? originalTerm,
  }) async {
    createMigratedLoanCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      loanProductId: loanProductId,
      originalPrincipal: originalPrincipal,
      openingPrincipalOutstanding: openingPrincipalOutstanding,
      historicalArrearsInstallments: historicalArrearsInstallments,
      idempotencyKey: idempotencyKey,
      mode: mode,
      contractedInterestAmount: contractedInterestAmount,
      monthlyInstallmentAmount: monthlyInstallmentAmount,
      historicalUnpaidCount: historicalUnpaidCount,
      totalHistoricalArrears: totalHistoricalArrears,
      originalTerm: originalTerm,
    ));
    _maybeThrow();
    return nextAccount;
  }

  LoanMigrationPreview? nextMigrationPreview;

  final List<
    ({
      String groupId,
      String membershipId,
      String loanProductId,
      double originalPrincipal,
      String mode,
    })
  >
  previewMigratedLoanCalls = [];

  @override
  Future<LoanMigrationPreview> previewMigratedLoan({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double originalPrincipal,
    required DateTime openingAsOfDate,
    double? openingPrincipalOutstanding,
    List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments =
        const [],
    double futureScheduledInterest = 0,
    int remainingInstallmentCount = 0,
    DateTime? nextDueDate,
    String mode = 'DETAILED',
    double? contractedInterestAmount,
    double? monthlyInstallmentAmount,
    int? historicalUnpaidCount,
    double? totalHistoricalArrears,
    int? originalTerm,
  }) async {
    previewMigratedLoanCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      loanProductId: loanProductId,
      originalPrincipal: originalPrincipal,
      mode: mode,
    ));
    _maybeThrow();
    return nextMigrationPreview ?? fakeLoanMigrationPreview();
  }

  // -- Loan servicing (Prompt 09E) ----------------------------------------

  LoanEarlySettlementQuote? nextEarlySettlementQuote;
  final List<({String groupId, String loanAccountId})>
  previewLoanEarlySettlementCalls = [];

  @override
  Future<LoanEarlySettlementQuote> previewLoanEarlySettlement({
    required String groupId,
    required String loanAccountId,
    DateTime? effectiveDate,
  }) async {
    previewLoanEarlySettlementCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
    ));
    _maybeThrow();
    return nextEarlySettlementQuote ?? fakeLoanEarlySettlementQuote();
  }

  LoanServicingPaymentResult? nextEarlySettlementResult;
  final List<
    ({String groupId, String loanAccountId, String financialAccountId})
  >
  settleLoanEarlyCalls = [];

  @override
  Future<LoanServicingPaymentResult> settleLoanEarly({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    settleLoanEarlyCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      financialAccountId: financialAccountId,
    ));
    _maybeThrow();
    return nextEarlySettlementResult ?? fakeLoanServicingPaymentResult();
  }

  LoanPrepaymentPreview? nextPrepaymentPreview;
  final List<
    ({String groupId, String loanAccountId, double amount, String treatment})
  >
  previewLoanPrepaymentCalls = [];

  @override
  Future<LoanPrepaymentPreview> previewLoanPrepayment({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    DateTime? effectiveDate,
  }) async {
    previewLoanPrepaymentCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      amount: amount,
      treatment: treatment,
    ));
    _maybeThrow();
    return nextPrepaymentPreview ??
        fakeLoanPrepaymentPreview(amount: amount, treatment: treatment);
  }

  LoanServicingPaymentResult? nextPrepaymentResult;
  final List<
    ({String groupId, String loanAccountId, double amount, String treatment})
  >
  prepayLoanPrincipalCalls = [];

  @override
  Future<LoanServicingPaymentResult> prepayLoanPrincipal({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    prepayLoanPrincipalCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      amount: amount,
      treatment: treatment,
    ));
    _maybeThrow();
    return nextPrepaymentResult ?? fakeLoanServicingPaymentResult();
  }

  LoanRestructurePreview? nextRestructurePreview;
  final List<({String groupId, String loanAccountId, int newTerm})>
  previewLoanRestructureCalls = [];

  @override
  Future<LoanRestructurePreview> previewLoanRestructure({
    required String groupId,
    required String loanAccountId,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  }) async {
    previewLoanRestructureCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      newTerm: newTerm,
    ));
    _maybeThrow();
    return nextRestructurePreview ??
        fakeLoanRestructurePreview(
          newTerm: newTerm,
          newFirstInstallmentDate: newFirstInstallmentDate,
        );
  }

  final List<
    ({String groupId, String loanAccountId, String reason, int newTerm})
  >
  restructureLoanCalls = [];

  @override
  Future<LoanAccount> restructureLoan({
    required String groupId,
    required String loanAccountId,
    required String reason,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  }) async {
    restructureLoanCalls.add((
      groupId: groupId,
      loanAccountId: loanAccountId,
      reason: reason,
      newTerm: newTerm,
    ));
    _maybeThrow();
    return nextAccount;
  }
}

LoanEarlySettlementQuote fakeLoanEarlySettlementQuote({
  DateTime? effectiveDate,
  double overduePenaltyOutstanding = 0,
  double overdueInterestOutstanding = 0,
  double overduePrincipalOutstanding = 0,
  double currentPayablePenalty = 0,
  double currentPayableInterest = 0,
  double currentPayablePrincipal = 0,
  double futurePrincipalOutstanding = 100000,
  double futureUnearnedInterest = 12000,
  double settlementAdjustmentAmount = 0,
  double totalSettlementAmount = 100000,
}) {
  return LoanEarlySettlementQuote(
    effectiveDate: effectiveDate ?? DateTime.utc(2026, 1, 1),
    overduePenaltyOutstanding: overduePenaltyOutstanding,
    overdueInterestOutstanding: overdueInterestOutstanding,
    overduePrincipalOutstanding: overduePrincipalOutstanding,
    currentPayablePenalty: currentPayablePenalty,
    currentPayableInterest: currentPayableInterest,
    currentPayablePrincipal: currentPayablePrincipal,
    futurePrincipalOutstanding: futurePrincipalOutstanding,
    futureUnearnedInterest: futureUnearnedInterest,
    settlementAdjustmentAmount: settlementAdjustmentAmount,
    totalSettlementAmount: totalSettlementAmount,
  );
}

LoanServicingPaymentResult fakeLoanServicingPaymentResult({
  String paymentId = 'payment-1',
  String receiptNumber = 'RCT-0001',
  double amount = 100000,
}) {
  return LoanServicingPaymentResult(
    paymentId: paymentId,
    receiptNumber: receiptNumber,
    amount: amount,
  );
}

LoanServicingScheduleRow fakeLoanServicingScheduleRow({
  int installmentNumber = 1,
  DateTime? dueDate,
  double principalDue = 50000,
  double interestDue = 5000,
}) {
  return LoanServicingScheduleRow(
    installmentNumber: installmentNumber,
    dueDate: dueDate ?? DateTime.utc(2026, 2, 1),
    principalDue: principalDue,
    interestDue: interestDue,
  );
}

LoanPrepaymentPreview fakeLoanPrepaymentPreview({
  double amount = 50000,
  String treatment = 'REDUCE_TERM',
  double futurePrincipalOutstandingBefore = 150000,
  double futurePrincipalOutstandingAfter = 100000,
  List<LoanServicingScheduleRow>? oldFutureInstallments,
  List<LoanServicingScheduleRow>? newFutureInstallments,
}) {
  return LoanPrepaymentPreview(
    amount: amount,
    treatment: treatment,
    futurePrincipalOutstandingBefore: futurePrincipalOutstandingBefore,
    futurePrincipalOutstandingAfter: futurePrincipalOutstandingAfter,
    oldFutureInstallments:
        oldFutureInstallments ?? [fakeLoanServicingScheduleRow()],
    newFutureInstallments:
        newFutureInstallments ?? [fakeLoanServicingScheduleRow()],
  );
}

LoanRestructurePreview fakeLoanRestructurePreview({
  double remainingPrincipalOutstanding = 100000,
  double newInterestRate = 12,
  int newTerm = 6,
  DateTime? newFirstInstallmentDate,
  List<LoanServicingScheduleRow>? oldRemainingInstallments,
  List<LoanServicingScheduleRow>? newInstallments,
}) {
  return LoanRestructurePreview(
    remainingPrincipalOutstanding: remainingPrincipalOutstanding,
    newInterestRate: newInterestRate,
    newTerm: newTerm,
    newFirstInstallmentDate:
        newFirstInstallmentDate ?? DateTime.utc(2026, 2, 1),
    oldRemainingInstallments:
        oldRemainingInstallments ?? [fakeLoanServicingScheduleRow()],
    newInstallments: newInstallments ?? [fakeLoanServicingScheduleRow()],
  );
}

LoanMigrationPreview fakeLoanMigrationPreview({
  String mode = 'SIMPLE',
  int? paidBeforeUmojaCount,
  List<LoanMigrationPreviewInstallment> historicalInstallments = const [],
  List<LoanMigrationPreviewInstallment> futureInstallments = const [],
  double? contractualHistoricalArrears,
  double? legacyPenaltyTotal,
  double historicalPrincipalTotal = 0,
  double historicalInterestTotal = 0,
  double historicalPenaltyTotal = 0,
  double totalHistoricalArrears = 0,
  double openingPrincipalOutstanding = 0,
  double futureScheduledPrincipal = 0,
  double futureScheduledInterest = 0,
  double futureContractualTotal = 0,
}) {
  return LoanMigrationPreview(
    mode: mode,
    paidBeforeUmojaCount: paidBeforeUmojaCount,
    historicalInstallments: historicalInstallments,
    futureInstallments: futureInstallments,
    contractualHistoricalArrears: contractualHistoricalArrears,
    legacyPenaltyTotal: legacyPenaltyTotal,
    historicalPrincipalTotal: historicalPrincipalTotal,
    historicalInterestTotal: historicalInterestTotal,
    historicalPenaltyTotal: historicalPenaltyTotal,
    totalHistoricalArrears: totalHistoricalArrears,
    openingPrincipalOutstanding: openingPrincipalOutstanding,
    futureScheduledPrincipal: futureScheduledPrincipal,
    futureScheduledInterest: futureScheduledInterest,
    futureContractualTotal: futureContractualTotal,
  );
}

LoanPenaltyCharge fakeLoanPenaltyCharge({
  String id = 'charge-1',
  String loanAccountId = 'loan-1',
  String loanInstallmentId = 'installment-1',
  int installmentNumber = 1,
  DateTime? assessmentDate,
  int sequenceNumber = 1,
  String origin = 'ASSESSED',
  String? penaltyType = 'FIXED',
  String? penaltyFrequency = 'ONCE',
  double? basisAmount = 100000,
  double? rate,
  double? fixedAmount = 20000,
  double penaltyAmount = 20000,
  double paidAmount = 0,
  double outstandingAmount = 20000,
  DateTime? createdAt,
}) {
  return LoanPenaltyCharge(
    id: id,
    loanAccountId: loanAccountId,
    loanInstallmentId: loanInstallmentId,
    installmentNumber: installmentNumber,
    assessmentDate: assessmentDate ?? DateTime.utc(2026, 9, 1),
    sequenceNumber: sequenceNumber,
    origin: origin,
    penaltyType: penaltyType,
    penaltyFrequency: penaltyFrequency,
    basisAmount: basisAmount,
    rate: rate,
    fixedAmount: fixedAmount,
    penaltyAmount: penaltyAmount,
    paidAmount: paidAmount,
    outstandingAmount: outstandingAmount,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 1),
  );
}
