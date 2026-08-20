import 'group_member.dart';

/// One page of `rpc_list_group_members()` results.
class GroupMemberPage {
  const GroupMemberPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory GroupMemberPage.fromJson(Map<String, dynamic> json) {
    return GroupMemberPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => GroupMember.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = GroupMemberPage(
    items: [],
    totalCount: 0,
    limit: 25,
    offset: 0,
  );

  final List<GroupMember> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
