import 'package:flutter_riverpod/flutter_riverpod.dart';

const _defaultLimit = 10;

/// The Contribution Periods list's current filter/pagination state.
class ContributionPeriodsQuery {
  const ContributionPeriodsQuery({
    this.contributionSetupId,
    this.status,
    this.limit = _defaultLimit,
  });

  /// `null` for "all setups".
  final String? contributionSetupId;

  /// One of DRAFT / SCHEDULED / OPEN / CLOSED / CANCELLED, or `null` for
  /// "All".
  final String? status;

  final int limit;
}

class ContributionPeriodsQueryNotifier
    extends Notifier<ContributionPeriodsQuery> {
  @override
  ContributionPeriodsQuery build() => const ContributionPeriodsQuery();

  void setSetupFilter(String? value) {
    state = ContributionPeriodsQuery(
      contributionSetupId: value,
      status: state.status,
    );
  }

  void setStatusFilter(String? value) {
    state = ContributionPeriodsQuery(
      contributionSetupId: state.contributionSetupId,
      status: value,
    );
  }

  void loadMore() {
    state = ContributionPeriodsQuery(
      contributionSetupId: state.contributionSetupId,
      status: state.status,
      limit: state.limit + _defaultLimit,
    );
  }

  void resetPageSize() {
    state = ContributionPeriodsQuery(
      contributionSetupId: state.contributionSetupId,
      status: state.status,
    );
  }
}

final contributionPeriodsQueryProvider =
    NotifierProvider<
      ContributionPeriodsQueryNotifier,
      ContributionPeriodsQuery
    >(ContributionPeriodsQueryNotifier.new);
