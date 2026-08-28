import 'contribution_opening_balance_item.dart';

/// One page of `rpc_list_contribution_opening_balances()` results.
class ContributionOpeningBalancePage {
  const ContributionOpeningBalancePage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory ContributionOpeningBalancePage.fromJson(Map<String, dynamic> json) {
    return ContributionOpeningBalancePage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => ContributionOpeningBalanceItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = ContributionOpeningBalancePage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<ContributionOpeningBalanceItem> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
