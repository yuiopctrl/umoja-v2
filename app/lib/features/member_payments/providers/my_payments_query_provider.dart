import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/my_payment.dart';

// Mirrors My Contributions' "growing limit from offset 0" convention
// (my_contributions_query_provider.dart): every fetch is a complete,
// self-consistent replacement from the start, so loaded rows are never
// merged, deduplicated, or duplicated.
const _defaultLimit = 20;

// Matches the backend clamp in rpc_get_my_payments (1..200).
const _maxLimit = 200;

/// Status/date filter state plus page size. Held apart from the fetch
/// so changing a filter is a state update, not a manual refetch.
/// Initial state: status = all (null), no dates.
class MyPaymentsQuery {
  const MyPaymentsQuery({
    this.status,
    this.fromDate,
    this.toDate,
    this.limit = _defaultLimit,
  });

  /// `null` means "All" — the status filter is never sent as a value
  /// the backend does not accept.
  final MyPaymentStatus? status;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int limit;

  bool get hasActiveFilters =>
      status != null || fromDate != null || toDate != null;
}

class MyPaymentsQueryNotifier extends Notifier<MyPaymentsQuery> {
  @override
  MyPaymentsQuery build() => const MyPaymentsQuery();

  /// Applies filters and resets pagination to the first page. Returns
  /// false and changes nothing when the date range is structurally
  /// invalid (from after to). Financial validation is never done here.
  bool applyFilters({
    MyPaymentStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
      return false;
    }
    state = MyPaymentsQuery(status: status, fromDate: fromDate, toDate: toDate);
    return true;
  }

  void clearFilters() => state = const MyPaymentsQuery();

  void loadMore() {
    final next = state.limit + _defaultLimit;
    state = MyPaymentsQuery(
      status: state.status,
      fromDate: state.fromDate,
      toDate: state.toDate,
      limit: next > _maxLimit ? _maxLimit : next,
    );
  }

  /// Refresh: same filters, base page size (refresh refetches offset 0).
  void resetPageSize() {
    state = MyPaymentsQuery(
      status: state.status,
      fromDate: state.fromDate,
      toDate: state.toDate,
    );
  }
}

final myPaymentsQueryProvider =
    NotifierProvider<MyPaymentsQueryNotifier, MyPaymentsQuery>(
      MyPaymentsQueryNotifier.new,
    );
