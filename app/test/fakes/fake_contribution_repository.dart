import 'package:umoja/features/contributions/data/contribution_member_amount_input.dart';
import 'package:umoja/features/contributions/data/contribution_repository.dart';
import 'package:umoja/features/contributions/domain/contribution_penalty_assessment_result.dart';
import 'package:umoja/features/contributions/domain/contribution_period.dart';
import 'package:umoja/features/contributions/domain/contribution_period_open_preview.dart';
import 'package:umoja/features/contributions/domain/contribution_period_page.dart';
import 'package:umoja/features/contributions/domain/contribution_setup.dart';
import 'package:umoja/features/contributions/domain/contribution_setup_page.dart';
import 'package:umoja/features/contributions/domain/contribution_type.dart';
import 'package:umoja/features/contributions/domain/contribution_type_page.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge_page.dart';

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
}
