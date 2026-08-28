import 'financial_account_entry.dart';

/// One page of `rpc_list_financial_account_entries()` results.
class FinancialAccountEntryPage {
  const FinancialAccountEntryPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory FinancialAccountEntryPage.fromJson(Map<String, dynamic> json) {
    return FinancialAccountEntryPage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) =>
                FinancialAccountEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = FinancialAccountEntryPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<FinancialAccountEntry> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
