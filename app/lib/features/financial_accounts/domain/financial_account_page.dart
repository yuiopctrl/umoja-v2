import 'financial_account.dart';

/// One page of `rpc_list_financial_accounts()` results.
class FinancialAccountPage {
  const FinancialAccountPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory FinancialAccountPage.fromJson(Map<String, dynamic> json) {
    return FinancialAccountPage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => FinancialAccount.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = FinancialAccountPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<FinancialAccount> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
