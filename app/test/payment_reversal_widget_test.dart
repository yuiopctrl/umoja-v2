import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

void main() {
  testWidgets('shows the warning message and the reason field', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentReversePath('p1'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This cannot be undone. The original payment stays on record, '
        'but the debt it settled becomes outstanding again.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('paymentReversalReasonField')), findsOneWidget);
  });

  testWidgets('confirming without a reason never calls the reversal RPC', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentReversePath('p1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paymentReversalConfirmAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.reversePaymentCalls, isEmpty);
  });

  testWidgets(
    'a wallet-credit-already-consumed block shows its own specific message, '
    'never a generic "something went wrong"',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentReversePath('p1'));
      await tester.pumpAndSettle();

      // Set the failure only after the detail has already loaded
      // successfully — the fake throws for every call, so setting it
      // upfront would also fail the detail fetch this screen needs to
      // render the form in the first place.
      fakeRepo.failure = const PaymentFailure(
        PaymentFailureType.reversalBlockedWalletCreditConsumed,
        'blocked',
      );

      await tester.enterText(
        find.byKey(const Key('paymentReversalReasonField')),
        'testing blocked reversal',
      );
      await tester.tap(find.byKey(const Key('paymentReversalConfirmAction')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This payment cannot be reversed: the wallet credit it created '
          'has already been used.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets('a successful reversal with a reason navigates back to detail', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentReversePath('p1'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('paymentReversalReasonField')),
      'accidental duplicate entry',
    );
    await tester.tap(find.byKey(const Key('paymentReversalConfirmAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.reversePaymentCalls, hasLength(1));
    expect(
      fakeRepo.reversePaymentCalls.single.reversalReason,
      'accidental duplicate entry',
    );
    // Prompt 07 UAT-FIX-04 regression: the RPC's `p_group_id` must be
    // the current group's id ('g1', from `paymentMembership()`), never
    // the paying member's own membershipId ('m1', from
    // `fakePaymentDetail()`) — passing the wrong id made
    // `has_group_permission` check an id that never matches the
    // caller's real membership row, denying every role (not just
    // ADMIN) with a misleading "permission denied".
    expect(fakeRepo.reversePaymentCalls.single.groupId, 'g1');
    expect(find.text('Payment Detail'), findsOneWidget);
  });

  testWidgets('renders with no crash at desktop/tablet width, showing the '
      '"← Payment Detail" back link (regression: backTo was set without '
      'the required backLabel, throwing a null-check error building '
      'UmojaPage on any non-mobile width)', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    // pumpPaymentsApp defaults to a mobile viewport — widen it to
    // exercise UmojaPage's desktop/tablet "← [backLabel]" link path.
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    router.go(AppRoutes.paymentReversePath('p1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final backLink = find.byKey(const Key('umojaPageDesktopBackLink'));
    expect(backLink, findsOneWidget);
    expect(
      find.descendant(of: backLink, matching: find.text('Payment Detail')),
      findsOneWidget,
    );
  });
}
