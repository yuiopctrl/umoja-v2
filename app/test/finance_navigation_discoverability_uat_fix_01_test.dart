import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// PROMPT 08B-UAT-FIX-01: reproduces the exact physical-UAT path
// (Home -> Fedha -> Financial Accounts -> Cash Box, and Home -> Fedha)
// end to end through the real GoRouter/route-guard/permission stack —
// never a fake bare `router.go` straight to the target route — since
// the reported gap was about *discoverability* (can the action be
// reached and seen at all), not whether the destination screen itself
// renders correctly in isolation.
void main() {
  testWidgets(
    'A/B: Home -> Fedha -> Hali ya Fedha is reachable by tapping through '
    'real navigation, without redirecting back to /home, for a caller '
    'with financial_report.view',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextPosition = fakeFinancialPosition();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homeFinanceShortcut')));
      await tester.pumpAndSettle();

      // K: never bounced back to /home by the route guard.
      expect(find.byKey(const Key('financialPositionEntry')), findsOneWidget);
      expect(find.byKey(const Key('homeFinanceShortcut')), findsNothing);

      await tester.tap(find.byKey(const Key('financialPositionEntry')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('financialPositionTotalBalanceCard')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'C/D: tapping through Home -> Fedha -> Financial Accounts -> Cash Box '
    'shows both Rekodi Mapato and Rekodi Matumizi for an ADMIN/TREASURER '
    'caller',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'a1', name: 'Cash Box')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        )
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box');

      final router = await pumpFinancialAccountsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: financialAccountMembership(roles: const ['TREASURER']),
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homeFinanceShortcut')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('financialAccountsEntry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash Box'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recordIncomeAction')), findsOneWidget);
      expect(find.byKey(const Key('recordExpenseAction')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'E/F/M: tapping Rekodi Mapato from Account Detail opens the existing '
    'income form with Cash Box preselected (no account re-picker), posts, '
    'and returning refreshes Account Detail\'s balance — no setState-'
    'during-build exception at any step (L)',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(
          id: 'a1',
          name: 'Cash Box',
          balance: 50000,
        )
        ..nextCategories = [
          fakeFinancialCategory(
            id: 'c1',
            name: 'Michango',
            categoryType: 'INCOME',
          ),
        ]
        ..nextManualEntryPostResult = fakeFinancialManualEntryPostResult(
          financialAccountBalance: 70000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recordIncomeAction')));
      await tester.pumpAndSettle();
      // L: the push itself must never throw (this is exactly the
      // setState-during-build crash fixed earlier this phase).
      expect(tester.takeException(), isNull);

      // The account is already resolved on this screen — no picker to
      // reselect Cash Box.
      expect(find.byKey(const Key('manualEntryCategoryField')), findsOneWidget);
      expect(find.text('Cash Box'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('manualEntryAmountField')),
        '20000',
      );
      await tester.tap(find.byKey(const Key('manualEntryCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Michango').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls.single.financialAccountId, 'a1');
      expect(find.text('Mapato yamerekodiwa.'), findsOneWidget);
      expect(find.textContaining('70,000'), findsOneWidget);
    },
  );

  testWidgets(
    'F: tapping Rekodi Matumizi from Account Detail opens the existing '
    'expense form with Cash Box preselected',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box');

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recordExpenseAction')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cash Box'), findsOneWidget);
      expect(find.byKey(const Key('manualEntryAmountField')), findsOneWidget);
    },
  );

  testWidgets(
    'G/H: a caller without financial_income.create/financial_expense.create '
    '(checked by permission key, not role name) sees neither posting '
    'action on Account Detail',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box');

      final router = await pumpFinancialAccountsApp(
        tester,
        fakeRepo: fakeRepo,
        // A custom, non-standard role name proves the check is by
        // permission key, not `role == 'ADMIN'`/`role == 'TREASURER'`.
        membership: financialAccountMembership(
          roles: const ['BOOKKEEPER_TRAINEE'],
          permissions: const ['group.view', 'financial_account.view'],
        ),
      );
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recordIncomeAction')), findsNothing);
      expect(find.byKey(const Key('recordExpenseAction')), findsNothing);
    },
  );

  testWidgets(
    'H: a caller with financial_income.create/financial_expense.create '
    'under that same non-standard role name DOES see both actions — '
    'proving the gate reads permission codes, never a role allowlist',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box');

      final router = await pumpFinancialAccountsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: financialAccountMembership(
          roles: const ['BOOKKEEPER_TRAINEE'],
          permissions: const [
            'group.view',
            'financial_account.view',
            'financial_income.create',
            'financial_expense.create',
          ],
        ),
      );
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recordIncomeAction')), findsOneWidget);
      expect(find.byKey(const Key('recordExpenseAction')), findsOneWidget);
    },
  );

  testWidgets(
    'I: at a realistic 360px mobile width, Account Detail exposes both '
    'Rekodi Mapato and Rekodi Matumizi without overflow — neither action '
    'lives only in a desktop-only headerTrailing/toolbar',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box');

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recordIncomeAction')), findsOneWidget);
      expect(find.byKey(const Key('recordExpenseAction')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'J/K: Finance is reachable purely by tapping through Home -> Fedha, '
    'with no manual route entry required, and never redirects back to '
    '/home',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository();

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homeFinanceShortcut')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('financialAccountsEntry')), findsOneWidget);
      expect(find.byKey(const Key('financialPositionEntry')), findsOneWidget);
      // Never bounced to Home.
      expect(find.byKey(const Key('homeFinanceShortcut')), findsNothing);
    },
  );
}
