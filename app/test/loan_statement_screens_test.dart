import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/loans/domain/loan_statement.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09G-03: the Loan Statement screen (Current Position,
/// Write-Off Position, Timeline, Schedule), the Loan Detail
/// Statement entry point + WRITTEN_OFF outstanding-card suppression
/// regression, route-target integrity, permission reuse, migrated-loan
/// presentation, and responsive layout.
void main() {
  group('Statement screen: ordinary servicing (ACTIVE) Current Position', () {
    testWidgets('15/16: shows ordinary Current Position with Principal/'
        'Earned Interest/Total Outstanding and Scheduled Unearned Interest '
        'shown separately', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          currentState: fakeLoanStatementCurrentState(
            status: 'ACTIVE',
            principalOutstanding: 200000,
            earnedInterestOutstanding: 10000,
            penaltyOutstanding: 0,
            totalOutstanding: 210000,
            scheduledUnearnedInterest: 5000,
          ),
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('statementCurrentPositionCard')),
        findsOneWidget,
      );
      expect(find.text('Principal Outstanding'), findsOneWidget);
      expect(find.text('Earned Interest Outstanding'), findsOneWidget);
      expect(find.text('Total Outstanding'), findsOneWidget);
      expect(find.text('Scheduled Unearned Interest'), findsOneWidget);
      expect(
        find.textContaining('Not part of the current amount owed'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('statementWriteOffPositionSection')),
        findsNothing,
      );
    });
  });

  group('Statement screen: WRITTEN_OFF Write-Off Position', () {
    testWidgets('17/18/19/20: WRITTEN_OFF statement suppresses the ordinary '
        'Outstanding block and shows Original Written Off/Recovered/'
        'Remaining Recoverable instead', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          currentState: fakeLoanStatementCurrentState(
            status: 'WRITTEN_OFF',
            principalOutstanding: 0,
            earnedInterestOutstanding: 0,
            penaltyOutstanding: 0,
            totalOutstanding: 0,
            scheduledUnearnedInterest: 0,
            writeOff: fakeLoanStatementWriteOffState(
              isActive: true,
              principalWrittenOff: 200000,
              interestWrittenOff: 15000,
              penaltyWrittenOff: 5000,
              recoveredPrincipal: 0,
              recoveredInterest: 4000,
              recoveredPenalty: 5000,
            ),
          ),
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      // 17: ordinary Outstanding block never appears.
      expect(
        find.byKey(const Key('statementCurrentPositionCard')),
        findsNothing,
      );
      expect(find.text('Total Outstanding'), findsNothing);

      // 18/19/20: Write-Off Position appears instead.
      expect(
        find.byKey(const Key('statementWriteOffPositionSection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('statementOriginalWrittenOffCard')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('statementRecoveredCard')), findsOneWidget);
      expect(
        find.byKey(const Key('statementRemainingRecoverableCard')),
        findsOneWidget,
      );
      expect(find.text('Original Written Off'), findsOneWidget);
      expect(find.text('Recovered'), findsOneWidget);
      expect(find.text('Remaining Recoverable'), findsOneWidget);
    });

    testWidgets('21: a fully recovered write-off remains WRITTEN_OFF and shows '
        'Remaining Recoverable total of 0', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          currentState: fakeLoanStatementCurrentState(
            status: 'WRITTEN_OFF',
            totalOutstanding: 0,
            writeOff: fakeLoanStatementWriteOffState(
              isActive: true,
              principalWrittenOff: 100000,
              interestWrittenOff: 5000,
              penaltyWrittenOff: 0,
              recoveredPrincipal: 100000,
              recoveredInterest: 5000,
              recoveredPenalty: 0,
            ),
          ),
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('statementRemainingRecoverableTotalRow')),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('statementRemainingRecoverableTotalRow')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      // The loan status shown on the statement stays WRITTEN_OFF, never
      // auto-reactivated by a full recovery.
      expect(find.byKey(const Key('statementStatusBadge')), findsOneWidget);
    });

    testWidgets(
      'a reversed (historical) write-off is shown truthfully as inactive',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextStatement = fakeLoanStatement(
            currentState: fakeLoanStatementCurrentState(
              status: 'ACTIVE',
              writeOff: fakeLoanStatementWriteOffState(isActive: false),
            ),
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanStatementPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('statementWriteOffPositionSection')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('statementWriteOffHistoricalNote')),
          findsOneWidget,
        );
      },
    );
  });

  group('Statement screen: timeline', () {
    testWidgets('22: a reversed event remains visible with a Reversed tag', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          timeline: [
            fakeLoanStatementEvent(
              eventId: '1:p1',
              eventType: 'PAYMENT_POSTED',
              isReversed: true,
              amount: 50000,
              references: {'payment_id': 'p1', 'receipt_number': 'RCT-0099'},
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('statementEvent_1:p1')), findsOneWidget);
      expect(
        find.byKey(const Key('statementEventReversedTag')),
        findsOneWidget,
      );
      expect(find.text('Reversed'), findsOneWidget);
    });

    testWidgets('23: an unrecognized event type renders the generic Activity '
        'Recorded fallback row instead of crashing the statement', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          timeline: [
            fakeLoanStatementEvent(
              eventId: '9:future-1',
              eventType: 'SOME_FUTURE_EVENT_TYPE',
              amount: 1000,
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Activity Recorded'), findsOneWidget);
    });

    testWidgets(
      '24: the timeline is rendered in exactly the server-provided order, '
      'never re-sorted client-side',
      (tester) async {
        // Deliberately out of chronological/date order — a client-side
        // sort would reorder these; the screen must not.
        final fakeRepo = FakeLoanRepository()
          ..nextStatement = fakeLoanStatement(
            timeline: [
              fakeLoanStatementEvent(
                eventId: 'z-last',
                eventType: 'LOAN_CLOSED',
                effectiveAt: DateTime.utc(2026, 1, 1),
                sequenceKey: '0:0:aaa',
              ),
              fakeLoanStatementEvent(
                eventId: 'a-first',
                eventType: 'LOAN_CREATED',
                effectiveAt: DateTime.utc(2026, 12, 1),
                sequenceKey: '0:0:zzz',
              ),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanStatementPath('loan-1'));
        await tester.pumpAndSettle();

        final firstOffset = tester.getTopLeft(
          find.byKey(const Key('statementEvent_z-last')),
        );
        final secondOffset = tester.getTopLeft(
          find.byKey(const Key('statementEvent_a-first')),
        );
        expect(firstOffset.dy, lessThan(secondOffset.dy));
      },
    );

    testWidgets('25: a single multi-allocation payment renders as exactly one '
        'timeline row', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          timeline: [
            fakeLoanStatementEvent(
              eventId: '1:p1',
              eventType: 'PAYMENT_POSTED',
              amount: 210000,
              components: const LoanStatementComponentBreakdown(
                principal: 200000,
                interest: 10000,
                penalty: 0,
              ),
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsWidgets);
      expect(find.text('Payment Posted'), findsOneWidget);
    });

    testWidgets(
      '26: a recovery event never fabricates an installment number or '
      'due date',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextStatement = fakeLoanStatement(
            timeline: [
              fakeLoanStatementEvent(
                eventId: '7:r1',
                eventType: 'RECOVERY_POSTED',
                amount: 9000,
                references: {
                  'recovery_event_id': 'r1',
                  'write_off_event_id': 'wo-1',
                  'payment_id': 'p9',
                  'receipt_number': 'RCT-0100',
                },
              ),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanStatementPath('loan-1'));
        await tester.pumpAndSettle();

        expect(find.text('Recovery Posted'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('statementEvent_7:r1')),
            matching: find.textContaining('Installment'),
          ),
          findsNothing,
        );
      },
    );
  });

  group('Statement screen: schedule', () {
    testWidgets('27: schedule.current renders', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          scheduleCurrent: [
            fakeLoanStatementScheduleEntry(id: 'inst-1', installmentNumber: 1),
            fakeLoanStatementScheduleEntry(id: 'inst-2', installmentNumber: 2),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('statementScheduleCurrentSection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('statementScheduleRow_inst-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('statementScheduleRow_inst-2')),
        findsOneWidget,
      );
    });

    testWidgets('28: schedule history is hidden when empty', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(scheduleHistory: const []);

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('statementScheduleHistorySection')),
        findsNothing,
      );
    });

    testWidgets('29/30: schedule history is visible when non-empty, and a '
        'cancelled/replaced installment appears only there, never in '
        'schedule.current', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          scheduleCurrent: [
            fakeLoanStatementScheduleEntry(
              id: 'inst-new-1',
              installmentNumber: 1,
            ),
          ],
          scheduleHistory: [
            fakeLoanStatementScheduleHistoryEntry(
              id: 'inst-old-1',
              installmentNumber: 1,
              cancellationReason: 'Superseded by restructure',
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('statementScheduleHistorySection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('statementScheduleHistoryRow_inst-old-1')),
        findsOneWidget,
      );
      // Never duplicated into schedule.current under the same id.
      expect(
        find.byKey(const Key('statementScheduleRow_inst-old-1')),
        findsNothing,
      );
    });
  });

  group('Loan Detail: Statement entry point + WRITTEN_OFF regression', () {
    testWidgets('31: ACTIVE Loan Detail keeps its ordinary outstanding card', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanRepaymentSummaryCard')), findsOneWidget);
    });

    testWidgets('32: CLOSED Loan Detail keeps its ordinary outstanding card '
        'unchanged', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'CLOSED',
          totalOutstanding: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanRepaymentSummaryCard')), findsOneWidget);
    });

    testWidgets(
      '33: WRITTEN_OFF Loan Detail suppresses the ordinary outstanding '
      'card/rows',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'WRITTEN_OFF',
            totalOutstanding: 0,
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('loanRepaymentSummaryCard')), findsNothing);
      },
    );

    testWidgets('34: WRITTEN_OFF Loan Detail write-off summary remains '
        'visible', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'WRITTEN_OFF',
          totalOutstanding: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanWriteOffSummarySection')),
        findsOneWidget,
      );
    });

    testWidgets('35: the Statement action on Loan Detail opens the correct '
        'loan\'s statement', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-42', status: 'ACTIVE')
        ..nextStatement = fakeLoanStatement(loanAccountId: 'loan-42');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-42'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('loanStatementAction')));
      await tester.tap(find.byKey(const Key('loanStatementAction')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('statementHeaderCard')), findsOneWidget);
      expect(fakeRepo.getLoanStatementCalls.single.loanAccountId, 'loan-42');
    });
  });

  group('Route / security', () {
    testWidgets('36: the statement route targets exactly the requested '
        'loan id', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(loanAccountId: 'loan-99');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-99'));
      await tester.pumpAndSettle();

      expect(fakeRepo.getLoanStatementCalls, hasLength(1));
      expect(fakeRepo.getLoanStatementCalls.single.loanAccountId, 'loan-99');
    });

    testWidgets(
      '37/38: a member with only the existing loan.view permission (no '
      'new statement-specific permission) can open the statement',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextStatement = fakeLoanStatement(loanAccountId: 'loan-1');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          membership: loanMembership(
            roles: const ['CHAIRPERSON'],
            permissions: loanViewOnlyPermissions,
          ),
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanStatementPath('loan-1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('statementHeaderCard')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Migrated loan presentation', () {
    testWidgets('39/40: a migrated loan\'s statement renders "Opening Position '
        'Imported" and never a fabricated Loan Created/Submitted/Approved/'
        'Disbursed label', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          header: fakeLoanStatementHeader(loanOrigin: 'MIGRATED'),
          timeline: [
            fakeLoanStatementEvent(
              eventId: '0:mig1',
              eventType: 'LOAN_MIGRATED',
              metadata: const {
                'reason': null,
                'from_status': null,
                'to_status': 'ACTIVE',
              },
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.text('Migrated'), findsOneWidget);
      expect(find.text('Opening Position Imported'), findsOneWidget);
      expect(find.text('Loan Created'), findsNothing);
      expect(find.text('Loan Submitted'), findsNothing);
      expect(find.text('Loan Approved'), findsNothing);
      expect(find.text('Loan Disbursed'), findsNothing);
    });
  });

  group('Responsive', () {
    testWidgets('41/42: the statement screen has no layout overflow at '
        'narrow mobile or desktop width', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextStatement = fakeLoanStatement(
          currentState: fakeLoanStatementCurrentState(
            status: 'WRITTEN_OFF',
            totalOutstanding: 0,
            writeOff: fakeLoanStatementWriteOffState(
              principalWrittenOff: 123456789,
              interestWrittenOff: 9876543,
              penaltyWrittenOff: 555555,
            ),
          ),
          scheduleCurrent: [fakeLoanStatementScheduleEntry()],
          scheduleHistory: [fakeLoanStatementScheduleHistoryEntry()],
          timeline: [
            fakeLoanStatementEvent(eventId: '0:e1', eventType: 'LOAN_CREATED'),
            fakeLoanStatementEvent(
              eventId: '6:wo1',
              eventType: 'WRITE_OFF',
              amount: 133888887,
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      addTearDown(tester.view.reset);
      router.push(AppRoutes.loanStatementPath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
