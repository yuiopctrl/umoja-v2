import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/data/auth_failure.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/security/controllers/pin_setup_controller.dart';

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
    'the first entry advances to the confirm step without saving anything',
    () {
      container.read(pinSetupControllerProvider.notifier).submitFirst('1234');

      final state = container.read(pinSetupControllerProvider);
      expect(state.step, PinSetupStep.confirmPin);
      expect(fakeAuth.setupPinCalls, isEmpty);
    },
  );

  test('matching confirmation sends the PIN via setup-pin (never plaintext '
      'stored client-side beyond the in-flight call)', () async {
    final notifier = container.read(pinSetupControllerProvider.notifier);
    notifier.submitFirst('1234');
    final ok = await notifier.submitConfirm('1234');

    expect(ok, isTrue);
    expect(fakeAuth.setupPinCalls, ['1234']);
  });

  test(
    'a mismatched confirmation restarts from the first step, saving nothing',
    () async {
      final notifier = container.read(pinSetupControllerProvider.notifier);
      notifier.submitFirst('1234');
      final ok = await notifier.submitConfirm('9999');

      expect(ok, isFalse);
      expect(fakeAuth.setupPinCalls, isEmpty);
      final state = container.read(pinSetupControllerProvider);
      expect(state.step, PinSetupStep.enterPin);
      expect(state.mismatch, isTrue);
    },
  );

  test(
    'a setup-pin failure surfaces as a save error, saving nothing',
    () async {
      fakeAuth.setupPinFailure = const AuthFailure(
        AuthFailureType.network,
        'network error',
      );
      final notifier = container.read(pinSetupControllerProvider.notifier);
      notifier.submitFirst('1234');
      final ok = await notifier.submitConfirm('1234');

      expect(ok, isFalse);
      final state = container.read(pinSetupControllerProvider);
      expect(state.saveError, isTrue);
    },
  );
}
