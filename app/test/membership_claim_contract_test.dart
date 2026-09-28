import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/membership_claim/data/membership_claim_failure.dart';
import 'package:umoja/features/membership_claim/data/supabase_membership_claim_repository.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim_queue_item.dart';

/// Prompt 09G-B1-D2 §Q items 1-18: domain parsing for [MembershipClaim]/
/// [MembershipClaimStatus] (1-6), wire-level repository contract
/// verification — the REAL [SupabaseMembershipClaimRepository] against a
/// [MockClient], matching the `loan_write_off_recovery_contract_test.dart`
/// pattern (7-14) — and error-mapping coverage (15-18).
void main() {
  group('Domain parsing: MembershipClaim', () {
    test('1: a full PENDING request-response parses', () {
      final claim = MembershipClaim.fromJson({
        'claim_id': 'claim-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'PENDING',
        'requested_at': '2026-09-20T10:00:00Z',
        'resolved_at': null,
        'rejection_reason': null,
        'already_requested': false,
      });

      expect(claim.claimId, 'claim-1');
      expect(claim.groupId, 'g1');
      expect(claim.membershipId, 'm1');
      expect(claim.status, MembershipClaimStatus.pending);
      expect(claim.requestedAt, DateTime.parse('2026-09-20T10:00:00Z'));
      expect(claim.resolvedAt, isNull);
      expect(claim.rejectionReason, isNull);
      expect(claim.alreadyRequested, isFalse);
      expect(claim.isPending, isTrue);
    });

    test('2: a claims-list row (no already_requested field) defaults it to '
        'false rather than throwing', () {
      final claim = MembershipClaim.fromJson({
        'claim_id': 'claim-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'APPROVED',
        'requested_at': '2026-09-20T10:00:00Z',
        'resolved_at': '2026-09-21T08:00:00Z',
        'rejection_reason': null,
      });

      expect(claim.alreadyRequested, isFalse);
      expect(claim.status, MembershipClaimStatus.approved);
      expect(claim.isApproved, isTrue);
      expect(claim.resolvedAt, DateTime.parse('2026-09-21T08:00:00Z'));
    });

    test('3: a REJECTED claim with a rejection reason parses it', () {
      final claim = MembershipClaim.fromJson({
        'claim_id': 'claim-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'REJECTED',
        'requested_at': '2026-09-20T10:00:00Z',
        'resolved_at': '2026-09-21T08:00:00Z',
        'rejection_reason': 'Member number did not match roster records.',
      });

      expect(claim.status, MembershipClaimStatus.rejected);
      expect(claim.isRejected, isTrue);
      expect(
        claim.rejectionReason,
        'Member number did not match roster records.',
      );
    });

    test('4: a CANCELLED claim (cancel-response shape) parses safely', () {
      final claim = MembershipClaim.fromJson({
        'claim_id': 'claim-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'CANCELLED',
        'resolved_at': '2026-09-21T08:00:00Z',
      });

      expect(claim.status, MembershipClaimStatus.cancelled);
      expect(claim.isCancelled, isTrue);
      expect(claim.requestedAt, isNull);
      expect(claim.rejectionReason, isNull);
    });

    test('5: an unrecognized status string parses to unknown instead of '
        'throwing (forward-compat safety)', () {
      final claim = MembershipClaim.fromJson({
        'claim_id': 'claim-1',
        'group_id': 'g1',
        'membership_id': 'm1',
        'status': 'SOME_FUTURE_STATUS',
      });

      expect(claim.status, MembershipClaimStatus.unknown);
      expect(claim.isPending, isFalse);
      expect(claim.isApproved, isFalse);
      expect(claim.isRejected, isFalse);
      expect(claim.isCancelled, isFalse);
    });

    test('6: a null/missing status string also parses to unknown', () {
      expect(
        MembershipClaimStatus.fromRaw(null),
        MembershipClaimStatus.unknown,
      );
      expect(
        MembershipClaimStatus.fromRaw('garbage'),
        MembershipClaimStatus.unknown,
      );
    });
  });

  group('Repository contract: SupabaseMembershipClaimRepository', () {
    late Map<String, dynamic>? capturedBody;
    late String? capturedPath;

    SupabaseMembershipClaimRepository buildRepo(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: MockClient((request) async {
          capturedPath = request.url.path;
          // A parameterless rpc() call (listMyMembershipClaims) sends a
          // literal JSON "null" body, not an empty string — jsonDecode
          // parses that to Dart `null`, so the cast must tolerate it
          // rather than assuming a non-empty body is always a map.
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
      return SupabaseMembershipClaimRepository(client);
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

    final pendingClaimJson = {
      'claim_id': 'claim-1',
      'group_id': 'g1',
      'membership_id': 'm1',
      'status': 'PENDING',
      'requested_at': '2026-09-20T10:00:00Z',
      'resolved_at': null,
      'already_requested': false,
    };

    test('7/8/9: requestMembershipClaimByReference sends exactly '
        'p_group_code/p_member_number — never a membership id, claimant id, '
        'phone, or group id', () async {
      final repo = buildRepo((_) async => jsonOk(pendingClaimJson));

      await repo.requestMembershipClaimByReference(
        groupCode: 'GRP-001',
        memberNumber: 'MEM-042',
      );

      expect(
        capturedPath,
        contains('rpc_request_membership_claim_by_reference'),
      );
      expect(capturedBody, {
        'p_group_code': 'GRP-001',
        'p_member_number': 'MEM-042',
      });
    });

    test('10: the request-response parses through the real repository path, '
        'including alreadyRequested', () async {
      final repo = buildRepo(
        (_) async => jsonOk({...pendingClaimJson, 'already_requested': true}),
      );

      final claim = await repo.requestMembershipClaimByReference(
        groupCode: 'GRP-001',
        memberNumber: 'MEM-042',
      );

      expect(claim.claimId, 'claim-1');
      expect(claim.alreadyRequested, isTrue);
      expect(claim.isPending, isTrue);
    });

    test('11: listMyMembershipClaims calls rpc_list_my_membership_claims with '
        'no parameters', () async {
      final repo = buildRepo((_) async => jsonOk([pendingClaimJson]));

      final claims = await repo.listMyMembershipClaims();

      expect(capturedPath, contains('rpc_list_my_membership_claims'));
      expect(capturedBody, isNull);
      expect(claims, hasLength(1));
      expect(claims.single.claimId, 'claim-1');
    });

    test(
      '12: listMyMembershipClaims parses every row of a multi-row array',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk([
            pendingClaimJson,
            {
              'claim_id': 'claim-2',
              'group_id': 'g2',
              'membership_id': 'm2',
              'status': 'REJECTED',
              'requested_at': '2026-09-10T10:00:00Z',
              'resolved_at': '2026-09-11T10:00:00Z',
              'rejection_reason': 'No matching member number.',
            },
          ]),
        );

        final claims = await repo.listMyMembershipClaims();

        expect(claims, hasLength(2));
        expect(claims[1].isRejected, isTrue);
        expect(claims[1].rejectionReason, 'No matching member number.');
      },
    );

    test('13/14: cancelMembershipClaim sends exactly p_claim_id and parses '
        'the CANCELLED response', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'claim_id': 'claim-1',
          'group_id': 'g1',
          'membership_id': 'm1',
          'status': 'CANCELLED',
          'resolved_at': '2026-09-21T08:00:00Z',
        }),
      );

      final claim = await repo.cancelMembershipClaim(claimId: 'claim-1');

      expect(capturedPath, contains('rpc_cancel_membership_claim'));
      expect(capturedBody, {'p_claim_id': 'claim-1'});
      expect(claim.isCancelled, isTrue);
    });

    test(
      '15: MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED maps to '
      'referenceNotVerified — the ONE generic anti-enumeration failure type',
      () async {
        final repo = buildRepo(
          (_) async =>
              postgrestError('MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED'),
        );

        await expectLater(
          repo.requestMembershipClaimByReference(
            groupCode: 'BAD',
            memberNumber: 'BAD',
          ),
          throwsA(
            isA<MembershipClaimFailure>().having(
              (f) => f.type,
              'type',
              MembershipClaimFailureType.referenceNotVerified,
            ),
          ),
        );
      },
    );

    test('16: MEMBERSHIP_CLAIM_NOT_PENDING maps to notPending', () async {
      final repo = buildRepo(
        (_) async => postgrestError('MEMBERSHIP_CLAIM_NOT_PENDING'),
      );

      await expectLater(
        repo.cancelMembershipClaim(claimId: 'claim-1'),
        throwsA(
          isA<MembershipClaimFailure>().having(
            (f) => f.type,
            'type',
            MembershipClaimFailureType.notPending,
          ),
        ),
      );
    });

    test('17: a 42501 error maps to permissionDenied', () async {
      final repo = buildRepo(
        (_) async => postgrestError('Not authorized', code: '42501'),
      );

      await expectLater(
        repo.listMyMembershipClaims(),
        throwsA(
          isA<MembershipClaimFailure>().having(
            (f) => f.type,
            'type',
            MembershipClaimFailureType.permissionDenied,
          ),
        ),
      );
    });

    test('18: an unrecognized PostgREST error message maps to unexpected — '
        'never surfaced as raw SQL/RPC text', () async {
      final repo = buildRepo(
        (_) async => postgrestError('some_internal_sqlstate_detail'),
      );

      await expectLater(
        repo.requestMembershipClaimByReference(
          groupCode: 'GRP-001',
          memberNumber: 'MEM-042',
        ),
        throwsA(
          isA<MembershipClaimFailure>().having(
            (f) => f.type,
            'type',
            MembershipClaimFailureType.unexpected,
          ),
        ),
      );
    });

    // -- Officer review (Prompt 09G-B1-D3) ---------------------------------

    final queueItemJson = {
      'claim_id': 'claim-1',
      'membership_id': 'm1',
      'membership_display_name': 'Amina Hassan',
      'membership_member_number': 'UMJ-2026-0001',
      'membership_phone': '+255700000001',
      'claimant_full_name': 'Amina H.',
      'claimant_phone': '+255700000002',
      'status': 'PENDING',
      'requested_at': '2026-09-20T10:00:00Z',
      'resolved_at': null,
      'rejection_reason': null,
    };

    test('1/2: listMembershipClaims calls rpc_list_membership_claims with '
        'exactly p_group_id/p_status/p_limit/p_offset — a concrete status '
        'sends its uppercase text label', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'items': [queueItemJson],
          'total_count': 1,
          'limit': 20,
          'offset': 0,
        }),
      );

      await repo.listMembershipClaims(groupId: 'g1');

      expect(capturedPath, contains('rpc_list_membership_claims'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_status': 'PENDING',
        'p_limit': 20,
        'p_offset': 0,
      });
    });

    test('listMembershipClaims(status: null) sends p_status: null — the '
        "RPC's own \"every status\" (History) contract", () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'items': <dynamic>[],
          'total_count': 0,
          'limit': 20,
          'offset': 0,
        }),
      );

      await repo.listMembershipClaims(groupId: 'g1', status: null);

      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_status': null,
        'p_limit': 20,
        'p_offset': 0,
      });
    });

    test(
      'the officer queue page parses through the real repository path',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'items': [queueItemJson],
            'total_count': 1,
            'limit': 20,
            'offset': 0,
          }),
        );

        final page = await repo.listMembershipClaims(groupId: 'g1');

        expect(page.items, hasLength(1));
        expect(page.items.single.claimantFullName, 'Amina H.');
        expect(page.items.single.membershipPhone, '+255700000001');
        expect(page.totalCount, 1);
        expect(page.hasMore, isFalse);
      },
    );

    test('3/4: getMembershipClaim is a derived read through '
        'rpc_list_membership_claims (no dedicated get-by-id RPC exists in '
        'the backend contract) — requests every status with a generous '
        'bound, and finds the matching claim id', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'items': [
            queueItemJson,
            {...queueItemJson, 'claim_id': 'claim-2'},
          ],
          'total_count': 2,
          'limit': 500,
          'offset': 0,
        }),
      );

      final item = await repo.getMembershipClaim(
        groupId: 'g1',
        claimId: 'claim-2',
      );

      expect(capturedPath, contains('rpc_list_membership_claims'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_status': null,
        'p_limit': 500,
        'p_offset': 0,
      });
      expect(item.claimId, 'claim-2');
    });

    test(
      'getMembershipClaim throws a notFound failure when the claim id is '
      'not among the results (e.g. a different group, or truly gone)',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'items': [queueItemJson],
            'total_count': 1,
            'limit': 500,
            'offset': 0,
          }),
        );

        await expectLater(
          repo.getMembershipClaim(groupId: 'g1', claimId: 'no-such-claim'),
          throwsA(
            isA<MembershipClaimFailure>().having(
              (f) => f.type,
              'type',
              MembershipClaimFailureType.notFound,
            ),
          ),
        );
      },
    );

    test('5/6: approveMembershipClaim calls rpc_approve_membership_claim with '
        'exactly p_group_id/p_claim_id', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'claim_id': 'claim-1',
          'group_id': 'g1',
          'membership_id': 'm1',
          'claimant_user_id': 'u1',
          'status': 'APPROVED',
          'resolved_at': '2026-09-21T08:00:00Z',
          'resolved_by': 'officer-1',
        }),
      );

      final claim = await repo.approveMembershipClaim(
        groupId: 'g1',
        claimId: 'claim-1',
      );

      expect(capturedPath, contains('rpc_approve_membership_claim'));
      expect(capturedBody, {'p_group_id': 'g1', 'p_claim_id': 'claim-1'});
      expect(claim.isApproved, isTrue);
    });

    test('7/8: rejectMembershipClaim calls rpc_reject_membership_claim with '
        'exactly p_group_id/p_claim_id/p_rejection_reason — never any other '
        'parameter', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'claim_id': 'claim-1',
          'group_id': 'g1',
          'membership_id': 'm1',
          'status': 'REJECTED',
          'resolved_at': '2026-09-21T08:00:00Z',
          'resolved_by': 'officer-1',
          'rejection_reason': 'Could not verify identity',
        }),
      );

      final claim = await repo.rejectMembershipClaim(
        groupId: 'g1',
        claimId: 'claim-1',
        rejectionReason: 'Could not verify identity',
      );

      expect(capturedPath, contains('rpc_reject_membership_claim'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_claim_id': 'claim-1',
        'p_rejection_reason': 'Could not verify identity',
      });
      expect(claim.isRejected, isTrue);
      expect(claim.rejectionReason, 'Could not verify identity');
    });

    for (final (message, expectedType) in [
      (
        'MEMBERSHIP_CLAIM_REJECTION_REASON_REQUIRED',
        MembershipClaimFailureType.rejectionReasonRequired,
      ),
      ('MEMBERSHIP_ALREADY_LINKED', MembershipClaimFailureType.alreadyLinked),
      (
        'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP',
        MembershipClaimFailureType.claimantAlreadyActiveInGroup,
      ),
      ('MEMBERSHIP_NOT_ACTIVE', MembershipClaimFailureType.membershipNotActive),
      ('GROUP_NOT_ACTIVE', MembershipClaimFailureType.groupNotActive),
    ]) {
      test('9: $message maps to $expectedType', () async {
        final repo = buildRepo((_) async => postgrestError(message));

        await expectLater(
          repo.approveMembershipClaim(groupId: 'g1', claimId: 'claim-1'),
          throwsA(
            isA<MembershipClaimFailure>().having(
              (f) => f.type,
              'type',
              expectedType,
            ),
          ),
        );
      });
    }

    test(
      '10: a cross-group "not found" (e.g. an ADMIN of a different group, '
      'or a stale/gone claim id) maps to notFound, never a raw 22023',
      () async {
        final repo = buildRepo(
          (_) async => postgrestError(
            'Membership claim not found in group',
            code: '22023',
          ),
        );

        await expectLater(
          repo.rejectMembershipClaim(
            groupId: 'g1',
            claimId: 'claim-1',
            rejectionReason: 'x',
          ),
          throwsA(
            isA<MembershipClaimFailure>().having(
              (f) => f.type,
              'type',
              MembershipClaimFailureType.notFound,
            ),
          ),
        );
      },
    );

    test('11: 42501 on the officer queue read maps to permissionDenied — a '
        'plain MEMBER (or an officer of a different group) is never shown '
        'a raw SQL error', () async {
      final repo = buildRepo(
        (_) async => postgrestError(
          'Not authorized to view membership claims in this group',
          code: '42501',
        ),
      );

      await expectLater(
        repo.listMembershipClaims(groupId: 'g1'),
        throwsA(
          isA<MembershipClaimFailure>().having(
            (f) => f.type,
            'type',
            MembershipClaimFailureType.permissionDenied,
          ),
        ),
      );
    });
  });

  group('Domain parsing: MembershipClaimQueueItem/Page', () {
    test('12: a full PENDING queue item parses every officer-facing field', () {
      final item = MembershipClaimQueueItem.fromJson({
        'claim_id': 'claim-1',
        'membership_id': 'm1',
        'membership_display_name': 'Amina Hassan',
        'membership_member_number': 'UMJ-2026-0001',
        'membership_phone': '+255700000001',
        'claimant_full_name': 'Amina H.',
        'claimant_phone': '+255700000002',
        'status': 'PENDING',
        'requested_at': '2026-09-20T10:00:00Z',
        'resolved_at': null,
        'rejection_reason': null,
      });

      expect(item.claimId, 'claim-1');
      expect(item.membershipDisplayName, 'Amina Hassan');
      expect(item.membershipMemberNumber, 'UMJ-2026-0001');
      expect(item.membershipPhone, '+255700000001');
      expect(item.claimantFullName, 'Amina H.');
      expect(item.claimantPhone, '+255700000002');
      expect(item.status, MembershipClaimStatus.pending);
      expect(item.isPending, isTrue);
    });

    test('13: an APPROVED item parses safely with resolved_at set', () {
      final item = MembershipClaimQueueItem.fromJson({
        'claim_id': 'claim-1',
        'membership_id': 'm1',
        'status': 'APPROVED',
        'resolved_at': '2026-09-21T08:00:00Z',
      });

      expect(item.status, MembershipClaimStatus.approved);
      expect(item.isPending, isFalse);
      expect(item.resolvedAt, DateTime.parse('2026-09-21T08:00:00Z'));
    });

    test('14: a REJECTED item parses its rejection reason', () {
      final item = MembershipClaimQueueItem.fromJson({
        'claim_id': 'claim-1',
        'membership_id': 'm1',
        'status': 'REJECTED',
        'rejection_reason': 'Could not verify identity',
      });

      expect(item.status, MembershipClaimStatus.rejected);
      expect(item.rejectionReason, 'Could not verify identity');
    });

    test('15: nullable officer-facing fields (missing roster/claimant '
        'context) parse safely rather than throwing', () {
      final item = MembershipClaimQueueItem.fromJson({
        'claim_id': 'claim-1',
        'membership_id': 'm1',
        'status': 'PENDING',
      });

      expect(item.membershipDisplayName, isNull);
      expect(item.membershipMemberNumber, isNull);
      expect(item.membershipPhone, isNull);
      expect(item.claimantFullName, isNull);
      expect(item.claimantPhone, isNull);
    });

    test('16: an unrecognized status parses to unknown, never throws', () {
      final item = MembershipClaimQueueItem.fromJson({
        'claim_id': 'claim-1',
        'membership_id': 'm1',
        'status': 'SOME_FUTURE_STATUS',
      });

      expect(item.status, MembershipClaimStatus.unknown);
      expect(item.isPending, isFalse);
    });

    test(
      'a page parses items/total_count/limit/offset and computes hasMore',
      () {
        final page = MembershipClaimQueuePage.fromJson({
          'items': [
            {'claim_id': 'c1', 'membership_id': 'm1', 'status': 'PENDING'},
          ],
          'total_count': 5,
          'limit': 1,
          'offset': 0,
        });

        expect(page.items, hasLength(1));
        expect(page.totalCount, 5);
        expect(page.hasMore, isTrue);
      },
    );

    test('an empty items array parses to an empty, not-hasMore page', () {
      final page = MembershipClaimQueuePage.fromJson({
        'items': <dynamic>[],
        'total_count': 0,
        'limit': 20,
        'offset': 0,
      });

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
