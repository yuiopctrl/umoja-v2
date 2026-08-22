import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/utils/otp_autofill.dart';

/// Unit coverage for [OtpAutofill]'s internal SMS Retriever API /
/// User Consent API race — see `otp_sms_autofill_test.dart` for the
/// screen-level integration (which overrides [OtpAutofill.listenForCode]
/// wholesale via a fake subclass, so it never exercises this racing
/// logic itself).
///
/// Note: `defaultTargetPlatform` in the Flutter test environment is
/// Android by default, so [OtpAutofill.listenForCode] does reach the
/// injected listeners here rather than short-circuiting to `null`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Retriever API winning (fully automatic, no dialog) is returned '
      'even if User Consent has not yet resolved', () async {
    final consentGate = Completer<String?>(); // Never completes.
    var retrieverCalls = 0;
    var consentCalls = 0;

    final autofill = OtpAutofill(
      retrieverListener: () async {
        retrieverCalls++;
        return '123456';
      },
      userConsentListener: () async {
        consentCalls++;
        return consentGate.future;
      },
    );

    final code = await autofill.listenForCode();

    expect(code, '123456');
    expect(retrieverCalls, 1);
    expect(consentCalls, 1);
  });

  test('today (no app hash in the SMS yet), Retriever never matches, so '
      'User Consent is what actually resolves', () async {
    final autofill = OtpAutofill(
      retrieverListener: () async {
        // Simulates Play services never delivering a match — the
        // current real-world behavior until the NextSMS message
        // includes the app-signature hash.
        return Completer<String?>().future.timeout(
          const Duration(milliseconds: 20),
          onTimeout: () => null,
        );
      },
      userConsentListener: () async => '654321',
    );

    final code = await autofill.listenForCode();

    expect(code, '654321');
  });

  test(
    'both mechanisms failing/timing out resolves to null, never throws',
    () async {
      final autofill = OtpAutofill(
        retrieverListener: () async => null,
        userConsentListener: () async => null,
      );

      final code = await autofill.listenForCode();

      expect(code, isNull);
    },
  );

  test(
    'cancel() is safe to call even when nothing is listening (Android '
    'target platform, real smart_auth channel unavailable in tests)',
    () async {
      final autofill = OtpAutofill();
      await expectLater(autofill.cancel(), completes);
    },
  );
}
