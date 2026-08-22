import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/security/controllers/pin_unlock_controller.dart';
import 'package:umoja/features/security/providers/lock_state_provider.dart';
import 'package:umoja/features/security/providers/pin_repository_provider.dart';

import 'fakes/fake_pin_repository.dart';

void main() {
  late FakePinRepository fakePins;
  late ProviderContainer container;

  setUp(() async {
    fakePins = FakePinRepository();
    await fakePins.setPin(userId: 'u1', pin: '1234');
    container = ProviderContainer(
      overrides: [
        pinRepositoryProvider.overrideWithValue(fakePins),
        authUserIdProvider.overrideWithValue('u1'),
      ],
    );
    addTearDown(container.dispose);
    // Start locked, as a fresh app process would.
    container.read(lockStateProvider.notifier).lock();
  });

  test('the correct PIN unlocks', () async {
    final ok = await container
        .read(pinUnlockControllerProvider.notifier)
        .verify('1234');

    expect(ok, isTrue);
    expect(container.read(lockStateProvider), LockState.unlocked);
  });

  test('the wrong PIN fails and does not unlock', () async {
    final ok = await container
        .read(pinUnlockControllerProvider.notifier)
        .verify('0000');

    expect(ok, isFalse);
    expect(container.read(lockStateProvider), LockState.locked);
    expect(container.read(pinUnlockControllerProvider).invalid, isTrue);
  });

  test("the PIN belongs to the current auth user — another user's PIN does not "
      'unlock this session', () async {
    final otherUserContainer = ProviderContainer(
      overrides: [
        pinRepositoryProvider.overrideWithValue(fakePins),
        authUserIdProvider.overrideWithValue('u2'),
      ],
    );
    addTearDown(otherUserContainer.dispose);

    final ok = await otherUserContainer
        .read(pinUnlockControllerProvider.notifier)
        .verify('1234');

    expect(ok, isFalse);
  });

  test('a second verify call while one is in flight is ignored (no duplicate submission)', () async {
    final notifier = container.read(pinUnlockControllerProvider.notifier);
    final first = notifier.verify('1234');
    final second = notifier.verify('1234');

    await Future.wait([first, second]);

    expect(fakePins.verifyPinCalls, hasLength(1));
  });

  test('repeated wrong attempts trigger a temporary local rate limit, never a permanent lockout', () async {
    final notifier = container.read(pinUnlockControllerProvider.notifier);
    for (var i = 0; i < 5; i++) {
      await notifier.verify('0000');
    }

    final state = container.read(pinUnlockControllerProvider);
    expect(state.isRateLimited, isTrue);
    expect(state.cooldownUntil, isNotNull);
    // Not permanent: the cooldown has a concrete end time in the near future.
    expect(
      state.cooldownUntil!.isBefore(
        DateTime.now().add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
  });
}
