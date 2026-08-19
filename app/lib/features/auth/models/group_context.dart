/// A group (tenant) as seen through one of the caller's memberships.
/// Mirrors the group fields embedded per-membership in the
/// `rpc_get_my_context()` response.
class GroupContext {
  const GroupContext({
    required this.groupId,
    required this.groupName,
    required this.groupStatus,
  });

  factory GroupContext.fromJson(Map<String, dynamic> json) {
    return GroupContext(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      groupStatus: json['group_status'] as String,
    );
  }

  final String groupId;
  final String groupName;

  /// One of ACTIVE / SUSPENDED / CLOSED. Kept as the raw backend code
  /// rather than a Dart enum so new statuses don't require a client
  /// release to display.
  final String groupStatus;
}
