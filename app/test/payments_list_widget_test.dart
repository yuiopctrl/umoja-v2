import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/domain/payment_page.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

void main() {
  testWidgets('an empty payments list shows the empty state', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentsPage = PaymentPage.empty;

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentsHistory);
    await tester.pumpAndSettle();

    expect(find.text('No Payments'), findsOneWidget);
  });

  testWidgets('a populated payments list shows each payment with amount and '
      'receipt number', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentsPage = PaymentPage(
        items: [
          fakePayment(
            paymentId: 'p1',
            memberDisplayName: 'Jane Doe',
            amount: 10000,
            receiptNumber: 'UMOJA-RCP-2026-000001',
          ),
          fakePayment(
            paymentId: 'p2',
            memberDisplayName: 'John Smith',
            amount: 5000,
            receiptNumber: 'UMOJA-RCP-2026-000002',
            status: 'REVERSED',
          ),
        ],
        totalCount: 2,
        limit: 10,
        offset: 0,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentsHistory);
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('John Smith'), findsOneWidget);
    expect(find.textContaining('10,000'), findsOneWidget);
    expect(find.text('Reversed'), findsOneWidget);
  });

  testWidgets('the Record Payment action is hidden without payment.create', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository();

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
    router.go(AppRoutes.paymentsHistory);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentRecordFab')), findsNothing);
    expect(find.text('Record Payment'), findsNothing);
  });

  testWidgets('the Record Payment action is visible with payment.create', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository();

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentsHistory);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentRecordFab')), findsOneWidget);
  });

  testWidgets('tapping a payment row navigates to its detail screen', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentsPage = PaymentPage(
        items: [fakePayment(paymentId: 'p1', memberDisplayName: 'Jane Doe')],
        totalCount: 1,
        limit: 10,
        offset: 0,
      )
      ..nextPaymentDetail = fakePaymentDetail(
        paymentId: 'p1',
        memberDisplayName: 'Jane Doe',
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentsHistory);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Detail'), findsOneWidget);
  });
}
