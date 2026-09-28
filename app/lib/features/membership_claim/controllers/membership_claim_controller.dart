import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/membership_claim_failure.dart';
import '../providers/membership_claim_detail_provider.dart';
import '../providers/membership_claim_repository_provider.dart';
import '../providers/membership_claims_queue_provider.dart';
import '../providers/my_membership_claims_provider.dart';

class MembershipClaimControllerState {
  const MembershipClaimControllerState({
    this.isSubmitting = false,
    this.isCancelling = false,
    this.isApproving = false,
    this.isRejecting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final bool isCancelling;
  final bool isApproving;
  final bool isRejecting;
  final MembershipClaimFailureType? errorType;
}

/// §K: failure types that mean the claim/membership's server-side
/// state itself moved out from under this action (someone else already
/// approved/rejected it, the membership/group became inactive, etc.)
/// — a stale read, not a transient/permission problem. These trigger
/// the same queue/detail refresh a SUCCESS would, so the officer
/// immediately sees the real current state rather than a frozen stale
/// one. `permissionDenied`/`network`/`unexpected`/
/// `rejectionReasonRequired` are deliberately excluded — none of those
/// mean the claim's own state changed.
const _staleStateFailureTypes = {
  MembershipClaimFailureType.notPending,
  MembershipClaimFailureType.alreadyLinked,
  MembershipClaimFailureType.claimantAlreadyActiveInGroup,
  MembershipClaimFailureType.membershipNotActive,
  MembershipClaimFailureType.groupNotActive,
};

/// Drives the two claimant-initiated actions: requesting a claim by
/// human-readable reference, and cancelling the caller's own still-
/// PENDING claim. Both always go through the corresponding backend
/// RPC — never a direct table write — and both refresh
/// [myMembershipClaimsProvider] on success rather than fabricating
/// the new state locally.
class MembershipClaimController
    extends Notifier<MembershipClaimControllerState> {
  @override
  MembershipClaimControllerState build() =>
      const MembershipClaimControllerState();

  /// Returns `true` on success (including an idempotent retry that
  /// returned the caller's own existing PENDING claim).
  Future<bool> requestByReference({
    required String groupCode,
    required String memberNumber,
  }) async {
    if (state.isSubmitting) return false;

    state = const MembershipClaimControllerState(isSubmitting: true);
    try {
      await ref
          .read(membershipClaimRepositoryProvider)
          .requestMembershipClaimByReference(
            groupCode: groupCode,
            memberNumber: memberNumber,
          );
      ref.invalidate(myMembershipClaimsProvider);
      state = const MembershipClaimControllerState();
      return true;
    } catch (error) {
      state = MembershipClaimControllerState(
        errorType: error is MembershipClaimFailure
            ? error.type
            : MembershipClaimFailureType.unexpected,
      );
      return false;
    }
  }

  /// Returns `true` on success. On failure, [state.errorType] is set
  /// and the claim's displayed status is left exactly as it was
  /// before this call — never optimistically marked CANCELLED.
  Future<bool> cancel({required String claimId}) async {
    if (state.isCancelling) return false;

    state = const MembershipClaimControllerState(isCancelling: true);
    try {
      await ref
          .read(membershipClaimRepositoryProvider)
          .cancelMembershipClaim(claimId: claimId);
      ref.invalidate(myMembershipClaimsProvider);
      state = const MembershipClaimControllerState();
      return true;
    } catch (error) {
      state = MembershipClaimControllerState(
        errorType: error is MembershipClaimFailure
            ? error.type
            : MembershipClaimFailureType.unexpected,
      );
      return false;
    }
  }

  // -- Officer review (Prompt 09G-B1-D3) ---------------------------------

  /// Approves a PENDING claim via `rpc_approve_membership_claim`. Never
  /// marks the claim APPROVED locally before the server confirms it —
  /// [state.errorType] is set on any failure (including a stale/
  /// already-resolved claim, re-validated authoritatively server-side)
  /// and the caller re-fetches [membershipClaimsQueueProvider]/
  /// [membershipClaimDetailProvider] to reflect the real current state
  /// either way. Returns `true` on success.
  Future<bool> approve({
    required String groupId,
    required String claimId,
  }) async {
    if (state.isApproving) return false;

    state = const MembershipClaimControllerState(isApproving: true);
    try {
      await ref
          .read(membershipClaimRepositoryProvider)
          .approveMembershipClaim(groupId: groupId, claimId: claimId);
      ref.invalidate(membershipClaimsQueueProvider);
      ref.invalidate(membershipClaimDetailProvider);
      state = const MembershipClaimControllerState();
      return true;
    } catch (error) {
      final errorType = error is MembershipClaimFailure
          ? error.type
          : MembershipClaimFailureType.unexpected;
      if (_staleStateFailureTypes.contains(errorType)) {
        ref.invalidate(membershipClaimsQueueProvider);
        ref.invalidate(membershipClaimDetailProvider);
      }
      state = MembershipClaimControllerState(errorType: errorType);
      return false;
    }
  }

  /// Rejects a PENDING claim via `rpc_reject_membership_claim`.
  /// [rejectionReason] is sent exactly as given — the server enforces
  /// non-blank, never a client-only rule. Returns `true` on success.
  Future<bool> reject({
    required String groupId,
    required String claimId,
    required String rejectionReason,
  }) async {
    if (state.isRejecting) return false;

    state = const MembershipClaimControllerState(isRejecting: true);
    try {
      await ref
          .read(membershipClaimRepositoryProvider)
          .rejectMembershipClaim(
            groupId: groupId,
            claimId: claimId,
            rejectionReason: rejectionReason,
          );
      ref.invalidate(membershipClaimsQueueProvider);
      ref.invalidate(membershipClaimDetailProvider);
      state = const MembershipClaimControllerState();
      return true;
    } catch (error) {
      final errorType = error is MembershipClaimFailure
          ? error.type
          : MembershipClaimFailureType.unexpected;
      if (_staleStateFailureTypes.contains(errorType)) {
        ref.invalidate(membershipClaimsQueueProvider);
        ref.invalidate(membershipClaimDetailProvider);
      }
      state = MembershipClaimControllerState(errorType: errorType);
      return false;
    }
  }
}

final membershipClaimControllerProvider =
    NotifierProvider<MembershipClaimController, MembershipClaimControllerState>(
      MembershipClaimController.new,
    );
