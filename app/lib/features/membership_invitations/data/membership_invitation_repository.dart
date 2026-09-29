import '../domain/membership_invitation.dart';
import '../domain/membership_invitation_acceptance.dart';
import '../domain/membership_invitation_preview.dart';
import '../domain/membership_invitation_queue_item.dart';
import '../domain/membership_invitation_status.dart';

/// Officer-facing member-invitation operations (Prompt 09G-B1-E1
/// backend / E2 UX). Every method calls the corresponding
/// `SECURITY DEFINER` RPC — never a direct table read/write — and
/// throws [MembershipInvitationFailure] on any failure.
abstract class MembershipInvitationRepository {
  /// `rpc_create_membership_invitation(p_group_id, p_membership_id,
  /// p_role_codes)`. [roleCodes] are sent exactly as given — never a
  /// role_id, never a user_id; the server resolves and re-validates
  /// every code itself.
  Future<MembershipInvitation> createMembershipInvitation({
    required String groupId,
    required String membershipId,
    required List<String> roleCodes,
  });

  /// `rpc_list_membership_invitations(p_group_id, p_status, p_limit,
  /// p_offset)`. `status: null` means every status (History).
  Future<MembershipInvitationQueuePage> listMembershipInvitations({
    required String groupId,
    MembershipInvitationStatus? status,
    int limit = 20,
    int offset = 0,
  });

  /// `rpc_cancel_membership_invitation(p_group_id, p_invitation_id)`.
  Future<void> cancelMembershipInvitation({
    required String groupId,
    required String invitationId,
  });

  /// `rpc_preview_membership_invitation(p_token)` (Prompt 09G-B1-E3) —
  /// safe, read-only, zero-mutation preview by bearer token alone.
  Future<MembershipInvitationPreview> previewMembershipInvitation({
    required String token,
  });

  /// `rpc_accept_membership_invitation(p_token)` — token-only; never
  /// sends a user/membership/group/role id.
  Future<MembershipInvitationAcceptance> acceptMembershipInvitation({
    required String token,
  });
}
