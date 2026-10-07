import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/member_loans/providers/member_loans_repository_provider.dart';

import 'fakes/fake_member_loans_repository.dart';
import 'fakes/member_loan_json_fixtures.dart';
import 'fakes/member_loans_multi_group.dart';

/// Prompt 09G-B5-C.1 §A: My Loans is scoped to the selected group. These tests
/// drive the real selected-group notifier and the real list/detail/schedule/
/// timeline providers. The SAME loan id exists in both groups with different
/// data, so any stale cache entry would show up as the wrong group's figures.
void main() {
  const shared = 'shared-loan';

  // Group A: two list pages, distinct numbers, dates and receipt.
  FakeMemberLoansRepository groupA() => FakeMemberLoansRepository(
    listPages: {
      0: memberLoansPageJson(
        items: [
          memberLoanListItemJson(
            loanAccountId: shared,
            loanNumber: 'LN-A-001',
            productName: 'Group A Product',
            position: memberLoanPositionJson(
              principal: 5400,
              interest: 0,
              penalty: 50,
              total: 5450,
            ),
          ),
        ],
        hasMore: true,
        limit: 1,
        totalCount: 2,
      ),
      1: memberLoansPageJson(
        items: [
          memberLoanListItemJson(
            loanAccountId: 'a-second',
            loanNumber: 'LN-A-002',
          ),
        ],
        hasMore: false,
        offset: 1,
        limit: 1,
        totalCount: 2,
      ),
    },
    details: {
      shared: memberLoanDetailJson(
        loanAccountId: shared,
        loanNumber: 'LN-A-001',
        position: memberLoanPositionJson(
          principal: 5400,
          interest: 0,
          penalty: 50,
          total: 5450,
        ),
      ),
    },
    schedules: {
      shared: memberLoanScheduleJson(
        loanAccountId: shared,
        current: [
          memberScheduleCurrentRowJson(
            installmentId: 'a-inst',
            dueDate: '2026-04-01',
          ),
        ],
      ),
    },
    timelines: {
      shared: {
        0: memberLoanTimelinePageJson(
          loanAccountId: shared,
          items: [
            memberTimelineEventJson(
              eventId: 'evA',
              effectiveAt: '2026-04-10',
              amount: 1100,
              metadata: {
                'receipt_number': 'A-RCPT',
                'payment_method': 'CASH',
                'reversed_at': null,
              },
            ),
          ],
        ),
      },
    },
  );

  // Group B: one page, different figures, dates and receipt.
  FakeMemberLoansRepository groupB() => FakeMemberLoansRepository(
    listPages: {
      0: memberLoansPageJson(
        items: [
          memberLoanListItemJson(
            loanAccountId: shared,
            loanNumber: 'LN-B-009',
            productName: 'Group B Product',
            position: memberLoanPositionJson(
              principal: 900,
              interest: 0,
              penalty: 0,
              total: 900,
            ),
            overdueAmount: 0,
            nextDueDate: '2026-08-01',
          ),
        ],
        hasMore: false,
      ),
    },
    details: {
      shared: memberLoanDetailJson(
        loanAccountId: shared,
        loanNumber: 'LN-B-009',
        position: memberLoanPositionJson(
          principal: 900,
          interest: 0,
          penalty: 0,
          total: 900,
        ),
        nextDueDate: '2026-08-01',
        firstRepaymentDate: '2026-08-01',
      ),
    },
    schedules: {
      shared: memberLoanScheduleJson(
        loanAccountId: shared,
        current: [
          memberScheduleCurrentRowJson(
            installmentId: 'b-inst',
            dueDate: '2026-08-01',
            memberScheduleStatus: 'UPCOMING',
            currentTotal: 900,
          ),
        ],
      ),
    },
    timelines: {
      shared: {
        0: memberLoanTimelinePageJson(
          loanAccountId: shared,
          items: [
            memberTimelineEventJson(
              eventId: 'evB',
              effectiveAt: '2026-08-05',
              amount: 2200,
              metadata: {
                'receipt_number': 'B-RCPT',
                'payment_method': 'CASH',
                'reversed_at': null,
              },
            ),
          ],
        ),
      },
    },
  );

  Future<ProviderContainer> pumpTwoGroups(WidgetTester tester) {
    return pumpMemberLoansMultiGroup(
      tester,
      repository: GroupScopedMemberLoansRepository({
        'gA': groupA(),
        'gB': groupB(),
      }),
      memberships: [
        memberLoansGroupMembership(
          membershipId: 'm-a',
          groupId: 'gA',
          groupName: 'Group A',
        ),
        memberLoansGroupMembership(
          membershipId: 'm-b',
          groupId: 'gB',
          groupName: 'Group B',
        ),
      ],
    );
  }

  GroupScopedMemberLoansRepository repoOf(ProviderContainer container) =>
      container.read(memberLoansRepositoryProvider)
          as GroupScopedMemberLoansRepository;

  /// The app's real "Change Group" path: return to the pending multi-group
  /// selection (which routes to /select-group), then select the target group.
  void switchGroup(ProviderContainer container, String membershipId) {
    final notifier = container.read(selectedGroupProvider.notifier);
    notifier.requireReselection([
      memberLoansGroupMembership(
        membershipId: 'm-a',
        groupId: 'gA',
        groupName: 'Group A',
      ),
      memberLoansGroupMembership(
        membershipId: 'm-b',
        groupId: 'gB',
        groupName: 'Group B',
      ),
    ]);
    notifier.selectGroup(membershipId);
  }

  testWidgets(
    '1. My Loans list is scoped to the selected group, and switching back is correct',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();

      // 2. Group A data is shown, and page 1 is loaded.
      expect(find.textContaining('LN-A-001'), findsOneWidget);
      expect(find.textContaining('LN-B-009'), findsNothing);
      await tester.tap(find.byKey(const Key('myLoansLoadMoreAction')));
      await tester.pumpAndSettle();
      expect(find.textContaining('LN-A-002'), findsOneWidget);

      // 3. Switching to B drops every A item, including the A-only page 1 item.
      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();
      expect(find.textContaining('LN-B-009'), findsOneWidget);
      expect(find.textContaining('LN-A-001'), findsNothing);
      expect(find.textContaining('LN-A-002'), findsNothing);

      // 7. A's pagination is not reused for B: B has no more pages.
      expect(find.byKey(const Key('myLoansLoadMoreAction')), findsNothing);
      expect(repoOf(container).trace.where((g) => g == 'gB'), isNotEmpty);

      // 8. Back to A: fresh first page, A's own data, and A's page 1 is not reused.
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      expect(find.textContaining('LN-A-001'), findsOneWidget);
      expect(find.textContaining('LN-B-009'), findsNothing);
      expect(find.textContaining('LN-A-002'), findsNothing);
      expect(find.byKey(const Key('myLoansLoadMoreAction')), findsOneWidget);
    },
  );

  testWidgets(
    '4. a Group A loan detail never remains visible as Group B detail after a switch',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myLoanDetailPath(shared));
      await tester.pumpAndSettle();
      expect(find.textContaining('LN-A-001'), findsOneWidget);

      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();
      expect(find.textContaining('LN-B-009'), findsOneWidget);
      expect(find.textContaining('LN-A-001'), findsNothing);
      expect(find.text('Group A Product'), findsNothing);
    },
  );

  testWidgets('5. Group A repayment schedule does not leak into Group B', (
    tester,
  ) async {
    final container = await pumpTwoGroups(tester);
    final router = container.read(routerProvider);
    switchGroup(container, 'm-a');
    await tester.pumpAndSettle();
    router.go(AppRoutes.myLoanDetailPath(shared));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Apr 2026'), findsWidgets);

    switchGroup(container, 'm-b');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Aug 2026'), findsWidgets);
    expect(find.textContaining('1 Apr 2026'), findsNothing);
  });

  testWidgets('6. Group A activity timeline does not leak into Group B', (
    tester,
  ) async {
    final container = await pumpTwoGroups(tester);
    final router = container.read(routerProvider);
    switchGroup(container, 'm-a');
    await tester.pumpAndSettle();
    router.go(AppRoutes.myLoanDetailPath(shared));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myLoanEvent_evA')), findsOneWidget);
    expect(find.text('Receipt A-RCPT'), findsOneWidget);

    switchGroup(container, 'm-b');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myLoanEvent_evB')), findsOneWidget);
    expect(find.text('Receipt B-RCPT'), findsOneWidget);
    expect(find.byKey(const Key('myLoanEvent_evA')), findsNothing);
    expect(find.text('Receipt A-RCPT'), findsNothing);
  });

  testWidgets(
    'the current position shown is the selected group figure, not the previous one',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myLoanDetailPath(shared));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('myLoanPositionCard'));
      expect(
        find.descendant(of: card, matching: find.text('5,450')),
        findsOneWidget,
      );

      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: card, matching: find.text('900')),
        findsWidgets,
      );
      expect(
        find.descendant(of: card, matching: find.text('5,450')),
        findsNothing,
      );
    },
  );

  testWidgets('the Members directory stays separately gated by member.view', (
    tester,
  ) async {
    final container = await pumpTwoGroups(tester);
    final router = container.read(routerProvider);
    switchGroup(container, 'm-a');
    await tester.pumpAndSettle();
    router.go(AppRoutes.membersList);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      isNot(AppRoutes.membersList),
      reason: 'the ordinary member has loan.self_view but no member.view',
    );
  });

  test('the member loan feature never calls officer loan RPCs or tables', () {
    final root = Directory('lib/features/member_loans');
    final sources = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    for (final banned in [
      'rpc_get_loan_',
      'rpc_list_loan',
      'rpc_create_loan',
      'loan_accounts',
      'loan_installments',
      'features/loans/',
      'member.view',
    ]) {
      expect(
        sources.contains(banned),
        isFalse,
        reason: 'member_loans must not reference $banned',
      );
    }
    expect(sources.contains('rpc_get_my_loan'), isTrue);
  });
}
