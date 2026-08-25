import 'member_contribution_charge.dart';

/// One page of `rpc_list_contribution_period_charges()` results.
class MemberContributionChargePage {
  const MemberContributionChargePage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory MemberContributionChargePage.fromJson(Map<String, dynamic> json) {
    return MemberContributionChargePage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) =>
                MemberContributionCharge.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = MemberContributionChargePage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<MemberContributionCharge> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
