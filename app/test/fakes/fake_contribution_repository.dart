import 'package:umoja/features/contributions/data/contribution_member_amount_input.dart';
import 'package:umoja/features/contributions/data/contribution_opening_balance_entry_input.dart';
import 'package:umoja/features/contributions/data/contribution_repository.dart';
import 'package:umoja/features/contributions/domain/contribution_charge_detail.dart';
import 'package:umoja/features/contributions/domain/contribution_correction_result.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_entry.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_import_result.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_page.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_preview.dart';
import 'package:umoja/features/contributions/domain/contribution_penalty_assessment_result.dart';
import 'package:umoja/features/contributions/domain/contribution_period.dart';
import 'package:umoja/features/contributions/domain/contribution_period_open_preview.dart';
import 'package:umoja/features/contributions/domain/contribution_period_page.dart';
import 'package:umoja/features/contributions/domain/contribution_setup.dart';
import 'package:umoja/features/contributions/domain/contribution_setup_page.dart';
import 'package:umoja/features/contributions/domain/contribution_type.dart';
import 'package:umoja/features/contributions/domain/contribution_type_page.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge_page.dart';
import 'package:umoja/features/contributions/domain/member_contribution_summary.dart';

ContributionType fakeContributionType({
  String id = 'type-1',
  String groupId = 'g1',
  String name = 'Michango ya Mwezi',
  String category = 'GENERAL',
  String accountingTreatment = 'GROUP_INCOME',
  bool isActive = true,
  int displayOrder = 0,
}) {
  return ContributionType(
    id: id,
    groupId: groupId,
    name: name,
    category: category,
    accountingTreatment: accountingTreatment,
    isActive: isActive,
    displayOrder: displayOrder,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

ContributionSetup fakeContributionSetup({
  String id = 'setup-1',
  String groupId = 'g1',
  String contributionTypeId = 'type-1',
  String name = 'Mchango wa Mwezi',
  String scheduleMode = 'MONTHLY',
  String amountMode = 'FIXED',
  double? fixedAmount = 5000,
  int? defaultDueDay = 5,
  int? defaultDueMonthOffset = 0,
  String penaltyMode = 'NONE',
  bool isActive = true,
}) {
  return ContributionSetup(
    id: id,
    groupId: groupId,
    contributionTypeId: contributionTypeId,
    name: name,
    scheduleMode: scheduleMode,
    amountMode: amountMode,
    fixedAmount: fixedAmount,
    defaultDueDay: defaultDueDay,
    defaultDueMonthOffset: defaultDueMonthOffset,
    penaltyMode: penaltyMode,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

ContributionPeriod fakeContributionPeriod({
  String id = 'period-1',
  String groupId = 'g1',
  String contributionSetupId = 'setup-1',
  String label = 'Januari 2026',
  String status = 'DRAFT',
  DateTime? periodStart,
  DateTime? periodEnd,
  DateTime? dueDate,
  int? excludedCount,
  int? customAmountCount,
  int? totalMembersCharged,
  double? totalBaseAssessed,
  String? snapshotAmountMode,
  String? snapshotPenaltyMode,
  double? totalPenaltyAssessed,
  int? penaltyChargeCount,
}) {
  final start = periodStart ?? DateTime.utc(2026, 1, 1);
  return ContributionPeriod(
    id: id,
    groupId: groupId,
    contributionSetupId: contributionSetupId,
    label: label,
    periodStart: start,
    periodEnd: periodEnd ?? DateTime.utc(2026, 1, 31),
    obligationDate: start,
    eligibilityDate: start,
    dueDate: dueDate ?? DateTime.utc(2026, 1, 5),
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    excludedCount: excludedCount,
    customAmountCount: customAmountCount,
    totalMembersCharged: totalMembersCharged,
    totalBaseAssessed: totalBaseAssessed,
    snapshotAmountMode: snapshotAmountMode,
    snapshotPenaltyMode: snapshotPenaltyMode,
    totalPenaltyAssessed: totalPenaltyAssessed,
    penaltyChargeCount: penaltyChargeCount,
  );
}

ContributionPenaltyAssessmentResult fakeContributionPenaltyAssessmentResult({
  String periodId = 'period-1',
  DateTime? assessmentDate,
  int qualifyingChargeCount = 1,
  int penaltiesCreatedCount = 1,
  int alreadyCurrentChargeCount = 0,
  double totalPenaltyAssessedThisRun = 500,
}) {
  return ContributionPenaltyAssessmentResult(
    periodId: periodId,
    assessmentDate: assessmentDate ?? DateTime.utc(2026, 1, 10),
    qualifyingChargeCount: qualifyingChargeCount,
    penaltiesCreatedCount: penaltiesCreatedCount,
    alreadyCurrentChargeCount: alreadyCurrentChargeCount,
    totalPenaltyAssessedThisRun: totalPenaltyAssessedThisRun,
  );
}

ContributionChargeDetail fakeContributionChargeDetail({
  String chargeId = 'charge-1',
  String groupId = 'g1',
  String periodId = 'period-1',
  String membershipId = 'membership-1',
  String memberNumberSnapshot = 'UM-0001',
  String memberNameSnapshot = 'Mwanachama Mmoja',
  double baseAmount = 100000,
  double penaltyAmount = 0,
  double adjustmentAmount = 0,
  double waiverAmount = 0,
  double openingBalanceAmount = 0,
}) {
  final components = <Map<String, dynamic>>[
    {
      'component_id': 'comp-base',
      'component_type': 'BASE',
      'amount': baseAmount,
      'reason': null,
      'effective_at': '2026-01-01',
      'sequence': 1,
      'created_at': '2026-01-01T00:00:00Z',
      'created_by': 'u1',
    },
    if (penaltyAmount != 0)
      {
        'component_id': 'comp-penalty',
        'component_type': 'PENALTY',
        'amount': penaltyAmount,
        'reason': null,
        'effective_at': '2026-01-10',
        'sequence': 1,
        'created_at': '2026-01-10T00:00:00Z',
        'created_by': 'u1',
      },
    if (adjustmentAmount != 0)
      {
        'component_id': 'comp-adjustment',
        'component_type': 'ADJUSTMENT',
        'amount': adjustmentAmount,
        'reason': 'Marekebisho',
        'effective_at': '2026-01-12',
        'sequence': 1,
        'created_at': '2026-01-12T00:00:00Z',
        'created_by': 'u1',
      },
    if (waiverAmount != 0)
      {
        'component_id': 'comp-waiver',
        'component_type': 'WAIVER',
        'amount': -waiverAmount.abs(),
        'reason': 'Msamaha',
        'effective_at': '2026-01-13',
        'sequence': 1,
        'created_at': '2026-01-13T00:00:00Z',
        'created_by': 'u1',
      },
    if (openingBalanceAmount != 0)
      {
        'component_id': 'comp-opening',
        'component_type': 'OPENING_BALANCE',
        'amount': openingBalanceAmount,
        'reason': null,
        'effective_at': '2026-01-01',
        'sequence': 1,
        'created_at': '2026-01-01T00:00:00Z',
        'created_by': 'u1',
      },
  ];
  final netAssessed =
      baseAmount +
      penaltyAmount +
      adjustmentAmount -
      waiverAmount.abs() +
      openingBalanceAmount;
  return ContributionChargeDetail.fromJson({
    'charge_id': chargeId,
    'group_id': groupId,
    'period_id': periodId,
    'membership_id': membershipId,
    'member_number_snapshot': memberNumberSnapshot,
    'member_name_snapshot': memberNameSnapshot,
    'effective_at': '2026-01-01',
    'due_date': '2026-01-05',
    'components': components,
    'net_assessed': netAssessed,
  });
}

MemberContributionSummary fakeMemberContributionSummary({
  String membershipId = 'membership-1',
  double baseAssessed = 100000,
  double penaltiesAssessed = 0,
  double adjustmentsAssessed = 0,
  double waiversAssessed = 0,
  double openingBalancesAssessed = 0,
}) {
  return MemberContributionSummary(
    membershipId: membershipId,
    baseAssessed: baseAssessed,
    penaltiesAssessed: penaltiesAssessed,
    adjustmentsAssessed: adjustmentsAssessed,
    waiversAssessed: waiversAssessed,
    openingBalancesAssessed: openingBalancesAssessed,
    netAssessed:
        baseAssessed +
        penaltiesAssessed +
        adjustmentsAssessed +
        waiversAssessed +
        openingBalancesAssessed,
  );
}

ContributionCorrectionResult fakeContributionCorrectionResult({
  String componentId = 'comp-1',
  String chargeId = 'charge-1',
  double amount = 10000,
  bool alreadyPosted = false,
  double netAssessed = 110000,
}) {
  return ContributionCorrectionResult(
    componentId: componentId,
    chargeId: chargeId,
    amount: amount,
    alreadyPosted: alreadyPosted,
    netAssessed: netAssessed,
  );
}

/// In-memory [ContributionRepository] fake for tests. Records every call
/// so tests can assert controllers/widgets call the right repository
/// method with the right arguments, and can be configured to throw a
/// specific failure to test error-surfacing. Mirrors
/// `FakeMemberRepository`'s pattern.
class FakeContributionRepository implements ContributionRepository {
  Object? failure;

  ContributionTypePage nextTypesPage = ContributionTypePage.empty;
  ContributionType nextType = fakeContributionType();
  ContributionSetupPage nextSetupsPage = ContributionSetupPage.empty;
  ContributionSetup nextSetup = fakeContributionSetup();
  ContributionPeriodPage nextPeriodsPage = ContributionPeriodPage.empty;
  ContributionPeriod nextPeriod = fakeContributionPeriod();
  ContributionPeriodOpenPreview? nextPreview;
  MemberContributionChargePage nextChargesPage =
      MemberContributionChargePage.empty;
  ContributionPenaltyAssessmentResult nextPenaltyAssessmentResult =
      fakeContributionPenaltyAssessmentResult();
  ContributionChargeDetail nextChargeDetail = fakeContributionChargeDetail();
  MemberContributionSummary nextMemberSummary = fakeMemberContributionSummary();
  ContributionCorrectionResult nextAdjustmentResult =
      fakeContributionCorrectionResult();
  ContributionCorrectionResult nextWaiverResult =
      fakeContributionCorrectionResult();
  ContributionOpeningBalancePreview? nextOpeningBalancePreview;
  ContributionOpeningBalanceImportResult? nextOpeningBalanceImportResult;
  ContributionOpeningBalancePage nextOpeningBalancesPage =
      ContributionOpeningBalancePage.empty;

  final List<({String groupId, String? search, bool? isActive})>
  listContributionTypesCalls = [];
  final List<
    ({String groupId, String name, String category, String accountingTreatment})
  >
  createContributionTypeCalls = [];
  final List<({String groupId, String typeId})> updateContributionTypeCalls =
      [];

  final List<({String groupId, String? contributionTypeId, bool? isActive})>
  listContributionSetupsCalls = [];
  final List<
    ({
      String groupId,
      String contributionTypeId,
      String name,
      String scheduleMode,
      String amountMode,
    })
  >
  createContributionSetupCalls = [];
  final List<({String groupId, String setupId})> updateContributionSetupCalls =
      [];

  final List<({String groupId, String? contributionSetupId, String? status})>
  listContributionPeriodsCalls = [];
  final List<({String groupId, String contributionSetupId, String label})>
  createContributionPeriodCalls = [];
  final List<({String groupId, String periodId, String? label})>
  updateContributionPeriodCalls = [];
  final List<({String groupId, String periodId, int amountsCount})>
  setContributionPeriodMemberAmountsCalls = [];
  final List<({String groupId, String periodId, String membershipId})>
  excludeContributionPeriodMemberCalls = [];
  final List<({String groupId, String periodId, String membershipId})>
  removeContributionPeriodMemberExclusionCalls = [];
  final List<({String groupId, String periodId})>
  previewContributionPeriodOpenCalls = [];
  final List<({String groupId, String periodId})> openContributionPeriodCalls =
      [];
  final List<
    ({String groupId, String periodId, String membershipId, double? amount})
  >
  enrollMemberInContributionPeriodCalls = [];
  final List<({String groupId, String periodId})> closeContributionPeriodCalls =
      [];
  final List<({String groupId, String periodId})>
  cancelContributionPeriodCalls = [];
  final List<({String groupId, String periodId, String? search})>
  listContributionPeriodChargesCalls = [];
  final List<({String groupId, String periodId, DateTime? assessmentDate})>
  assessContributionPeriodPenaltiesCalls = [];
  final List<({String groupId, String chargeId})>
  getContributionChargeDetailCalls = [];
  final List<({String groupId, String membershipId})>
  getMemberContributionSummaryCalls = [];
  final List<
    ({
      String groupId,
      String chargeId,
      double amount,
      String reason,
      DateTime effectiveAt,
      String? idempotencyKey,
    })
  >
  createContributionAdjustmentCalls = [];
  final List<
    ({
      String groupId,
      String chargeId,
      double amount,
      String reason,
      DateTime effectiveAt,
      String? idempotencyKey,
    })
  >
  waiveContributionChargeCalls = [];
  final List<
    ({
      String groupId,
      String contributionTypeId,
      DateTime effectiveAt,
      int entryCount,
    })
  >
  previewContributionOpeningBalanceImportCalls = [];
  final List<
    ({
      String groupId,
      String contributionTypeId,
      DateTime effectiveAt,
      int entryCount,
    })
  >
  importContributionOpeningBalancesCalls = [];
  final List<({String groupId, String? contributionTypeId})>
  listContributionOpeningBalancesCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<ContributionTypePage> listContributionTypes({
    required String groupId,
    String? search,
    bool? isActive,
    int limit = 10,
    int offset = 0,
  }) async {
    listContributionTypesCalls.add((
      groupId: groupId,
      search: search,
      isActive: isActive,
    ));
    _maybeThrow();
    return nextTypesPage;
  }

  @override
  Future<ContributionType> getContributionType({
    required String groupId,
    required String typeId,
  }) async {
    _maybeThrow();
    return nextType;
  }

  @override
  Future<ContributionType> createContributionType({
    required String groupId,
    required String name,
    required String category,
    required String accountingTreatment,
    String? description,
    int displayOrder = 0,
  }) async {
    createContributionTypeCalls.add((
      groupId: groupId,
      name: name,
      category: category,
      accountingTreatment: accountingTreatment,
    ));
    _maybeThrow();
    // Mimics a real backend: the next list-types call sees this new row.
    // A test proves invalidation actually happened only if the widget
    // shows this new row after create — not merely because the fake
    // unconditionally returns "the latest thing created" regardless of
    // caching.
    nextTypesPage = ContributionTypePage(
      items: [...nextTypesPage.items, nextType],
      totalCount: nextTypesPage.totalCount + 1,
      limit: nextTypesPage.limit,
      offset: nextTypesPage.offset,
    );
    return nextType;
  }

  @override
  Future<ContributionType> updateContributionType({
    required String groupId,
    required String typeId,
    String? name,
    String? description,
    String? category,
    String? accountingTreatment,
    int? displayOrder,
    bool? isActive,
  }) async {
    updateContributionTypeCalls.add((groupId: groupId, typeId: typeId));
    _maybeThrow();
    return nextType;
  }

  @override
  Future<ContributionSetupPage> listContributionSetups({
    required String groupId,
    String? contributionTypeId,
    bool? isActive,
    int limit = 10,
    int offset = 0,
  }) async {
    listContributionSetupsCalls.add((
      groupId: groupId,
      contributionTypeId: contributionTypeId,
      isActive: isActive,
    ));
    _maybeThrow();
    return nextSetupsPage;
  }

  @override
  Future<ContributionSetup> getContributionSetup({
    required String groupId,
    required String setupId,
  }) async {
    _maybeThrow();
    return nextSetup;
  }

  @override
  Future<ContributionSetup> createContributionSetup({
    required String groupId,
    required String contributionTypeId,
    required String name,
    required String scheduleMode,
    required String amountMode,
    String? description,
    double? fixedAmount,
    int? defaultDueDay,
    int? defaultDueMonthOffset,
    String penaltyMode = 'NONE',
    int? penaltyGraceDays,
    double? penaltyValue,
    double? penaltyCapAmount,
  }) async {
    createContributionSetupCalls.add((
      groupId: groupId,
      contributionTypeId: contributionTypeId,
      name: name,
      scheduleMode: scheduleMode,
      amountMode: amountMode,
    ));
    _maybeThrow();
    // See createContributionType's matching comment: mimics a real
    // backend so a test proves invalidation (list screen AND the period
    // form's setup picker) actually refetches, rather than the fake
    // just always returning "the latest thing created".
    nextSetupsPage = ContributionSetupPage(
      items: [...nextSetupsPage.items, nextSetup],
      totalCount: nextSetupsPage.totalCount + 1,
      limit: nextSetupsPage.limit,
      offset: nextSetupsPage.offset,
    );
    return nextSetup;
  }

  @override
  Future<ContributionSetup> updateContributionSetup({
    required String groupId,
    required String setupId,
    String? name,
    String? description,
    double? fixedAmount,
    int? defaultDueDay,
    int? defaultDueMonthOffset,
    String? penaltyMode,
    int? penaltyGraceDays,
    double? penaltyValue,
    double? penaltyCapAmount,
    bool? isActive,
  }) async {
    updateContributionSetupCalls.add((groupId: groupId, setupId: setupId));
    _maybeThrow();
    return nextSetup;
  }

  @override
  Future<ContributionPeriodPage> listContributionPeriods({
    required String groupId,
    String? contributionSetupId,
    String? status,
    int limit = 10,
    int offset = 0,
  }) async {
    listContributionPeriodsCalls.add((
      groupId: groupId,
      contributionSetupId: contributionSetupId,
      status: status,
    ));
    _maybeThrow();
    return nextPeriodsPage;
  }

  @override
  Future<ContributionPeriod> getContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    _maybeThrow();
    return nextPeriod;
  }

  @override
  Future<ContributionPeriod> createContributionPeriod({
    required String groupId,
    required String contributionSetupId,
    required String label,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? obligationDate,
    DateTime? eligibilityDate,
    DateTime? dueDate,
    String status = 'DRAFT',
    DateTime? scheduledOpenDate,
  }) async {
    createContributionPeriodCalls.add((
      groupId: groupId,
      contributionSetupId: contributionSetupId,
      label: label,
    ));
    _maybeThrow();
    // See createContributionType's matching comment.
    nextPeriodsPage = ContributionPeriodPage(
      items: [...nextPeriodsPage.items, nextPeriod],
      totalCount: nextPeriodsPage.totalCount + 1,
      limit: nextPeriodsPage.limit,
      offset: nextPeriodsPage.offset,
    );
    return nextPeriod;
  }

  @override
  Future<ContributionPeriod> updateContributionPeriod({
    required String groupId,
    required String periodId,
    String? label,
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? obligationDate,
    DateTime? eligibilityDate,
    DateTime? dueDate,
    DateTime? scheduledOpenDate,
  }) async {
    updateContributionPeriodCalls.add((
      groupId: groupId,
      periodId: periodId,
      label: label,
    ));
    _maybeThrow();
    return nextPeriod;
  }

  @override
  Future<void> setContributionPeriodMemberAmounts({
    required String groupId,
    required String periodId,
    required List<ContributionMemberAmountInput> amounts,
  }) async {
    setContributionPeriodMemberAmountsCalls.add((
      groupId: groupId,
      periodId: periodId,
      amountsCount: amounts.length,
    ));
    _maybeThrow();
  }

  @override
  Future<void> excludeContributionPeriodMember({
    required String groupId,
    required String periodId,
    required String membershipId,
    String? reason,
  }) async {
    excludeContributionPeriodMemberCalls.add((
      groupId: groupId,
      periodId: periodId,
      membershipId: membershipId,
    ));
    _maybeThrow();
  }

  @override
  Future<void> removeContributionPeriodMemberExclusion({
    required String groupId,
    required String periodId,
    required String membershipId,
  }) async {
    removeContributionPeriodMemberExclusionCalls.add((
      groupId: groupId,
      periodId: periodId,
      membershipId: membershipId,
    ));
    _maybeThrow();
  }

  @override
  Future<ContributionPeriodOpenPreview> previewContributionPeriodOpen({
    required String groupId,
    required String periodId,
  }) async {
    previewContributionPeriodOpenCalls.add((
      groupId: groupId,
      periodId: periodId,
    ));
    _maybeThrow();
    return nextPreview ??
        ContributionPeriodOpenPreview(
          periodId: periodId,
          status: 'DRAFT',
          dueDate: DateTime.utc(2026, 1, 5),
          amountMode: 'FIXED',
          eligibleCount: 0,
          eligibleMembers: const [],
          excludedCount: 0,
          excludedMembers: const [],
          missingCustomAmountCount: 0,
          missingCustomAmountMembers: const [],
          expectedTotalAssessment: 0,
          canOpen: true,
        );
  }

  @override
  Future<void> openContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    openContributionPeriodCalls.add((groupId: groupId, periodId: periodId));
    _maybeThrow();
  }

  @override
  Future<void> enrollMemberInContributionPeriod({
    required String groupId,
    required String periodId,
    required String membershipId,
    double? amount,
  }) async {
    enrollMemberInContributionPeriodCalls.add((
      groupId: groupId,
      periodId: periodId,
      membershipId: membershipId,
      amount: amount,
    ));
    _maybeThrow();
  }

  @override
  Future<void> closeContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    closeContributionPeriodCalls.add((groupId: groupId, periodId: periodId));
    _maybeThrow();
  }

  @override
  Future<void> cancelContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    cancelContributionPeriodCalls.add((groupId: groupId, periodId: periodId));
    _maybeThrow();
  }

  @override
  Future<MemberContributionChargePage> listContributionPeriodCharges({
    required String groupId,
    required String periodId,
    String? search,
    int limit = 10,
    int offset = 0,
  }) async {
    listContributionPeriodChargesCalls.add((
      groupId: groupId,
      periodId: periodId,
      search: search,
    ));
    _maybeThrow();
    return nextChargesPage;
  }

  @override
  Future<ContributionPenaltyAssessmentResult>
  assessContributionPeriodPenalties({
    required String groupId,
    required String periodId,
    DateTime? assessmentDate,
  }) async {
    assessContributionPeriodPenaltiesCalls.add((
      groupId: groupId,
      periodId: periodId,
      assessmentDate: assessmentDate,
    ));
    _maybeThrow();
    return nextPenaltyAssessmentResult;
  }

  @override
  Future<ContributionChargeDetail> getContributionChargeDetail({
    required String groupId,
    required String chargeId,
  }) async {
    getContributionChargeDetailCalls.add((
      groupId: groupId,
      chargeId: chargeId,
    ));
    _maybeThrow();
    return nextChargeDetail;
  }

  @override
  Future<MemberContributionSummary> getMemberContributionSummary({
    required String groupId,
    required String membershipId,
  }) async {
    getMemberContributionSummaryCalls.add((
      groupId: groupId,
      membershipId: membershipId,
    ));
    _maybeThrow();
    return nextMemberSummary;
  }

  @override
  Future<ContributionCorrectionResult> createContributionAdjustment({
    required String groupId,
    required String chargeId,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? idempotencyKey,
  }) async {
    createContributionAdjustmentCalls.add((
      groupId: groupId,
      chargeId: chargeId,
      amount: amount,
      reason: reason,
      effectiveAt: effectiveAt,
      idempotencyKey: idempotencyKey,
    ));
    _maybeThrow();
    return nextAdjustmentResult;
  }

  @override
  Future<ContributionCorrectionResult> waiveContributionCharge({
    required String groupId,
    required String chargeId,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? idempotencyKey,
  }) async {
    waiveContributionChargeCalls.add((
      groupId: groupId,
      chargeId: chargeId,
      amount: amount,
      reason: reason,
      effectiveAt: effectiveAt,
      idempotencyKey: idempotencyKey,
    ));
    _maybeThrow();
    return nextWaiverResult;
  }

  @override
  Future<ContributionOpeningBalancePreview>
  previewContributionOpeningBalanceImport({
    required String groupId,
    required String contributionTypeId,
    required DateTime effectiveAt,
    required List<ContributionOpeningBalanceEntryInput> entries,
  }) async {
    previewContributionOpeningBalanceImportCalls.add((
      groupId: groupId,
      contributionTypeId: contributionTypeId,
      effectiveAt: effectiveAt,
      entryCount: entries.length,
    ));
    _maybeThrow();
    return nextOpeningBalancePreview ??
        ContributionOpeningBalancePreview(
          contributionTypeId: contributionTypeId,
          effectiveAt: effectiveAt,
          memberCount: entries.length,
          totalOpeningObligation: entries.fold(
            0.0,
            (sum, e) => sum + (e.amount ?? 0),
          ),
          entries: entries
              .map(
                (e) => ContributionOpeningBalanceEntry(
                  membershipId: e.membershipId,
                  memberNumber: null,
                  displayName: null,
                  amount: e.amount ?? 0,
                  alreadyImported: false,
                ),
              )
              .toList(growable: false),
          canImport: true,
        );
  }

  @override
  Future<ContributionOpeningBalanceImportResult>
  importContributionOpeningBalances({
    required String groupId,
    required String contributionTypeId,
    required DateTime effectiveAt,
    required List<ContributionOpeningBalanceEntryInput> entries,
  }) async {
    importContributionOpeningBalancesCalls.add((
      groupId: groupId,
      contributionTypeId: contributionTypeId,
      effectiveAt: effectiveAt,
      entryCount: entries.length,
    ));
    _maybeThrow();
    return nextOpeningBalanceImportResult ??
        ContributionOpeningBalanceImportResult(
          periodId: 'ob-period-1',
          contributionTypeId: contributionTypeId,
          effectiveAt: effectiveAt,
          importedCount: entries.length,
          totalOpeningObligation: entries.fold(
            0.0,
            (sum, e) => sum + (e.amount ?? 0),
          ),
        );
  }

  @override
  Future<ContributionOpeningBalancePage> listContributionOpeningBalances({
    required String groupId,
    String? contributionTypeId,
    int limit = 10,
    int offset = 0,
  }) async {
    listContributionOpeningBalancesCalls.add((
      groupId: groupId,
      contributionTypeId: contributionTypeId,
    ));
    _maybeThrow();
    return nextOpeningBalancesPage;
  }
}
