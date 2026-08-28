import 'payment.dart';

/// One page of `rpc_list_member_payments()` results.
class PaymentPage {
  const PaymentPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory PaymentPage.fromJson(Map<String, dynamic> json) {
    return PaymentPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => Payment.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = PaymentPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<Payment> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
