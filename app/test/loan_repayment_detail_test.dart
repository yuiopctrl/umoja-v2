import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/utils/money_format.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  testWidgets('an ACTIVE loan detail shows the repayment summary and each '
      'installment'
      's derived status (Prompt 09C)', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(
        id: 'loan-1',
        status: 'ACTIVE',
        principalAmount: 1000000,
        term: 4,
        principalRepaid: 250000,
        principalOutstanding: 750000,
        interestRecognized: 50000,
        interestOutstanding: 150000,
        totalOutstanding: 900000,
        nextDueDate: DateTime.utc(2026, 11, 1),
        overdueAmount: 0,
        installments: [
          fakeLoanInstallment(
            installmentNumber: 1,
            dueDate: DateTime.utc(2026, 10, 1),
            principalDue: 250000,
            interestDue: 50000,
            principalPaid: 250000,
            principalOutstanding: 0,
            interestPaid: 50000,
            interestOutstanding: 0,
            totalOutstanding: 0,
            status: 'PAID',
          ),
          fakeLoanInstallment(
            installmentNumber: 2,
            dueDate: DateTime.utc(2026, 11, 1),
            principalDue: 250000,
            interestDue: 50000,
            principalPaid: 0,
            principalOutstanding: 250000,
            interestPaid: 0,
            interestOutstanding: 50000,
            totalOutstanding: 300000,
            status: 'UPCOMING',
          ),
        ],
      );

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanRepaymentSummaryCard')), findsOneWidget);
    expect(find.text(formatAmount(250000)), findsWidgets);
    expect(find.text(formatAmount(750000)), findsOneWidget);
    expect(find.text(formatAmount(50000)), findsWidgets);
    expect(find.text(formatAmount(900000)), findsOneWidget);
    expect(find.text('Imelipwa'), findsOneWidget);
    expect(find.text('Inakuja'), findsOneWidget);
  });

  testWidgets('a CLOSED loan shows no Edit, Cancel, or Disburse action — fully '
      'settled and read-only', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'CLOSED');

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.text('Imefungwa'), findsOneWidget);
    expect(find.byKey(const Key('loanEditTermsAction')), findsNothing);
    expect(find.byKey(const Key('loanCancelAction')), findsNothing);
    expect(find.byKey(const Key('loanDisburseAction')), findsNothing);
  });

  testWidgets(
    'no layout overflow at 360px or desktop width with a full repayment '
    'summary and several schedule rows',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          principalRepaid: 250000,
          principalOutstanding: 750000,
          interestRecognized: 50000,
          interestOutstanding: 150000,
          totalOutstanding: 900000,
          nextDueDate: DateTime.utc(2026, 11, 1),
          overdueAmount: 12345,
          installments: [
            for (var i = 1; i <= 4; i++)
              fakeLoanInstallment(
                installmentNumber: i,
                dueDate: DateTime.utc(2026, i + 9, 1),
                status: i == 1 ? 'PAID' : 'UPCOMING',
              ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
