import 'membership_invitation_status.dart';

/// `rpc_create_membership_invitation`'s result (Prompt 09G-B1-E1). The
/// server returns the plaintext bearer [token] EXACTLY ONCE, on a
/// successful creation call — it is never persisted (SharedPreferences,
/// local DB, logs, analytics) and never reconstructable from
/// `token_hash`. Treat it as ephemeral: safe to hold in memory only for
/// as long as the "Invitation Created" screen that rendered this exact
/// result is on screen.
class MembershipInvitation {
  const MembershipInvitation({
    required this.invitationId,
    required this.groupId,
    required this.membershipId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.roleCodes,
    required this.token,
  });

  factory MembershipInvitation.fromJson(Map<String, dynamic> json) {
    return MembershipInvitation(
      invitationId: json['invitation_id'] as String,
      groupId: json['group_id'] as String,
      membershipId: json['membership_id'] as String,
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      roleCodes: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      token: json['token'] as String,
    );
  }

  final String invitationId;
  final String groupId;
  final String membershipId;
  final MembershipInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> roleCodes;

  /// The one-time plaintext bearer token. See the class doc — never
  /// persist, log, or send to analytics.
  final String token;
}
