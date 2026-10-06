import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/my_contribution.dart';

// Mirrors the Member Financial Statement's "growing limit from offset 0"
// convention (member_statement_query_provider.dart): every fetch is a
// complete, self-consistent replacement from the start, so loaded rows
// are never merged, deduplicated, or duplicated.
const _defaultLimit = 20;

// Matches the backend clamp in rpc_get_my_contributions (1..200).
const _maxLimit = 200;

/// Status/type/date filter state plus page size. Held apart from the
/// fetch so changing a filter is a state update, not a manual refetch.
/// Initial state: status = all (null), type = all (null), no dates.
class MyContributionsQuery {
  const MyContributionsQuery({
    this.status,
    this.contributionTypeId,
    this.fromDate,
    this.toDate,
    this.limit = _defaultLimit,
  });

  /// `null` means "All" — the status filter is never sent as a value
  /// the backend does not accept.
  final MyContributionStatus? status;
  final String? contributionTypeId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int limit;

  bool get hasActiveFilters =>
      status != null ||
      contributionTypeId != null ||
      fromDate != null ||
      toDate != null;
}

class MyContributionsQueryNotifier extends Notifier<MyContributionsQuery> {
  @override
  MyContributionsQuery build() => const MyContributionsQuery();

  /// Applies filters and resets pagination to the first page. Returns
  /// false and changes nothing when the date range is structurally
  /// invalid (from after to). Financial validation is never done here.
  bool applyFilters({
    MyContributionStatus? status,
    String? contributionTypeId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
      return false;
    }
    state = MyContributionsQuery(
      status: status,
      contributionTypeId: contributionTypeId,
      fromDate: fromDate,
      toDate: toDate,
    );
    return true;
  }

  void clearFilters() => state = const MyContributionsQuery();

  void loadMore() {
    final next = state.limit + _defaultLimit;
    state = MyContributionsQuery(
      status: state.status,
      contributionTypeId: state.contributionTypeId,
      fromDate: state.fromDate,
      toDate: state.toDate,
      limit: next > _maxLimit ? _maxLimit : next,
    );
  }

  /// Refresh: same filters, base page size (refresh refetches offset 0).
  void resetPageSize() {
    state = MyContributionsQuery(
      status: state.status,
      contributionTypeId: state.contributionTypeId,
      fromDate: state.fromDate,
      toDate: state.toDate,
    );
  }
}

final myContributionsQueryProvider =
    NotifierProvider<MyContributionsQueryNotifier, MyContributionsQuery>(
      MyContributionsQueryNotifier.new,
    );
