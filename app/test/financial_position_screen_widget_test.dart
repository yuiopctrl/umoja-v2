import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/financial_accounts/domain/financial_position.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B sections 23-25/35/38: Hali ya Fedha (Financial Position) —
// never a full accounting balance sheet, and each classification is
// shown as a distinct figure rather than folded into "income".
void main() {
  testWidgets(
    'B: each financial account is listed with its own balance, and the '
    'total funds figure is shown separately',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextPosition = fakeFinancialPosition(
          accounts: const [
            FinancialPositionAccount(
              id: 'a1',
              name: 'Main Cash',
              accountType: 'CASH',
              isActive: true,
              balance: 70000,
            ),
            FinancialPositionAccount(
              id: 'a2',
              name: 'NMB Main',
              accountType: 'BANK',
              isActive: true,
              balance: 30000,
            ),
          ],
          totalFinancialAccountBalance: 100000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialPosition);
      await tester.pumpAndSettle();

      expect(find.text('Main Cash'), findsOneWidget);
      expect(find.text('NMB Main'), findsOneWidget);
      expect(find.textContaining('70,000'), findsOneWidget);
      expect(find.textContaining('30,000'), findsOneWidget);
      expect(find.textContaining('100,000'), findsOneWidget);
    },
  );

  testWidgets(
    'P: pass-through funds are shown as their own classification row, '
    'never folded into the Income figure',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextPosition = fakeFinancialPosition(
          groupIncome: 60000,
          passThroughReceived: 20000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialPosition);
      await tester.pumpAndSettle();

      final incomeCard = find.byKey(const Key('financialPositionIncomeCard'));
      expect(
        find.descendant(
          of: incomeCard,
          matching: find.textContaining('60,000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: incomeCard,
          matching: find.textContaining('80,000'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('financialPositionPassThroughRow')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Q: member wallet liability is shown as its own row, separate from '
    'the total account balance',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextPosition = fakeFinancialPosition(
          totalFinancialAccountBalance: 100000,
          memberWalletLiability: 5000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialPosition);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('financialPositionWalletLiabilityRow')),
        findsOneWidget,
      );
      final totalCard = find.byKey(
        const Key('financialPositionTotalBalanceCard'),
      );
      expect(
        find.descendant(
          of: totalCard,
          matching: find.textContaining('100,000'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('S: Swahili labels render for the classification rows', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextPosition = fakeFinancialPosition();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialPosition);
    await tester.pumpAndSettle();

    expect(find.text('Hali ya Fedha'), findsOneWidget);
    expect(find.text('Fedha Zisizo Pato la Kikundi'), findsOneWidget);
    expect(find.text('Deni la Salio la Wanachama'), findsOneWidget);
  });

  testWidgets('T: English labels render for the classification rows', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextPosition = fakeFinancialPosition();

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.financialPosition);
    await tester.pumpAndSettle();

    expect(find.text('Financial Position'), findsOneWidget);
    expect(find.text('Pass-through Funds'), findsOneWidget);
    expect(find.text('Member Wallet Liability'), findsOneWidget);
  });

  testWidgets('Prompt 09C: recognized loan interest income is shown as its own '
      'classification row', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextPosition = fakeFinancialPosition(
        fundedLoanPrincipalReceivable: 750000,
        scheduledUnearnedInterest: 150000,
        recognizedLoanInterestIncome: 50000,
      );

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.financialPosition);
    await tester.pumpAndSettle();

    expect(find.text('Recognized Loan Interest Income'), findsOneWidget);
    final row = find.byKey(
      const Key('financialPositionRecognizedLoanInterestIncomeRow'),
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('50,000')),
      findsOneWidget,
    );
  });

  testWidgets(
    'R: no layout overflow at a realistic small Android width (360)',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextPosition = fakeFinancialPosition();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.go(AppRoutes.financialPosition);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
