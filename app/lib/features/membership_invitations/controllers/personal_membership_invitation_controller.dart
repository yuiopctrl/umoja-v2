import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/app_context_provider.dart';
import '../data/membership_invitation_failure.dart';
import '../domain/membership_invitation_acceptance.dart';
import '../domain/membership_invitation_decline.dart';
import '../providers/membership_invitation_repository_provider.dart';
import '../providers/my_membership_invitations_provider.dart';

class PersonalMembershipInvitationState {
  const PersonalMembershipInvitationState({
    this.isAccepting = false,
    this.isDeclining = false,
    this.errorType,
  });

  final bool isAccepting;
  final bool isDeclining;
  final MembershipInvitationFailureType? errorType;
}

/// Drives the personal inbox's two recipient actions — accept and
/// decline a PHONE invitation (Prompt 09G-B1-F2). Deliberately
/// SEPARATE from [MembershipInvitationAcceptanceController] (the
/// TOKEN-flow controller wired into `route_guard.dart`'s
/// `invitationJustAccepted` signal for `/invite/:token`'s own hold
/// logic) — the personal inbox has no equivalent per-token route hold
/// to coordinate with, so reusing that controller would entangle two
/// unrelated concerns. Both actions here send ONLY the invitation id
/// (Prompt 09G-B1-F1 §J/§K) — never a phone/user/membership/group/role
/// — and never manually construct/patch `MembershipContext`; the
/// authoritative post-accept membership/role/group-selection state is
/// always re-derived from `appContextProvider`
/// (`selectedGroupProvider` already watches it — see
/// `selected_group_provider.dart`).
class PersonalMembershipInvitationController
    extends Notifier<PersonalMembershipInvitationState> {
  @override
  PersonalMembershipInvitationState build() =>
      const PersonalMembershipInvitationState();

  /// Returns `true` on success (including a safe same-user replay of
  /// an already-accepted invitation). `isAccepting` guards against a
  /// double-submit from a fast double-tap.
  Future<bool> accept({required String invitationId}) async {
    if (state.isAccepting) return false;

    state = const PersonalMembershipInvitationState(isAccepting: true);
    try {
      final MembershipInvitationAcceptance _ = await ref
          .read(membershipInvitationRepositoryProvider)
          .acceptPhoneInvitation(invitationId: invitationId);
      // appContextProvider's refetch is what lets selectedGroupProvider
      // re-derive the (possibly now-multi-group) operational state —
      // this controller never constructs that state itself.
      ref.invalidate(appContextProvider);
      ref.invalidate(myMembershipInvitationsProvider);
      state = const PersonalMembershipInvitationState();
      return true;
    } catch (error) {
      state = PersonalMembershipInvitationState(
        errorType: error is MembershipInvitationFailure
            ? error.type
            : MembershipInvitationFailureType.unexpected,
      );
      return false;
    }
  }

  /// Returns `true` on success (including a safe same-user replay of
  /// an already-declined invitation). Never mutates
  /// group_memberships/appContext — decline only ever changes the
  /// invitation's own terminal state.
  Future<bool> decline({required String invitationId}) async {
    if (state.isDeclining) return false;

    state = const PersonalMembershipInvitationState(isDeclining: true);
    try {
      final MembershipInvitationDecline _ = await ref
          .read(membershipInvitationRepositoryProvider)
          .declinePhoneInvitation(invitationId: invitationId);
      ref.invalidate(myMembershipInvitationsProvider);
      state = const PersonalMembershipInvitationState();
      return true;
    } catch (error) {
      state = PersonalMembershipInvitationState(
        errorType: error is MembershipInvitationFailure
            ? error.type
            : MembershipInvitationFailureType.unexpected,
      );
      return false;
    }
  }
}

final personalMembershipInvitationControllerProvider =
    NotifierProvider<
      PersonalMembershipInvitationController,
      PersonalMembershipInvitationState
    >(PersonalMembershipInvitationController.new);
