import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B section 31/38-A: the Fedha (Finance) home is the single
// entry point for both the Financial Position report and the existing
// Financial Accounts feature — kept deliberately minimal, with each
// entry gated by its own permission.
void main() {
  testWidgets(
    'A: a fully-permissioned caller sees both Hali ya Fedha and Akaunti '
    'za Fedha entries',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('financialPositionEntry')), findsOneWidget);
      expect(find.byKey(const Key('financialAccountsEntry')), findsOneWidget);
      expect(find.byKey(const Key('financialCategoriesEntry')), findsOneWidget);
    },
  );

  testWidgets(
    'UAT-FIX-05 follow-up: a caller without financial_account.manage does '
    'not see the Financial Categories entry — but a caller with it does, '
    'and tapping it reaches the categories screen',
    (tester) async {
      final fakeRepoNoManage = FakeFinancialAccountRepository();
      final routerNoManage = await pumpFinancialAccountsApp(
        tester,
        fakeRepo: fakeRepoNoManage,
        membership: financialAccountMembership(
          roles: const ['SECRETARY'],
          permissions: const ['group.view', 'financial_account.view'],
        ),
      );
      routerNoManage.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('financialCategoriesEntry')), findsNothing);
    },
  );

  testWidgets(
    'UAT-FIX-05 follow-up: tapping Financial Categories from Fedha home '
    'reaches the existing categories management screen',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('financialCategoriesEntry')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kategoria za Fedha'), findsOneWidget);
    },
  );

  testWidgets(
    'a caller with only financial_account.view (no financial_report.view) '
    'sees Akaunti za Fedha but not Hali ya Fedha',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: financialAccountMembership(
          roles: const ['SECRETARY'],
          permissions: const ['group.view', 'financial_account.view'],
        ),
      );
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('financialAccountsEntry')), findsOneWidget);
      expect(find.byKey(const Key('financialPositionEntry')), findsNothing);
    },
  );

  testWidgets(
    'a caller with only financial_report.view (no financial_account.view) '
    'sees Hali ya Fedha but not Akaunti za Fedha',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: financialAccountMembership(
          roles: const ['CHAIRPERSON'],
          permissions: const ['group.view', 'financial_report.view'],
        ),
      );
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('financialPositionEntry')), findsOneWidget);
      expect(find.byKey(const Key('financialAccountsEntry')), findsNothing);
    },
  );

  testWidgets(
    'tapping Hali ya Fedha from Fedha home reaches the Financial Position '
    'screen',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextPosition = fakeFinancialPosition();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('financialPositionEntry')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('financialPositionTotalBalanceCard')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'R: no layout overflow at a realistic small Android width (360)',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
