import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09D: Loan Detail penalty visibility — frozen penalty
/// snapshot (section 39, never the live product policy), penalty
/// outstanding in the repayment summary and per-installment, and
/// penalty history (section 32).
void main() {
  testWidgets(
    'an ACTIVE loan with an enabled FIXED penalty shows its frozen policy '
    'description, never the raw enum values',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          penaltyEnabled: true,
          penaltyType: 'FIXED',
          penaltyFrequency: 'ONCE',
          penaltyGraceDays: 5,
          penaltyFixedAmount: 20000,
          penaltyOutstanding: 20000,
          totalOutstanding: 20000,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanPenaltySnapshotCard')), findsOneWidget);
      expect(find.textContaining('FIXED'), findsNothing);
      expect(find.textContaining('ONCE'), findsNothing);
    },
  );

  testWidgets(
    'a penalty-disabled loan shows the disabled policy message, not a '
    'blank/garbled description',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          penaltyEnabled: false,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.text('Hakuna sera ya adhabu'), findsOneWidget);
    },
  );

  testWidgets(
    'an outstanding penalty is shown in the repayment summary and stays '
    'ACTIVE (never CLOSED) while it remains unpaid',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          principalOutstanding: 0,
          interestOutstanding: 0,
          penaltyEnabled: true,
          penaltyType: 'FIXED',
          penaltyFrequency: 'ONCE',
          penaltyGraceDays: 0,
          penaltyFixedAmount: 15000,
          penaltyPaid: 0,
          penaltyOutstanding: 15000,
          totalOutstanding: 15000,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanSummaryPenaltyOutstandingRow')),
        findsOneWidget,
      );
      expect(find.text('Inaendelea'), findsOneWidget); // ACTIVE badge label
    },
  );

  testWidgets(
    'a CLOSED loan (principal+interest+penalty all zero) shows no penalty '
    'outstanding row',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'CLOSED',
          principalOutstanding: 0,
          interestOutstanding: 0,
          penaltyEnabled: true,
          penaltyType: 'FIXED',
          penaltyFrequency: 'ONCE',
          penaltyGraceDays: 0,
          penaltyFixedAmount: 15000,
          penaltyPaid: 15000,
          penaltyOutstanding: 0,
          totalOutstanding: 0,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanSummaryPenaltyOutstandingRow')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'per-installment penalty outstanding is shown next to its due date',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          installments: [
            fakeLoanInstallment(
              installmentNumber: 1,
              penaltyOutstanding: 20000,
              status: 'OVERDUE',
            ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Adhabu ya Mkopo'), findsWidgets);
    },
  );

  testWidgets('penalty history lists every assessed occurrence', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(
        id: 'loan-1',
        status: 'ACTIVE',
        penaltyEnabled: true,
        penaltyType: 'PERCENTAGE',
        penaltyFrequency: 'RECURRING_MONTHLY',
        penaltyGraceDays: 3,
        penaltyRate: 5,
      )
      ..nextPenaltyCharges = [
        fakeLoanPenaltyCharge(
          id: 'c1',
          sequenceNumber: 1,
          penaltyAmount: 10000,
        ),
        fakeLoanPenaltyCharge(
          id: 'c2',
          sequenceNumber: 2,
          penaltyAmount: 10500,
        ),
      ];

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanPenaltyHistorySection')), findsOneWidget);
    expect(find.textContaining('Tukio 1'), findsOneWidget);
    expect(find.textContaining('Tukio 2'), findsOneWidget);
  });
}
