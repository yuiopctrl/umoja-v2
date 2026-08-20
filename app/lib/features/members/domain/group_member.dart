/// A group member (a domain `group_memberships` row), as returned by
/// `rpc_list_group_members()`/`rpc_get_group_member()`.
///
/// A member is not the same thing as an authenticated Umoja user — see
/// docs/product/member-identity-model.md. [isLoginLinked] reflects
/// `group_memberships.user_id IS NOT NULL`; the raw id is never exposed
/// as a UI concept.
class GroupMember {
  const GroupMember({
    required this.membershipId,
    required this.groupId,
    required this.displayName,
    this.memberNumber,
    this.phone,
    required this.status,
    this.joinedAt,
    this.exitedAt,
    required this.createdAt,
    this.updatedAt,
    required this.isLoginLinked,
    this.roleCodes,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      membershipId: json['membership_id'] as String,
      groupId: json['group_id'] as String,
      displayName: json['display_name'] as String,
      memberNumber: json['member_number'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String,
      joinedAt: _parseDate(json['joined_at']),
      exitedAt: _parseDate(json['exited_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      isLoginLinked: json['is_login_linked'] as bool? ?? false,
      // `roles` is `null` when the caller lacks role.view (not shown),
      // and a (possibly empty) list when they can see role assignments.
      roleCodes: json['roles'] == null
          ? null
          : (json['roles'] as List<dynamic>).cast<String>(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  final String membershipId;
  final String groupId;
  final String displayName;
  final String? memberNumber;
  final String? phone;

  /// One of ACTIVE / SUSPENDED / EXITED.
  final String status;
  final DateTime? joinedAt;
  final DateTime? exitedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLoginLinked;

  /// `null` means role assignments are not visible to the caller (no
  /// role.view in this group) — distinct from an empty list, which
  /// means the caller can see roles and this member genuinely has none.
  final List<String>? roleCodes;

  bool get isActive => status == 'ACTIVE';
  bool get isSuspended => status == 'SUSPENDED';
  bool get isExited => status == 'EXITED';

  /// Whether the caller can see role assignments for this member at
  /// all (role.view was granted server-side).
  bool get canViewRoles => roleCodes != null;
}
