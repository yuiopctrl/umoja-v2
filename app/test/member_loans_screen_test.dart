import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/member_loans/data/member_loans_failure.dart';

import 'fakes/fake_member_loans_repository.dart';
import 'fakes/member_loan_json_fixtures.dart';
import 'fakes/member_loans_test_app.dart';

void main() {
  group(
    'navigation and permission gating (UX only; the RPC is authoritative)',
    () {
      testWidgets('My Loans appears in More with loan.self_view', (
        tester,
      ) async {
        final router = await pumpMemberLoansApp(
          tester,
          repository: FakeMemberLoansRepository(),
        );
        router.go(AppRoutes.more);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreMyLoansAction')), findsOneWidget);
      });

      testWidgets('My Loans is hidden without loan.self_view', (tester) async {
        final router = await pumpMemberLoansApp(
          tester,
          repository: FakeMemberLoansRepository(),
          membership: memberLoansMembership(permissions: const ['group.view']),
        );
        router.go(AppRoutes.more);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreMyLoansAction')), findsNothing);
      });

      testWidgets('an ordinary member reaches My Loans without member.view', (
        tester,
      ) async {
        final repo = FakeMemberLoansRepository();
        final router = await pumpMemberLoansApp(tester, repository: repo);
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          AppRoutes.myLoans,
        );
        expect(find.byKey(const Key('myLoansList')), findsOneWidget);
        expect(
          memberLoansMembership().hasPermission('member.view'),
          isFalse,
          reason: 'the ordinary MEMBER baseline must not carry member.view',
        );
      });

      testWidgets('My Loans route is blocked without loan.self_view', (
        tester,
      ) async {
        final repo = FakeMemberLoansRepository();
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          membership: memberLoansMembership(permissions: const ['group.view']),
        );
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          isNot(AppRoutes.myLoans),
        );
        expect(repo.calls, isEmpty);
      });

      testWidgets('detail route is blocked without loan.self_view', (
        tester,
      ) async {
        final repo = FakeMemberLoansRepository();
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          membership: memberLoansMembership(permissions: const ['group.view']),
        );
        router.go(AppRoutes.myLoanDetailPath('loan-701'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          isNot(startsWith(AppRoutes.myLoans)),
        );
        expect(repo.calls, isEmpty);
      });
    },
  );

  group('My Loans list', () {
    testWidgets('loads and shows one card per loan with the current total', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(),
              memberLoanListItemJson(
                loanAccountId: 'loan-702',
                loanNumber: 'LN-B5B-702',
                productName: 'Emergency Loan',
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myLoanCard_loan-701')), findsOneWidget);
      expect(find.byKey(const Key('myLoanCard_loan-702')), findsOneWidget);
      expect(find.text('5,450'), findsWidgets);
      expect(repo.lastGroupId, 'g1');
    });

    testWidgets('an ACTIVE loan shows the overdue amount and next due date', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository();
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoanOverdue_loan-701')), findsOneWidget);
      expect(find.textContaining('Overdue: 3,050'), findsOneWidget);
      expect(find.textContaining('Next due: 1 Apr 2026'), findsOneWidget);
    });

    testWidgets('an empty list shows the localized empty state, not an error', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {0: memberLoansPageJson(items: const [])},
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoansEmpty')), findsOneWidget);
      expect(find.text("You don't have any loans yet."), findsOneWidget);
    });

    testWidgets('a failed list shows a safe message and retry recovers', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository()
        ..nextListError = const MemberLoansFailure(
          MemberLoansFailureType.network,
        );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(
        find.text('Network error. Check your connection and try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoanCard_loan-701')), findsOneWidget);
    });

    testWidgets('a foreign or missing loan message never reveals existence', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository()
        ..nextListError = const MemberLoansFailure(
          MemberLoansFailureType.notAuthorized,
        );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.textContaining('access to your loans'), findsOneWidget);
    });

    testWidgets(
      'load more appends the next page once and never duplicates items',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          listPages: {
            0: memberLoansPageJson(
              items: [memberLoanListItemJson()],
              hasMore: true,
              limit: 1,
              totalCount: 2,
            ),
            1: memberLoansPageJson(
              items: [
                memberLoanListItemJson(
                  loanAccountId: 'loan-702',
                  loanNumber: 'LN-B5B-702',
                ),
              ],
              hasMore: false,
              offset: 1,
              limit: 1,
              totalCount: 2,
            ),
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('myLoansLoadMoreAction')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('myLoanCard_loan-701')), findsOneWidget);
        expect(find.byKey(const Key('myLoanCard_loan-702')), findsOneWidget);
        expect(find.byKey(const Key('myLoansLoadMoreAction')), findsNothing);
        expect(repo.calls.where((c) => c == 'list:1'), hasLength(1));
      },
    );
  });

  group('status and zero-position presentation (backend values only)', () {
    testWidgets('a CLOSED loan with a zero total shows zero, not a debt', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(
                loanAccountId: 'loan-707',
                loanNumber: 'LN-B5B-707',
                memberStatus: 'CLOSED',
                position: memberLoanPositionJson(
                  principal: 0,
                  interest: 0,
                  penalty: 0,
                  total: 0,
                ),
                nextDueDate: null,
                overdueAmount: 0,
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.byKey(const Key('myLoanOverdue_loan-707')), findsNothing);
    });

    testWidgets('a WRITTEN_OFF loan shows zero and no active overdue', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(
                loanAccountId: 'loan-702',
                loanNumber: 'LN-B5B-702',
                memberStatus: 'WRITTEN_OFF',
                position: memberLoanPositionJson(
                  principal: 0,
                  interest: 0,
                  penalty: 0,
                  total: 0,
                ),
                overdueAmount: 0,
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.text('Written off'), findsWidgets);
      expect(find.byKey(const Key('myLoanOverdue_loan-702')), findsNothing);
    });

    testWidgets('a never-disbursed REJECTED loan shows a zero receivable', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(
                loanAccountId: 'loan-704',
                loanNumber: 'LN-B5B-704',
                memberStatus: 'REJECTED',
                position: memberLoanPositionJson(
                  principal: 0,
                  interest: 0,
                  penalty: 0,
                  total: 0,
                ),
                nextDueDate: null,
                overdueAmount: 0,
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets(
      'an unknown future status renders a fallback label and does not crash',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          listPages: {
            0: memberLoansPageJson(
              items: [memberLoanListItemJson(memberStatus: 'FUTURE_STATE')],
            ),
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(find.text('Status unavailable'), findsOneWidget);
        expect(find.byKey(const Key('myLoanCard_loan-701')), findsOneWidget);
      },
    );

    testWidgets(
      'an opening-position loan is labelled Opening Position and never MIGRATED',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          listPages: {
            0: memberLoansPageJson(
              items: [
                memberLoanListItemJson(
                  loanAccountId: 'loan-708',
                  loanNumber: 'LN-B5B-708',
                  originContext: 'OPENING_POSITION',
                ),
              ],
            ),
          },
          details: {
            'loan-708': memberLoanDetailJson(
              loanAccountId: 'loan-708',
              loanNumber: 'LN-B5B-708',
              originContext: 'OPENING_POSITION',
              openingAsOfDate: '2026-01-01',
              originalDisbursementDate: '2025-06-01',
            ),
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('myLoanOpeningBadge_loan-708')),
          findsOneWidget,
        );
        expect(find.text('MIGRATED'), findsNothing);

        router.go(AppRoutes.myLoanDetailPath('loan-708'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('myLoanDetailOpeningBadge')),
          findsOneWidget,
        );
        expect(find.textContaining('MIGRATED'), findsNothing);
        expect(find.textContaining('Umoja'), findsWidgets);
      },
    );

    testWidgets('a CANCELLED loan shows zero and no receivable', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(
                loanAccountId: 'loan-703',
                loanNumber: 'LN-B5B-703',
                memberStatus: 'CANCELLED',
                position: memberLoanPositionJson(
                  principal: 0,
                  interest: 0,
                  penalty: 0,
                  total: 0,
                ),
                nextDueDate: null,
                overdueAmount: 0,
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byKey(const Key('myLoanOverdue_loan-703')), findsNothing);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('a NEW loan shows no opening-position label', (tester) async {
      final repo = FakeMemberLoansRepository();
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('myLoanOpeningBadge_loan-701')),
        findsNothing,
      );
    });
  });

  group('loan detail', () {
    testWidgets('opening a card navigates to that loan detail', (tester) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {'loan-701': memberLoanScheduleJson()},
        timelines: {
          'loan-701': {0: memberLoanTimelinePageJson()},
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('myLoanCard_loan-701')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoanDetailNumber')), findsOneWidget);
    });

    testWidgets(
      'detail shows the backend current position, not a recalculated figure',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {'loan-701': memberLoanDetailJson()},
          schedules: {'loan-701': memberLoanScheduleJson()},
          timelines: {
            'loan-701': {0: memberLoanTimelinePageJson()},
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-701'));
        await tester.pumpAndSettle();
        final position = find.byKey(const Key('myLoanPositionCard'));
        expect(position, findsOneWidget);
        expect(
          find.descendant(of: position, matching: find.text('5,400')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: position, matching: find.text('5,450')),
          findsOneWidget,
        );
        expect(
          find.text('Future installment interest is not included.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a null backend amount displays as Not available, never zero', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {
          'loan-701': memberLoanDetailJson(
            position: memberLoanPositionJson(
              principal: null,
              interest: null,
              penalty: null,
              total: null,
            ),
          ),
        },
        schedules: {'loan-701': memberLoanScheduleJson()},
        timelines: {
          'loan-701': {0: memberLoanTimelinePageJson()},
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      final position = find.byKey(const Key('myLoanPositionCard'));
      expect(
        find.descendant(of: position, matching: find.text('Not available')),
        findsWidgets,
      );
    });

    testWidgets(
      'a failed detail offers retry and never shows raw database text',
      (tester) async {
        final repo =
            FakeMemberLoansRepository(
                details: {'loan-701': memberLoanDetailJson()},
                schedules: {'loan-701': memberLoanScheduleJson()},
                timelines: {
                  'loan-701': {0: memberLoanTimelinePageJson()},
                },
              )
              ..nextDetailError = const MemberLoansFailure(
                MemberLoansFailureType.unexpected,
              );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-701'));
        await tester.pumpAndSettle();
        expect(find.text("We couldn't load your loans."), findsOneWidget);
        expect(find.textContaining('PGRST'), findsNothing);
        await tester.tap(find.text('Retry').first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('myLoanDetailNumber')), findsOneWidget);
      },
    );

    testWidgets('a timeline failure does not blank the loaded detail', (
      tester,
    ) async {
      final repo =
          FakeMemberLoansRepository(
              details: {'loan-701': memberLoanDetailJson()},
              schedules: {'loan-701': memberLoanScheduleJson()},
            )
            ..nextTimelineError = const MemberLoansFailure(
              MemberLoansFailureType.network,
            );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoanDetailNumber')), findsOneWidget);
      expect(find.byKey(const Key('myLoanPositionCard')), findsOneWidget);
    });
  });

  group('repayment schedule', () {
    testWidgets('each member schedule status is shown with its own label', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {
          'loan-701': memberLoanScheduleJson(
            current: [
              memberScheduleCurrentRowJson(
                installmentId: 'a',
                installmentNumber: 1,
                memberScheduleStatus: 'OVERDUE',
              ),
              memberScheduleCurrentRowJson(
                installmentId: 'b',
                installmentNumber: 2,
                memberScheduleStatus: 'SETTLED',
                currentTotal: 0,
              ),
              memberScheduleCurrentRowJson(
                installmentId: 'c',
                installmentNumber: 3,
                memberScheduleStatus: 'PARTIALLY_SETTLED',
              ),
              memberScheduleCurrentRowJson(
                installmentId: 'd',
                installmentNumber: 4,
                memberScheduleStatus: 'DUE',
              ),
              memberScheduleCurrentRowJson(
                installmentId: 'e',
                installmentNumber: 5,
                memberScheduleStatus: 'UPCOMING',
              ),
            ],
          ),
        },
        timelines: {
          'loan-701': {0: memberLoanTimelinePageJson()},
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Settled'), findsWidgets);
      expect(find.text('Partly settled'), findsWidgets);
      expect(find.text('Due today'), findsWidgets);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Paid'), findsNothing);
    });

    testWidgets('history is a separate group and never merged into current', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {
          'loan-701': memberLoanScheduleJson(
            current: [
              memberScheduleCurrentRowJson(
                memberScheduleStatus: 'UPCOMING',
                currentTotal: 2400,
              ),
            ],
            history: [
              memberScheduleHistoryRowJson(
                status: 'REPLACED',
                replacementReason: 'RESTRUCTURE',
              ),
            ],
          ),
        },
        timelines: {
          'loan-701': {0: memberLoanTimelinePageJson()},
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('myLoanScheduleHistoryTitle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('myLoanHistoryRow_inst-h1')), findsOneWidget);
      expect(find.text('Replaced by a loan restructure'), findsOneWidget);
      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets('scheduled future interest is labelled as not owed yet', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {
          'loan-701': memberLoanScheduleJson(
            current: [
              memberScheduleCurrentRowJson(
                memberScheduleStatus: 'UPCOMING',
                currentTotal: 2400,
                futureInterest: 60,
              ),
            ],
          ),
        },
        timelines: {
          'loan-701': {0: memberLoanTimelinePageJson()},
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(
        find.text('Scheduled future interest (not owed yet)'),
        findsNothing,
        reason: 'the detail row is inside a collapsed tile until expanded',
      );
      // Prompt 09G-B5-C.3 §E: the Current Position note appears exactly
      // once, near Current Position — never again below the schedule.
      expect(
        find.text('Future installment interest is not included.'),
        findsOneWidget,
      );
      // Prompt 09G-B5-C.3 §D: "Repayment Schedule" is the one heading;
      // there is no second, immediately-repeated "Current Schedule" title.
      expect(find.text('Current Schedule'), findsNothing);
      await tester.ensureVisible(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(
        find.text('Scheduled future interest (not owed yet)'),
        findsOneWidget,
      );
      // Still exactly once after expanding the row.
      expect(
        find.text('Future installment interest is not included.'),
        findsOneWidget,
      );
    });
  });

  group('activity timeline', () {
    testWidgets('a payment is shown once with its breakdown and receipt', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {'loan-701': memberLoanScheduleJson()},
        timelines: {
          'loan-701': {
            0: memberLoanTimelinePageJson(
              items: [memberTimelineEventJson(eventId: 'pay-1', amount: 1100)],
            ),
          },
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoanEvent_pay-1')), findsOneWidget);
      expect(find.text('Payment received'), findsOneWidget);
      // Prompt 09G-B5-C.3 §B: the title already says "Payment received",
      // so the redundant "Money in" copy is gone.
      expect(find.text('Money in'), findsNothing);
      expect(find.text('Receipt B5B-RCPT-001'), findsOneWidget);
      expect(find.text('Breakdown'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('Interest'), findsOneWidget);
    });

    testWidgets('WALLET_APPLIED is non-cash and never labelled as a payment', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-712': memberLoanDetailJson(loanAccountId: 'loan-712')},
        schedules: {
          'loan-712': memberLoanScheduleJson(loanAccountId: 'loan-712'),
        },
        timelines: {
          'loan-712': {
            0: memberLoanTimelinePageJson(
              loanAccountId: 'loan-712',
              items: [
                memberTimelineEventJson(
                  eventId: 'wal-1',
                  eventType: 'WALLET_APPLIED',
                  amount: 100,
                  isCash: false,
                  cashDirection: null,
                  componentBreakdown: {'principal': 100},
                  metadata: {},
                ),
              ],
            ),
          },
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-712'));
      await tester.pumpAndSettle();
      expect(find.text('Wallet Applied'), findsOneWidget);
      expect(find.text('Not a cash movement'), findsOneWidget);
      expect(find.text('Payment received'), findsNothing);
      expect(find.text('Money in'), findsNothing);
    });

    testWidgets('a reversed payment stays visible and is marked Reversed', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {'loan-701': memberLoanScheduleJson()},
        timelines: {
          'loan-701': {
            0: memberLoanTimelinePageJson(
              items: [
                memberTimelineEventJson(
                  eventId: 'rev-1',
                  amount: 200,
                  isReversed: true,
                ),
              ],
            ),
          },
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('myLoanEvent_rev-1')), findsOneWidget);
      expect(find.byKey(const Key('myLoanReversed_rev-1')), findsOneWidget);
    });

    testWidgets(
      'a prepayment and its payment are distinct, and the treatment is localized',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {
            'loan-714': memberLoanDetailJson(loanAccountId: 'loan-714'),
          },
          schedules: {
            'loan-714': memberLoanScheduleJson(loanAccountId: 'loan-714'),
          },
          timelines: {
            'loan-714': {
              0: memberLoanTimelinePageJson(
                loanAccountId: 'loan-714',
                items: [
                  memberTimelineEventJson(eventId: 'pay-p', amount: 1500),
                  memberTimelineEventJson(
                    eventId: 'prep-p',
                    eventType: 'PRINCIPAL_PREPAYMENT',
                    eventSubtype: 'REDUCE_INSTALLMENT',
                    amount: null,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {},
                    metadata: {
                      'treatment': 'REDUCE_INSTALLMENT',
                      'principal_reduction_amount': 1500,
                    },
                  ),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-714'));
        await tester.pumpAndSettle();
        expect(find.text('Payment received'), findsOneWidget);
        expect(find.text('Principal prepayment'), findsOneWidget);
        expect(find.text('Lower installments'), findsOneWidget);
      },
    );

    testWidgets(
      'restructure, write-off and recovery are presented with the right cash meaning',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {
            'loan-710': memberLoanDetailJson(loanAccountId: 'loan-710'),
          },
          schedules: {
            'loan-710': memberLoanScheduleJson(loanAccountId: 'loan-710'),
          },
          timelines: {
            'loan-710': {
              0: memberLoanTimelinePageJson(
                loanAccountId: 'loan-710',
                items: [
                  memberTimelineEventJson(
                    eventId: 'rec-1',
                    eventType: 'RECOVERY_POSTED',
                    amount: 300,
                    isCash: true,
                    cashDirection: 'IN',
                    componentBreakdown: {'principal': 300},
                  ),
                  memberTimelineEventJson(
                    eventId: 'wo-1',
                    eventType: 'WRITE_OFF',
                    amount: 2020,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {'principal': 2000, 'interest': 20},
                    metadata: {'reason_code': 'GROUP_DECISION'},
                  ),
                  memberTimelineEventJson(
                    eventId: 'rst-1',
                    eventType: 'LOAN_RESTRUCTURED',
                    amount: null,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {},
                    metadata: {'new_term': 6},
                  ),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-710'));
        await tester.pumpAndSettle();
        expect(find.text('Recovery payment'), findsOneWidget);
        expect(find.text('Loan written off'), findsOneWidget);
        expect(find.text('Loan restructured'), findsOneWidget);
        expect(
          find.text('Payment received'),
          findsNothing,
          reason: 'a recovery is never shown as an ordinary payment',
        );
      },
    );

    testWidgets(
      'the opening position activity shows its snapshot and a note, not a payment',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {
            'loan-708': memberLoanDetailJson(
              loanAccountId: 'loan-708',
              originContext: 'OPENING_POSITION',
              openingAsOfDate: '2026-01-01',
            ),
          },
          schedules: {
            'loan-708': memberLoanScheduleJson(loanAccountId: 'loan-708'),
          },
          timelines: {
            'loan-708': {
              0: memberLoanTimelinePageJson(
                loanAccountId: 'loan-708',
                items: [
                  memberTimelineEventJson(
                    eventId: 'open-1',
                    eventType: 'OPENING_POSITION',
                    effectiveAt: '2026-01-01',
                    amount: 9140,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {
                      'principal': 9000,
                      'interest': 100,
                      'penalty': 40,
                    },
                    metadata: {'original_disbursement_date': '2025-06-01'},
                  ),
                  memberTimelineEventJson(
                    eventId: 'pen-1',
                    eventType: 'PENALTY_ASSESSED',
                    effectiveAt: '2025-12-15',
                    amount: 25,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {'penalty': 25},
                    metadata: {'installment_number': 2},
                  ),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-708'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('myLoanEvent_open-1')), findsOneWidget);
        expect(find.byKey(const Key('myLoanEvent_pen-1')), findsOneWidget);
        expect(find.textContaining('not a new payment'), findsOneWidget);
        expect(find.text('Payment received'), findsNothing);
        expect(find.text('Loan disbursed'), findsNothing);
      },
    );

    testWidgets(
      'an unknown event type renders a generic label without crashing',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {'loan-701': memberLoanDetailJson()},
          schedules: {'loan-701': memberLoanScheduleJson()},
          timelines: {
            'loan-701': {
              0: memberLoanTimelinePageJson(
                items: [
                  memberTimelineEventJson(
                    eventId: 'unk-1',
                    eventType: 'FUTURE_EVENT',
                    amount: null,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {},
                    metadata: {},
                  ),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-701'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('myLoanEvent_unk-1')), findsOneWidget);
        expect(find.text('Activity'), findsWidgets);
      },
    );

    testWidgets(
      'early settlement is a non-cash semantic event beside its single payment',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {
            'loan-713': memberLoanDetailJson(
              loanAccountId: 'loan-713',
              memberStatus: 'CLOSED',
            ),
          },
          schedules: {
            'loan-713': memberLoanScheduleJson(
              loanAccountId: 'loan-713',
              memberStatus: 'CLOSED',
            ),
          },
          timelines: {
            'loan-713': {
              0: memberLoanTimelinePageJson(
                loanAccountId: 'loan-713',
                items: [
                  memberTimelineEventJson(eventId: 'clear-1', amount: 500),
                  memberTimelineEventJson(
                    eventId: 'settle-1',
                    eventType: 'LOAN_EARLY_SETTLED',
                    amount: null,
                    isCash: false,
                    cashDirection: null,
                    componentBreakdown: {},
                    metadata: {},
                  ),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-713'));
        await tester.pumpAndSettle();
        expect(find.text('Payment received'), findsOneWidget);
        expect(find.text('Loan settled early'), findsOneWidget);
        expect(find.byKey(const Key('myLoanEvent_clear-1')), findsOneWidget);
        expect(find.byKey(const Key('myLoanEvent_settle-1')), findsOneWidget);
        expect(
          find.text('Not a cash movement'),
          findsOneWidget,
          reason: 'only the settlement semantic event is non-cash; the payment is cash',
        );
      },
    );

    testWidgets(
      'timeline events are shown in the order the backend returned them',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {'loan-701': memberLoanDetailJson()},
          schedules: {'loan-701': memberLoanScheduleJson()},
          timelines: {
            'loan-701': {
              0: memberLoanTimelinePageJson(
                items: [
                  memberTimelineEventJson(
                    eventId: 'newest',
                    effectiveAt: '2026-07-01',
                    amount: 1500,
                  ),
                  memberTimelineEventJson(
                    eventId: 'middle',
                    effectiveAt: '2026-05-10',
                    amount: 3080,
                  ),
                  memberTimelineEventJson(
                    eventId: 'oldest',
                    effectiveAt: '2026-04-10',
                    amount: 1100,
                  ),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-701'));
        await tester.pumpAndSettle();
        final newest = tester.getTopLeft(
          find.byKey(const Key('myLoanEvent_newest')),
        );
        final middle = tester.getTopLeft(
          find.byKey(const Key('myLoanEvent_middle')),
        );
        final oldest = tester.getTopLeft(
          find.byKey(const Key('myLoanEvent_oldest')),
        );
        expect(newest.dy < middle.dy && middle.dy < oldest.dy, isTrue);
      },
    );

    testWidgets('an empty timeline shows a localized empty note', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        details: {'loan-701': memberLoanDetailJson()},
        schedules: {'loan-701': memberLoanScheduleJson()},
        timelines: {
          'loan-701': {0: memberLoanTimelinePageJson(items: const [])},
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoanDetailPath('loan-701'));
      await tester.pumpAndSettle();
      expect(find.text('No activity yet.'), findsOneWidget);
    });
  });

  group('Swahili and layout', () {
    testWidgets('Swahili shows Mikopo Yangu and the Opening Position wording', (
      tester,
    ) async {
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(
                loanAccountId: 'loan-708',
                loanNumber: 'LN-B5B-708',
                originContext: 'OPENING_POSITION',
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.swahili,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(find.text('Mikopo Yangu'), findsOneWidget);
      expect(find.text('Salio la Mwanzo'), findsOneWidget);
      expect(find.text('Opening Position'), findsNothing);
    });

    testWidgets(
      'Swahili payment card: concise hierarchy, no implementation-style sentence',
      (tester) async {
        final repo = FakeMemberLoansRepository(
          details: {'loan-701': memberLoanDetailJson()},
          schedules: {'loan-701': memberLoanScheduleJson()},
          timelines: {
            'loan-701': {
              0: memberLoanTimelinePageJson(
                items: [
                  memberTimelineEventJson(eventId: 'pay-sw', amount: 437500),
                ],
              ),
            },
          },
        );
        final router = await pumpMemberLoansApp(
          tester,
          repository: repo,
          language: AppLanguage.swahili,
        );
        router.go(AppRoutes.myLoanDetailPath('loan-701'));
        await tester.pumpAndSettle();
        expect(find.text('Malipo yamepokelewa'), findsOneWidget);
        expect(find.text('Mgawanyo'), findsOneWidget);
        expect(find.text('Mtaji'), findsOneWidget);
        expect(find.text('Riba'), findsOneWidget);
        expect(
          find.text(
            'Malipo moja, yanaonyeshwa mara moja. Mgawanyo wake uko hapa chini.',
          ),
          findsNothing,
        );
        expect(find.text('Fedha imeingia'), findsNothing);
      },
    );

    testWidgets('large TSH-scale values do not overflow on a 320px phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = FakeMemberLoansRepository(
        listPages: {
          0: memberLoansPageJson(
            items: [
              memberLoanListItemJson(
                productName: 'A Very Long Product Name For Group Savings And Emergency Lending',
                position: memberLoanPositionJson(
                  principal: 987654321.5,
                  interest: 12345678,
                  penalty: 9999999,
                  total: 999999999.5,
                ),
                overdueAmount: 123456789,
              ),
            ],
          ),
        },
      );
      final router = await pumpMemberLoansApp(
        tester,
        repository: repo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
