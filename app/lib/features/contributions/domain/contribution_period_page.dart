import 'contribution_period.dart';

/// One page of `rpc_list_contribution_periods()` results.
class ContributionPeriodPage {
  const ContributionPeriodPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory ContributionPeriodPage.fromJson(Map<String, dynamic> json) {
    return ContributionPeriodPage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => ContributionPeriod.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = ContributionPeriodPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<ContributionPeriod> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
