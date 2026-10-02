import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/member_statement/data/supabase_member_statement_repository.dart';
import 'package:umoja/features/member_statement/domain/member_financial_statement.dart';

/// Prompt 09G-B3-C: domain parsing for the Member Financial Statement
/// contract (`rpc_get_my_member_statement`) and wire-level repository
/// contract verification (matching `loan_statement_contract_test.dart`'s
/// pattern — the REAL [SupabaseMemberStatementRepository] against a
/// [MockClient], not just a helper function in isolation).
void main() {
  Map<String, dynamic> baseResponse({
    Map<String, dynamic>? period,
    List<Map<String, dynamic>> items = const [],
  }) => {
    'member': {
      'membership_id': 'm1',
      'display_name': 'Test Member',
      'member_number': 'G1-0001',
      'membership_status': 'ACTIVE',
    },
    'group': {
      'group_id': 'g1',
      'group_name': 'Test Group',
      'group_code': 'TG01',
      'currency': 'TZS',
    },
    'period':
        period ??
        {'from_date': null, 'to_date': null, 'opening': null, 'closing': null},
    'summary': {
      'contributions': {'current_outstanding': 9000, 'pending_penalties': 0},
      'loans': {'current_outstanding': 97000, 'pending_penalties': 0},
      'wallet': {'current_balance': 25000},
      'last_payment': null,
    },
    'activity': {
      'items': items,
      'limit': 50,
      'offset': 0,
      'total_count': items.length,
      'has_more': false,
    },
  };

  group('Domain parsing: MemberFinancialStatement', () {
    test('1: a minimal statement (no period, no activity) parses', () {
      final statement = MemberFinancialStatement.fromJson(baseResponse());

      expect(statement.member.membershipId, 'm1');
      expect(statement.member.memberNumber, 'G1-0001');
      expect(statement.group.groupName, 'Test Group');
      expect(statement.group.currency, 'TZS');
      expect(statement.period.opening, isNull);
      expect(statement.period.closing, isNull);
      expect(statement.summary.contributionsCurrentOutstanding, 9000);
      expect(statement.summary.loansCurrentOutstanding, 97000);
      expect(statement.summary.walletCurrentBalance, 25000);
      expect(statement.activity.items, isEmpty);
    });

    test('2: null opening and null closing both parse as null, never a '
        'fabricated zero position', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          period: {
            'from_date': null,
            'to_date': null,
            'opening': null,
            'closing': null,
          },
        ),
      );

      expect(statement.period.opening, isNull);
      expect(statement.period.closing, isNull);
    });

    test('3: a non-null opening and closing both parse their three '
        'independent positions', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          period: {
            'from_date': '2026-01-16',
            'to_date': '2026-02-10',
            'opening': {
              'as_of_date': '2026-01-15',
              'contributions': {'outstanding': 10100},
              'loans': {'outstanding': 98000},
              'wallet': {'balance': 0},
            },
            'closing': {
              'as_of_date': '2026-02-10',
              'contributions': {'outstanding': 10100},
              'loans': {'outstanding': 97000},
              'wallet': {'balance': 25000},
            },
          },
        ),
      );

      expect(statement.period.fromDate, DateTime.parse('2026-01-16'));
      expect(statement.period.toDate, DateTime.parse('2026-02-10'));
      final opening = statement.period.opening!;
      expect(opening.asOfDate, DateTime.parse('2026-01-15'));
      expect(opening.contributionsOutstanding, 10100);
      expect(opening.loansOutstanding, 98000);
      expect(opening.walletBalance, 0);
      final closing = statement.period.closing!;
      expect(closing.loansOutstanding, 97000);
      expect(closing.walletBalance, 25000);
    });

    test('4: activity pagination metadata parses from the backend exactly '
        '(never inferred from items.length)', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse()..update('activity', (a) {
          final map = a as Map<String, dynamic>;
          return {
            ...map,
            'limit': 20,
            'offset': 40,
            'total_count': 67,
            'has_more': true,
          };
        }),
      );

      expect(statement.activity.limit, 20);
      expect(statement.activity.offset, 40);
      expect(statement.activity.totalCount, 67);
      expect(statement.activity.hasMore, isTrue);
    });

    test('5: a CONTRIBUTION activity item parses its component type and '
        'period metadata', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          items: [
            {
              'event_id': 'c1',
              'domain': 'CONTRIBUTION',
              'event_type': 'BASE',
              'effective_date': '2026-10-01',
              'amount': 50000,
              'is_reversed': false,
              'metadata': {
                'charge_id': 'charge-1',
                'period_id': 'period-1',
                'period_label': 'October 2026 Dues',
                'due_date': '2026-10-15',
                'reason': null,
              },
            },
          ],
        ),
      );

      final item = statement.activity.items.single;
      expect(item.domain, 'CONTRIBUTION');
      expect(item.eventType, 'BASE');
      expect(item.amount, 50000);
      expect(item.periodLabel, 'October 2026 Dues');
    });

    test('6: a PAYMENT activity item with nested allocations parses — '
        'allocations are detail under the payment, never separate items', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          items: [
            {
              'event_id': 'pay-1',
              'domain': 'PAYMENT',
              'event_type': 'PAYMENT',
              'effective_date': '2026-02-05',
              'amount': 100000,
              'is_reversed': false,
              'metadata': {
                'status': 'POSTED',
                'receipt_number': 'UMOJA-RCP-2026-000001',
                'payment_method': 'CASH',
                'external_reference': null,
                'reversal_reason': null,
                'allocations': [
                  {
                    'amount': 45000,
                    'target_type': 'CONTRIBUTION_COMPONENT',
                    'charge_id': 'charge-1',
                    'charge_component_id': 'comp-1',
                    'loan_account_id': null,
                    'loan_installment_id': null,
                  },
                  {
                    'amount': 30000,
                    'target_type': 'LOAN_PRINCIPAL',
                    'charge_id': null,
                    'charge_component_id': null,
                    'loan_account_id': 'loan-1',
                    'loan_installment_id': 'inst-1',
                  },
                ],
              },
            },
          ],
        ),
      );

      final item = statement.activity.items.single;
      expect(item.domain, 'PAYMENT');
      expect(item.amount, 100000);
      expect(item.receiptNumber, 'UMOJA-RCP-2026-000001');
      expect(item.allocations, hasLength(2));
      expect(item.allocations[0].isContribution, isTrue);
      expect(item.allocations[1].isLoan, isTrue);
      expect(item.allocations[0].amount + item.allocations[1].amount, 75000);
    });

    test('7: a reversed PAYMENT parses is_reversed=true and still carries '
        'its full metadata — history is never hidden', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          items: [
            {
              'event_id': 'pay-2',
              'domain': 'PAYMENT',
              'event_type': 'PAYMENT',
              'effective_date': '2026-01-10',
              'amount': 10000,
              'is_reversed': true,
              'metadata': {
                'status': 'REVERSED',
                'receipt_number': 'UMOJA-RCP-2026-000002',
                'payment_method': 'CASH',
                'external_reference': null,
                'reversal_reason': 'Wrong member credited',
                'allocations': <dynamic>[],
              },
            },
          ],
        ),
      );

      final item = statement.activity.items.single;
      expect(item.isReversed, isTrue);
      expect(item.allocations, isEmpty);
    });

    test('8: a LOAN activity item parses its loan_number metadata', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          items: [
            {
              'event_id': 'd1',
              'domain': 'LOAN',
              'event_type': 'DISBURSEMENT',
              'effective_date': '2026-01-01',
              'amount': 50000,
              'is_reversed': false,
              'metadata': {
                'loan_account_id': 'loan-1',
                'loan_number': 'LN-STB3B-001',
                'reference': null,
              },
            },
          ],
        ),
      );

      final item = statement.activity.items.single;
      expect(item.domain, 'LOAN');
      expect(item.loanNumber, 'LN-STB3B-001');
    });

    test('9: a WALLET activity item parses its entry type and source', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          items: [
            {
              'event_id': 'w1',
              'domain': 'WALLET',
              'event_type': 'PAYMENT_CREDIT',
              'effective_date': '2026-02-05',
              'amount': 25000,
              'is_reversed': false,
              'metadata': {'source_type': 'PAYMENT', 'source_id': 'pay-1'},
            },
          ],
        ),
      );

      final item = statement.activity.items.single;
      expect(item.domain, 'WALLET');
      expect(item.eventType, 'PAYMENT_CREDIT');
    });

    test('10: all four activity domains parse in one response, preserving '
        'the exact order the backend returned', () {
      final statement = MemberFinancialStatement.fromJson(
        baseResponse(
          items: [
            {
              'event_id': 'c1',
              'domain': 'CONTRIBUTION',
              'event_type': 'OPENING_BALANCE',
              'effective_date': '2026-01-01',
              'amount': 10000,
              'is_reversed': false,
              'metadata': <String, dynamic>{},
            },
            {
              'event_id': 'd1',
              'domain': 'LOAN',
              'event_type': 'DISBURSEMENT',
              'effective_date': '2026-01-01',
              'amount': 50000,
              'is_reversed': false,
              'metadata': <String, dynamic>{},
            },
            {
              'event_id': 'pay-1',
              'domain': 'PAYMENT',
              'event_type': 'PAYMENT',
              'effective_date': '2026-02-05',
              'amount': 100000,
              'is_reversed': false,
              'metadata': {'allocations': <dynamic>[]},
            },
            {
              'event_id': 'w1',
              'domain': 'WALLET',
              'event_type': 'PAYMENT_CREDIT',
              'effective_date': '2026-02-05',
              'amount': 25000,
              'is_reversed': false,
              'metadata': <String, dynamic>{},
            },
          ],
        ),
      );

      expect(statement.activity.items.map((i) => i.domain).toList(), [
        'CONTRIBUTION',
        'LOAN',
        'PAYMENT',
        'WALLET',
      ]);
    });
  });

  group('Repository contract: getMyStatement', () {
    late Map<String, dynamic>? capturedBody;
    late String? capturedPath;

    SupabaseMemberStatementRepository buildRepo(
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
      return SupabaseMemberStatementRepository(client);
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

    test('11: no date range sends p_group_id/p_from_date=null/'
        'p_to_date=null/p_limit/p_offset — nothing else', () async {
      final repo = buildRepo((_) async => jsonOk(baseResponse()));

      await repo.getMyStatement(groupId: 'g1', limit: 50, offset: 0);

      expect(capturedPath, contains('rpc_get_my_member_statement'));
      expect(capturedBody, {
        'p_group_id': 'g1',
        'p_from_date': null,
        'p_to_date': null,
        'p_limit': 50,
        'p_offset': 0,
      });
    });

    test('12: a full date range sends exact date-only (no time component) '
        'strings', () async {
      final repo = buildRepo((_) async => jsonOk(baseResponse()));

      await repo.getMyStatement(
        groupId: 'g1',
        fromDate: DateTime(2026, 1, 16),
        toDate: DateTime(2026, 2, 10),
        limit: 20,
        offset: 0,
      );

      expect(capturedBody!['p_from_date'], '2026-01-16');
      expect(capturedBody!['p_to_date'], '2026-02-10');
    });

    test('13: pagination sends the exact requested offset', () async {
      final repo = buildRepo((_) async => jsonOk(baseResponse()));

      await repo.getMyStatement(groupId: 'g1', limit: 20, offset: 40);

      expect(capturedBody!['p_limit'], 20);
      expect(capturedBody!['p_offset'], 40);
    });

    test('14: the request body NEVER contains p_user_id, '
        'p_membership_id, p_phone, or p_role_id', () async {
      final repo = buildRepo((_) async => jsonOk(baseResponse()));

      await repo.getMyStatement(groupId: 'g1');

      expect(capturedBody!.containsKey('p_user_id'), isFalse);
      expect(capturedBody!.containsKey('p_membership_id'), isFalse);
      expect(capturedBody!.containsKey('p_phone'), isFalse);
      expect(capturedBody!.containsKey('p_role_id'), isFalse);
      expect(capturedBody!.keys, hasLength(5));
    });

    test('15: the response parses through the real repository path into a '
        'full MemberFinancialStatement', () async {
      final repo = buildRepo((_) async => jsonOk(baseResponse()));

      final statement = await repo.getMyStatement(groupId: 'g1');

      expect(statement.member.membershipId, 'm1');
      expect(statement.summary.walletCurrentBalance, 25000);
    });
  });
}
