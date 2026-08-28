import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';

import 'fakes/financial_accounts_test_app.dart';
import 'fakes/fake_financial_account_repository.dart';

void main() {
  testWidgets('the home shortcut and financial accounts entry are visible with '
      'financial_account.view', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('homeFinancialAccountsShortcut')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('homeFinancialAccountsShortcut')));
    await tester.pumpAndSettle();

    // Something only the list screen itself renders — proves this
    // actually navigated there rather than bouncing back to Home
    // (where the shortcut card's own title text would be a
    // false-positive match for a plain "Akaunti za Fedha" search).
    expect(find.text('Tafuta akaunti'), findsOneWidget);
  });

  testWidgets('the home shortcut is hidden without financial_account.view', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      membership: financialAccountMembership(
        roles: const ['MEMBER'],
        permissions: const ['group.view'],
      ),
    );
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('homeFinancialAccountsShortcut')),
      findsNothing,
    );
  });

  testWidgets('an empty accounts list shows the empty state', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage.empty;

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialAccountsList);
    await tester.pumpAndSettle();

    expect(find.text('Hakuna Akaunti za Fedha'), findsOneWidget);
  });

  testWidgets('a populated accounts list shows each account with its balance', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Main Cash', balance: 50000),
          fakeFinancialAccount(
            id: 'a2',
            name: 'Bank X',
            accountType: 'BANK',
            balance: 0,
          ),
        ],
        totalCount: 2,
        limit: 10,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialAccountsList);
    await tester.pumpAndSettle();

    expect(find.text('Main Cash'), findsOneWidget);
    expect(find.text('Bank X'), findsOneWidget);
    expect(find.textContaining('50,000'), findsOneWidget);
  });

  testWidgets('the Add Account and Transfer actions are hidden without the '
      'matching permissions', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      membership: financialAccountMembership(
        roles: const ['CHAIRPERSON'],
        permissions: const ['group.view', 'financial_account.view'],
      ),
    );
    router.go(AppRoutes.financialAccountsList);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('financialAccountNewFab')), findsNothing);
    expect(find.text('Ongeza Akaunti'), findsNothing);
    expect(find.text('Hamisha Fedha'), findsNothing);
  });

  // UAT-FIX-03: "Transfer Funds" previously lived only in `headerTrailing`,
  // which `UmojaPage` never renders below the desktop/tablet
  // breakpoint — so an authorized Mobile user had no way to reach the
  // transfer screen at all, even though the flow itself worked fine
  // once reached (e.g. via Desktop). These tests pump at the app's
  // standard mobile width (390×844, set by `pumpFinancialAccountsApp`)
  // — a realistic small-phone Android width.
  testWidgets(
    'A: at mobile width, an authorized user (financial_account.transfer'
    '.create) sees the Transfer Funds action',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountsList);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('financialAccountTransferFundsAction')),
        findsOneWidget,
      );
      expect(find.text('Hamisha Fedha'), findsOneWidget);
    },
  );

  testWidgets('B: at mobile width, an unauthorized user does not see the '
      'Transfer Funds action', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      membership: financialAccountMembership(
        roles: const ['SECRETARY'],
        permissions: const ['group.view', 'financial_account.view'],
      ),
    );
    router.go(AppRoutes.financialAccountsList);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('financialAccountTransferFundsAction')),
      findsNothing,
    );
    expect(find.text('Hamisha Fedha'), findsNothing);
  });

  testWidgets('C: tapping the mobile Transfer Funds action opens the existing '
      'transfer screen — no second mobile-only implementation', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialAccountsList);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('financialAccountTransferFundsAction')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hamisha Fedha Kati ya Akaunti'), findsOneWidget);
  });

  testWidgets('D: at desktop width, the same authorized user still sees the '
      'Transfer Funds action — exactly one instance, not a duplicate', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.financialAccountsList);
    await tester.pumpAndSettle();

    expect(find.text('Hamisha Fedha'), findsOneWidget);
  });

  testWidgets(
    'E: no layout overflow at a realistic small Android width (360)',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'a1', name: 'Main Cash')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.go(AppRoutes.financialAccountsList);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hamisha Fedha'), findsOneWidget);
    },
  );
}
