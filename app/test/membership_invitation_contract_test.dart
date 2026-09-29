import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/membership_invitations/data/membership_invitation_failure.dart';
import 'package:umoja/features/membership_invitations/data/supabase_membership_invitation_repository.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_acceptance.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_preview.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_queue_item.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_status.dart';

/// Prompt 09G-B1-E2 §O items 1-8: domain parsing for
/// [MembershipInvitation]/[MembershipInvitationQueueItem]/
/// [MembershipInvitationStatus], wire-level repository contract
/// verification — the REAL [SupabaseMembershipInvitationRepository]
/// against a [MockClient], matching
/// `membership_claim_contract_test.dart`'s own pattern — and
/// error-mapping coverage. Every JSON shape here matches the actual
/// `jsonb_build_object(...)` calls in
/// `supabase/migrations/20260922090000_create_membership_invitation_workflow.sql`,
/// read directly, not inferred.
void main() {
  group('Domain parsing: MembershipInvitation (create result)', () {
    test('1: a full create-result parses, including the plaintext token', () {
      final invitation = MembershipInvitation.fromJson({
        'invitation_id': 'invitation-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'PENDING',
        'created_at': '2026-09-20T10:00:00Z',
        'expires_at': '2026-09-27T10:00:00Z',
        'roles': ['MEMBER', 'TREASURER'],
        'token': 'deadbeef' * 8,
      });

      expect(invitation.invitationId, 'invitation-1');
      expect(invitation.groupId, 'g1');
      expect(invitation.membershipId, 'm1');
      expect(invitation.status, MembershipInvitationStatus.pending);
      expect(invitation.createdAt, DateTime.parse('2026-09-20T10:00:00Z'));
      expect(invitation.expiresAt, DateTime.parse('2026-09-27T10:00:00Z'));
      expect(invitation.roleCodes, ['MEMBER', 'TREASURER']);
      expect(invitation.token, 'deadbeef' * 8);
    });
  });

  group('Domain parsing: MembershipInvitationStatus', () {
    test('2: every raw backend enum value maps to its Dart case', () {
      expect(
        MembershipInvitationStatus.fromRaw('PENDING'),
        MembershipInvitationStatus.pending,
      );
      expect(
        MembershipInvitationStatus.fromRaw('ACCEPTED'),
        MembershipInvitationStatus.accepted,
      );
      expect(
        MembershipInvitationStatus.fromRaw('CANCELLED'),
        MembershipInvitationStatus.cancelled,
      );
      expect(
        MembershipInvitationStatus.fromRaw('EXPIRED'),
        MembershipInvitationStatus.expired,
      );
      expect(
        MembershipInvitationStatus.fromRaw('SOMETHING_NEW'),
        MembershipInvitationStatus.unknown,
      );
      expect(
        MembershipInvitationStatus.fromRaw(null),
        MembershipInvitationStatus.unknown,
      );
    });
  });

  group('Domain parsing: MembershipInvitationQueueItem/Page', () {
    test('3: a PENDING-but-expired row parses is_expired and computes '
        'effectiveStatus as expired, without ever mutating the raw status', () {
      final item = MembershipInvitationQueueItem.fromJson({
        'invitation_id': 'invitation-1',
        'membership_id': 'm1',
        'membership_display_name': 'Amina Hassan',
        'membership_member_number': 'UMJ-2026-0001',
        'status': 'PENDING',
        'is_expired': true,
        'roles': ['MEMBER'],
        'created_at': '2026-09-01T10:00:00Z',
        'expires_at': '2026-09-08T10:00:00Z',
        'created_by_full_name': 'Officer One',
        'accepted_at': null,
        'accepted_by_full_name': null,
        'cancelled_at': null,
        'cancelled_by_full_name': null,
      });

      expect(item.status, MembershipInvitationStatus.pending);
      expect(item.isExpired, isTrue);
      expect(item.effectiveStatus, MembershipInvitationStatus.expired);
      expect(item.canCancel, isFalse);
    });

    test('4: a genuinely still-actionable PENDING row can be cancelled', () {
      final item = MembershipInvitationQueueItem.fromJson({
        'invitation_id': 'invitation-1',
        'membership_id': 'm1',
        'status': 'PENDING',
        'is_expired': false,
        'roles': ['MEMBER'],
        'created_at': '2026-09-20T10:00:00Z',
        'expires_at': '2026-09-27T10:00:00Z',
      });

      expect(item.effectiveStatus, MembershipInvitationStatus.pending);
      expect(item.canCancel, isTrue);
    });

    test('5: an ACCEPTED row parses acceptance metadata and cannot be '
        'cancelled', () {
      final item = MembershipInvitationQueueItem.fromJson({
        'invitation_id': 'invitation-1',
        'membership_id': 'm1',
        'status': 'ACCEPTED',
        'is_expired': false,
        'roles': ['MEMBER'],
        'created_at': '2026-09-01T10:00:00Z',
        'expires_at': '2026-09-08T10:00:00Z',
        'accepted_at': '2026-09-03T10:00:00Z',
        'accepted_by_full_name': 'Jane Member',
      });

      expect(item.effectiveStatus, MembershipInvitationStatus.accepted);
      expect(item.acceptedAt, DateTime.parse('2026-09-03T10:00:00Z'));
      expect(item.acceptedByFullName, 'Jane Member');
      expect(item.canCancel, isFalse);
    });

    test('6: a page parses items/total_count/limit/offset', () {
      final page = MembershipInvitationQueuePage.fromJson({
        'items': [
          {
            'invitation_id': 'invitation-1',
            'membership_id': 'm1',
            'status': 'PENDING',
            'is_expired': false,
            'roles': ['MEMBER'],
            'created_at': '2026-09-20T10:00:00Z',
            'expires_at': '2026-09-27T10:00:00Z',
          },
        ],
        'total_count': 5,
        'limit': 20,
        'offset': 0,
      });

      expect(page.items, hasLength(1));
      expect(page.totalCount, 5);
      expect(page.hasMore, isTrue);
    });
  });

  group('Repository contract: SupabaseMembershipInvitationRepository', () {
    late Map<String, dynamic>? capturedBody;
    late String? capturedPath;

    SupabaseMembershipInvitationRepository buildRepo(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: MockClient((request) async {
          capturedPath = request.url.path;
          final decoded = request.body.isEmpty
              ? null
              : jsonDecode(request.body);
          capturedBody = decoded == null
              ? null
              : decoded as Map<String, dynamic>;
          final response = await handler(request);
          return http.Response(
            response.body,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }),
      );
      return SupabaseMembershipInvitationRepository(client);
    }

    http.Response jsonOk(dynamic body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

    http.Response postgrestError(String message, {String code = 'P0001'}) =>
        http.Response(
          jsonEncode({
            'message': message,
            'code': code,
            'details': null,
            'hint': null,
          }),
          400,
          headers: {'content-type': 'application/json'},
        );

    setUp(() {
      capturedBody = null;
      capturedPath = null;
    });

    final createResultJson = {
      'invitation_id': 'invitation-1',
      'group_id': 'g1',
      'membership_id': 'm1',
      'status': 'PENDING',
      'created_at': '2026-09-20T10:00:00Z',
      'expires_at': '2026-09-27T10:00:00Z',
      'roles': ['MEMBER'],
      'token': 'a' * 64,
    };

    test('7/8/9: createMembershipInvitation sends exactly p_group_id/'
        'p_membership_id/p_role_codes — never a user_id or role_id', () async {
      final repo = buildRepo((_) async => jsonOk(createResultJson));

      await repo.createMembershipInvitation(
        groupId: 'g1',
        membershipId: 'm1',
        roleCodes: ['MEMBER', 'TREASURER'],
      );

      expect(capturedPath, contains('rpc_create_membership_invitation'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_membership_id': 'm1',
        'p_role_codes': ['MEMBER', 'TREASURER'],
      });
      expect(capturedBody!.containsKey('p_user_id'), isFalse);
      expect(capturedBody!.containsKey('p_role_id'), isFalse);
      expect(capturedBody!.containsKey('p_role_ids'), isFalse);
    });

    test('10: role codes are sent exactly as given — never transformed, '
        'never mapped to ids', () async {
      final repo = buildRepo((_) async => jsonOk(createResultJson));

      await repo.createMembershipInvitation(
        groupId: 'g1',
        membershipId: 'm1',
        roleCodes: ['ADMIN'],
      );

      expect(capturedBody!['p_role_codes'], ['ADMIN']);
    });

    test('11: the create response parses through the real repository path, '
        'including the one-time plaintext token', () async {
      final repo = buildRepo((_) async => jsonOk(createResultJson));

      final invitation = await repo.createMembershipInvitation(
        groupId: 'g1',
        membershipId: 'm1',
        roleCodes: ['MEMBER'],
      );

      expect(invitation.invitationId, 'invitation-1');
      expect(invitation.token, 'a' * 64);
    });

    test('12: listMembershipInvitations sends exactly p_group_id/p_status/'
        'p_limit/p_offset', () async {
      final repo = buildRepo(
        (_) async =>
            jsonOk({'items': [], 'total_count': 0, 'limit': 20, 'offset': 0}),
      );

      await repo.listMembershipInvitations(
        groupId: 'g1',
        status: MembershipInvitationStatus.pending,
        limit: 20,
        offset: 0,
      );

      expect(capturedPath, contains('rpc_list_membership_invitations'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_status': 'PENDING',
        'p_limit': 20,
        'p_offset': 0,
      });
    });

    test('13: cancelMembershipInvitation sends exactly p_group_id/'
        'p_invitation_id', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'invitation_id': 'invitation-1',
          'group_id': 'g1',
          'membership_id': 'm1',
          'status': 'CANCELLED',
          'cancelled_at': '2026-09-21T08:00:00Z',
          'cancelled_by': 'u1',
        }),
      );

      await repo.cancelMembershipInvitation(
        groupId: 'g1',
        invitationId: 'invitation-1',
      );

      expect(capturedPath, contains('rpc_cancel_membership_invitation'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_invitation_id': 'invitation-1',
      });
    });

    test('14/15: a PostgREST 42501 maps to permissionDenied; ADMIN-'
        'escalation message maps to adminRoleRequired', () async {
      final repo = buildRepo(
        (_) async => postgrestError(
          'Not authorized to invite members in this group',
          code: '42501',
        ),
      );

      await expectLater(
        repo.createMembershipInvitation(
          groupId: 'g1',
          membershipId: 'm1',
          roleCodes: ['MEMBER'],
        ),
        throwsA(
          isA<MembershipInvitationFailure>().having(
            (f) => f.type,
            'type',
            MembershipInvitationFailureType.permissionDenied,
          ),
        ),
      );

      final adminRepo = buildRepo(
        (_) async => postgrestError(
          'Only an existing ADMIN may invite a member with the ADMIN role',
          code: '42501',
        ),
      );

      await expectLater(
        adminRepo.createMembershipInvitation(
          groupId: 'g1',
          membershipId: 'm1',
          roleCodes: ['ADMIN'],
        ),
        throwsA(
          isA<MembershipInvitationFailure>().having(
            (f) => f.type,
            'type',
            MembershipInvitationFailureType.adminRoleRequired,
          ),
        ),
      );
    });

    test('16: MEMBERSHIP_INVITATION_ALREADY_PENDING maps to '
        'invitationAlreadyPending', () async {
      final repo = buildRepo(
        (_) async => postgrestError('MEMBERSHIP_INVITATION_ALREADY_PENDING'),
      );

      await expectLater(
        repo.createMembershipInvitation(
          groupId: 'g1',
          membershipId: 'm1',
          roleCodes: ['MEMBER'],
        ),
        throwsA(
          isA<MembershipInvitationFailure>().having(
            (f) => f.type,
            'type',
            MembershipInvitationFailureType.invitationAlreadyPending,
          ),
        ),
      );
    });

    test(
      '17: MEMBERSHIP_INVITATION_NOT_PENDING maps to invitationNotPending',
      () async {
        final repo = buildRepo(
          (_) async => postgrestError('MEMBERSHIP_INVITATION_NOT_PENDING'),
        );

        await expectLater(
          repo.cancelMembershipInvitation(
            groupId: 'g1',
            invitationId: 'invitation-1',
          ),
          throwsA(
            isA<MembershipInvitationFailure>().having(
              (f) => f.type,
              'type',
              MembershipInvitationFailureType.invitationNotPending,
            ),
          ),
        );
      },
    );

    test('18: an unrecognized PostgrestException falls back to unexpected, '
        'never surfacing the raw message/code as the classification', () async {
      final repo = buildRepo(
        (_) async => postgrestError('some new backend message', code: 'XX000'),
      );

      await expectLater(
        repo.createMembershipInvitation(
          groupId: 'g1',
          membershipId: 'm1',
          roleCodes: ['MEMBER'],
        ),
        throwsA(
          isA<MembershipInvitationFailure>().having(
            (f) => f.type,
            'type',
            MembershipInvitationFailureType.unexpected,
          ),
        ),
      );
    });
  });

  group('Domain parsing: MembershipInvitationPreview/Acceptance', () {
    test('19: a full PENDING preview parses group/member/role display '
        'context', () {
      final preview = MembershipInvitationPreview.fromJson({
        'status': 'PENDING',
        'expires_at': '2026-09-27T10:00:00Z',
        'group_name': 'Umoja Wamama',
        'membership_display_name': 'Amina Hassan',
        'membership_member_number': 'UMJ-2026-0001',
        'roles': ['Treasurer', 'Secretary'],
      });

      expect(preview.status, MembershipInvitationStatus.pending);
      expect(preview.isActionable, isTrue);
      expect(preview.groupName, 'Umoja Wamama');
      expect(preview.membershipDisplayName, 'Amina Hassan');
      expect(preview.membershipMemberNumber, 'UMJ-2026-0001');
      // 9: roles are parsed as DISPLAY NAMES, not codes.
      expect(preview.roleNames, ['Treasurer', 'Secretary']);
    });

    test('10: an EXPIRED preview (server-computed effective status) is not '
        'actionable', () {
      final preview = MembershipInvitationPreview.fromJson({
        'status': 'EXPIRED',
        'expires_at': '2026-09-08T10:00:00Z',
        'group_name': 'Umoja Wamama',
        'membership_display_name': 'Amina Hassan',
        'membership_member_number': 'UMJ-2026-0001',
        'roles': ['Treasurer'],
      });

      expect(preview.status, MembershipInvitationStatus.expired);
      expect(preview.isActionable, isFalse);
    });

    test('11: a CANCELLED preview is not actionable', () {
      final preview = MembershipInvitationPreview.fromJson({
        'status': 'CANCELLED',
        'expires_at': '2026-09-27T10:00:00Z',
        'group_name': 'Umoja Wamama',
        'membership_display_name': 'Amina Hassan',
        'membership_member_number': 'UMJ-2026-0001',
        'roles': ['Treasurer'],
      });

      expect(preview.status, MembershipInvitationStatus.cancelled);
      expect(preview.isActionable, isFalse);
    });

    test('13: an ACCEPTED preview is not actionable', () {
      final preview = MembershipInvitationPreview.fromJson({
        'status': 'ACCEPTED',
        'expires_at': '2026-09-27T10:00:00Z',
        'group_name': 'Umoja Wamama',
        'membership_display_name': 'Amina Hassan',
        'membership_member_number': 'UMJ-2026-0001',
        'roles': ['Treasurer'],
      });

      expect(preview.status, MembershipInvitationStatus.accepted);
      expect(preview.isActionable, isFalse);
    });

    test('a real accept-response shape parses, including already_accepted', () {
      final acceptance = MembershipInvitationAcceptance.fromJson({
        'invitation_id': 'invitation-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'ACCEPTED',
        'accepted_at': '2026-09-21T08:00:00Z',
        'already_accepted': true,
      });

      expect(acceptance.invitationId, 'invitation-1');
      expect(acceptance.status, MembershipInvitationStatus.accepted);
      expect(acceptance.alreadyAccepted, isTrue);
    });
  });

  group('Repository contract: preview/accept', () {
    late Map<String, dynamic>? capturedBody;
    late String? capturedPath;

    SupabaseMembershipInvitationRepository buildRepo(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: MockClient((request) async {
          capturedPath = request.url.path;
          final decoded = request.body.isEmpty
              ? null
              : jsonDecode(request.body);
          capturedBody = decoded == null
              ? null
              : decoded as Map<String, dynamic>;
          final response = await handler(request);
          return http.Response(
            response.body,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }),
      );
      return SupabaseMembershipInvitationRepository(client);
    }

    http.Response jsonOk(dynamic body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

    http.Response postgrestError(String message, {String code = 'P0001'}) =>
        http.Response(
          jsonEncode({
            'message': message,
            'code': code,
            'details': null,
            'hint': null,
          }),
          400,
          headers: {'content-type': 'application/json'},
        );

    setUp(() {
      capturedBody = null;
      capturedPath = null;
    });

    test('1/2: previewMembershipInvitation calls exactly '
        'rpc_preview_membership_invitation with exactly p_token', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'status': 'PENDING',
          'expires_at': '2026-09-27T10:00:00Z',
          'group_name': 'Umoja Wamama',
          'membership_display_name': 'Amina Hassan',
          'membership_member_number': 'UMJ-2026-0001',
          'roles': ['Treasurer'],
        }),
      );

      await repo.previewMembershipInvitation(token: 'deadbeef' * 8);

      expect(capturedPath, contains('rpc_preview_membership_invitation'));
      expect(capturedBody, {'p_token': 'deadbeef' * 8});
      expect(capturedBody!.containsKey('p_group_id'), isFalse);
      expect(capturedBody!.containsKey('p_membership_id'), isFalse);
      expect(capturedBody!.containsKey('p_user_id'), isFalse);
    });

    test('3/4/5/6/7: acceptMembershipInvitation calls exactly '
        'rpc_accept_membership_invitation with ONLY p_token — never a '
        'user_id, membership_id, group_id, or role id/code', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'invitation_id': 'invitation-1',
          'group_id': 'g1',
          'membership_id': 'm1',
          'status': 'ACCEPTED',
          'accepted_at': '2026-09-21T08:00:00Z',
          'already_accepted': false,
        }),
      );

      await repo.acceptMembershipInvitation(token: 'deadbeef' * 8);

      expect(capturedPath, contains('rpc_accept_membership_invitation'));
      expect(capturedBody, {'p_token': 'deadbeef' * 8});
      expect(capturedBody!.keys, ['p_token']);
    });

    test('12: an unknown/invalid token maps to invitationNotFound, never a '
        'raw message', () async {
      final repo = buildRepo(
        (_) async => postgrestError('MEMBERSHIP_INVITATION_NOT_FOUND'),
      );

      await expectLater(
        repo.previewMembershipInvitation(token: 'garbage'),
        throwsA(
          isA<MembershipInvitationFailure>().having(
            (f) => f.type,
            'type',
            MembershipInvitationFailureType.invitationNotFound,
          ),
        ),
      );
    });

    test(
      'an expired invitation at accept time maps to invitationExpired',
      () async {
        final repo = buildRepo(
          (_) async => postgrestError('MEMBERSHIP_INVITATION_EXPIRED'),
        );

        await expectLater(
          repo.acceptMembershipInvitation(token: 'deadbeef' * 8),
          throwsA(
            isA<MembershipInvitationFailure>().having(
              (f) => f.type,
              'type',
              MembershipInvitationFailureType.invitationExpired,
            ),
          ),
        );
      },
    );

    test('a claimant already active in the group maps to '
        'claimantAlreadyActiveInGroup', () async {
      final repo = buildRepo(
        (_) async =>
            postgrestError('CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP'),
      );

      await expectLater(
        repo.acceptMembershipInvitation(token: 'deadbeef' * 8),
        throwsA(
          isA<MembershipInvitationFailure>().having(
            (f) => f.type,
            'type',
            MembershipInvitationFailureType.claimantAlreadyActiveInGroup,
          ),
        ),
      );
    });
  });
}
