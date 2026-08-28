import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/domain/wallet_entry_page.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

void main() {
  testWidgets('shows the current balance and ledger history', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: [
          fakeWalletEntry(entryType: 'PAYMENT_CREDIT', amount: 5000),
          fakeWalletEntry(entryType: 'ALLOCATION_DEBIT', amount: 2000),
        ],
        totalCount: 2,
        limit: 10,
        offset: 0,
        walletBalance: 3000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3,000'), findsOneWidget);
    expect(find.text('Credited'), findsOneWidget);
    expect(find.text('Allocated'), findsOneWidget);
  });

  testWidgets('the Allocate Balance action is hidden without wallet.allocate', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: const [],
        totalCount: 0,
        limit: 10,
        offset: 0,
        walletBalance: 5000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
      membership: paymentMembership(
        roles: const ['SECRETARY'],
        permissions: const ['group.view', 'wallet.view'],
      ),
    );
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('walletAllocateAction')), findsNothing);
  });

  testWidgets('the allocate flow: open sheet -> preview -> confirm', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: const [],
        totalCount: 0,
        limit: 10,
        offset: 0,
        walletBalance: 5000,
      )
      ..nextWalletPreview = fakeWalletAllocationPreview(
        walletBalance: 5000,
        amount: 3000,
        totalAllocated: 3000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('walletAllocateAction')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('walletAllocateAmountField')),
      '3000',
    );
    await tester.tap(find.byKey(const Key('walletAllocatePreviewAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.previewWalletAllocationCalls, hasLength(1));
    expect(fakeRepo.previewWalletAllocationCalls.single.amount, 3000);

    await tester.tap(find.byKey(const Key('walletAllocateConfirmAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.allocateMemberWalletCalls, hasLength(1));
    expect(fakeRepo.allocateMemberWalletCalls.single.amount, 3000);
    expect(
      find.text('Wallet balance allocated against outstanding debt.'),
      findsOneWidget,
    );
  });
}
