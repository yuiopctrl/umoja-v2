import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/membership_invitation.dart';
import '../domain/membership_invitation_acceptance.dart';
import '../domain/membership_invitation_preview.dart';
import '../domain/membership_invitation_queue_item.dart';
import '../domain/membership_invitation_status.dart';
import 'membership_invitation_failure.dart';
import 'membership_invitation_repository.dart';

final _log = Logger('SupabaseMembershipInvitationRepository');

class SupabaseMembershipInvitationRepository
    implements MembershipInvitationRepository {
  SupabaseMembershipInvitationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MembershipInvitation> createMembershipInvitation({
    required String groupId,
    required String membershipId,
    required List<String> roleCodes,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_membership_invitation',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_role_codes': roleCodes,
        },
      );
      return MembershipInvitation.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipInvitationQueuePage> listMembershipInvitations({
    required String groupId,
    MembershipInvitationStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_membership_invitations',
        params: {
          'p_group_id': groupId,
          'p_status': _statusParam(status),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return MembershipInvitationQueuePage.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> cancelMembershipInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    try {
      await _client.rpc(
        'rpc_cancel_membership_invitation',
        params: {'p_group_id': groupId, 'p_invitation_id': invitationId},
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipInvitationPreview> previewMembershipInvitation({
    required String token,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_membership_invitation',
        params: {'p_token': token},
      );
      return MembershipInvitationPreview.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MembershipInvitationAcceptance> acceptMembershipInvitation({
    required String token,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_accept_membership_invitation',
        params: {'p_token': token},
      );
      return MembershipInvitationAcceptance.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

/// `rpc_list_membership_invitations`'s `p_status` is a Postgres enum,
/// sent as its bare uppercase text label — `null` maps through
/// untouched (the RPC's own `p_status is null` branch means "every
/// status").
String? _statusParam(MembershipInvitationStatus? status) => switch (status) {
  null => null,
  MembershipInvitationStatus.pending => 'PENDING',
  MembershipInvitationStatus.accepted => 'ACCEPTED',
  MembershipInvitationStatus.cancelled => 'CANCELLED',
  MembershipInvitationStatus.expired => 'EXPIRED',
  MembershipInvitationStatus.unknown => null,
};

MembershipInvitationFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning(
      'Membership invitation RPC error (code=${error.code})',
      error,
      stackTrace,
    );

    final message = error.message;
    final code = error.code;

    if (message.contains('MEMBERSHIP_INVITATION_NOT_FOUND')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.invitationNotFound,
        'We could not find that invitation.',
      );
    }
    if (message.contains('MEMBERSHIP_INVITATION_EXPIRED')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.invitationExpired,
        'This invitation has expired.',
      );
    }
    if (message.contains('CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.claimantAlreadyActiveInGroup,
        'You already have an active membership in this group.',
      );
    }
    if (message.contains('ACCOUNT_DISABLED')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.accountDisabled,
        'Your account access has been disabled. Contact your group administrator.',
      );
    }
    if (message.contains('Only an existing ADMIN may invite')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.adminRoleRequired,
        'Only an existing ADMIN may invite a member with the ADMIN role.',
      );
    }
    if (message.contains('At least one role must be selected')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.roleSelectionRequired,
        'At least one role must be selected.',
      );
    }
    if (message.contains('Unknown role code')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.unknownRole,
        'One of the selected roles is not recognized.',
      );
    }
    if (message.contains('MEMBERSHIP_INVITATION_ALREADY_PENDING')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.invitationAlreadyPending,
        'An invitation is already pending for this member.',
      );
    }
    if (message.contains('MEMBERSHIP_INVITATION_NOT_PENDING')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.invitationNotPending,
        'This invitation has already been resolved.',
      );
    }
    if (message.contains('MEMBERSHIP_ALREADY_LINKED')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.membershipAlreadyLinked,
        'This member already has a linked account.',
      );
    }
    if (message.contains('MEMBERSHIP_NOT_ACTIVE')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.membershipNotActive,
        'This member is no longer active.',
      );
    }
    if (message.contains('GROUP_NOT_ACTIVE')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.groupNotActive,
        'This group is no longer active.',
      );
    }
    if (message.contains('not found')) {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.membershipNotFound,
        'Not found.',
      );
    }
    if (code == '42501') {
      return const MembershipInvitationFailure(
        MembershipInvitationFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const MembershipInvitationFailure(
      MembershipInvitationFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe(
    'Unexpected membership invitation repository error',
    error,
    stackTrace,
  );

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const MembershipInvitationFailure(
      MembershipInvitationFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const MembershipInvitationFailure(
    MembershipInvitationFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
