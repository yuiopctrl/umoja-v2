import 'contribution_type.dart';

/// One page of `rpc_list_contribution_types()` results.
class ContributionTypePage {
  const ContributionTypePage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory ContributionTypePage.fromJson(Map<String, dynamic> json) {
    return ContributionTypePage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => ContributionType.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = ContributionTypePage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<ContributionType> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
