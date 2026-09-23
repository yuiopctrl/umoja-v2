import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/data/supabase_loan_repository.dart';

/// Prompt 09F-A-09 (UAT Blocker-02) Defect A/B — the repository must
/// never send an explicit JSON `null` for `p_effective_date` (PostgREST
/// forwards that as a literal SQL NULL, overriding the RPC's own
/// `DEFAULT CURRENT_DATE` and tripping its `22023: Effective date is
/// required` guard — exactly what broke Waive/Correct in physical UAT).
/// These tests exercise the REAL [SupabaseLoanRepository] against a
/// [MockClient] so they verify actual wire-level RPC parameter
/// construction, not just a helper function's return value in
/// isolation.
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

  group('effective-date omission (Defect A)', () {
    test('A: waiver preview with effectiveDate == null omits p_effective_date '
        'from the RPC params entirely', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'target_type': 'LOAN_PENALTY',
          'target_id': 't1',
          'current_outstanding': 40000,
          'waiver_amount': 15000,
          'remaining_outstanding': 25000,
          'cash_impact': 0,
          'payment_created': false,
          'receipt_created': false,
        }),
      );

      await repo.previewLoanObligationWaiver(
        groupId: 'g1',
        loanAccountId: 'l1',
        targetType: 'LOAN_PENALTY',
        targetId: 't1',
        amount: 15000,
        reasonCode: 'HARDSHIP',
      );

      expect(capturedPath, contains('rpc_preview_loan_obligation_waiver'));
      expect(capturedBody, isNotNull);
      expect(capturedBody!.containsKey('p_effective_date'), isFalse);
    });

    test(
      'B: waiver post with effectiveDate == null omits p_effective_date',
      () async {
        final repo = buildRepo(
          (_) async => jsonOk({
            'adjustment_id': 'a1',
            'target_type': 'LOAN_PENALTY',
            'adjustment_type': 'WAIVER',
            'amount': -15000,
            'outstanding_after': 25000,
            'already_posted': false,
            'loan_status': 'ACTIVE',
          }),
        );

        await repo.postLoanObligationWaiver(
          groupId: 'g1',
          loanAccountId: 'l1',
          targetType: 'LOAN_PENALTY',
          targetId: 't1',
          amount: 15000,
          reasonCode: 'HARDSHIP',
        );

        expect(capturedPath, contains('rpc_post_loan_obligation_waiver'));
        expect(capturedBody!.containsKey('p_effective_date'), isFalse);
      },
    );

    test('C: correction preview with effectiveDate == null omits '
        'p_effective_date', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'target_type': 'LOAN_PENALTY',
          'target_id': 't1',
          'adjustment_type': 'CORRECTION_DECREASE',
          'source_original_amount': 50000,
          'prior_net_corrections': 0,
          'current_effective_amount': 50000,
          'proposed_correction': -10000,
          'new_effective_amount': 40000,
          'outstanding_before': 50000,
          'outstanding_after': 40000,
          'cash_impact': 0,
          'payment_created': false,
          'receipt_created': false,
        }),
      );

      await repo.previewLoanObligationCorrection(
        groupId: 'g1',
        loanAccountId: 'l1',
        targetType: 'LOAN_PENALTY',
        targetId: 't1',
        adjustmentType: 'CORRECTION_DECREASE',
        amount: 10000,
        reasonCode: 'ASSESSMENT_ERROR',
      );

      expect(capturedPath, contains('rpc_preview_loan_obligation_correction'));
      expect(capturedBody!.containsKey('p_effective_date'), isFalse);
    });

    test('D: correction post with effectiveDate == null omits '
        'p_effective_date', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'adjustment_id': 'a1',
          'target_type': 'LOAN_PENALTY',
          'adjustment_type': 'CORRECTION_DECREASE',
          'amount': -10000,
          'outstanding_after': 40000,
          'already_posted': false,
          'loan_status': 'ACTIVE',
        }),
      );

      await repo.postLoanObligationCorrection(
        groupId: 'g1',
        loanAccountId: 'l1',
        targetType: 'LOAN_PENALTY',
        targetId: 't1',
        adjustmentType: 'CORRECTION_DECREASE',
        amount: 10000,
        reasonCode: 'ASSESSMENT_ERROR',
      );

      expect(capturedPath, contains('rpc_post_loan_obligation_correction'));
      expect(capturedBody!.containsKey('p_effective_date'), isFalse);
    });

    test('E: an explicit effectiveDate is present and serialized as a plain '
        'date-only string', () async {
      final repo = buildRepo(
        (_) async => jsonOk({
          'target_type': 'LOAN_PENALTY',
          'target_id': 't1',
          'current_outstanding': 40000,
          'waiver_amount': 15000,
          'remaining_outstanding': 25000,
          'cash_impact': 0,
          'payment_created': false,
          'receipt_created': false,
        }),
      );

      await repo.previewLoanObligationWaiver(
        groupId: 'g1',
        loanAccountId: 'l1',
        targetType: 'LOAN_PENALTY',
        targetId: 't1',
        amount: 15000,
        reasonCode: 'HARDSHIP',
        effectiveDate: DateTime.utc(2026, 6, 15),
      );

      expect(capturedBody!['p_effective_date'], '2026-06-15');
    });
  });

  group('error mapping (Defect B / regression)', () {
    test('F: "Effective date is required" maps to the dedicated localized '
        'failure type, not the generic fallback', () async {
      final repo = buildRepo(
        (_) async =>
            postgrestError('Effective date is required', code: '22023'),
      );

      await expectLater(
        repo.previewLoanObligationWaiver(
          groupId: 'g1',
          loanAccountId: 'l1',
          targetType: 'LOAN_PENALTY',
          targetId: 't1',
          amount: 15000,
          reasonCode: 'HARDSHIP',
        ),
        throwsA(
          isA<LoanFailure>().having(
            (f) => f.type,
            'type',
            LoanFailureType.adjustmentEffectiveDateRequired,
          ),
        ),
      );
    });

    test('G: future-interest correction rejection maps to a dedicated '
        'localized failure, distinct from the waiver one', () async {
      final repo = buildRepo(
        (_) async => postgrestError('LOAN_FUTURE_INTEREST_NOT_CORRECTABLE'),
      );

      await expectLater(
        repo.previewLoanObligationCorrection(
          groupId: 'g1',
          loanAccountId: 'l1',
          targetType: 'LOAN_INTEREST',
          targetId: 't1',
          adjustmentType: 'CORRECTION_DECREASE',
          amount: 100,
          reasonCode: 'ASSESSMENT_ERROR',
        ),
        throwsA(
          isA<LoanFailure>().having(
            (f) => f.type,
            'type',
            LoanFailureType.futureInterestNotCorrectable,
          ),
        ),
      );
    });

    test('H: unrelated PostgREST errors retain their normal, pre-existing '
        'mapping (not swallowed by the new branches)', () async {
      final repo = buildRepo((_) async => postgrestError('LOAN_NOT_ACTIVE'));

      await expectLater(
        repo.previewLoanObligationWaiver(
          groupId: 'g1',
          loanAccountId: 'l1',
          targetType: 'LOAN_PENALTY',
          targetId: 't1',
          amount: 15000,
          reasonCode: 'HARDSHIP',
        ),
        throwsA(
          isA<LoanFailure>().having(
            (f) => f.type,
            'type',
            LoanFailureType.loanNotActive,
          ),
        ),
      );

      final permissionRepo = buildRepo(
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
        permissionRepo.previewLoanObligationWaiver(
          groupId: 'g1',
          loanAccountId: 'l1',
          targetType: 'LOAN_PENALTY',
          targetId: 't1',
          amount: 15000,
          reasonCode: 'HARDSHIP',
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
}
