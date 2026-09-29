import 'dart:async';

import 'package:umoja/features/membership_invitations/data/membership_invitation_repository.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_acceptance.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_preview.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_queue_item.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_status.dart';

MembershipInvitationPreview fakeMembershipInvitationPreview({
  MembershipInvitationStatus status = MembershipInvitationStatus.pending,
  DateTime? expiresAt,
  String? groupName = 'Umoja Wamama',
  String? membershipDisplayName = 'Amina Hassan',
  String? membershipMemberNumber = 'UMJ-2026-0001',
  List<String> roleNames = const ['Treasurer'],
}) {
  return MembershipInvitationPreview(
    status: status,
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 27),
    groupName: groupName,
    membershipDisplayName: membershipDisplayName,
    membershipMemberNumber: membershipMemberNumber,
    roleNames: roleNames,
  );
}

MembershipInvitationAcceptance fakeMembershipInvitationAcceptance({
  String invitationId = 'invitation-1',
  String groupId = 'g1',
  String membershipId = 'm1',
  MembershipInvitationStatus status = MembershipInvitationStatus.accepted,
  DateTime? acceptedAt,
  bool alreadyAccepted = false,
}) {
  return MembershipInvitationAcceptance(
    invitationId: invitationId,
    groupId: groupId,
    membershipId: membershipId,
    status: status,
    acceptedAt: acceptedAt ?? DateTime.utc(2026, 9, 21),
    alreadyAccepted: alreadyAccepted,
  );
}

MembershipInvitation fakeMembershipInvitation({
  String invitationId = 'invitation-1',
  String groupId = 'g1',
  String membershipId = 'm1',
  MembershipInvitationStatus status = MembershipInvitationStatus.pending,
  DateTime? createdAt,
  DateTime? expiresAt,
  List<String> roleCodes = const ['MEMBER'],
  String token =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) {
  return MembershipInvitation(
    invitationId: invitationId,
    groupId: groupId,
    membershipId: membershipId,
    status: status,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 20),
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 27),
    roleCodes: roleCodes,
    token: token,
  );
}

MembershipInvitationQueueItem fakeMembershipInvitationQueueItem({
  String invitationId = 'invitation-1',
  String membershipId = 'm1',
  String? membershipDisplayName = 'Amina Hassan',
  String? membershipMemberNumber = 'UMJ-2026-0001',
  MembershipInvitationStatus status = MembershipInvitationStatus.pending,
  bool isExpired = false,
  List<String> roleCodes = const ['MEMBER'],
  DateTime? createdAt,
  DateTime? expiresAt,
  String? createdByFullName = 'Officer One',
  DateTime? acceptedAt,
  String? acceptedByFullName,
  DateTime? cancelledAt,
  String? cancelledByFullName,
}) {
  return MembershipInvitationQueueItem(
    invitationId: invitationId,
    membershipId: membershipId,
    membershipDisplayName: membershipDisplayName,
    membershipMemberNumber: membershipMemberNumber,
    status: status,
    isExpired: isExpired,
    roleCodes: roleCodes,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 20),
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 27),
    createdByFullName: createdByFullName,
    acceptedAt: acceptedAt,
    acceptedByFullName: acceptedByFullName,
    cancelledAt: cancelledAt,
    cancelledByFullName: cancelledByFullName,
  );
}

/// In-memory [MembershipInvitationRepository] fake for tests (Prompt
/// 09G-B1-E2) — mirrors [FakeMembershipClaimRepository]'s pattern:
/// records every call so tests can assert double-submit prevention and
/// the exact arguments passed, and can be configured to throw a
/// specific failure to test error-surfacing.
class FakeMembershipInvitationRepository
    implements MembershipInvitationRepository {
  Object? failure;

  MembershipInvitation nextCreateResult = fakeMembershipInvitation();
  List<MembershipInvitationQueueItem> nextQueueItems = [];

  /// When set, `createMembershipInvitation` awaits this before
  /// returning — used to hold a call "in flight" for double-submit
  /// prevention tests.
  Completer<void>? createGate;

  final List<({String groupId, String membershipId, List<String> roleCodes})>
  createMembershipInvitationCalls = [];
  final List<
    ({
      String groupId,
      MembershipInvitationStatus? status,
      int limit,
      int offset,
    })
  >
  listMembershipInvitationsCalls = [];
  final List<({String groupId, String invitationId})>
  cancelMembershipInvitationCalls = [];

  MembershipInvitationPreview nextPreviewResult =
      fakeMembershipInvitationPreview();
  MembershipInvitationAcceptance nextAcceptanceResult =
      fakeMembershipInvitationAcceptance();

  /// When set, `acceptMembershipInvitation` awaits this before
  /// returning — used to hold a call "in flight" for double-submit
  /// prevention tests.
  Completer<void>? acceptGate;

  final List<({String token})> previewMembershipInvitationCalls = [];
  final List<({String token})> acceptMembershipInvitationCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<MembershipInvitation> createMembershipInvitation({
    required String groupId,
    required String membershipId,
    required List<String> roleCodes,
  }) async {
    createMembershipInvitationCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      roleCodes: roleCodes,
    ));
    final gate = createGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextCreateResult;
  }

  @override
  Future<MembershipInvitationQueuePage> listMembershipInvitations({
    required String groupId,
    MembershipInvitationStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    listMembershipInvitationsCalls.add((
      groupId: groupId,
      status: status,
      limit: limit,
      offset: offset,
    ));
    _maybeThrow();
    return MembershipInvitationQueuePage(
      items: nextQueueItems,
      totalCount: nextQueueItems.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<void> cancelMembershipInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    cancelMembershipInvitationCalls.add((
      groupId: groupId,
      invitationId: invitationId,
    ));
    _maybeThrow();
  }

  @override
  Future<MembershipInvitationPreview> previewMembershipInvitation({
    required String token,
  }) async {
    previewMembershipInvitationCalls.add((token: token));
    _maybeThrow();
    return nextPreviewResult;
  }

  @override
  Future<MembershipInvitationAcceptance> acceptMembershipInvitation({
    required String token,
  }) async {
    acceptMembershipInvitationCalls.add((token: token));
    final gate = acceptGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextAcceptanceResult;
  }
}
