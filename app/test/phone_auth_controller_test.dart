import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/controllers/phone_auth_controller.dart';
import 'package:umoja/features/auth/data/auth_failure.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';

import 'fakes/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeAuth;
  late ProviderContainer container;

  setUp(() {
    fakeAuth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
    );
    addTearDown(container.dispose);
  });

  test(
    'submitting a valid phone sends an OTP and moves to awaitingCode',
    () async {
      final ok = await container
          .read(phoneAuthControllerProvider.notifier)
          .submitPhone('0712345678');

      expect(ok, isTrue);
      expect(fakeAuth.sentOtpTo, ['+255712345678']);

      final state = container.read(phoneAuthControllerProvider);
      expect(state.step, PhoneAuthStep.awaitingCode);
      expect(state.phone?.e164, '+255712345678');
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'submitting an invalid phone shows an error without calling the repository',
    () async {
      final ok = await container
          .read(phoneAuthControllerProvider.notifier)
          .submitPhone('not a phone');

      expect(ok, isFalse);
      expect(fakeAuth.sentOtpTo, isEmpty);

      final state = container.read(phoneAuthControllerProvider);
      expect(state.step, PhoneAuthStep.enteringPhone);
      expect(state.errorMessage, isNotNull);
    },
  );

  test(
    'a send-OTP failure surfaces a safe error message, not a raw exception',
    () async {
      fakeAuth.sendOtpFailure = const AuthFailure(
        AuthFailureType.tooManyRequests,
        'Too many attempts. Please wait a moment and try again.',
      );

      final ok = await container
          .read(phoneAuthControllerProvider.notifier)
          .submitPhone('0712345678');

      expect(ok, isFalse);
      final state = container.read(phoneAuthControllerProvider);
      expect(state.step, PhoneAuthStep.enteringPhone);
      expect(
        state.errorMessage,
        'Too many attempts. Please wait a moment and try again.',
      );
    },
  );

  test('an invalid OTP shows a safe error and does not crash', () async {
    await container
        .read(phoneAuthControllerProvider.notifier)
        .submitPhone('0712345678');
    fakeAuth.verifyOtpFailure = const AuthFailure(
      AuthFailureType.invalidOtp,
      'That code is not correct. Please check and try again.',
    );

    final ok = await container
        .read(phoneAuthControllerProvider.notifier)
        .verifyOtp('000000');

    expect(ok, isFalse);
    final state = container.read(phoneAuthControllerProvider);
    expect(
      state.errorMessage,
      'That code is not correct. Please check and try again.',
    );
    expect(state.isSubmitting, isFalse);
  });

  test('a correct OTP verifies successfully with no error', () async {
    await container
        .read(phoneAuthControllerProvider.notifier)
        .submitPhone('0712345678');

    final ok = await container
        .read(phoneAuthControllerProvider.notifier)
        .verifyOtp('123456');

    expect(ok, isTrue);
    expect(fakeAuth.verifiedOtps, [('+255712345678', '123456')]);
    final state = container.read(phoneAuthControllerProvider);
    expect(state.errorMessage, isNull);
  });

  test('changeNumber resets back to the phone-entry step', () async {
    await container
        .read(phoneAuthControllerProvider.notifier)
        .submitPhone('0712345678');
    container.read(phoneAuthControllerProvider.notifier).changeNumber();

    final state = container.read(phoneAuthControllerProvider);
    expect(state.step, PhoneAuthStep.enteringPhone);
    expect(state.phone, isNull);
  });
}
