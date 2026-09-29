import 'membership_invitation_status.dart';

/// `rpc_create_membership_phone_invitation`'s result (Prompt
/// 09G-B1-F1). No bearer token is ever generated for a PHONE
/// invitation — see [MembershipInvitation] (`domain/
/// membership_invitation.dart`) for the legacy TOKEN creation result,
/// which this deliberately does NOT share a class with (different
/// field shape: [targetPhoneE164] here, `token` there).
class MembershipPhoneInvitation {
  const MembershipPhoneInvitation({
    required this.invitationId,
    required this.groupId,
    required this.membershipId,
    required this.status,
    required this.targetPhoneE164,
    required this.createdAt,
    required this.expiresAt,
    required this.roleCodes,
  });

  factory MembershipPhoneInvitation.fromJson(Map<String, dynamic> json) {
    return MembershipPhoneInvitation(
      invitationId: json['invitation_id'] as String,
      groupId: json['group_id'] as String,
      membershipId: json['membership_id'] as String,
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      targetPhoneE164: json['target_phone_e164'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      roleCodes: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  final String invitationId;
  final String groupId;
  final String membershipId;
  final MembershipInvitationStatus status;

  /// The canonical (+255XXXXXXXXX) target phone, as normalized and
  /// echoed back by the server — never re-derived client-side.
  final String targetPhoneE164;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> roleCodes;
}
