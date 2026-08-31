import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

void main() {
  testWidgets('payment detail shows allocations and wallet credit', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(
        paymentId: 'p1',
        memberDisplayName: 'Jane Doe',
        amount: 13000,
        allocations: [
          PaymentAllocationLine(
            componentType: 'BASE',
            dueDate: DateTime.utc(2026, 1, 15),
            amount: 10000,
          ),
        ],
        walletCreditAmount: 3000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentDetailPath('p1'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('13,000'), findsOneWidget);
    expect(find.text('Base'), findsOneWidget);
    expect(find.text('3,000'), findsOneWidget);
  });

  testWidgets(
    'the Reverse Payment action is visible with payment.reverse and hidden '
    'once already reversed',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentDetail = fakePaymentDetail(
          paymentId: 'p1',
          status: 'POSTED',
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentDetailPath('p1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('paymentDetailReverseAction')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ADMIN\'s resolved permissions include payment.reverse, so the Reverse '
    'Payment action is visible for ADMIN specifically (Prompt 07 '
    'UAT-FIX-04 — not just the default TREASURER fixture)',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentDetail = fakePaymentDetail(
          paymentId: 'p1',
          status: 'POSTED',
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const [
            'group.view',
            'payment.view',
            'payment.create',
            'payment.reverse',
            'payment.receipt.view',
            'wallet.view',
            'wallet.allocate',
          ],
        ),
      );
      router.go(AppRoutes.paymentDetailPath('p1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('paymentDetailReverseAction')),
        findsOneWidget,
      );
    },
  );

  testWidgets('the Reverse Payment action is hidden without payment.reverse', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
      membership: paymentMembership(
        roles: const ['SECRETARY'],
        permissions: const [
          'group.view',
          'payment.view',
          'payment.receipt.view',
        ],
      ),
    );
    router.go(AppRoutes.paymentDetailPath('p1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentDetailReverseAction')), findsNothing);
  });

  testWidgets('an already-reversed payment never shows the Reverse action', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(
        paymentId: 'p1',
        status: 'REVERSED',
        reversalReason: 'duplicate entry',
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentDetailPath('p1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentDetailReverseAction')), findsNothing);
    expect(find.text('duplicate entry'), findsOneWidget);
    expect(find.text('Reversed'), findsOneWidget);
  });
}
