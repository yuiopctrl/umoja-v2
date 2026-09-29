import 'dart:async';

import 'package:umoja/features/membership_invitations/data/membership_invitation_repository.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_acceptance.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_decline.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_preview.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_queue_item.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_status.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_type.dart';
import 'package:umoja/features/membership_invitations/domain/membership_phone_invitation.dart';
import 'package:umoja/features/membership_invitations/domain/my_membership_invitation.dart';

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

MembershipInvitationDecline fakeMembershipInvitationDecline({
  String invitationId = 'invitation-1',
  String groupId = 'g1',
  String membershipId = 'm1',
  MembershipInvitationStatus status = MembershipInvitationStatus.declined,
  DateTime? declinedAt,
  bool alreadyDeclined = false,
}) {
  return MembershipInvitationDecline(
    invitationId: invitationId,
    groupId: groupId,
    membershipId: membershipId,
    status: status,
    declinedAt: declinedAt ?? DateTime.utc(2026, 9, 21),
    alreadyDeclined: alreadyDeclined,
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

MembershipPhoneInvitation fakeMembershipPhoneInvitation({
  String invitationId = 'invitation-1',
  String groupId = 'g1',
  String membershipId = 'm1',
  MembershipInvitationStatus status = MembershipInvitationStatus.pending,
  String targetPhoneE164 = '+255712345678',
  DateTime? createdAt,
  DateTime? expiresAt,
  List<String> roleCodes = const ['MEMBER'],
}) {
  return MembershipPhoneInvitation(
    invitationId: invitationId,
    groupId: groupId,
    membershipId: membershipId,
    status: status,
    targetPhoneE164: targetPhoneE164,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 20),
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 27),
    roleCodes: roleCodes,
  );
}

MembershipInvitationQueueItem fakeMembershipInvitationQueueItem({
  String invitationId = 'invitation-1',
  MembershipInvitationType type = MembershipInvitationType.token,
  String? targetPhoneE164,
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
  DateTime? declinedAt,
}) {
  return MembershipInvitationQueueItem(
    invitationId: invitationId,
    type: type,
    targetPhoneE164: targetPhoneE164,
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
    declinedAt: declinedAt,
  );
}

MyMembershipInvitation fakeMyMembershipInvitation({
  String invitationId = 'invitation-1',
  MembershipInvitationStatus status = MembershipInvitationStatus.pending,
  bool canAccept = true,
  String? groupName = 'Umoja Wamama',
  String? membershipDisplayName = 'Amina Hassan',
  String? membershipMemberNumber = 'UMJ-2026-0001',
  List<String> roleNames = const ['Treasurer'],
  DateTime? invitedAt,
  DateTime? expiresAt,
}) {
  return MyMembershipInvitation(
    invitationId: invitationId,
    status: status,
    canAccept: canAccept,
    groupName: groupName,
    membershipDisplayName: membershipDisplayName,
    membershipMemberNumber: membershipMemberNumber,
    roleNames: roleNames,
    invitedAt: invitedAt ?? DateTime.utc(2026, 9, 20),
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 27),
  );
}

/// In-memory [MembershipInvitationRepository] fake for tests (Prompt
/// 09G-B1-E2, extended additively by F2 for PHONE/personal
/// operations) — mirrors [FakeMembershipClaimRepository]'s pattern:
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

  // -- F2 additions ------------------------------------------------------

  MembershipPhoneInvitation nextCreatePhoneResult =
      fakeMembershipPhoneInvitation();
  MyMembershipInvitationsPage nextMyInvitationsPage =
      MyMembershipInvitationsPage.empty;
  MembershipInvitationDecline nextDeclineResult =
      fakeMembershipInvitationDecline();

  /// When set, `createPhoneInvitation` awaits this before returning —
  /// used for double-submit prevention tests.
  Completer<void>? createPhoneGate;

  /// When set, `acceptPhoneInvitation` awaits this before returning.
  Completer<void>? acceptPhoneGate;

  /// When set, `declinePhoneInvitation` awaits this before returning.
  Completer<void>? declinePhoneGate;

  final List<
    ({
      String groupId,
      String membershipId,
      String phone,
      List<String> roleCodes,
    })
  >
  createPhoneInvitationCalls = [];
  final List<({MembershipInvitationStatus? status, int limit, int offset})>
  listMyInvitationsCalls = [];
  final List<({String invitationId})> acceptPhoneInvitationCalls = [];
  final List<({String invitationId})> declinePhoneInvitationCalls = [];

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

  @override
  Future<MembershipPhoneInvitation> createPhoneInvitation({
    required String groupId,
    required String membershipId,
    required String phone,
    required List<String> roleCodes,
  }) async {
    createPhoneInvitationCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      phone: phone,
      roleCodes: roleCodes,
    ));
    final gate = createPhoneGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextCreatePhoneResult;
  }

  @override
  Future<MyMembershipInvitationsPage> listMyInvitations({
    MembershipInvitationStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    listMyInvitationsCalls.add((status: status, limit: limit, offset: offset));
    _maybeThrow();
    return nextMyInvitationsPage;
  }

  @override
  Future<MembershipInvitationAcceptance> acceptPhoneInvitation({
    required String invitationId,
  }) async {
    acceptPhoneInvitationCalls.add((invitationId: invitationId));
    final gate = acceptPhoneGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextAcceptanceResult;
  }

  @override
  Future<MembershipInvitationDecline> declinePhoneInvitation({
    required String invitationId,
  }) async {
    declinePhoneInvitationCalls.add((invitationId: invitationId));
    final gate = declinePhoneGate;
    if (gate != null) await gate.future;
    _maybeThrow();
    return nextDeclineResult;
  }
}
