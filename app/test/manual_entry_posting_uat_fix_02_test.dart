import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// PROMPT 08B-UAT-FIX-02: the reported physical failure was that a
// filled-in Record Income/Expense form did not complete posting.
// Backend diagnosis (this phase): both `rpc_record_manual_income` and
// `rpc_record_expense` were called directly over the real local
// Supabase REST/RPC endpoint with the *exact* parameter shape the
// Dart repository sends (including `p_idempotency_key: null`, which
// the form never populates) and both succeeded (HTTP 200, correct
// JSON), so no backend/parameter-mismatch defect exists. These tests
// lock in the remaining write-path guarantees at the Flutter layer:
// error surfacing, duplicate-tap protection, and mobile layout.
void main() {
  testWidgets(
    'B: a valid expense post succeeds end to end and shows the resulting '
    'balance from the server response',
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
            name: 'Usafiri',
            categoryType: 'EXPENSE',
          ),
        ]
        ..nextManualEntryPostResult = fakeFinancialManualEntryPostResult(
          entryKind: 'EXPENSE',
          financialAccountBalance: 42000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountRecordExpensePath('a1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('manualEntryAmountField')),
        '8000',
      );
      await tester.tap(find.byKey(const Key('manualEntryCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usafiri').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordExpenseCalls, hasLength(1));
      expect(fakeRepo.recordExpenseCalls.single.categoryId, 'c1');
      expect(fakeRepo.recordExpenseCalls.single.financialAccountId, 'a1');
      expect(fakeRepo.recordExpenseCalls.single.amount, 8000);
      expect(find.text('Matumizi yamerekodiwa.'), findsOneWidget);
      expect(find.textContaining('42,000'), findsOneWidget);
    },
  );

  testWidgets(
    'E: a backend failure surfaces as a visible error message, resets '
    'the loading state, and re-enables the confirm button — never an '
    'infinite spinner',
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

      await tester.enterText(
        find.byKey(const Key('manualEntryAmountField')),
        '20000',
      );
      await tester.tap(find.byKey(const Key('manualEntryCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Michango').last);
      await tester.pumpAndSettle();

      // Only now — the account/category loads above must succeed
      // first, exactly like a real backend that only refuses the
      // *posting* RPC, not every read.
      fakeRepo.failure = const FinancialAccountFailure(
        FinancialAccountFailureType.categoryInactive,
        'category inactive',
      );

      await tester.tap(find.byKey(const Key('manualEntryConfirmAction')));
      await tester.pumpAndSettle();

      // A concrete, user-visible error — never a silent/blank failure.
      expect(find.text('Kategoria hii haifanyi kazi tena.'), findsOneWidget);
      // No lingering "success" state.
      expect(find.text('Mapato yamerekodiwa.'), findsNothing);
      // The confirm button is enabled again (not stuck loading/disabled).
      final confirmButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('manualEntryConfirmAction')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(confirmButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'I: while a post is genuinely in flight (real network latency), the '
    'confirm button is disabled and a second tap never posts twice',
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
        ..manualEntryPostGate = Completer<void>();

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
      // One real frame — enough for a realistic minimum gap between
      // any two human taps — while the RPC is still "in flight".
      await tester.pump();

      // The button is still present but disabled (loading), not gone
      // and not tappable — this is what actually protects against a
      // second real tap while a slow network call is pending.
      final confirmButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('manualEntryConfirmAction')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(confirmButton.onPressed, isNull);

      // A second tap on the disabled button is a no-op.
      await tester.tap(
        find.byKey(const Key('manualEntryConfirmAction')),
        warnIfMissed: false,
      );
      await tester.pump();

      fakeRepo.manualEntryPostGate!.complete();
      await tester.pumpAndSettle();

      expect(fakeRepo.recordManualIncomeCalls, hasLength(1));
    },
  );

  testWidgets('J: the Record Income form is usable at a realistic 360px mobile '
      'width — no overflow, all fields and the confirm action reachable', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box')
      ..nextCategories = [
        fakeFinancialCategory(
          id: 'c1',
          name: 'Michango',
          categoryType: 'INCOME',
        ),
      ];

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.financialAccountRecordIncomePath('a1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manualEntryAmountField')), findsOneWidget);
    expect(find.byKey(const Key('manualEntryCategoryField')), findsOneWidget);
    expect(find.byKey(const Key('manualEntryConfirmAction')), findsOneWidget);
    expect(tester.takeException(), isNull);

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
    expect(tester.takeException(), isNull);
  });
}
