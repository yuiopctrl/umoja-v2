import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/loans/domain/loan_installment.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09F-A-12: Loan Detail must not offer Waive/Correct on
/// LOAN_INTEREST for a future/not-yet-due installment — the backend
/// always correctly rejected this (09F-A-11 Blocker-03 proved there was
/// no accounting defect), but the UI invited a tap the server was
/// guaranteed to reject, which is exactly what caused the physical
/// tester's target confusion. The gate mirrors the server's own
/// `due_date <= effective_date` rule using the same `dueDate` field
/// already on [LoanInstallment], compared against the device clock for
/// UX purposes only (documented limitation — the server independently
/// re-evaluates its own date on every call regardless of what the UI
/// decides to show).
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final futureDueDate = today.add(const Duration(days: 30));
  final pastDueDate = today.subtract(const Duration(days: 15));

  group('Future-interest action visibility', () {
    testWidgets('1/2: a future installment with positive interest hides '
        'both Waive and Correct', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          installments: [
            LoanInstallment(
              id: 'installment-future',
              installmentNumber: 4,
              dueDate: futureDueDate,
              principalDue: 800000,
              interestDue: 90000,
              totalDue: 890000,
              interestOutstanding: 90000,
              status: 'UPCOMING',
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanWaiveInterestAction_installment-future')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('loanCorrectInterestAction_installment-future')),
        findsNothing,
      );
    });

    testWidgets('3: a due-today installment with positive interest shows both '
        'Waive and Correct for ADMIN', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          installments: [
            LoanInstallment(
              id: 'installment-due-today',
              installmentNumber: 3,
              dueDate: today,
              principalDue: 800000,
              interestDue: 80000,
              totalDue: 880000,
              interestOutstanding: 80000,
              status: 'DUE',
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanWaiveInterestAction_installment-due-today')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('loanCorrectInterestAction_installment-due-today'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '4: a past-due installment with positive interest shows both Waive '
      'and Correct for ADMIN',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            installments: [
              LoanInstallment(
                id: 'installment-past',
                installmentNumber: 1,
                dueDate: pastDueDate,
                principalDue: 800000,
                interestDue: 70000,
                totalDue: 870000,
                interestOutstanding: 70000,
                status: 'OVERDUE',
              ),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanWaiveInterestAction_installment-past')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanCorrectInterestAction_installment-past')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '5: a due/past installment with zero effective interest shows no '
      'interest adjustment actions',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            installments: [
              LoanInstallment(
                id: 'installment-paid',
                installmentNumber: 1,
                dueDate: pastDueDate,
                principalDue: 800000,
                interestDue: 70000,
                totalDue: 870000,
                interestOutstanding: 0,
                status: 'PAID',
              ),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanWaiveInterestAction_installment-paid')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('loanCorrectInterestAction_installment-paid')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '6: an eligible (due-today) installment shows Waive but not Correct '
      'for TREASURER',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            installments: [
              LoanInstallment(
                id: 'installment-due-today',
                installmentNumber: 3,
                dueDate: today,
                principalDue: 800000,
                interestDue: 80000,
                totalDue: 880000,
                interestOutstanding: 80000,
                status: 'DUE',
              ),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          membership: loanMembership(
            roles: const ['TREASURER'],
            permissions: loanTreasurerPermissions,
          ),
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const Key('loanWaiveInterestAction_installment-due-today'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('loanCorrectInterestAction_installment-due-today'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '9: penalty adjustment actions are unaffected by the future-interest '
      'UI gate — visible on a positive-outstanding charge regardless of '
      'the future-interest rule',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            penaltyEnabled: true,
            penaltyType: 'FIXED',
            penaltyFrequency: 'ONCE',
            installments: [
              LoanInstallment(
                id: 'installment-future',
                installmentNumber: 4,
                dueDate: futureDueDate,
                principalDue: 800000,
                interestDue: 90000,
                totalDue: 890000,
                interestOutstanding: 90000,
                status: 'UPCOMING',
              ),
            ],
          )
          ..nextPenaltyCharges = [
            fakeLoanPenaltyCharge(id: 'charge-1', outstandingAmount: 50000),
          ];

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        // The interest action on the future installment stays hidden...
        expect(
          find.byKey(const Key('loanWaiveInterestAction_installment-future')),
          findsNothing,
        );
        // ...while the unrelated penalty actions are untouched by this
        // gate.
        expect(
          find.byKey(const Key('loanWaivePenaltyAction_charge-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanCorrectPenaltyAction_charge-1')),
          findsOneWidget,
        );
      },
    );
  });

  group('Target context and route-target correctness', () {
    testWidgets('7/8/10: tapping a specific eligible installment among several '
        'routes to a screen whose target context matches THAT installment '
        'exactly — not another one (the exact confusion 09F-A-11 diagnosed)', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          installments: [
            LoanInstallment(
              id: 'installment-1',
              installmentNumber: 1,
              dueDate: pastDueDate,
              principalDue: 800000,
              interestDue: 50000,
              totalDue: 850000,
              interestOutstanding: 50000,
              status: 'OVERDUE',
            ),
            LoanInstallment(
              id: 'installment-2',
              installmentNumber: 2,
              dueDate: today,
              principalDue: 800000,
              interestDue: 30000,
              totalDue: 830000,
              interestOutstanding: 30000,
              status: 'DUE',
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      // Tap installment 2's Waive action specifically.
      await tester.ensureVisible(
        find.byKey(const Key('loanWaiveInterestAction_installment-2')),
      );
      await tester.tap(
        find.byKey(const Key('loanWaiveInterestAction_installment-2')),
      );
      await tester.pumpAndSettle();

      // The target-context header must identify installment 2 (30,000
      // outstanding), never installment 1 (50,000 outstanding).
      final targetContext = find.byKey(
        const Key('loanObligationTargetContext'),
      );
      expect(targetContext, findsOneWidget);
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('Installment 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('Installment 1'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('30,000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('Interest'),
        ),
        findsOneWidget,
        reason: 'the component label "Interest" must be shown',
      );
    });

    testWidgets('7: Correct screen target context also identifies the exact '
        'installment/due date/component/outstanding', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          installments: [
            LoanInstallment(
              id: 'installment-1',
              installmentNumber: 1,
              dueDate: pastDueDate,
              principalDue: 800000,
              interestDue: 50000,
              totalDue: 850000,
              interestOutstanding: 50000,
              status: 'OVERDUE',
            ),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanCorrectInterestAction_installment-1')),
      );
      await tester.tap(
        find.byKey(const Key('loanCorrectInterestAction_installment-1')),
      );
      await tester.pumpAndSettle();

      final targetContext = find.byKey(
        const Key('loanObligationTargetContext'),
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('Installment 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('50,000'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('8: penalty Correct screen target context identifies the exact '
        'charge/component/outstanding', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          penaltyEnabled: true,
          penaltyType: 'FIXED',
          penaltyFrequency: 'ONCE',
        )
        ..nextPenaltyCharges = [
          fakeLoanPenaltyCharge(
            id: 'charge-1',
            installmentNumber: 2,
            outstandingAmount: 45000,
          ),
        ];

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanCorrectPenaltyAction_charge-1')),
      );
      await tester.tap(
        find.byKey(const Key('loanCorrectPenaltyAction_charge-1')),
      );
      await tester.pumpAndSettle();

      final targetContext = find.byKey(
        const Key('loanObligationTargetContext'),
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('Installment 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: targetContext,
          matching: find.textContaining('45,000'),
        ),
        findsOneWidget,
      );
    });
  });
}
