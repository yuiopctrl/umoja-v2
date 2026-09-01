import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';
import 'package:umoja/features/payments/domain/wallet_entry_page.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09C-UAT-FIX-02: physical UAT found that Wallet → Loan
/// "Preview Allocation" showed bare "Interest — 20,000" / "Principal —
/// 20,000" lines with no indication of which loan (or, with more than
/// one ACTIVE loan, which OF THEM) was being settled.
void main() {
  testWidgets('1/2/3/4: the wallet allocation preview shows the loan product '
      'name, loan number, installment number, and Riba/Mtaji labels', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: const [],
        totalCount: 0,
        limit: 10,
        offset: 0,
        walletBalance: 40000,
      )
      ..nextWalletPreview = fakeWalletAllocationPreview(
        walletBalance: 40000,
        amount: 40000,
        allocations: [
          PaymentAllocationLine(
            componentType: 'INTEREST',
            dueDate: DateTime.utc(2026, 10, 5),
            amount: 20000,
            obligationKind: 'LOAN_INTEREST',
            loanNumber: 'UMO-LN-2026-0012',
            loanProductName: 'Mkopo wa Dharura',
            installmentNumber: 2,
          ),
          PaymentAllocationLine(
            componentType: 'PRINCIPAL',
            dueDate: DateTime.utc(2026, 10, 5),
            amount: 20000,
            obligationKind: 'LOAN_PRINCIPAL',
            loanNumber: 'UMO-LN-2026-0012',
            loanProductName: 'Mkopo wa Dharura',
            installmentNumber: 2,
          ),
        ],
        totalAllocated: 40000,
      );

    final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('walletAllocateAction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('walletAllocateAmountField')),
      '40000',
    );
    await tester.tap(find.byKey(const Key('walletAllocatePreviewAction')));
    await tester.pumpAndSettle();

    // 1. loan product name.
    expect(find.text('Mkopo wa Dharura'), findsOneWidget);
    // 2. loan number.
    expect(find.text('UMO-LN-2026-0012'), findsOneWidget);
    // 3. installment number.
    expect(find.textContaining('Awamu 2'), findsOneWidget);
    // 4. interest/principal labels, never a raw enum.
    expect(find.text('Riba'), findsOneWidget);
    expect(find.text('Mtaji'), findsOneWidget);
    expect(find.text('INTEREST'), findsNothing);
    expect(find.text('LOAN_PRINCIPAL'), findsNothing);
  });

  testWidgets('5: two ACTIVE loans are clearly distinguishable in one wallet '
      'allocation preview, never a flat undifferentiated list', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: const [],
        totalCount: 0,
        limit: 10,
        offset: 0,
        walletBalance: 140000,
      )
      ..nextWalletPreview = fakeWalletAllocationPreview(
        walletBalance: 140000,
        amount: 140000,
        allocations: [
          PaymentAllocationLine(
            componentType: 'INTEREST',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 20000,
            obligationKind: 'LOAN_INTEREST',
            loanNumber: 'UMO-LN-2026-0010',
            loanProductName: 'Emergency Loan',
            installmentNumber: 1,
          ),
          PaymentAllocationLine(
            componentType: 'PRINCIPAL',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 20000,
            obligationKind: 'LOAN_PRINCIPAL',
            loanNumber: 'UMO-LN-2026-0010',
            loanProductName: 'Emergency Loan',
            installmentNumber: 1,
          ),
          PaymentAllocationLine(
            componentType: 'INTEREST',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 50000,
            obligationKind: 'LOAN_INTEREST',
            loanNumber: 'UMO-LN-2026-0011',
            loanProductName: 'Business Loan',
            installmentNumber: 1,
          ),
          PaymentAllocationLine(
            componentType: 'PRINCIPAL',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 50000,
            obligationKind: 'LOAN_PRINCIPAL',
            loanNumber: 'UMO-LN-2026-0011',
            loanProductName: 'Business Loan',
            installmentNumber: 1,
          ),
        ],
        totalAllocated: 140000,
      );

    final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('walletAllocateAction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('walletAllocateAmountField')),
      '140000',
    );
    await tester.tap(find.byKey(const Key('walletAllocatePreviewAction')));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Loan'), findsOneWidget);
    expect(find.text('UMO-LN-2026-0010'), findsOneWidget);
    expect(find.text('Business Loan'), findsOneWidget);
    expect(find.text('UMO-LN-2026-0011'), findsOneWidget);
    // Each loan's Riba/Mtaji pair renders once per loan (2 loans).
    expect(find.text('Riba'), findsNWidgets(2));
    expect(find.text('Mtaji'), findsNWidgets(2));
  });

  testWidgets('6: no layout overflow at 360px with a long product name and a '
      'long loan number', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: const [],
        totalCount: 0,
        limit: 10,
        offset: 0,
        walletBalance: 40000,
      )
      ..nextWalletPreview = fakeWalletAllocationPreview(
        walletBalance: 40000,
        amount: 40000,
        allocations: [
          PaymentAllocationLine(
            componentType: 'INTEREST',
            dueDate: DateTime.utc(2026, 10, 5),
            amount: 20000,
            obligationKind: 'LOAN_INTEREST',
            loanNumber: 'UMOJA-GROUP-LOAN-NUMBER-2026-000012-LONG',
            loanProductName:
                'Mkopo wa Dharura kwa Wanachama wa Muda Mrefu wa Kikundi',
            installmentNumber: 2,
          ),
          PaymentAllocationLine(
            componentType: 'PRINCIPAL',
            dueDate: DateTime.utc(2026, 10, 5),
            amount: 20000,
            obligationKind: 'LOAN_PRINCIPAL',
            loanNumber: 'UMOJA-GROUP-LOAN-NUMBER-2026-000012-LONG',
            loanProductName:
                'Mkopo wa Dharura kwa Wanachama wa Muda Mrefu wa Kikundi',
            installmentNumber: 2,
          ),
        ],
        totalAllocated: 40000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('walletAllocateAction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('walletAllocateAmountField')),
      '40000',
    );
    await tester.tap(find.byKey(const Key('walletAllocatePreviewAction')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
