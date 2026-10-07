import 'package:umoja/features/member_loans/data/member_loans_failure.dart';
import 'package:umoja/features/member_loans/data/member_loans_repository.dart';
import 'package:umoja/features/member_loans/domain/member_loan.dart';

import 'member_loan_json_fixtures.dart';

/// In-memory stand-in for [MemberLoansRepository]. Serves the same JSON
/// shape the deployed RPCs return (see member_loan_json_fixtures.dart), parsed
/// through the real `fromJson` factories. Errors are injected as failures.
class FakeMemberLoansRepository implements MemberLoansRepository {
  FakeMemberLoansRepository({
    Map<int, Map<String, dynamic>>? listPages,
    Map<String, Map<String, dynamic>>? details,
    Map<String, Map<String, dynamic>>? schedules,
    Map<String, Map<int, Map<String, dynamic>>>? timelines,
  }) : listPages = listPages ?? {0: memberLoansPageJson()},
       details = details ?? {},
       schedules = schedules ?? {},
       timelines = timelines ?? {};

  /// Page JSON by offset.
  final Map<int, Map<String, dynamic>> listPages;

  /// Detail JSON by loan account id.
  final Map<String, Map<String, dynamic>> details;

  /// Schedule JSON by loan account id.
  final Map<String, Map<String, dynamic>> schedules;

  /// Timeline page JSON by loan account id, then by offset.
  final Map<String, Map<int, Map<String, dynamic>>> timelines;

  /// When set, the next call of that kind throws this failure once.
  MemberLoansFailure? nextListError;
  MemberLoansFailure? nextDetailError;
  MemberLoansFailure? nextScheduleError;
  MemberLoansFailure? nextTimelineError;

  final List<String> calls = [];
  String? lastGroupId;

  @override
  Future<MemberLoansPage> getMyLoans({
    required String groupId,
    required int limit,
    required int offset,
  }) async {
    calls.add('list:$offset');
    lastGroupId = groupId;
    final error = nextListError;
    if (error != null) {
      nextListError = null;
      throw error;
    }
    final json =
        listPages[offset] ??
        memberLoansPageJson(items: const [], hasMore: false, offset: offset);
    return MemberLoansPage.fromJson(json);
  }

  @override
  Future<MemberLoanDetail> getMyLoanDetail({
    required String groupId,
    required String loanAccountId,
  }) async {
    calls.add('detail:$loanAccountId');
    lastGroupId = groupId;
    final error = nextDetailError;
    if (error != null) {
      nextDetailError = null;
      throw error;
    }
    final json = details[loanAccountId];
    if (json == null) {
      throw const MemberLoansFailure(MemberLoansFailureType.notFound);
    }
    return MemberLoanDetail.fromJson(json);
  }

  @override
  Future<MemberLoanSchedule> getMyLoanSchedule({
    required String groupId,
    required String loanAccountId,
  }) async {
    calls.add('schedule:$loanAccountId');
    lastGroupId = groupId;
    final error = nextScheduleError;
    if (error != null) {
      nextScheduleError = null;
      throw error;
    }
    final json =
        schedules[loanAccountId] ??
        memberLoanScheduleJson(loanAccountId: loanAccountId);
    return MemberLoanSchedule.fromJson(json);
  }

  @override
  Future<MemberLoanTimelinePage> getMyLoanTimeline({
    required String groupId,
    required String loanAccountId,
    required int limit,
    required int offset,
  }) async {
    calls.add('timeline:$loanAccountId:$offset');
    lastGroupId = groupId;
    final error = nextTimelineError;
    if (error != null) {
      nextTimelineError = null;
      throw error;
    }
    final json =
        timelines[loanAccountId]?[offset] ??
        memberLoanTimelinePageJson(
          loanAccountId: loanAccountId,
          items: const [],
          hasMore: false,
          offset: offset,
        );
    return MemberLoanTimelinePage.fromJson(json);
  }
}
