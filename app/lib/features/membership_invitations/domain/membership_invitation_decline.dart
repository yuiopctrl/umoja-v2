import 'membership_invitation_status.dart';

/// `rpc_decline_membership_phone_invitation`'s result (Prompt
/// 09G-B1-F1). Never touches group_memberships/group_membership_roles
/// server-side, so this carries no membership/role information at
/// all — only the invitation's own new terminal state.
class MembershipInvitationDecline {
  const MembershipInvitationDecline({
    required this.invitationId,
    required this.groupId,
    required this.membershipId,
    required this.status,
    required this.declinedAt,
    required this.alreadyDeclined,
  });

  factory MembershipInvitationDecline.fromJson(Map<String, dynamic> json) {
    return MembershipInvitationDecline(
      invitationId: json['invitation_id'] as String,
      groupId: json['group_id'] as String,
      membershipId: json['membership_id'] as String,
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      declinedAt: json['declined_at'] == null
          ? null
          : DateTime.parse(json['declined_at'] as String),
      alreadyDeclined: json['already_declined'] as bool? ?? false,
    );
  }

  final String invitationId;
  final String groupId;
  final String membershipId;
  final MembershipInvitationStatus status;
  final DateTime? declinedAt;

  /// `true` when this call was a safe idempotent retry by the SAME
  /// user who already declined this exact invitation.
  final bool alreadyDeclined;
}
