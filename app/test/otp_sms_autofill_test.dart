import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/utils/otp_autofill.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// "ADD OTP SMS AUTOFILL": regression coverage for `OtpAutofill`'s
/// integration into `OtpVerifyScreen` (the same wiring is duplicated
/// in `PinRecoveryVerifyScreen` — see its doc comment — so this suite
/// stands in for both). `smart_auth`'s real Android plugin has no
/// platform-channel handler in the widget-test environment (calling it
/// for real would throw `MissingPluginException`, which `OtpAutofill`
/// already catches and treats as "no code" — see the "manual entry"
/// test below, which deliberately exercises that *default*, unmocked
/// path) — everything else here overrides `otpAutofillProvider` with a
/// [FakeOtpAutofill] so the SMS-arrival side of the flow is
/// controllable without touching the real plugin.
class FakeOtpAutofill extends OtpAutofill {
  FakeOtpAutofill({this.codeToReturn, this.gate});

  final String? codeToReturn;
  final Completer<String?>? gate;
  int listenCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<String?> listenForCode() async {
    listenCallCount++;
    final gate = this.gate;
    if (gate != null) return gate.future;
    return codeToReturn;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount++;
  }
}

Future<FakeAuthRepository> _pumpOnOtpVerify(
  WidgetTester tester, {
  required OtpAutofill otpAutofill,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeAuth = FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(
          AuthSessionStatus.signedOut,
        ),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        otpAutofillProvider.overrideWithValue(otpAutofill),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, '0712345678');
  await tester.tap(find.text('Mara ya kwanza? Thibitisha namba kwa OTP'));
  await tester.pumpAndSettle();
  expect(find.text('Thibitisha'), findsOneWidget);

  return fakeAuth;
}

void main() {
  testWidgets(
    'an SMS-extracted OTP fills the code field and triggers exactly one '
    'verifyOtp call',
    (tester) async {
      final fakeOtp = FakeOtpAutofill(codeToReturn: '123456');
      final fakeAuth = await _pumpOnOtpVerify(tester, otpAutofill: fakeOtp);

      await tester.pumpAndSettle();

      expect(fakeAuth.verifiedOtps, [('+255712345678', '123456')]);
      expect(fakeOtp.listenCallCount, 1);
    },
  );

  testWidgets('manual entry still works when SMS autofill finds nothing (the '
      'default, real OtpAutofill() — never mocked here)', (tester) async {
    final fakeAuth = await _pumpOnOtpVerify(tester, otpAutofill: OtpAutofill());

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pumpAndSettle();

    expect(fakeAuth.verifiedOtps, [('+255712345678', '654321')]);
  });

  testWidgets(
    'a non-matching SMS (autofill resolves with null) never fills the '
    'field or calls verifyOtp on its own',
    (tester) async {
      final fakeOtp = FakeOtpAutofill(codeToReturn: null);
      final fakeAuth = await _pumpOnOtpVerify(tester, otpAutofill: fakeOtp);

      await tester.pumpAndSettle();

      expect(fakeAuth.verifiedOtps, isEmpty);
      expect(find.text('Thibitisha'), findsOneWidget);
    },
  );

  testWidgets(
    'autofill arriving after the user already typed a code is ignored — '
    'never overwrites/duplicates the in-progress manual entry',
    (tester) async {
      final gate = Completer<String?>();
      final fakeOtp = FakeOtpAutofill(gate: gate);
      final fakeAuth = await _pumpOnOtpVerify(tester, otpAutofill: fakeOtp);

      await tester.enterText(find.byType(TextField), '111111');
      await tester.pumpAndSettle();
      expect(fakeAuth.verifiedOtps, [('+255712345678', '111111')]);

      // The SMS "arrives" only now, after manual entry already
      // completed verification.
      gate.complete('999999');
      await tester.pumpAndSettle();

      expect(fakeAuth.verifiedOtps, [('+255712345678', '111111')]);
    },
  );

  testWidgets('the listener is cancelled once verification succeeds', (
    tester,
  ) async {
    final fakeOtp = FakeOtpAutofill(codeToReturn: null);
    await _pumpOnOtpVerify(tester, otpAutofill: fakeOtp);

    await tester.enterText(find.byType(TextField), '222222');
    await tester.pumpAndSettle();

    expect(fakeOtp.cancelCallCount, greaterThanOrEqualTo(1));
  });

  testWidgets('the listener is cancelled when the screen is disposed', (
    tester,
  ) async {
    final gate = Completer<String?>(); // Never completes.
    final fakeOtp = FakeOtpAutofill(gate: gate);
    await _pumpOnOtpVerify(tester, otpAutofill: fakeOtp);

    expect(fakeOtp.cancelCallCount, 0);

    // Unmount the whole tree — the same lifecycle event that fires
    // when the router navigates away.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(fakeOtp.cancelCallCount, 1);
  });
}
