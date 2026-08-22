import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/controllers/pin_login_controller.dart';
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
    'a correct phone + PIN calls pin-login with the normalized phone',
    () async {
      final ok = await container
          .read(pinLoginControllerProvider.notifier)
          .submit(rawPhone: '0712345678', pin: '1234');

      expect(ok, isTrue);
      expect(fakeAuth.pinLoginCalls, [('+255712345678', '1234')]);
      expect(container.read(pinLoginControllerProvider).errorType, isNull);
    },
  );

  test('an invalid phone shows an error without calling pin-login', () async {
    final ok = await container
        .read(pinLoginControllerProvider.notifier)
        .submit(rawPhone: 'not a phone', pin: '1234');

    expect(ok, isFalse);
    expect(fakeAuth.pinLoginCalls, isEmpty);
    expect(
      container.read(pinLoginControllerProvider).errorType,
      AuthFailureType.invalidPhone,
    );
  });

  test('a wrong PIN / unknown phone surfaces the generic invalidCredentials '
      'error — pin-login never distinguishes the two (no account '
      'enumeration)', () async {
    fakeAuth.pinLoginFailure = const AuthFailure(
      AuthFailureType.invalidCredentials,
      'Phone number or PIN is incorrect.',
    );

    final ok = await container
        .read(pinLoginControllerProvider.notifier)
        .submit(rawPhone: '0712345678', pin: '0000');

    expect(ok, isFalse);
    expect(
      container.read(pinLoginControllerProvider).errorType,
      AuthFailureType.invalidCredentials,
    );
  });

  test(
    'a locked credential surfaces pinLocked, distinct from a wrong PIN',
    () async {
      fakeAuth.pinLoginFailure = const AuthFailure(
        AuthFailureType.pinLocked,
        'Try again in a few minutes.',
      );

      final ok = await container
          .read(pinLoginControllerProvider.notifier)
          .submit(rawPhone: '0712345678', pin: '1234');

      expect(ok, isFalse);
      expect(
        container.read(pinLoginControllerProvider).errorType,
        AuthFailureType.pinLocked,
      );
    },
  );

  test('a second submit while one is already in flight is ignored — auto-'
      'submit racing the manual button can never send two concurrent '
      'pin-login calls', () async {
    final gate = Completer<void>();
    fakeAuth.pinLoginGate = gate;
    final notifier = container.read(pinLoginControllerProvider.notifier);

    final first = notifier.submit(rawPhone: '0712345678', pin: '1234');
    // The first call is now in flight (isSubmitting == true) — a
    // second submit before it resolves must be a no-op.
    expect(container.read(pinLoginControllerProvider).isSubmitting, isTrue);

    final second = await notifier.submit(rawPhone: '0712345678', pin: '1234');
    expect(second, isFalse);
    expect(fakeAuth.pinLoginCalls, hasLength(1));

    gate.complete();
    final ok = await first;
    expect(ok, isTrue);
  });
}
