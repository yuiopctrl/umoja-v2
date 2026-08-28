import 'wallet_entry.dart';

/// One page of `rpc_list_member_wallet_entries()` results — bundles
/// the current [walletBalance] alongside the ledger page itself, so a
/// screen never needs a second round-trip just to show the balance.
class WalletEntryPage {
  const WalletEntryPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
    required this.walletBalance,
  });

  factory WalletEntryPage.fromJson(Map<String, dynamic> json) {
    return WalletEntryPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => WalletEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      walletBalance: (json['wallet_balance'] as num).toDouble(),
    );
  }

  static const empty = WalletEntryPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
    walletBalance: 0,
  );

  final List<WalletEntry> items;
  final int totalCount;
  final int limit;
  final int offset;
  final double walletBalance;

  bool get hasMore => offset + items.length < totalCount;
}
