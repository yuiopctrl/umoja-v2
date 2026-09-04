import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/failure_messages.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';
import 'package:umoja/features/payments/data/supabase_payment_repository.dart';
import 'package:umoja/l10n/app_localizations_en.dart';
import 'package:umoja/l10n/app_localizations_sw.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09E-UAT-BLOCKER-04: reversing a principal prepayment whose
/// replacement schedule has since been superseded (a second
/// prepayment, a restructure, or an early settlement) correctly
/// BLOCKS server-side with `LOAN_PREPAYMENT_REVERSAL_BLOCKED_
/// SUBSEQUENT_ACTIVITY` — but `mapPaymentRepositoryError` had no
/// branch for that code, so it fell all the way through to the
/// generic "Something went wrong. Please try again." fallback,
/// collapsing an expected domain rejection into an apparent system
/// failure.
void main() {
  group('1: repository maps the domain error code to a dedicated failure', () {
    test('LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY maps to '
        'reversalBlockedSubsequentActivity, never unexpected', () {
      final error = PostgrestException(
        message: 'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
        code: 'P0001',
      );

      final failure = mapPaymentRepositoryError(error, StackTrace.current);

      expect(
        failure.type,
        PaymentFailureType.reversalBlockedSubsequentActivity,
      );
    });

    test('3: a genuinely unexpected Postgres error still maps to the '
        'generic fallback', () {
      final error = PostgrestException(
        message: 'some_never_before_seen_backend_error',
        code: 'XX000',
      );

      final failure = mapPaymentRepositoryError(error, StackTrace.current);

      expect(failure.type, PaymentFailureType.unexpected);
    });

    test('3b: a non-Postgres exception (e.g. a parsing TypeError) also '
        'still maps to the generic fallback, never this domain type', () {
      // A real, dynamically-thrown TypeError — the same shape as
      // Prompt 09E-UAT-BLOCKER-03's null-cast bug — never mistaken
      // for this domain rejection either.
      final dynamic notAString = 42;
      Object caught;
      try {
        caught = notAString as String;
      } catch (error) {
        caught = error;
      }

      final failure = mapPaymentRepositoryError(caught, StackTrace.current);

      expect(failure.type, PaymentFailureType.unexpected);
    });
  });

  group('2: UI renders the friendly localized message', () {
    testWidgets('EN: the exact recommended English message is shown', (
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

      fakeRepo.failure = const PaymentFailure(
        PaymentFailureType.reversalBlockedSubsequentActivity,
        'unused fallback',
      );

      await tester.enterText(
        find.byKey(const Key('paymentReversalReasonField')),
        'testing blocked reversal',
      );
      await tester.tap(find.byKey(const Key('paymentReversalConfirmAction')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          AppLocalizationsEn().paymentErrorReversalBlockedSubsequentActivity,
        ),
        findsOneWidget,
      );
      // Never the generic fallback, and never raw internals.
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
      expect(find.textContaining('LOAN_PREPAYMENT_REVERSAL'), findsNothing);
      expect(find.textContaining('rpc_reverse_payment'), findsNothing);
      expect(find.textContaining('P0001'), findsNothing);
    });

    testWidgets('SW: the Kiswahili message is shown (default language)', (
      tester,
    ) async {
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');

      final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.paymentReversePath('p1'));
      await tester.pumpAndSettle();

      fakeRepo.failure = const PaymentFailure(
        PaymentFailureType.reversalBlockedSubsequentActivity,
        'unused fallback',
      );

      await tester.enterText(
        find.byKey(const Key('paymentReversalReasonField')),
        'testing blocked reversal',
      );
      await tester.tap(find.byKey(const Key('paymentReversalConfirmAction')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          AppLocalizationsSw().paymentErrorReversalBlockedSubsequentActivity,
        ),
        findsOneWidget,
      );
    });
  });

  test('paymentFailureMessage resolves every PaymentFailureType (no runtime '
      'gap in the switch for the new domain type)', () {
    final l10nEn = AppLocalizationsEn();
    for (final type in PaymentFailureType.values) {
      expect(paymentFailureMessage(l10nEn, type), isNotEmpty);
    }
  });

  testWidgets(
    '4: an immediate safe reversal (no later activity) still succeeds '
    'normally and never shows the blocked-reversal message',
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

      await tester.enterText(
        find.byKey(const Key('paymentReversalReasonField')),
        'accidental duplicate entry',
      );
      await tester.tap(find.byKey(const Key('paymentReversalConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.reversePaymentCalls, hasLength(1));
      expect(
        find.text(
          AppLocalizationsEn().paymentErrorReversalBlockedSubsequentActivity,
        ),
        findsNothing,
      );
      // Navigated back to Payment Detail — the success path, unchanged.
      expect(find.text('Payment Detail'), findsOneWidget);
    },
  );
}
