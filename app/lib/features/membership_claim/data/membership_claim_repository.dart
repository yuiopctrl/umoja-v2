import '../domain/membership_claim.dart';
import '../domain/membership_claim_queue_item.dart';

/// Server-authoritative access to the membership-claim workflow
/// (Prompt 09G-B1). Every call maps to exactly one backend RPC; there
/// is no direct table read/write anywhere in this module — ownership/
/// linking authority remains entirely server-side.
abstract class MembershipClaimRepository {
  /// Calls `rpc_request_membership_claim_by_reference()`. Sends only
  /// `p_group_code`/`p_member_number` — never a membership id,
  /// claimant id, phone, or group id. Idempotent: retrying with the
  /// same reference returns the caller's own existing PENDING claim
  /// ([MembershipClaim.alreadyRequested] `true`) rather than creating
  /// a duplicate.
  Future<MembershipClaim> requestMembershipClaimByReference({
    required String groupCode,
    required String memberNumber,
  });

  /// Calls `rpc_list_my_membership_claims()` — always and only the
  /// caller's own claims, any status, any group.
  Future<List<MembershipClaim>> listMyMembershipClaims();

  /// Calls `rpc_cancel_membership_claim()`. Only the claimant's own
  /// still-PENDING claim can be cancelled — enforced server-side.
  Future<MembershipClaim> cancelMembershipClaim({required String claimId});

  // -- Officer review (Prompt 09G-B1-D3) ----------------------------------

  /// Calls `rpc_list_membership_claims()` — the group-scoped,
  /// `member.claim.approve`-gated officer queue. [status] `null` means
  /// every status (matching the RPC's own `p_status is null` = "all"
  /// contract); omitting it defaults to PENDING, mirroring the RPC's
  /// own `p_status default 'PENDING'`.
  Future<MembershipClaimQueuePage> listMembershipClaims({
    required String groupId,
    MembershipClaimStatus? status = MembershipClaimStatus.pending,
    int limit = 20,
    int offset = 0,
  });

  /// A single claim's officer-facing detail. There is no dedicated
  /// get-by-id RPC in the backend contract (confirmed by inspecting
  /// 20260921091000/092000) — this is a derived read through the same
  /// `rpc_list_membership_claims()` the queue uses (requesting every
  /// status, across a bound generous enough for one group's realistic
  /// history), which inherits that RPC's exact same group/permission
  /// scoping for free. Throws a not-found-style
  /// [MembershipClaimFailure] if [claimId] is not among the results.
  Future<MembershipClaimQueueItem> getMembershipClaim({
    required String groupId,
    required String claimId,
  });

  /// Calls `rpc_approve_membership_claim()`. Requires
  /// `member.claim.approve`; the server re-validates every eligibility
  /// condition against the current row state — never trust a
  /// client-cached PENDING status.
  Future<MembershipClaim> approveMembershipClaim({
    required String groupId,
    required String claimId,
  });

  /// Calls `rpc_reject_membership_claim()`. [rejectionReason] is
  /// mandatory server-side (non-blank after trim) — never sent blank.
  Future<MembershipClaim> rejectMembershipClaim({
    required String groupId,
    required String claimId,
    required String rejectionReason,
  });
}
