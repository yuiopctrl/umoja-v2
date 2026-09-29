import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/app_context_provider.dart';
import '../data/membership_invitation_failure.dart';
import '../domain/membership_invitation_acceptance.dart';
import '../providers/membership_invitation_repository_provider.dart';

class MembershipInvitationAcceptanceState {
  const MembershipInvitationAcceptanceState({
    this.isAccepting = false,
    this.errorType,
    this.acceptance,
    this.acceptedToken,
  });

  final bool isAccepting;
  final MembershipInvitationFailureType? errorType;

  /// Set only after a successful (including idempotent-replay) accept
  /// call. Never used to construct/patch `MembershipContext` — it is
  /// display-only context for the brief success moment before
  /// [appContextProvider]'s own refetch resolves and the router takes
  /// over (Prompt 09G-B1-E3 §H).
  final MembershipInvitationAcceptance? acceptance;

  /// The EXACT bearer token [acceptance] belongs to. This controller
  /// is a single global instance (not per-token), so
  /// `route_guard.dart`'s `invitationJustAccepted` signal always
  /// compares against the CURRENT URL's token rather than trusting
  /// [acceptance] alone — otherwise a leftover success from a
  /// previously-accepted invitation could incorrectly mark a
  /// DIFFERENT, later-opened invitation as "just accepted" too.
  final String? acceptedToken;

  bool isAcceptedFor(String token) => acceptedToken == token;
}

/// Drives `rpc_accept_membership_invitation` (Prompt 09G-B1-E3). On
/// success, invalidates [appContextProvider] and stops — it never
/// manually constructs/patches a `MembershipContext`, never injects
/// roles/permissions from this RPC's own response (which doesn't even
/// return any), and never navigates itself. `selectedGroupProvider`
/// re-resolving and the router's existing redirect logic
/// (`route_guard.dart`) determine the destination naturally, exactly
/// like the D4 claim-approval transition.
class MembershipInvitationAcceptanceController
    extends Notifier<MembershipInvitationAcceptanceState> {
  @override
  MembershipInvitationAcceptanceState build() =>
      const MembershipInvitationAcceptanceState();

  /// Returns `true` on success (including a safe same-user replay of
  /// an already-accepted invitation). Never auto-retries; `isAccepting`
  /// guards against a double-submit from a fast double-tap.
  Future<bool> accept({required String token}) async {
    if (state.isAccepting) return false;

    state = const MembershipInvitationAcceptanceState(isAccepting: true);
    try {
      final acceptance = await ref
          .read(membershipInvitationRepositoryProvider)
          .acceptMembershipInvitation(token: token);
      ref.invalidate(appContextProvider);
      state = MembershipInvitationAcceptanceState(
        acceptance: acceptance,
        acceptedToken: token,
      );
      return true;
    } catch (error) {
      state = MembershipInvitationAcceptanceState(
        errorType: error is MembershipInvitationFailure
            ? error.type
            : MembershipInvitationFailureType.unexpected,
      );
      return false;
    }
  }
}

final membershipInvitationAcceptanceControllerProvider =
    NotifierProvider<
      MembershipInvitationAcceptanceController,
      MembershipInvitationAcceptanceState
    >(MembershipInvitationAcceptanceController.new);
