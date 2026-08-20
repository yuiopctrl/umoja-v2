import 'package:flutter_riverpod/flutter_riverpod.dart';

const _defaultLimit = 25;

/// The Members list's current search/filter/pagination state. Held
/// separately from the actual data fetch ([membersListProvider]) so
/// changing a filter is a simple state update, not a manual refetch.
class MembersQuery {
  const MembersQuery({
    this.search = '',
    this.status,
    this.limit = _defaultLimit,
  });

  final String search;

  /// One of ACTIVE / SUSPENDED / EXITED, or `null` for "All".
  final String? status;

  /// Deliberately a growing *limit* fetched from offset 0, not an
  /// accumulating offset — see [MembersQueryNotifier.loadMore]. Every
  /// fetch is then a complete, self-consistent replacement of the
  /// visible list, which trivially avoids duplicate rows or stale-page
  /// races without needing manual merge/dedupe logic.
  final int limit;
}

class MembersQueryNotifier extends Notifier<MembersQuery> {
  @override
  MembersQuery build() => const MembersQuery();

  /// Changing search resets pagination back to the first page.
  void setSearch(String value) {
    state = MembersQuery(search: value, status: state.status);
  }

  /// Changing the status filter resets pagination back to the first page.
  void setStatus(String? value) {
    state = MembersQuery(search: state.search, status: value);
  }

  void loadMore() {
    state = MembersQuery(
      search: state.search,
      status: state.status,
      limit: state.limit + _defaultLimit,
    );
  }

  /// Pull-to-refresh: re-fetch the current filters at the base page size.
  void resetPageSize() {
    state = MembersQuery(search: state.search, status: state.status);
  }
}

final membersQueryProvider =
    NotifierProvider<MembersQueryNotifier, MembersQuery>(
      MembersQueryNotifier.new,
    );
