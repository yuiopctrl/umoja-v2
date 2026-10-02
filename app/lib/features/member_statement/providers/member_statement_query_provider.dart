import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mirrors MembersQueryNotifier's established "growing limit from
// offset 0" pagination convention (members_query_provider.dart) —
// every fetch is a complete, self-consistent replacement of the
// visible activity list from the start, which trivially avoids
// duplicate rows or stale-page races without manual merge/dedupe
// logic, and Riverpod's default `skipLoadingOnRefresh` keeps the
// previously-loaded items visible (with a small inline "loading more"
// indicator) while a larger page is fetched — see
// MemberStatementScreen.
const _defaultLimit = 20;

/// The Member Financial Statement's current date-range/pagination
/// state. Held separately from the actual data fetch
/// ([myMemberStatementProvider]) so changing a filter is a simple
/// state update, not a manual refetch — matching the project's
/// existing query-provider convention.
class MemberStatementQuery {
  const MemberStatementQuery({
    this.fromDate,
    this.toDate,
    this.limit = _defaultLimit,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final int limit;
}

class MemberStatementQueryNotifier extends Notifier<MemberStatementQuery> {
  @override
  MemberStatementQuery build() => const MemberStatementQuery();

  /// Changing the date range resets pagination back to the first page
  /// (Prompt 09G-B3-C §P).
  void setDateRange({DateTime? fromDate, DateTime? toDate}) {
    state = MemberStatementQuery(fromDate: fromDate, toDate: toDate);
  }

  void loadMore() {
    state = MemberStatementQuery(
      fromDate: state.fromDate,
      toDate: state.toDate,
      limit: state.limit + _defaultLimit,
    );
  }

  /// Refresh: re-fetch the current date range at the base page size
  /// (Prompt 09G-B3-C §S — "refresh must refetch offset 0").
  void resetPageSize() {
    state = MemberStatementQuery(
      fromDate: state.fromDate,
      toDate: state.toDate,
    );
  }
}

final memberStatementQueryProvider =
    NotifierProvider<MemberStatementQueryNotifier, MemberStatementQuery>(
      MemberStatementQueryNotifier.new,
    );
