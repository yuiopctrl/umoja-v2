import 'dart:async';

import 'package:umoja/features/membership_claim/data/membership_claim_failure.dart';
import 'package:umoja/features/membership_claim/data/membership_claim_repository.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim_queue_item.dart';

MembershipClaimQueueItem fakeMembershipClaimQueueItem({
  String claimId = 'claim-1',
  String membershipId = 'm1',
  String? membershipDisplayName = 'Amina Hassan',
  String? membershipMemberNumber = 'UMJ-2026-0001',
  String? membershipPhone = '+255700000001',
  String? claimantFullName = 'Amina H.',
  String? claimantPhone = '+255700000002',
  MembershipClaimStatus status = MembershipClaimStatus.pending,
  DateTime? requestedAt,
  DateTime? resolvedAt,
  String? rejectionReason,
}) {
  return MembershipClaimQueueItem(
    claimId: claimId,
    membershipId: membershipId,
    membershipDisplayName: membershipDisplayName,
    membershipMemberNumber: membershipMemberNumber,
    membershipPhone: membershipPhone,
    claimantFullName: claimantFullName,
    claimantPhone: claimantPhone,
    status: status,
    requestedAt: requestedAt ?? DateTime.utc(2026, 9, 20),
    resolvedAt: resolvedAt,
    rejectionReason: rejectionReason,
  );
}

MembershipClaim fakeMembershipClaim({
  String claimId = 'claim-1',
  String? groupId = 'g1',
  String? membershipId = 'm1',
  MembershipClaimStatus status = MembershipClaimStatus.pending,
  DateTime? requestedAt,
  DateTime? resolvedAt,
  String? rejectionReason,
  bool alreadyRequested = false,
}) {
  return MembershipClaim(
    claimId: claimId,
    groupId: groupId,
    membershipId: membershipId,
    status: status,
    requestedAt: requestedAt ?? DateTime.utc(2026, 9, 20),
    resolvedAt: resolvedAt,
    rejectionReason: rejectionReason,
    alreadyRequested: alreadyRequested,
  );
}

/// In-memory [MembershipClaimRepository] fake for tests (Prompt
/// 09G-B1-D2) — mirrors [FakeLoanRepository]'s pattern: records every
/// call so tests can assert double-submit prevention and the exact
/// arguments passed, and can be configured to throw a specific
/// failure to test error-surfacing.
class FakeMembershipClaimRepository implements MembershipClaimRepository {
  Object? failure;

  List<MembershipClaim> nextClaims = [];
  MembershipClaim nextRequestResult = fakeMembershipClaim();
  MembershipClaim nextCancelResult = fakeMembershipClaim(
    status: MembershipClaimStatus.cancelled,
    requestedAt: null,
    resolvedAt: DateTime.utc(2026, 9, 21),
  );

  /// When set, `requestMembershipClaimByReference` awaits this before
  /// returning — used to hold a call "in flight" for double-submit
  /// prevention tests.
  Completer<void>? requestGate;
  Completer<void>? cancelGate;
  Completer<void>? approveGate;
  Completer<void>? rejectGate;

  final List<({String groupCode, String memberNumber})>
  requestMembershipClaimByReferenceCalls = [];
  int listMyMembershipClaimsCallCount = 0;
  final List<({String claimId})> cancelMembershipClaimCalls = [];

  // -- Officer review (Prompt 09G-B1-D3) ----------------------------------

  List<MembershipClaimQueueItem> nextQueueItems = [];
  MembershipClaimQueueItem? nextDetailItem;
  MembershipClaim nextApproveResult = fakeMembershipClaim(
    status: MembershipClaimStatus.approved,
    resolvedAt: DateTime.utc(2026, 9, 21),
  );
  MembershipClaim nextRejectResult = fakeMembershipClaim(
    status: MembershipClaimStatus.rejected,
    resolvedAt: DateTime.utc(2026, 9, 21),
    rejectionReason: 'Could not verify identity',
  );

  final List<
    ({String groupId, MembershipClaimStatus? status, int limit, int offset})
  >
  listMembershipClaimsCalls = [];
  final List<({String groupId, String claimId})> getMembershipClaimCalls = [];
  final List<({String groupId, String claimId})> approveMembershipClaimCalls =
      [];
  final List<({String groupId, String claimId, String rejectionReason})>
  rejectMembershipClaimCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<MembershipClaim> requestMembershipClaimByReference({
    required String groupCode,
    required String memberNumber,
  }) async {
    requestMembershipClaimByReferenceCalls.add((
      groupCode: groupCode,
      memberNumber: memberNumber,
    ));
    final gate = requestGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextRequestResult;
  }

  @override
  Future<List<MembershipClaim>> listMyMembershipClaims() async {
    listMyMembershipClaimsCallCount++;
    _maybeThrow();
    return nextClaims;
  }

  @override
  Future<MembershipClaim> cancelMembershipClaim({
    required String claimId,
  }) async {
    cancelMembershipClaimCalls.add((claimId: claimId));
    final gate = cancelGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextCancelResult;
  }

  @override
  Future<MembershipClaimQueuePage> listMembershipClaims({
    required String groupId,
    MembershipClaimStatus? status = MembershipClaimStatus.pending,
    int limit = 20,
    int offset = 0,
  }) async {
    listMembershipClaimsCalls.add((
      groupId: groupId,
      status: status,
      limit: limit,
      offset: offset,
    ));
    _maybeThrow();
    return MembershipClaimQueuePage(
      items: nextQueueItems,
      totalCount: nextQueueItems.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<MembershipClaimQueueItem> getMembershipClaim({
    required String groupId,
    required String claimId,
  }) async {
    getMembershipClaimCalls.add((groupId: groupId, claimId: claimId));
    _maybeThrow();
    final detail = nextDetailItem;
    if (detail != null) return detail;
    throw const MembershipClaimFailure(
      MembershipClaimFailureType.notFound,
      'Membership claim not found in group.',
    );
  }

  @override
  Future<MembershipClaim> approveMembershipClaim({
    required String groupId,
    required String claimId,
  }) async {
    approveMembershipClaimCalls.add((groupId: groupId, claimId: claimId));
    final gate = approveGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextApproveResult;
  }

  @override
  Future<MembershipClaim> rejectMembershipClaim({
    required String groupId,
    required String claimId,
    required String rejectionReason,
  }) async {
    rejectMembershipClaimCalls.add((
      groupId: groupId,
      claimId: claimId,
      rejectionReason: rejectionReason,
    ));
    final gate = rejectGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextRejectResult;
  }
}
