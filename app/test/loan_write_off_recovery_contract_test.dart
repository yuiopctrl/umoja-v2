import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/data/supabase_loan_repository.dart';

/// Prompt 09F-B: applies the exact 09F-A-09 lesson (Defect A) to the
/// four new optional-effective-date write-off/recovery RPC calls — the
/// repository must never send an explicit JSON `null` for
/// `p_effective_date` (PostgREST forwards that as a literal SQL NULL,
/// overriding the RPC's own `DEFAULT CURRENT_DATE`). These tests
/// exercise the REAL [SupabaseLoanRepository] against a [MockClient] so
/// they verify actual wire-level RPC parameter construction, not just a
/// helper function's return value in isolation.
void main() {
  late Map<String, dynamic>? capturedBody;
  late String? capturedPath;

  SupabaseLoanRepository buildRepo(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = request.body.isEmpty
            ? null
            : jsonDecode(request.body) as Map<String, dynamic>;
        final response = await handler(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    return SupabaseLoanRepository(client);
  }

  http.Response jsonOk(Map<String, dynamic> body) => http.Response(
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

  group('effective-date omission', () {
    test(
      'A: write-off preview with effectiveDate == null omits p_effective_date',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'loan_account_id': 'l1',
            'reason_code': 'PROLONGED_DEFAULT',
            'note': null,
            'effective_date': '2026-09-01',
            'principal_amount': 200000,
            'interest_amount': 15000,
            'penalty_amount': 5000,
            'total_amount': 220000,
            'cash_impact': 0,
            'payment_created': false,
            'receipt_created': false,
          }),
        );

        await repo.previewLoanWriteOff(
          groupId: 'g1',
          loanAccountId: 'l1',
          reasonCode: 'PROLONGED_DEFAULT',
        );

        expect(capturedPath, contains('rpc_preview_loan_write_off'));
        expect(capturedBody, isNotNull);
        expect(capturedBody!.containsKey('p_effective_date'), isFalse);
      },
    );

    test(
      'B: write-off post with effectiveDate == null omits p_effective_date',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'write_off_event_id': 'w1',
            'loan_account_id': 'l1',
            'principal_amount': 200000,
            'interest_amount': 15000,
            'penalty_amount': 5000,
            'total_amount': 220000,
            'cash_impact': 0,
            'payment_created': false,
            'receipt_created': false,
            'already_posted': false,
            'loan_status': 'WRITTEN_OFF',
          }),
        );

        await repo.postLoanWriteOff(
          groupId: 'g1',
          loanAccountId: 'l1',
          reasonCode: 'PROLONGED_DEFAULT',
        );

        expect(capturedPath, contains('rpc_post_loan_write_off'));
        expect(capturedBody!.containsKey('p_effective_date'), isFalse);
      },
    );

    test(
      'C: recovery preview with effectiveDate == null omits p_effective_date',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'loan_account_id': 'l1',
            'write_off_event_id': 'w1',
            'write_off_total_amount': 220000,
            'remaining_before': {
              'principal': 200000,
              'interest': 15000,
              'penalty': 5000,
              'total': 220000,
            },
            'recovery_amount': 10000,
            'allocation': {'penalty': 5000, 'interest': 5000, 'principal': 0},
            'remaining_after': {
              'principal': 200000,
              'interest': 10000,
              'penalty': 0,
              'total': 210000,
            },
            'cash_impact': 10000,
            'payment_created': true,
            'receipt_created': true,
          }),
        );

        await repo.previewLoanRecovery(
          groupId: 'g1',
          loanAccountId: 'l1',
          amount: 10000,
        );

        expect(capturedPath, contains('rpc_preview_loan_recovery'));
        expect(capturedBody!.containsKey('p_effective_date'), isFalse);
      },
    );

    test(
      'D: recovery post with effectiveDate == null omits p_effective_date',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'recovery_event_id': 'r1',
            'payment_id': 'p1',
            'receipt_number': 'RCT-0001',
            'loan_account_id': 'l1',
            'write_off_event_id': 'w1',
            'amount': 10000,
            'allocation': {'penalty': 5000, 'interest': 5000, 'principal': 0},
            'already_posted': false,
            'loan_status': 'WRITTEN_OFF',
          }),
        );

        await repo.postLoanRecovery(
          groupId: 'g1',
          loanAccountId: 'l1',
          amount: 10000,
          financialAccountId: 'account-1',
          paymentMethod: 'CASH',
        );

        expect(capturedPath, contains('rpc_post_loan_recovery'));
        expect(capturedBody!.containsKey('p_effective_date'), isFalse);
      },
    );

    test('E: an explicit effectiveDate is present and serialized as a plain '
        'date-only string', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'loan_account_id': 'l1',
          'reason_code': 'PROLONGED_DEFAULT',
          'note': null,
          'effective_date': '2026-06-15',
          'principal_amount': 200000,
          'interest_amount': 15000,
          'penalty_amount': 5000,
          'total_amount': 220000,
          'cash_impact': 0,
          'payment_created': false,
          'receipt_created': false,
        }),
      );

      await repo.previewLoanWriteOff(
        groupId: 'g1',
        loanAccountId: 'l1',
        reasonCode: 'PROLONGED_DEFAULT',
        effectiveDate: DateTime.utc(2026, 6, 15),
      );

      expect(capturedBody!['p_effective_date'], '2026-06-15');
    });

    test('F: idempotencyKey is passed through as an explicit key (not '
        'omitted, unlike effective_date)', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'write_off_event_id': 'w1',
          'loan_account_id': 'l1',
          'principal_amount': 200000,
          'interest_amount': 15000,
          'penalty_amount': 5000,
          'total_amount': 220000,
          'cash_impact': 0,
          'payment_created': false,
          'receipt_created': false,
          'already_posted': false,
          'loan_status': 'WRITTEN_OFF',
        }),
      );

      await repo.postLoanWriteOff(
        groupId: 'g1',
        loanAccountId: 'l1',
        reasonCode: 'PROLONGED_DEFAULT',
        idempotencyKey: 'idem-key-1',
      );

      expect(capturedBody!['p_idempotency_key'], 'idem-key-1');
    });
  });

  group('error mapping', () {
    test(
      'G: LOAN_WRITE_OFF_NOTHING_OUTSTANDING maps to its dedicated type',
      () async {
        final repo = buildRepo(
          (_) async => postgrestError('LOAN_WRITE_OFF_NOTHING_OUTSTANDING'),
        );

        await expectLater(
          repo.previewLoanWriteOff(
            groupId: 'g1',
            loanAccountId: 'l1',
            reasonCode: 'PROLONGED_DEFAULT',
          ),
          throwsA(
            isA<LoanFailure>().having(
              (f) => f.type,
              'type',
              LoanFailureType.writeOffNothingOutstanding,
            ),
          ),
        );
      },
    );

    test(
      'H: LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF maps to its dedicated type',
      () async {
        final repo = buildRepo(
          (_) async => postgrestError('LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF'),
        );

        await expectLater(
          repo.previewLoanRecovery(
            groupId: 'g1',
            loanAccountId: 'l1',
            amount: 10000,
          ),
          throwsA(
            isA<LoanFailure>().having(
              (f) => f.type,
              'type',
              LoanFailureType.recoveryTargetNotWrittenOff,
            ),
          ),
        );
      },
    );

    test(
      'I: LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE maps to its dedicated type',
      () async {
        final repo = buildRepo(
          (_) async =>
              postgrestError('LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE'),
        );

        await expectLater(
          repo.postLoanRecovery(
            groupId: 'g1',
            loanAccountId: 'l1',
            amount: 999999,
            financialAccountId: 'account-1',
            paymentMethod: 'CASH',
          ),
          throwsA(
            isA<LoanFailure>().having(
              (f) => f.type,
              'type',
              LoanFailureType.recoveryExceedsRemainingBalance,
            ),
          ),
        );
      },
    );

    test('J: LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY (reused '
        '09F-A code) maps correctly for write-off reversal', () async {
      final repo = buildRepo(
        (_) async => postgrestError(
          'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
        ),
      );

      await expectLater(
        repo.reverseLoanWriteOff(
          groupId: 'g1',
          writeOffEventId: 'w1',
          reversalReason: 'attempt',
        ),
        throwsA(
          isA<LoanFailure>().having(
            (f) => f.type,
            'type',
            LoanFailureType.adjustmentReversalBlockedSubsequentActivity,
          ),
        ),
      );
    });

    test('K: LOAN_NOT_ACTIVE (unrelated, pre-existing mapping) is not '
        'swallowed by the new branches', () async {
      final repo = buildRepo((_) async => postgrestError('LOAN_NOT_ACTIVE'));

      await expectLater(
        repo.previewLoanWriteOff(
          groupId: 'g1',
          loanAccountId: 'l1',
          reasonCode: 'PROLONGED_DEFAULT',
        ),
        throwsA(
          isA<LoanFailure>().having(
            (f) => f.type,
            'type',
            LoanFailureType.loanNotActive,
          ),
        ),
      );
    });

    test('L: 42501 maps to permissionDenied for a recovery post', () async {
      final repo = buildRepo(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Not authorized',
            'code': '42501',
            'details': null,
            'hint': null,
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        repo.postLoanRecovery(
          groupId: 'g1',
          loanAccountId: 'l1',
          amount: 10000,
          financialAccountId: 'account-1',
          paymentMethod: 'CASH',
        ),
        throwsA(
          isA<LoanFailure>().having(
            (f) => f.type,
            'type',
            LoanFailureType.permissionDenied,
          ),
        ),
      );
    });
  });

  group('domain parsing', () {
    test('M: recovery post already_posted=true carries the SAME full shape '
        'as a fresh post (recovery_event_id/write_off_event_id/allocation '
        'always present)', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'recovery_event_id': 'r1',
          'payment_id': 'p1',
          'receipt_number': 'RCT-0001',
          'loan_account_id': 'l1',
          'write_off_event_id': 'w1',
          'amount': 10000,
          'allocation': {'penalty': 5000, 'interest': 5000, 'principal': 0},
          'already_posted': true,
          'loan_status': 'WRITTEN_OFF',
        }),
      );

      final result = await repo.postLoanRecovery(
        groupId: 'g1',
        loanAccountId: 'l1',
        amount: 10000,
        financialAccountId: 'account-1',
        paymentMethod: 'CASH',
      );

      expect(result.alreadyPosted, isTrue);
      expect(result.recoveryEventId, 'r1');
      expect(result.writeOffEventId, 'w1');
      expect(result.allocation.penalty, 5000);
    });

    test(
      'N: write-off summary with no prior write-off parses writeOff/'
      'remainingRecoverable as null and recoveries as an empty list',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'loan_account_id': 'l1',
            'loan_status': 'ACTIVE',
            'write_off': null,
            'remaining_recoverable': null,
            'recoveries': [],
          }),
        );

        final summary = await repo.getLoanWriteOffSummary(
          groupId: 'g1',
          loanAccountId: 'l1',
        );

        expect(summary.writeOff, isNull);
        expect(summary.remainingRecoverable, isNull);
        expect(summary.recoveries, isEmpty);
        expect(summary.hasWriteOff, isFalse);
      },
    );

    test('O: a recovery history entry with a nullable createdBy parses '
        'without throwing', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'loan_account_id': 'l1',
          'loan_status': 'WRITTEN_OFF',
          'write_off': {
            'id': 'w1',
            'principal_amount': 200000,
            'interest_amount': 15000,
            'penalty_amount': 5000,
            'total_amount': 220000,
            'reason_code': 'PROLONGED_DEFAULT',
            'note': null,
            'effective_date': '2026-09-01',
            'created_by': null,
            'created_at': '2026-09-01T00:00:00Z',
            'is_reversed': false,
          },
          'remaining_recoverable': {
            'principal': 200000,
            'interest': 15000,
            'penalty': 0,
            'total': 215000,
          },
          'recoveries': [
            {
              'id': 'r1',
              'payment_id': 'p1',
              'receipt_number': 'RCT-0001',
              'principal_recovered': 0,
              'interest_recovered': 0,
              'penalty_recovered': 5000,
              'total_recovered': 5000,
              'effective_at': '2026-09-05',
              'payment_status': 'POSTED',
              'created_by': null,
              'created_at': '2026-09-05T00:00:00Z',
            },
          ],
        }),
      );

      final summary = await repo.getLoanWriteOffSummary(
        groupId: 'g1',
        loanAccountId: 'l1',
      );

      expect(summary.recoveries.single.createdBy, isNull);
      expect(summary.recoveries.single.totalRecovered, 5000);
      expect(summary.recoveries.single.isReversed, isFalse);
      expect(summary.writeOff!.createdBy, isNull);
    });
  });
}
