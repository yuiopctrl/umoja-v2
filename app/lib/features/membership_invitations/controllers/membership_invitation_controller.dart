import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/membership_invitation_failure.dart';
import '../domain/membership_invitation.dart';
import '../domain/membership_phone_invitation.dart';
import '../providers/membership_invitation_repository_provider.dart';
import '../providers/membership_invitations_queue_provider.dart';

class MembershipInvitationControllerState {
  const MembershipInvitationControllerState({
    this.isSubmitting = false,
    this.isCancelling = false,
    this.errorType,
  });

  final bool isSubmitting;
  final bool isCancelling;
  final MembershipInvitationFailureType? errorType;
}

/// Drives the two officer-initiated invitation actions: creating an
/// invitation and cancelling a still-PENDING one. Both always go
/// through the corresponding backend RPC — never a direct table write
/// — and both refresh [membershipInvitationsQueueProvider] on success
/// rather than fabricating the new state locally.
class MembershipInvitationController
    extends Notifier<MembershipInvitationControllerState> {
  @override
  MembershipInvitationControllerState build() =>
      const MembershipInvitationControllerState();

  /// Returns the created invitation (including its one-time plaintext
  /// token) on success, or `null` on failure with [state.errorType]
  /// set. `isSubmitting` guards against a double-submit from a fast
  /// double-tap.
  Future<MembershipInvitation?> create({
    required String groupId,
    required String membershipId,
    required List<String> roleCodes,
  }) async {
    if (state.isSubmitting) return null;

    state = const MembershipInvitationControllerState(isSubmitting: true);
    try {
      final invitation = await ref
          .read(membershipInvitationRepositoryProvider)
          .createMembershipInvitation(
            groupId: groupId,
            membershipId: membershipId,
            roleCodes: roleCodes,
          );
      state = const MembershipInvitationControllerState();
      return invitation;
    } catch (error) {
      state = MembershipInvitationControllerState(
        errorType: error is MembershipInvitationFailure
            ? error.type
            : MembershipInvitationFailureType.unexpected,
      );
      return null;
    }
  }

  /// Returns the created PHONE invitation on success, or `null` on
  /// failure with [state.errorType] set (Prompt 09G-B1-F1/F2 — the
  /// PRIMARY officer creation path from F2 onward). No bearer token is
  /// ever generated or returned. `isSubmitting` guards against a
  /// double-submit exactly like [create].
  Future<MembershipPhoneInvitation?> createPhoneInvitation({
    required String groupId,
    required String membershipId,
    required String phone,
    required List<String> roleCodes,
  }) async {
    if (state.isSubmitting) return null;

    state = const MembershipInvitationControllerState(isSubmitting: true);
    try {
      final invitation = await ref
          .read(membershipInvitationRepositoryProvider)
          .createPhoneInvitation(
            groupId: groupId,
            membershipId: membershipId,
            phone: phone,
            roleCodes: roleCodes,
          );
      state = const MembershipInvitationControllerState();
      return invitation;
    } catch (error) {
      state = MembershipInvitationControllerState(
        errorType: error is MembershipInvitationFailure
            ? error.type
            : MembershipInvitationFailureType.unexpected,
      );
      return null;
    }
  }

  /// Returns `true` on success. Never marks the invitation CANCELLED
  /// locally before the server confirms it.
  Future<bool> cancel({
    required String groupId,
    required String invitationId,
  }) async {
    if (state.isCancelling) return false;

    state = const MembershipInvitationControllerState(isCancelling: true);
    try {
      await ref
          .read(membershipInvitationRepositoryProvider)
          .cancelMembershipInvitation(
            groupId: groupId,
            invitationId: invitationId,
          );
      _invalidateQueues();
      state = const MembershipInvitationControllerState();
      return true;
    } catch (error) {
      final errorType = error is MembershipInvitationFailure
          ? error.type
          : MembershipInvitationFailureType.unexpected;
      // A stale-state failure (already resolved) means the server-side
      // state moved out from under this action — refresh so the
      // officer sees the real current state rather than a frozen one.
      if (errorType == MembershipInvitationFailureType.invitationNotPending) {
        _invalidateQueues();
      }
      state = MembershipInvitationControllerState(errorType: errorType);
      return false;
    }
  }

  void _invalidateQueues() {
    ref.invalidate(membershipInvitationsQueueProvider);
  }
}

final membershipInvitationControllerProvider =
    NotifierProvider<
      MembershipInvitationController,
      MembershipInvitationControllerState
    >(MembershipInvitationController.new);
