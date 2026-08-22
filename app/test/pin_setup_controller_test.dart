import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/security/controllers/pin_setup_controller.dart';
import 'package:umoja/features/security/providers/lock_state_provider.dart';
import 'package:umoja/features/security/providers/pin_repository_provider.dart';

import 'fakes/fake_pin_repository.dart';

void main() {
  late FakePinRepository fakePins;
  late ProviderContainer container;

  setUp(() {
    fakePins = FakePinRepository();
    container = ProviderContainer(
      overrides: [
        pinRepositoryProvider.overrideWithValue(fakePins),
        authUserIdProvider.overrideWithValue('u1'),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'the first entry advances to the confirm step without saving anything',
    () {
      container.read(pinSetupControllerProvider.notifier).submitFirst('1234');

      final state = container.read(pinSetupControllerProvider);
      expect(state.step, PinSetupStep.confirmPin);
      expect(fakePins.setPinCalls, isEmpty);
    },
  );

  test(
    'matching confirmation saves the PIN for the current user and unlocks',
    () async {
      final notifier = container.read(pinSetupControllerProvider.notifier);
      notifier.submitFirst('1234');
      final ok = await notifier.submitConfirm('1234');

      expect(ok, isTrue);
      expect(fakePins.setPinCalls, ['u1']);
      expect(await fakePins.hasPin('u1'), isTrue);
      expect(container.read(lockStateProvider), LockState.unlocked);
    },
  );

  test(
    'a mismatched confirmation restarts from the first step, saving nothing',
    () async {
      final notifier = container.read(pinSetupControllerProvider.notifier);
      notifier.submitFirst('1234');
      final ok = await notifier.submitConfirm('9999');

      expect(ok, isFalse);
      expect(fakePins.setPinCalls, isEmpty);
      final state = container.read(pinSetupControllerProvider);
      expect(state.step, PinSetupStep.enterPin);
      expect(state.mismatch, isTrue);
    },
  );
}
