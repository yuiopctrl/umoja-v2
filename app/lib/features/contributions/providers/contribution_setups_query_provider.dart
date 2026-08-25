import 'package:flutter_riverpod/flutter_riverpod.dart';

const _defaultLimit = 10;

/// The Contribution Setups list's current filter/pagination state.
class ContributionSetupsQuery {
  const ContributionSetupsQuery({
    this.contributionTypeId,
    this.isActive,
    this.limit = _defaultLimit,
  });

  /// `null` for "all types".
  final String? contributionTypeId;

  /// `null` for "All", otherwise filters to active/inactive only.
  final bool? isActive;

  final int limit;
}

class ContributionSetupsQueryNotifier
    extends Notifier<ContributionSetupsQuery> {
  @override
  ContributionSetupsQuery build() => const ContributionSetupsQuery();

  void setTypeFilter(String? value) {
    state = ContributionSetupsQuery(
      contributionTypeId: value,
      isActive: state.isActive,
    );
  }

  void setActiveFilter(bool? value) {
    state = ContributionSetupsQuery(
      contributionTypeId: state.contributionTypeId,
      isActive: value,
    );
  }

  void loadMore() {
    state = ContributionSetupsQuery(
      contributionTypeId: state.contributionTypeId,
      isActive: state.isActive,
      limit: state.limit + _defaultLimit,
    );
  }

  void resetPageSize() {
    state = ContributionSetupsQuery(
      contributionTypeId: state.contributionTypeId,
      isActive: state.isActive,
    );
  }
}

final contributionSetupsQueryProvider =
    NotifierProvider<ContributionSetupsQueryNotifier, ContributionSetupsQuery>(
      ContributionSetupsQueryNotifier.new,
    );
