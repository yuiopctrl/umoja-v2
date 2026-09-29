import '../domain/membership_invitation.dart';
import '../domain/membership_invitation_acceptance.dart';
import '../domain/membership_invitation_decline.dart';
import '../domain/membership_invitation_preview.dart';
import '../domain/membership_invitation_queue_item.dart';
import '../domain/membership_invitation_status.dart';
import '../domain/membership_phone_invitation.dart';
import '../domain/my_membership_invitation.dart';

/// Member-invitation operations, both officer-facing (Prompt
/// 09G-B1-E1/E2, extended additively by F1/F2 for PHONE invitations)
/// and personal/recipient-facing (F1/F2). Every method calls the
/// corresponding `SECURITY DEFINER` RPC — never a direct table read/
/// write — and throws [MembershipInvitationFailure] on any failure.
abstract class MembershipInvitationRepository {
  // -- Officer: legacy TOKEN (Prompt 09G-B1-E1/E2/E3, kept for backward
  // compatibility — no longer the primary creation path from F2
  // onward, but old links must keep working).
  // -------------------------------------------------------------------

  /// `rpc_create_membership_invitation(p_group_id, p_membership_id,
  /// p_role_codes)`. [roleCodes] are sent exactly as given — never a
  /// role_id, never a user_id; the server resolves and re-validates
  /// every code itself.
  Future<MembershipInvitation> createMembershipInvitation({
    required String groupId,
    required String membershipId,
    required List<String> roleCodes,
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

  // -- Officer: shared across TOKEN and PHONE (unchanged by F1/F2 —
  // both invitation types flow through the exact same list/cancel
  // RPCs).
  // -------------------------------------------------------------------

  /// `rpc_list_membership_invitations(p_group_id, p_status, p_limit,
  /// p_offset)`. `status: null` means every status (History). Returns
  /// BOTH TOKEN and PHONE invitations for the group.
  Future<MembershipInvitationQueuePage> listMembershipInvitations({
    required String groupId,
    MembershipInvitationStatus? status,
    int limit = 20,
    int offset = 0,
  });

  /// `rpc_cancel_membership_invitation(p_group_id, p_invitation_id)`.
  /// Works on a PENDING invitation of either type.
  Future<void> cancelMembershipInvitation({
    required String groupId,
    required String invitationId,
  });

  // -- Officer: PHONE (Prompt 09G-B1-F1/F2 — the PRIMARY creation path
  // from F2 onward).
  // -------------------------------------------------------------------

  /// `rpc_create_membership_phone_invitation(p_group_id,
  /// p_membership_id, p_phone, p_role_codes)`. [phone] is sent exactly
  /// as typed/confirmed by the officer — the backend, never this
  /// client, is authoritative for normalization. Never sends a
  /// user_id/role_id.
  Future<MembershipPhoneInvitation> createPhoneInvitation({
    required String groupId,
    required String membershipId,
    required String phone,
    required List<String> roleCodes,
  });

  // -- Personal (Prompt 09G-B1-F1/F2) — the authenticated caller's OWN
  // invitations, discovered from their verified Auth phone. NEVER
  // takes a phone/user/group/membership id parameter of any kind.
  // -------------------------------------------------------------------

  /// `rpc_list_my_membership_invitations(p_status, p_limit,
  /// p_offset)`. Sends no phone/user/group id — ownership is resolved
  /// entirely server-side from `auth.uid()` + the caller's verified
  /// Auth phone.
  Future<MyMembershipInvitationsPage> listMyInvitations({
    MembershipInvitationStatus? status,
    int limit = 20,
    int offset = 0,
  });

  /// `rpc_accept_membership_phone_invitation(p_invitation_id)` — the
  /// invitation id is the ONLY input; never a phone/user/membership/
  /// group/role.
  Future<MembershipInvitationAcceptance> acceptPhoneInvitation({
    required String invitationId,
  });

  /// `rpc_decline_membership_phone_invitation(p_invitation_id)` — the
  /// invitation id is the ONLY input.
  Future<MembershipInvitationDecline> declinePhoneInvitation({
    required String invitationId,
  });
}
