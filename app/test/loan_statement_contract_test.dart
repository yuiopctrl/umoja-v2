import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/loans/data/supabase_loan_repository.dart';
import 'package:umoja/features/loans/domain/loan_account.dart';
import 'package:umoja/features/loans/domain/loan_statement.dart';

/// Prompt 09G-03: domain parsing for the Loan Statement contract
/// (`rpc_get_loan_statement`), the additive `rpc_get_loan_account`
/// write-off fields, and wire-level repository contract verification
/// (matching 09F-B's `loan_write_off_recovery_contract_test.dart`
/// pattern — the REAL [SupabaseLoanRepository] against a [MockClient],
/// not just a helper function in isolation).
void main() {
  group('Domain parsing: LoanStatement', () {
    Map<String, dynamic> baseHeader({String status = 'ACTIVE'}) => {
      'loan_account_id': 'loan-1',
      'loan_number': 'STD-LN-2026-0001',
      'loan_product_id': 'product-1',
      'loan_product_name': 'Standard Loan',
      'membership_id': 'm1',
      'borrower_display_name': 'Test Member',
      'borrower_member_number': 'STD-2026-0011',
      'loan_origin': 'NEW',
      'principal_amount': 300000,
      'interest_rate': 5.0,
      'interest_rate_basis': 'MONTHLY',
      'interest_method': 'FLAT',
      'term': 3,
      'term_unit': 'MONTH',
      'first_repayment_date': '2026-04-15',
      'application_date': '2026-04-01',
      'status': status,
    };

    Map<String, dynamic> scheduleJson({
      List<Map<String, dynamic>> current = const [],
      List<Map<String, dynamic>> history = const [],
    }) => {'current': current, 'history': history};

    test('1: a full normal (ACTIVE) statement parses', () {
      final statement = LoanStatement.fromJson({
        'header': baseHeader(),
        'current_state': {
          'status': 'ACTIVE',
          'principal_outstanding': 200000,
          'earned_interest_outstanding': 10000,
          'penalty_outstanding': 0,
          'total_outstanding': 210000,
          'scheduled_unearned_interest': 5000,
          'overdue_principal': 0,
          'overdue_interest': 0,
          'overdue_penalty': 0,
          'total_overdue': 0,
          'write_off': null,
        },
        'timeline': [
          {
            'event_id': '0:e1',
            'event_type': 'LOAN_CREATED',
            'event_subtype': null,
            'effective_at': '2026-04-01',
            'created_at': '2026-04-01T10:00:00Z',
            'sequence_key': '0:0:e1',
            'title_code': 'LOAN_CREATED',
            'actor_user_id': 'u1',
            'is_reversed': false,
            'reversed_by_event_id': null,
            'amount': null,
            'components': null,
            'references': <String, dynamic>{},
            'metadata': {
              'reason': null,
              'from_status': null,
              'to_status': 'DRAFT',
            },
          },
        ],
        'schedule': scheduleJson(
          current: [
            {
              'id': 'inst-1',
              'installment_number': 1,
              'due_date': '2026-04-15',
              'principal_due': 100000,
              'interest_due': 5000,
              'total_due': 105000,
              'principal_outstanding': 100000,
              'interest_outstanding': 5000,
              'penalty_outstanding': 0,
            },
          ],
        ),
      });

      expect(statement.header.loanAccountId, 'loan-1');
      expect(statement.header.borrowerMemberNumber, 'STD-2026-0011');
      expect(statement.currentState.status, 'ACTIVE');
      expect(statement.currentState.totalOutstanding, 210000);
      expect(statement.currentState.writeOff, isNull);
      expect(statement.timeline, hasLength(1));
      expect(
        statement.timeline.first.eventType,
        LoanStatementEventType.loanCreated,
      );
      expect(statement.schedule.current, hasLength(1));
      expect(statement.schedule.history, isEmpty);
    });

    test('2: a WRITTEN_OFF statement parses the nested write_off object', () {
      final statement = LoanStatement.fromJson({
        'header': baseHeader(status: 'WRITTEN_OFF'),
        'current_state': {
          'status': 'WRITTEN_OFF',
          'principal_outstanding': 0,
          'earned_interest_outstanding': 0,
          'penalty_outstanding': 0,
          'total_outstanding': 0,
          'scheduled_unearned_interest': 0,
          'overdue_principal': 0,
          'overdue_interest': 0,
          'overdue_penalty': 0,
          'total_overdue': 0,
          'write_off': {
            'is_active': true,
            'write_off_event_id': 'wo-1',
            'effective_date': '2026-06-01',
            'reason_code': 'PROLONGED_DEFAULT',
            'note': null,
            'principal_written_off': 200000,
            'interest_written_off': 15000,
            'penalty_written_off': 5000,
            'amount_written_off': 220000,
            'recovered_principal': 0,
            'recovered_interest': 0,
            'recovered_penalty': 0,
            'total_recovered': 0,
            'remaining_recoverable_principal': 200000,
            'remaining_recoverable_interest': 15000,
            'remaining_recoverable_penalty': 5000,
            'remaining_recoverable': 220000,
          },
        },
        'timeline': [],
        'schedule': scheduleJson(),
      });

      expect(statement.currentState.isWrittenOff, isTrue);
      expect(statement.currentState.totalOutstanding, 0);
      final writeOff = statement.currentState.writeOff!;
      expect(writeOff.isActive, isTrue);
      expect(writeOff.amountWrittenOff, 220000);
      expect(writeOff.remainingRecoverable, 220000);
    });

    test('3: an ACTIVE loan that has never been written off parses '
        'write_off as null', () {
      final statement = LoanStatement.fromJson({
        'header': baseHeader(),
        'current_state': {
          'status': 'ACTIVE',
          'principal_outstanding': 300000,
          'earned_interest_outstanding': 0,
          'penalty_outstanding': 0,
          'total_outstanding': 300000,
          'scheduled_unearned_interest': 15000,
          'overdue_principal': 0,
          'overdue_interest': 0,
          'overdue_penalty': 0,
          'total_overdue': 0,
          'write_off': null,
        },
        'timeline': [],
        'schedule': scheduleJson(),
      });

      expect(statement.currentState.writeOff, isNull);
    });

    test('4: partial recovery components parse correctly', () {
      final writeOff = LoanStatementWriteOffState.fromJson({
        'is_active': true,
        'write_off_event_id': 'wo-1',
        'effective_date': '2026-06-01',
        'reason_code': 'PROLONGED_DEFAULT',
        'note': null,
        'principal_written_off': 200000,
        'interest_written_off': 15000,
        'penalty_written_off': 5000,
        'amount_written_off': 220000,
        'recovered_principal': 0,
        'recovered_interest': 4000,
        'recovered_penalty': 5000,
        'total_recovered': 9000,
        'remaining_recoverable_principal': 200000,
        'remaining_recoverable_interest': 11000,
        'remaining_recoverable_penalty': 0,
        'remaining_recoverable': 211000,
      });

      expect(writeOff.recoveredPenalty, 5000);
      expect(writeOff.recoveredInterest, 4000);
      expect(writeOff.remainingRecoverablePenalty, 0);
      expect(writeOff.remainingRecoverable, 211000);
    });

    test('5: fully recovered write-off parses remaining_recoverable as 0 '
        'while the loan stays WRITTEN_OFF', () {
      final statement = LoanStatement.fromJson({
        'header': baseHeader(status: 'WRITTEN_OFF'),
        'current_state': {
          'status': 'WRITTEN_OFF',
          'principal_outstanding': 0,
          'earned_interest_outstanding': 0,
          'penalty_outstanding': 0,
          'total_outstanding': 0,
          'scheduled_unearned_interest': 0,
          'overdue_principal': 0,
          'overdue_interest': 0,
          'overdue_penalty': 0,
          'total_overdue': 0,
          'write_off': {
            'is_active': true,
            'write_off_event_id': 'wo-2',
            'effective_date': '2026-08-15',
            'reason_code': 'PROLONGED_DEFAULT',
            'note': null,
            'principal_written_off': 100000,
            'interest_written_off': 5000,
            'penalty_written_off': 0,
            'amount_written_off': 105000,
            'recovered_principal': 100000,
            'recovered_interest': 5000,
            'recovered_penalty': 0,
            'total_recovered': 105000,
            'remaining_recoverable_principal': 0,
            'remaining_recoverable_interest': 0,
            'remaining_recoverable_penalty': 0,
            'remaining_recoverable': 0,
          },
        },
        'timeline': [],
        'schedule': scheduleJson(),
      });

      expect(statement.header.status, 'WRITTEN_OFF');
      expect(statement.currentState.writeOff!.remainingRecoverable, 0);
      expect(statement.currentState.writeOff!.isActive, isTrue);
    });

    test('6: an unrecognized event_type parses to unknown instead of '
        'throwing, preserving its raw type/date/amount', () {
      final statement = LoanStatement.fromJson({
        'header': baseHeader(),
        'current_state': {
          'status': 'ACTIVE',
          'principal_outstanding': 0,
          'earned_interest_outstanding': 0,
          'penalty_outstanding': 0,
          'total_outstanding': 0,
          'scheduled_unearned_interest': 0,
          'overdue_principal': 0,
          'overdue_interest': 0,
          'overdue_penalty': 0,
          'total_overdue': 0,
          'write_off': null,
        },
        'timeline': [
          {
            'event_id': '9:future-1',
            'event_type': 'FUTURE_EVENT_TYPE_NOT_YET_KNOWN',
            'event_subtype': 'SOME_SUBTYPE',
            'effective_at': '2026-10-01',
            'created_at': '2026-10-01T09:00:00Z',
            'sequence_key': '9:0:future-1',
            'title_code': 'FUTURE_EVENT_TYPE_NOT_YET_KNOWN',
            'actor_user_id': 'u1',
            'is_reversed': false,
            'reversed_by_event_id': null,
            'amount': 12345,
            'components': null,
            'references': <String, dynamic>{},
            'metadata': <String, dynamic>{},
          },
        ],
        'schedule': scheduleJson(),
      });

      final event = statement.timeline.single;
      expect(event.eventType, LoanStatementEventType.unknown);
      expect(event.rawEventType, 'FUTURE_EVENT_TYPE_NOT_YET_KNOWN');
      expect(event.effectiveAt, DateTime.parse('2026-10-01'));
      expect(event.amount, 12345);
    });

    test('7: nullable components/references/metadata all parse safely', () {
      final event = LoanStatementEvent.fromJson({
        'event_id': '5:re1',
        'event_type': 'LOAN_RESTRUCTURED',
        'event_subtype': null,
        'effective_at': '2026-05-01',
        'created_at': '2026-05-01T00:00:00Z',
        'sequence_key': '5:0:re1',
        'title_code': 'LOAN_RESTRUCTURED',
        'actor_user_id': null,
        'is_reversed': false,
        'reversed_by_event_id': null,
        'amount': null,
        'components': null,
        'references': null,
        'metadata': null,
      });

      expect(event.components, isNull);
      expect(event.references, isEmpty);
      expect(event.metadata, isEmpty);
      expect(event.actorUserId, isNull);
    });

    test('8: schedule.current and schedule.history both parse', () {
      final schedule = LoanStatementSchedule.fromJson(
        scheduleJson(
          current: [
            {
              'id': 'inst-2',
              'installment_number': 2,
              'due_date': '2026-05-15',
              'principal_due': 100000,
              'interest_due': 5000,
              'total_due': 105000,
              'principal_outstanding': 100000,
              'interest_outstanding': 5000,
              'penalty_outstanding': 0,
            },
          ],
          history: [
            {
              'id': 'inst-1-old',
              'installment_number': 1,
              'due_date': '2026-04-15',
              'principal_due': 100000,
              'interest_due': 5000,
              'cancelled_at': '2026-04-20T00:00:00Z',
              'cancellation_reason': 'Superseded by restructure',
              'cancelled_by_payment_id': null,
              'created_by_payment_id': null,
            },
          ],
        ),
      );

      expect(schedule.current, hasLength(1));
      expect(schedule.history, hasLength(1));
      expect(
        schedule.history.single.cancellationReason,
        'Superseded by restructure',
      );
    });
  });

  group('Domain parsing: LoanAccount additive write-off fields', () {
    Map<String, dynamic> baseAccountJson({
      String status = 'ACTIVE',
      double? principalOutstanding,
      double? interestOutstanding,
      double? penaltyOutstanding,
      double? totalOutstanding,
      String? nextDueDate,
      double? writtenOffTotal,
      double? remainingRecoverableTotal,
      double? remainingRecoverablePrincipal,
      double? remainingRecoverableInterest,
      double? remainingRecoverablePenalty,
    }) => {
      'id': 'loan-1',
      'group_id': 'g1',
      'membership_id': 'm1',
      'borrower_display_name': 'Test Member',
      'borrower_member_number': null,
      'loan_product_id': 'product-1',
      'loan_product_name': 'Standard Loan',
      'loan_product_code': 'STD',
      'loan_number': 'STD-LN-2026-0001',
      'loan_origin': 'NEW',
      'principal_amount': 300000,
      'interest_rate': 5.0,
      'interest_rate_basis': 'MONTHLY',
      'interest_method': 'FLAT',
      'term': 3,
      'term_unit': 'MONTH',
      'repayment_frequency': 'MONTHLY',
      'application_date': '2026-04-01',
      'first_repayment_date': '2026-04-15',
      'status': status,
      'created_at': '2026-04-01T00:00:00Z',
      'updated_at': '2026-04-01T00:00:00Z',
      'installments': <dynamic>[],
      'events': <dynamic>[],
      'principal_repaid': 0,
      'principal_outstanding': principalOutstanding,
      'interest_recognized': 0,
      'interest_outstanding': interestOutstanding,
      'penalty_paid': 0,
      'penalty_outstanding': penaltyOutstanding,
      'total_outstanding': totalOutstanding,
      'next_due_date': nextDueDate,
      'overdue_amount': 0,
      'written_off_total': writtenOffTotal,
      'remaining_recoverable_total': remainingRecoverableTotal,
      'remaining_recoverable_principal': remainingRecoverablePrincipal,
      'remaining_recoverable_interest': remainingRecoverableInterest,
      'remaining_recoverable_penalty': remainingRecoverablePenalty,
    };

    test('9: updated LoanAccount additive write-off fields parse when '
        'present', () {
      final account = LoanAccount.fromJson(
        baseAccountJson(
          status: 'WRITTEN_OFF',
          principalOutstanding: 0,
          interestOutstanding: 0,
          penaltyOutstanding: 0,
          totalOutstanding: 0,
          nextDueDate: null,
          writtenOffTotal: 220000,
          remainingRecoverableTotal: 211000,
          remainingRecoverablePrincipal: 200000,
          remainingRecoverableInterest: 11000,
          remainingRecoverablePenalty: 0,
        ),
      );

      expect(account.writtenOffTotal, 220000);
      expect(account.remainingRecoverableTotal, 211000);
      expect(account.remainingRecoverablePrincipal, 200000);
      expect(account.remainingRecoverableInterest, 11000);
      expect(account.remainingRecoverablePenalty, 0);
    });

    test('10: WRITTEN_OFF LoanAccount ordinary outstanding zeros parse '
        'correctly (server-corrected, Prompt 09G-02) and next_due_date is '
        'null', () {
      final account = LoanAccount.fromJson(
        baseAccountJson(
          status: 'WRITTEN_OFF',
          principalOutstanding: 0,
          interestOutstanding: 0,
          penaltyOutstanding: 0,
          totalOutstanding: 0,
          nextDueDate: null,
        ),
      );

      expect(account.isWrittenOff, isTrue);
      expect(account.principalOutstanding, 0);
      expect(account.interestOutstanding, 0);
      expect(account.penaltyOutstanding, 0);
      expect(account.totalOutstanding, 0);
      expect(account.nextDueDate, isNull);
    });

    test('never-written-off LoanAccount leaves the additive fields null', () {
      final account = LoanAccount.fromJson(baseAccountJson());

      expect(account.writtenOffTotal, isNull);
      expect(account.remainingRecoverableTotal, isNull);
      expect(account.remainingRecoverablePrincipal, isNull);
      expect(account.remainingRecoverableInterest, isNull);
      expect(account.remainingRecoverablePenalty, isNull);
    });
  });

  group('Repository contract: getLoanStatement', () {
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

    setUp(() {
      capturedBody = null;
      capturedPath = null;
    });

    final statementJson = {
      'header': {
        'loan_account_id': 'loan-1',
        'loan_number': 'STD-LN-2026-0001',
        'loan_product_id': 'product-1',
        'loan_product_name': 'Standard Loan',
        'membership_id': 'm1',
        'borrower_display_name': 'Test Member',
        'borrower_member_number': null,
        'loan_origin': 'NEW',
        'principal_amount': 300000,
        'interest_rate': 5.0,
        'interest_rate_basis': 'MONTHLY',
        'interest_method': 'FLAT',
        'term': 3,
        'term_unit': 'MONTH',
        'first_repayment_date': '2026-04-15',
        'application_date': '2026-04-01',
        'status': 'ACTIVE',
      },
      'current_state': {
        'status': 'ACTIVE',
        'principal_outstanding': 300000,
        'earned_interest_outstanding': 0,
        'penalty_outstanding': 0,
        'total_outstanding': 300000,
        'scheduled_unearned_interest': 15000,
        'overdue_principal': 0,
        'overdue_interest': 0,
        'overdue_penalty': 0,
        'total_overdue': 0,
        'write_off': null,
      },
      'timeline': <dynamic>[],
      'schedule': {'current': <dynamic>[], 'history': <dynamic>[]},
    };

    test('11/12/13: calls rpc_get_loan_statement with exactly '
        'p_group_id/p_loan_account_id', () async {
      final repo = buildRepo((_) async => jsonOk(statementJson));

      await repo.getLoanStatement(groupId: 'g1', loanAccountId: 'loan-1');

      expect(capturedPath, contains('rpc_get_loan_statement'));
      expect(capturedBody, {'p_group_id': 'g1', 'p_loan_account_id': 'loan-1'});
    });

    test('14: the response parses through the real SupabaseLoanRepository '
        'path into a full LoanStatement', () async {
      final repo = buildRepo((_) async => jsonOk(statementJson));

      final statement = await repo.getLoanStatement(
        groupId: 'g1',
        loanAccountId: 'loan-1',
      );

      expect(statement.header.loanAccountId, 'loan-1');
      expect(statement.currentState.totalOutstanding, 300000);
      expect(statement.timeline, isEmpty);
      expect(statement.schedule.current, isEmpty);
    });
  });
}
