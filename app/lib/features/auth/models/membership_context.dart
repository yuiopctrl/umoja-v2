import 'group_context.dart';

/// One of the caller's group memberships, with the group it belongs to,
/// their assigned role codes, and their effective permission codes in
/// that group — as returned by `rpc_get_my_context()`.
///
/// Role and permission codes are kept as plain strings (matching
/// `roles.code` / `permissions.code`) rather than Dart enums, since the
/// backend is the source of truth for which codes exist.
class MembershipContext {
  const MembershipContext({
    required this.membershipId,
    required this.group,
    required this.membershipStatus,
    required this.displayName,
    required this.roleCodes,
    required this.permissionCodes,
  });

  factory MembershipContext.fromJson(Map<String, dynamic> json) {
    return MembershipContext(
      membershipId: json['membership_id'] as String,
      group: GroupContext.fromJson(json),
      membershipStatus: json['membership_status'] as String,
      displayName: json['display_name'] as String,
      roleCodes: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      permissionCodes: (json['permissions'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  final String membershipId;
  final GroupContext group;

  /// One of ACTIVE / SUSPENDED / EXITED.
  final String membershipStatus;
  final String displayName;
  final List<String> roleCodes;
  final List<String> permissionCodes;

  bool hasPermission(String code) => permissionCodes.contains(code);
}
