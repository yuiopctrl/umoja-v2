import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/controllers/financial_account_form_controller.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';
import 'package:umoja/features/financial_accounts/providers/financial_accounts_list_provider.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// UAT-FIX-01: a financial account created on one device/session never
// appeared on another already-running session until the app was fully
// restarted, and the transfer picker kept showing only whichever
// accounts existed when it was first read. Root cause: neither
// `financialAccountsListProvider` nor `financialAccountsActiveForPickerProvider`
// were invalidated by account create/update, and both were plain
// (non-autoDispose) providers with no re-entry refetch. These tests warm
// the relevant provider first (matching the real flow: the screen was
// already open once) and only then trigger the mutation/re-entry, so
// they only pass if invalidation/refetch genuinely happens.
const _listQuery = (search: '', limit: 10);

void main() {
  testWidgets(
    'creating an account refreshes an already-warm accounts list — the '
    'new account appears without restart',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage.empty;

      await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // `financialAccountsListProvider` is `.autoDispose` — hold a
      // live listener so the two reads below share one instance
      // (otherwise a bare read always refetches fresh regardless of
      // whether the controller invalidated anything, making this an
      // invalid regression test).
      final subscription = container.listen(
        financialAccountsListProvider(_listQuery),
        (_, _) {},
      );
      addTearDown(subscription.close);

      final before = await container.read(
        financialAccountsListProvider(_listQuery).future,
      );
      expect(before.items, isEmpty);

      fakeRepo.nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box');

      await container
          .read(financialAccountFormControllerProvider.notifier)
          .create(groupId: 'g1', name: 'Cash Box', accountType: 'CASH');
      await tester.pumpAndSettle();

      final after = await container.read(
        financialAccountsListProvider(_listQuery).future,
      );
      expect(after.items, hasLength(1));
      expect(after.items.single.name, 'Cash Box');
    },
  );

  testWidgets('creating an account refreshes an already-warm active-accounts '
      'picker — the new account becomes selectable for transfer without '
      'restart', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [fakeFinancialAccount(id: 'a1', name: 'Main Cash')],
        totalCount: 1,
        limit: 100,
        offset: 0,
      );

    await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // `financialAccountsActiveForPickerProvider` is `.autoDispose` —
    // a bare `container.read(...future)` alone would dispose it
    // again immediately after resolving, so a *second* bare read
    // would always be a fresh fetch regardless of whether the
    // controller ever invalidated anything. Holding a live listener
    // (matching how the transfer screen's own `ref.watch` keeps it
    // alive) is what makes this a genuine invalidation test.
    final subscription = container.listen(
      financialAccountsActiveForPickerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final before = await container.read(
      financialAccountsActiveForPickerProvider.future,
    );
    expect(before, hasLength(1));

    // The fake mimics a real backend: creating appends `nextAccount`
    // to whatever page it already holds (currently the 1-item page
    // set up above), rather than this test hand-assembling the
    // post-create page itself.
    fakeRepo.nextAccount = fakeFinancialAccount(
      id: 'a2',
      name: 'Bank X',
      accountType: 'BANK',
    );

    await container
        .read(financialAccountFormControllerProvider.notifier)
        .create(groupId: 'g1', name: 'Bank X', accountType: 'BANK');
    await tester.pumpAndSettle();

    final after = await container.read(
      financialAccountsActiveForPickerProvider.future,
    );
    expect(after, hasLength(2));
    expect(after.map((a) => a.name), containsAll(['Main Cash', 'Bank X']));
  });

  testWidgets(
    'deactivating an account refreshes an already-warm active-accounts '
    'picker — it stops being offered for transfer without restart',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'a1', name: 'Main Cash')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      final subscription = container.listen(
        financialAccountsActiveForPickerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final before = await container.read(
        financialAccountsActiveForPickerProvider.future,
      );
      expect(before, hasLength(1));

      fakeRepo.nextAccountsPage = FinancialAccountPage.empty;

      await container
          .read(financialAccountFormControllerProvider.notifier)
          .update(groupId: 'g1', accountId: 'a1', isActive: false);
      await tester.pumpAndSettle();

      final after = await container.read(
        financialAccountsActiveForPickerProvider.future,
      );
      expect(after, isEmpty);
    },
  );

  testWidgets(
    'leaving the Financial Accounts screen and returning refetches the '
    'latest backend state — simulating an account created elsewhere '
    'while this session was away',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'a1', name: 'Main Cash')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountsList);
      await tester.pumpAndSettle();

      expect(find.text('Main Cash'), findsOneWidget);
      expect(find.text('Bank X'), findsNothing);

      // Leave the screen (simulating the session going elsewhere while
      // another device/session creates a new account server-side).
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      fakeRepo.nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Main Cash'),
          fakeFinancialAccount(id: 'a2', name: 'Bank X', accountType: 'BANK'),
        ],
        totalCount: 2,
        limit: 10,
        offset: 0,
      );

      // Re-enter the screen — no explicit invalidation was ever called
      // for this session; only screen re-entry itself.
      router.go(AppRoutes.financialAccountsList);
      await tester.pumpAndSettle();

      expect(find.text('Main Cash'), findsOneWidget);
      expect(find.text('Bank X'), findsOneWidget);
    },
  );
}
