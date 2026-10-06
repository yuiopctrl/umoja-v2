import 'package:umoja/features/my_contributions/data/my_contributions_failure.dart';
import 'package:umoja/features/my_contributions/data/my_contributions_repository.dart';
import 'package:umoja/features/my_contributions/domain/my_contribution.dart';

/// In-memory stand-in for [MyContributionsRepository]. Records every call
/// so tests can assert the exact group/filter/page arguments sent, and
/// serves details by charge id (an unknown id behaves like the backend's
/// not-found response).
class FakeMyContributionsRepository implements MyContributionsRepository {
  FakeMyContributionsRepository({
    MyContributionsPage? page,
    Map<String, MyContributionDetail>? details,
  }) : page = page ?? myContributionsPageFixture(),
       details = details ?? {};

  MyContributionsPage page;
  final Map<String, MyContributionDetail> details;

  /// When set, the next call throws this failure, then the flag clears.
  MyContributionsFailure? nextError;

  int listCallCount = 0;
  int detailCallCount = 0;
  String? lastGroupId;
  MyContributionStatus? lastStatus;
  String? lastContributionTypeId;
  DateTime? lastFromDate;
  DateTime? lastToDate;
  int? lastLimit;
  int? lastOffset;
  String? lastChargeId;

  @override
  Future<MyContributionsPage> getMyContributions({
    required String groupId,
    MyContributionStatus? status,
    String? contributionTypeId,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  }) async {
    listCallCount++;
    lastGroupId = groupId;
    lastStatus = status;
    lastContributionTypeId = contributionTypeId;
    lastFromDate = fromDate;
    lastToDate = toDate;
    lastLimit = limit;
    lastOffset = offset;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return page;
  }

  @override
  Future<MyContributionDetail> getMyContributionChargeDetail({
    required String groupId,
    required String chargeId,
  }) async {
    detailCallCount++;
    lastGroupId = groupId;
    lastChargeId = chargeId;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final detail = details[chargeId];
    if (detail == null) {
      throw const MyContributionsFailure(MyContributionsFailureType.notFound);
    }
    return detail;
  }
}

Map<String, dynamic> myContributionItemJson({
  String chargeId = 'c1',
  String typeId = 't1',
  String typeName = 'Monthly Savings',
  String category = 'GENERAL',
  String? periodLabel = 'March 2026',
  String periodPurpose = 'NORMAL',
  String effectiveAt = '2026-03-01T00:00:00Z',
  String? dueDate = '2026-03-10',
  num netAssessed = 12000,
  num allocatedAmount = 5000,
  num outstanding = 7000,
  String status = 'PARTIALLY_SETTLED',
}) => {
  'charge_id': chargeId,
  'contribution_type_id': typeId,
  'contribution_type_name': typeName,
  'contribution_category': category,
  'period_id': 'p-$chargeId',
  'period_label': periodLabel,
  'period_purpose': periodPurpose,
  'effective_at': effectiveAt,
  'due_date': dueDate,
  'net_assessed': netAssessed,
  'allocated_amount': allocatedAmount,
  'outstanding': outstanding,
  'status': status,
};

MyContribution myContributionFixture({
  String chargeId = 'c1',
  String typeName = 'Monthly Savings',
  String? periodLabel = 'March 2026',
  String periodPurpose = 'NORMAL',
  num netAssessed = 12000,
  num allocatedAmount = 5000,
  num outstanding = 7000,
  String status = 'PARTIALLY_SETTLED',
  String? dueDate = '2026-03-10',
}) => MyContribution.fromJson(
  myContributionItemJson(
    chargeId: chargeId,
    typeName: typeName,
    periodLabel: periodLabel,
    periodPurpose: periodPurpose,
    netAssessed: netAssessed,
    allocatedAmount: allocatedAmount,
    outstanding: outstanding,
    status: status,
    dueDate: dueDate,
  ),
);

/// A full `rpc_get_my_contributions` response, built from the same JSON
/// shape the deployed backend returns.
MyContributionsPage myContributionsPageFixture({
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> contributionTypes = const [],
  num totalOutstanding = 7000,
  int limit = 20,
  int offset = 0,
  int? totalCount,
  bool hasMore = false,
}) {
  return MyContributionsPage.fromJson({
    'member': {
      'membership_id': 'm1',
      'display_name': 'Test Member',
      'member_number': 'G1-0001',
      'membership_status': 'ACTIVE',
    },
    'group': {
      'group_id': 'g1',
      'group_name': 'Umoja Demo',
      'group_code': 'TG01',
      'currency': 'TZS',
    },
    'summary': {'total_outstanding': totalOutstanding},
    'filter_options': {'contribution_types': contributionTypes},
    'items': items,
    'pagination': {
      'limit': limit,
      'offset': offset,
      'total_count': totalCount ?? items.length,
      'has_more': hasMore,
    },
  });
}

Map<String, dynamic> myContributionDetailJson({
  String chargeId = 'c1',
  String status = 'PARTIALLY_SETTLED',
  List<Map<String, dynamic>> components = const [],
  List<Map<String, dynamic>> settlementHistory = const [],
  String? periodLabel = 'March 2026',
  String periodPurpose = 'NORMAL',
}) => {
  'charge_id': chargeId,
  'contribution_type_id': 't1',
  'contribution_type_name': 'Monthly Savings',
  'contribution_category': 'GENERAL',
  'period_id': 'p-$chargeId',
  'period_label': periodLabel,
  'period_purpose': periodPurpose,
  'effective_at': '2026-03-01T00:00:00Z',
  'due_date': '2026-03-10',
  'net_assessed': 12000,
  'allocated_amount': 5000,
  'outstanding': 7000,
  'status': status,
  'components': components,
  'settlement_history': settlementHistory,
};

MyContributionDetail myContributionDetailFixture({
  String chargeId = 'c1',
  String status = 'PARTIALLY_SETTLED',
  List<Map<String, dynamic>> components = const [],
  List<Map<String, dynamic>> settlementHistory = const [],
  String? periodLabel = 'March 2026',
  String periodPurpose = 'NORMAL',
}) => MyContributionDetail.fromJson(
  myContributionDetailJson(
    chargeId: chargeId,
    status: status,
    components: components,
    settlementHistory: settlementHistory,
    periodLabel: periodLabel,
    periodPurpose: periodPurpose,
  ),
);
