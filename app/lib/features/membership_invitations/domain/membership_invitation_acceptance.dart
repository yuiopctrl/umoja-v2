import 'membership_invitation_status.dart';

/// `rpc_accept_membership_invitation`'s result (Prompt 09G-B1-E3).
/// Deliberately does NOT carry role/permission information — the
/// accept RPC itself never returns roles; the authoritative post-
/// accept membership/role/permission state is always read back from
/// `appContextProvider` (`rpc_get_my_context()`), never fabricated
/// from this result.
class MembershipInvitationAcceptance {
  const MembershipInvitationAcceptance({
    required this.invitationId,
    required this.groupId,
    required this.membershipId,
    required this.status,
    required this.acceptedAt,
    required this.alreadyAccepted,
  });

  factory MembershipInvitationAcceptance.fromJson(Map<String, dynamic> json) {
    return MembershipInvitationAcceptance(
      invitationId: json['invitation_id'] as String,
      groupId: json['group_id'] as String,
      membershipId: json['membership_id'] as String,
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      alreadyAccepted: json['already_accepted'] as bool? ?? false,
    );
  }

  final String invitationId;
  final String groupId;
  final String membershipId;
  final MembershipInvitationStatus status;
  final DateTime? acceptedAt;

  /// `true` when this call was a safe idempotent retry by the SAME
  /// user who already successfully accepted this exact invitation —
  /// never a mutation the second time.
  final bool alreadyAccepted;
}
