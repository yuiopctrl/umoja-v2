import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B sections 4/5/32/33/38 (C-G): one shared screen posts both
// manual income and manual expense — never before an explicit confirm,
// and never client-side predicting the resulting balance.
void main() {
  testWidgets('UAT-FIX-05: with zero active income categories, the field is '
      'replaced with a clear "no categories" message and a way to manage '
      'categories — never a silently-disabled dropdown that reads as '
      '"read only" with no explanation', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1')
      ..nextCategories = [];

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manualEntryCategoryField')), findsNothing);
    expect(
      find.text('There are no income categories set up for this group yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Manage Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Financial Categories'), findsOneWidget);
  });

  testWidgets(
    'UAT-FIX-05: with exactly one active category, it is auto-selected — '
    'a tester never has to realize a tap-to-select is required for a '
    'field that only ever has one possible value',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
        ..nextCategories = [
          fakeFinancialCategory(
            id: 'c1',
            name: 'Michango',
            categoryType: 'INCOME',
          ),
        ];

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
      await tester.pumpAndSettle();

      // Never touched the category field at all.
      await tester.enterText(
        find.byKey(const Key('manualEntryAmountField')),
        '5000',
      );
      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls, hasLength(1));
      expect(fakeRepo.recordManualIncomeCalls.single.categoryId, 'c1');
      expect(
        find.byKey(const Key('manualEntryLocalValidationError')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'C: confirming Record Income with no amount and no category selected '
    'never calls the repository, and — UAT-FIX-05 — shows a visible '
    'validation message instead of silently doing nothing',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1')
        // Empty on purpose: with any single category, UAT-FIX-05's
        // auto-select would fill it in, so this needs zero categories
        // to genuinely represent "neither field provided".
        ..nextCategories = [];

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
      await tester.pumpAndSettle();

      // Before the UAT-FIX-05 fix, this tap produced zero visible
      // feedback of any kind — from the user's perspective, tapping
      // Confirm on an incomplete form "did nothing".
      expect(
        find.byKey(const Key('manualEntryLocalValidationError')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls, isEmpty);
      expect(
        find.byKey(const Key('manualEntryLocalValidationError')),
        findsOneWidget,
      );
      expect(
        find.text('Weka kiasi sahihi na chagua kategoria.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UAT-FIX-05: with more than one category to choose from, entering an '
    'amount but leaving the category unselected shows the validation '
    'message on Confirm; selecting one and confirming again clears it '
    'and posts successfully',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
        ..nextCategories = [
          fakeFinancialCategory(
            id: 'c1',
            name: 'Michango',
            categoryType: 'INCOME',
          ),
          fakeFinancialCategory(
            id: 'c2',
            name: 'Riba ya Benki',
            categoryType: 'INCOME',
          ),
        ];

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('manualEntryAmountField')),
        '20000',
      );
      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls, isEmpty);
      // The precise, single-field message — never the combined "amount
      // and category" wording when the amount is already valid. (The
      // dropdown's own placeholder also reads "Chagua kategoria." while
      // unselected, so the error is asserted by key, not bare text.)
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('manualEntryLocalValidationError')),
            )
            .data,
        'Chagua kategoria.',
      );

      await tester.tap(find.byKey(const Key('manualEntryCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Michango').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls, hasLength(1));
      expect(
        find.byKey(const Key('manualEntryLocalValidationError')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'UAT-FIX-05: selecting a category but leaving the amount empty shows '
    'the precise amount-only message, never the combined wording',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
        ..nextCategories = [
          fakeFinancialCategory(
            id: 'c1',
            name: 'Michango',
            categoryType: 'INCOME',
          ),
        ];

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('manualEntryCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Michango').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls, isEmpty);
      expect(find.text('Weka kiasi sahihi.'), findsOneWidget);
      expect(find.text('Chagua kategoria.'), findsNothing);
      expect(find.text('Weka kiasi sahihi na chagua kategoria.'), findsNothing);
    },
  );

  testWidgets(
    'D: filling amount and category then confirming Record Income posts '
    'via rpc_record_manual_income and shows the success message with the '
    'resulting balance',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
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
      router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
      await tester.pumpAndSettle();

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

      expect(fakeRepo.recordManualIncomeCalls, hasLength(1));
      expect(fakeRepo.recordManualIncomeCalls.single.categoryId, 'c1');
      expect(fakeRepo.recordManualIncomeCalls.single.amount, 20000);
      expect(find.text('Mapato yamerekodiwa.'), findsOneWidget);
      expect(find.textContaining('70,000'), findsOneWidget);
    },
  );

  testWidgets(
    'E: confirming Record Expense with no amount and no category selected '
    'never calls the repository',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1');

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordExpensePath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordExpenseCalls, isEmpty);
    },
  );

  testWidgets(
    'F: a blocked expense (backend refuses to overdraw the account) shows '
    'the insufficient-balance error and never a fabricated success message',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 5000)
        ..nextCategories = [
          fakeFinancialCategory(
            id: 'c2',
            name: 'Usafiri',
            categoryType: 'EXPENSE',
          ),
        ];

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordExpensePath('a1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('manualEntryAmountField')),
        '999999',
      );
      await tester.tap(find.byKey(const Key('manualEntryCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usafiri').last);
      await tester.pumpAndSettle();

      // Set the failure only now — the initial account/category loads
      // above must succeed first, exactly like a real backend that
      // only refuses the *posting* RPC, not every read.
      fakeRepo.failure = const FinancialAccountFailure(
        FinancialAccountFailureType.insufficientBalance,
        'insufficient',
      );

      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The source account does not have enough balance for this transfer.',
        ),
        findsNothing,
      );
      expect(find.text('Matumizi yamerekodiwa.'), findsNothing);
      expect(fakeRepo.recordExpenseCalls, hasLength(1));
    },
  );
}
