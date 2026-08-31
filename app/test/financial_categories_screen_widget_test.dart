import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// UAT-FIX-05 follow-up: this screen was routed but had no navigation
// entry point anywhere in the app, so this exact overflow — the
// section header Row (title + "Add Category") not fitting at mobile
// width — had never actually been exercised until a Fedha-home link
// was added.
void main() {
  testWidgets('no layout overflow at a realistic small Android width (360)', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextCategories = [
        fakeFinancialCategory(
          id: 'c1',
          name: 'Michango',
          categoryType: 'INCOME',
        ),
        fakeFinancialCategory(
          id: 'c2',
          name: 'Usafiri',
          categoryType: 'EXPENSE',
        ),
      ];

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.financialCategoriesList);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Michango'), findsOneWidget);
    expect(find.text('Usafiri'), findsOneWidget);
  });

  testWidgets(
    'adding a new category calls rpc_create_financial_category with the '
    'entered name and the section\'s category type',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextCategories = [
          fakeFinancialCategory(
            id: 'c1',
            name: 'Michango',
            categoryType: 'INCOME',
          ),
        ];

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialCategoriesList);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ongeza Kategoria').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Zawadi');
      await tester.tap(find.text('Hifadhi'));
      await tester.pumpAndSettle();

      expect(fakeRepo.createFinancialCategoryCalls, hasLength(1));
      expect(fakeRepo.createFinancialCategoryCalls.single.name, 'Zawadi');
      expect(
        fakeRepo.createFinancialCategoryCalls.single.categoryType,
        'INCOME',
      );
    },
  );
}
