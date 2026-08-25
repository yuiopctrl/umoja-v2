import 'contribution_setup.dart';

/// One page of `rpc_list_contribution_setups()` results.
class ContributionSetupPage {
  const ContributionSetupPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory ContributionSetupPage.fromJson(Map<String, dynamic> json) {
    return ContributionSetupPage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => ContributionSetup.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = ContributionSetupPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<ContributionSetup> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
