import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mirrors MembersQueryNotifier's page-size philosophy (see
// members_query_provider.dart) — the backend RPC's own default is 10
// (clamped to a max of 100), and Flutter sends its own smaller default
// explicitly.
const _defaultLimit = 10;

/// The Contribution Types list's current search/filter/pagination
/// state. Held separately from the actual data fetch
/// ([contributionTypesListProvider]) so changing a filter is a simple
/// state update, not a manual refetch.
class ContributionTypesQuery {
  const ContributionTypesQuery({
    this.search = '',
    this.isActive,
    this.limit = _defaultLimit,
  });

  final String search;

  /// `null` for "All", otherwise filters to active/inactive only.
  final bool? isActive;

  /// Deliberately a growing *limit* fetched from offset 0, not an
  /// accumulating offset — see [ContributionTypesQueryNotifier.loadMore].
  final int limit;
}

class ContributionTypesQueryNotifier extends Notifier<ContributionTypesQuery> {
  @override
  ContributionTypesQuery build() => const ContributionTypesQuery();

  void setSearch(String value) {
    state = ContributionTypesQuery(search: value, isActive: state.isActive);
  }

  void setActiveFilter(bool? value) {
    state = ContributionTypesQuery(search: state.search, isActive: value);
  }

  void loadMore() {
    state = ContributionTypesQuery(
      search: state.search,
      isActive: state.isActive,
      limit: state.limit + _defaultLimit,
    );
  }

  void resetPageSize() {
    state = ContributionTypesQuery(
      search: state.search,
      isActive: state.isActive,
    );
  }
}

final contributionTypesQueryProvider =
    NotifierProvider<ContributionTypesQueryNotifier, ContributionTypesQuery>(
      ContributionTypesQueryNotifier.new,
    );
