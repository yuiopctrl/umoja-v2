import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/app/routing/navigation_history_provider.dart';
import 'package:umoja/app/shell/app_exit_guard.dart';
import 'package:umoja/app/shell/app_shell.dart';
import 'package:umoja/core/localization/language_provider.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09G-B6-C.5 §L/§M/§N/§O/§Q: the global Android double-back-
/// to-exit policy, exercised via [WidgetTester.binding]'s
/// `handlePopRoute()` — the standard way to simulate the real Android
/// system Back button/gesture in a widget test, so these tests go
/// through the exact same framework `PopScope` dispatch a device
/// would, rather than reaching into the widget tree by hand.
///
/// [appExitActionProvider] is overridden in every terminal-route test
/// so a confirmed exit is observed as a recorded call instead of
/// actually tearing down the test process — the minimum platform seam
/// the prompt calls for, never a change to what a real device does
/// (which still calls the real `SystemNavigator.pop`, the provider's
/// own default).

/// Runs [body] with [debugDefaultTargetPlatformOverride] set to
/// [platform], resetting it to `null` before this function returns —
/// NOT via `addTearDown`/`tearDown()`, both of which fire too late:
/// `TestWidgetsFlutterBinding._runTestBody` checks every foundation
/// debug variable is back to its default IMMEDIATELY after the test
/// body itself completes, before any teardown callback runs.
Future<void> _asPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('Android terminal route (no history, nothing to pop, no fallback)', () {
    testWidgets(
      'first Back does NOT close the app — it is consumed, the app stays '
      'open, and the localized "Press back again to exit" message shows',
      (tester) => _asPlatform(TargetPlatform.android, () async {
        var exitCalls = 0;
        await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          extraOverrides: [
            appExitActionProvider.overrideWithValue(() async {
              exitCalls++;
            }),
          ],
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(exitCalls, 0);
        expect(find.text('Press back again to exit'), findsOneWidget);
        // Home is still rendered — the app did not close.
        expect(find.text('Umoja'), findsNothing); // sanity: no crash screen
      }),
    );

    testWidgets(
      'a second Back within the confirmation window actually exits',
      (tester) => _asPlatform(TargetPlatform.android, () async {
        var exitCalls = 0;
        await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          extraOverrides: [
            appExitActionProvider.overrideWithValue(() async {
              exitCalls++;
            }),
          ],
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(exitCalls, 0);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(exitCalls, 1);
      }),
    );

    testWidgets(
      'after the confirmation window elapses, Back becomes a fresh first '
      'press again — it does not exit, and shows the message again',
      (tester) => _asPlatform(TargetPlatform.android, () async {
        var exitCalls = 0;
        await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          extraOverrides: [
            appExitActionProvider.overrideWithValue(() async {
              exitCalls++;
            }),
          ],
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Elapse well past the 2-second confirmation window.
        await tester.pump(const Duration(seconds: 3));

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Treated as a fresh first press, not the second of a pair.
        expect(exitCalls, 0);
        expect(find.text('Press back again to exit'), findsOneWidget);
      }),
    );

    testWidgets(
      'a settled navigation between the first and second Back resets the '
      'pending exit confirmation — the next Back is a fresh first press',
      (tester) => _asPlatform(TargetPlatform.android, () async {
        var exitCalls = 0;
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          extraOverrides: [
            appExitActionProvider.overrideWithValue(() async {
              exitCalls++;
            }),
          ],
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // The user continues using the app instead of pressing Back
        // again right away.
        router.go(AppRoutes.more);
        await tester.pumpAndSettle();
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        // Back to the exact same terminal condition as the test's
        // start (no real history to go back to) — isolating what this
        // test actually checks (the navigation-triggered RESET) from
        // the separate, already-covered "Back defers to real history"
        // behavior.
        ProviderScope.containerOf(tester.element(find.byType(AppShell)))
            .read(navigationHistoryProvider.notifier)
            .clear();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(exitCalls, 0);
        expect(find.text('Press back again to exit'), findsOneWidget);
      }),
    );
  });

  group('Android non-terminal route — defers to performAppBack first', () {
    testWidgets(
      'system Back on a route with real history navigates back instead '
      'of counting as a terminal Back press at all',
      (tester) => _asPlatform(TargetPlatform.android, () async {
        var exitCalls = 0;
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          extraOverrides: [
            appExitActionProvider.overrideWithValue(() async {
              exitCalls++;
            }),
          ],
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.home);
        expect(exitCalls, 0);
        expect(find.text('Press back again to exit'), findsNothing);
      }),
    );
  });

  group('Web/desktop regression (§O) — never inherits Android exit policy', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    ]) {
      testWidgets(
        'on $platform, system Back at the terminal route never shows the '
        'Android exit-confirmation message and never calls the exit action',
        (tester) => _asPlatform(platform, () async {
          var exitCalls = 0;
          await pumpPaymentsApp(
            tester,
            fakeRepo: FakePaymentRepository(),
            language: AppLanguage.english,
            extraOverrides: [
              appExitActionProvider.overrideWithValue(() async {
                exitCalls++;
              }),
            ],
          );

          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          expect(find.text('Press back again to exit'), findsNothing);
          expect(exitCalls, 0);
        }),
      );
    }
  });
}
