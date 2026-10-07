import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/member_loan.dart';
import 'member_loans_repository_provider.dart';

/// Every member-loan provider's key includes the GROUP ID (Prompt 09G-B5-C.1
/// §A). Each group therefore has its own cache entry, and a previous group's
/// data can never be returned for another group, even while a provider is
/// reloading. The group is always part of the key, not an internal watch.
///
/// Keys are value-equal records, so equal inputs share one cached entry.

/// One page of the caller's own loans in one group.
typedef MemberLoansPageRequest = ({String groupId, int offset});

final memberLoansPageProvider = FutureProvider.autoDispose
    .family<MemberLoansPage, MemberLoansPageRequest>(retry: _noRetry, (
      ref,
      request,
    ) async {
      return ref
          .watch(memberLoansRepositoryProvider)
          .getMyLoans(
            groupId: request.groupId,
            limit: memberLoansPageSize,
            offset: request.offset,
          );
    });

/// One loan's member-safe detail in one group. Independent of the timeline
/// and the schedule, so a failure in either never destroys this detail.
typedef MemberLoanRequest = ({String groupId, String loanAccountId});

final memberLoanDetailProvider = FutureProvider.autoDispose
    .family<MemberLoanDetail, MemberLoanRequest>(retry: _noRetry, (
      ref,
      request,
    ) async {
      return ref
          .watch(memberLoansRepositoryProvider)
          .getMyLoanDetail(
            groupId: request.groupId,
            loanAccountId: request.loanAccountId,
          );
    });

/// The current schedule and history for one loan in one group.
final memberLoanScheduleProvider = FutureProvider.autoDispose
    .family<MemberLoanSchedule, MemberLoanRequest>(retry: _noRetry, (
      ref,
      request,
    ) async {
      return ref
          .watch(memberLoansRepositoryProvider)
          .getMyLoanSchedule(
            groupId: request.groupId,
            loanAccountId: request.loanAccountId,
          );
    });

/// One page of a loan's activity timeline in one group.
typedef MemberLoanTimelineRequest = ({
  String groupId,
  String loanAccountId,
  int offset,
});

final memberLoanTimelinePageProvider = FutureProvider.autoDispose
    .family<MemberLoanTimelinePage, MemberLoanTimelineRequest>(
      retry: _noRetry,
      (ref, request) async {
        return ref
            .watch(memberLoansRepositoryProvider)
            .getMyLoanTimeline(
              groupId: request.groupId,
              loanAccountId: request.loanAccountId,
              limit: memberLoanTimelinePageSize,
              offset: request.offset,
            );
      },
    );

/// Page sizes. The backend clamps to its own default and maximum, and the
/// screen never requests more than the backend allows.
const int memberLoansPageSize = 20;
const int memberLoanTimelinePageSize = 20;

/// Errors surface immediately and are retried by the user (the screens offer
/// Retry), never silently by the provider framework.
Duration? _noRetry(int retryCount, Object error) => null;
