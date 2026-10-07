import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/member_loans/data/member_loans_failure.dart';
import 'package:umoja/features/member_loans/data/supabase_member_loans_repository.dart';
import 'package:umoja/features/member_loans/domain/member_loan.dart';

import 'fakes/member_loan_json_fixtures.dart';

/// Prompt 09G-B5-C §C/§AP: RPC payloads, the deployed JSON contract, and the
/// safe error mapping. Values are asserted exactly as the backend returns
/// them. Nothing is recomputed here.
void main() {
  group('RPC payloads (only the four member-safe RPCs)', () {
    test('list sends group, limit and offset', () async {
      String? name;
      Map<String, dynamic>? params;
      final repo = SupabaseMemberLoansRepository.withInvoker((fn, p) async {
        name = fn;
        params = p;
        return memberLoansPageJson();
      });
      await repo.getMyLoans(groupId: 'g1', limit: 20, offset: 40);
      expect(name, 'rpc_get_my_loans');
      expect(params, {'p_group_id': 'g1', 'p_limit': 20, 'p_offset': 40});
    });

    test('detail, schedule and timeline use the correct RPC names', () async {
      final names = <String>[];
      final repo = SupabaseMemberLoansRepository.withInvoker((fn, p) async {
        names.add(fn);
        if (fn == 'rpc_get_my_loan_detail') return memberLoanDetailJson();
        if (fn == 'rpc_get_my_loan_schedule') return memberLoanScheduleJson();
        return memberLoanTimelinePageJson();
      });
      await repo.getMyLoanDetail(groupId: 'g1', loanAccountId: 'loan-701');
      await repo.getMyLoanSchedule(groupId: 'g1', loanAccountId: 'loan-701');
      await repo.getMyLoanTimeline(
        groupId: 'g1',
        loanAccountId: 'loan-701',
        limit: 20,
        offset: 0,
      );
      expect(names, [
        'rpc_get_my_loan_detail',
        'rpc_get_my_loan_schedule',
        'rpc_get_my_loan_timeline',
      ]);
    });

    test('no membership, user or phone identity is ever sent', () async {
      Map<String, dynamic>? params;
      final repo = SupabaseMemberLoansRepository.withInvoker((_, p) async {
        params = p;
        return memberLoanTimelinePageJson();
      });
      await repo.getMyLoanTimeline(
        groupId: 'g1',
        loanAccountId: 'loan-701',
        limit: 20,
        offset: 0,
      );
      expect(
        params!.keys.where(
          (k) =>
              k.contains('member') ||
              k.contains('user') ||
              k.contains('phone') ||
              k.contains('role'),
        ),
        isEmpty,
      );
    });
  });

  group('deployed JSON contract', () {
    test('list page parses items and pagination exactly', () {
      final page = MemberLoansPage.fromJson(memberLoansPageJson(hasMore: true));
      expect(page.items.single.loanNumber, 'LN-B5B-701');
      expect(page.items.single.status, MemberLoanStatus.active);
      expect(page.items.single.currentPosition.totalOutstanding, 5450);
      expect(page.pagination.hasMore, isTrue);
      expect(page.pagination.totalCount, isNonNegative);
    });

    test(
      'an opening-position loan carries origin context; a NEW loan does not',
      () {
        final opening = MemberLoanListItem.fromJson(
          memberLoanListItemJson(originContext: 'OPENING_POSITION'),
        );
        final newLoan = MemberLoanListItem.fromJson(memberLoanListItemJson());
        expect(opening.isOpeningPosition, isTrue);
        expect(newLoan.originContext, isNull);
        expect(newLoan.isOpeningPosition, isFalse);
      },
    );

    test('DISBURSED is never a member status; the enum has no such value', () {
      expect(
        MemberLoanStatus.values.map((s) => s.wire),
        isNot(contains('DISBURSED')),
      );
      expect(MemberLoanStatus.fromWire('DISBURSED'), MemberLoanStatus.unknown);
    });

    test(
      'an unknown future status falls back to unknown instead of throwing',
      () {
        final item = MemberLoanListItem.fromJson(
          memberLoanListItemJson(memberStatus: 'SOME_FUTURE_STATUS'),
        );
        expect(item.status, MemberLoanStatus.unknown);
      },
    );

    test('a null current position amount stays null, never zero', () {
      final item = MemberLoanListItem.fromJson(
        memberLoanListItemJson(
          position: memberLoanPositionJson(
            principal: null,
            interest: null,
            penalty: null,
            total: null,
          ),
        ),
      );
      expect(item.currentPosition.totalOutstanding, isNull);
      expect(item.currentPosition.isAvailable, isFalse);
    });

    test(
      'schedule keeps current and history apart and carries member statuses',
      () {
        final schedule = MemberLoanSchedule.fromJson(
          memberLoanScheduleJson(
            current: [
              memberScheduleCurrentRowJson(
                memberScheduleStatus: 'PARTIALLY_SETTLED',
              ),
            ],
            history: [memberScheduleHistoryRowJson(status: 'REPLACED')],
          ),
        );
        expect(
          schedule.current.single.status,
          MemberScheduleStatus.partiallySettled,
        );
        expect(
          schedule.history.single.status,
          MemberScheduleHistoryStatus.replaced,
        );
        expect(schedule.history.single.replacementReason, 'RESTRUCTURE');
      },
    );

    test(
      'scheduled future interest is a separate field, never current interest',
      () {
        final row = MemberScheduleRow.fromJson(
          memberScheduleCurrentRowJson(
            futureInterest: 60,
            memberScheduleStatus: 'UPCOMING',
          ),
        );
        expect(row.scheduledFutureInterestOutstanding, 60);
        expect(row.currentEarnedInterestOutstanding, 0);
      },
    );

    test('a payment event parses with its loan-attributable amount and cash direction', () {
      final event = MemberLoanTimelineEvent.fromJson(memberTimelineEventJson());
      expect(event.eventType, MemberLoanEventType.paymentPosted);
      expect(event.isCash, isTrue);
      expect(event.cashDirection, MemberLoanCashDirection.cashIn);
      expect(event.amount, 1100);
      expect(event.receiptNumber, 'B5B-RCPT-001');
    });

    test('a non-cash event carries an amount but is not cash', () {
      final event = MemberLoanTimelineEvent.fromJson(
        memberTimelineEventJson(
          eventType: 'PENALTY_ASSESSED',
          amount: 50,
          isCash: false,
          cashDirection: null,
          componentBreakdown: {'penalty': 50},
          metadata: {'installment_number': 1},
        ),
      );
      expect(event.isCash, isFalse);
      expect(event.cashDirection, isNull);
      expect(event.amount, 50);
    });

    test('an unknown future event type falls back without crashing', () {
      final event = MemberLoanTimelineEvent.fromJson(
        memberTimelineEventJson(
          eventType: 'NEW_FUTURE_EVENT',
          isCash: false,
          amount: null,
          cashDirection: null,
        ),
      );
      expect(event.eventType, MemberLoanEventType.unknown);
    });

    test('a reversed payment stays one event marked reversed', () {
      final event = MemberLoanTimelineEvent.fromJson(
        memberTimelineEventJson(isReversed: true),
      );
      expect(event.isReversed, isTrue);
    });
  });

  group('failure mapping (no raw database text)', () {
    test('42501 and 28000 map to notAuthorized', () async {
      for (final code in ['42501', '28000']) {
        final repo = SupabaseMemberLoansRepository.withInvoker((_, _) async {
          throw PostgrestException(message: 'raw db text', code: code);
        });
        await expectLater(
          repo.getMyLoans(groupId: 'g1', limit: 20, offset: 0),
          throwsA(
            isA<MemberLoansFailure>().having(
              (f) => f.type,
              'type',
              MemberLoansFailureType.notAuthorized,
            ),
          ),
        );
      }
    });

    test('22023 on a loan-scoped RPC maps to notFound', () async {
      final repo = SupabaseMemberLoansRepository.withInvoker((_, _) async {
        throw const PostgrestException(
          message: 'Loan account not found',
          code: '22023',
        );
      });
      await expectLater(
        repo.getMyLoanDetail(groupId: 'g1', loanAccountId: 'x'),
        throwsA(
          isA<MemberLoansFailure>().having(
            (f) => f.type,
            'type',
            MemberLoansFailureType.notFound,
          ),
        ),
      );
    });

    test('a malformed payload maps to unexpected, not network', () async {
      final repo = SupabaseMemberLoansRepository.withInvoker(
        (_, _) async => 'not a map',
      );
      await expectLater(
        repo.getMyLoans(groupId: 'g1', limit: 20, offset: 0),
        throwsA(
          isA<MemberLoansFailure>().having(
            (f) => f.type,
            'type',
            MemberLoansFailureType.unexpected,
          ),
        ),
      );
    });

    test('any other error maps to network', () async {
      final repo = SupabaseMemberLoansRepository.withInvoker((_, _) async {
        throw Exception('socket closed');
      });
      await expectLater(
        repo.getMyLoans(groupId: 'g1', limit: 20, offset: 0),
        throwsA(
          isA<MemberLoansFailure>().having(
            (f) => f.type,
            'type',
            MemberLoansFailureType.network,
          ),
        ),
      );
    });
  });
}
