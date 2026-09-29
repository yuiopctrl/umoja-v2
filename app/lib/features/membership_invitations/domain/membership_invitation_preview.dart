import 'membership_invitation_status.dart';

/// `rpc_preview_membership_invitation`'s result (Prompt 09G-B1-E3) —
/// safe, read-only, zero-mutation confirmation context for the invited
/// member, before acceptance. Every field here is exactly what the RPC
/// returns; this model never derives, infers, or supplements anything
/// from the URL/token itself, and never carries an internal id
/// (membership_id/group_id/invitation_id are deliberately never
/// returned by this RPC — see the E1 migration).
class MembershipInvitationPreview {
  const MembershipInvitationPreview({
    required this.status,
    required this.expiresAt,
    required this.groupName,
    required this.membershipDisplayName,
    required this.membershipMemberNumber,
    required this.roleNames,
  });

  factory MembershipInvitationPreview.fromJson(Map<String, dynamic> json) {
    return MembershipInvitationPreview(
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      groupName: json['group_name'] as String?,
      membershipDisplayName: json['membership_display_name'] as String?,
      membershipMemberNumber: json['membership_member_number'] as String?,
      roleNames: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  /// The server-computed EFFECTIVE status (PENDING/EXPIRED/ACCEPTED/
  /// CANCELLED) — the RPC itself already resolves PENDING-but-past-
  /// expiry to EXPIRED before returning, so this is never re-derived
  /// client-side.
  final MembershipInvitationStatus status;
  final DateTime expiresAt;
  final String? groupName;
  final String? membershipDisplayName;
  final String? membershipMemberNumber;

  /// Role DISPLAY NAMES (e.g. "Treasurer"), never codes — this RPC
  /// returns `roles.name`, not `roles.code`.
  final List<String> roleNames;

  bool get isActionable => status == MembershipInvitationStatus.pending;
}
