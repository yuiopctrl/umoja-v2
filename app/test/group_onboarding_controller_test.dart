import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/providers/group_repository_provider.dart';
import 'package:umoja/features/onboarding/controllers/group_onboarding_controller.dart';

import 'fakes/fake_group_repository.dart';

void main() {
  late FakeGroupRepository fakeGroups;
  late ProviderContainer container;

  setUp(() {
    fakeGroups = FakeGroupRepository();
    container = ProviderContainer(
      overrides: [groupRepositoryProvider.overrideWithValue(fakeGroups)],
    );
    addTearDown(container.dispose);
  });

  test('creating a group calls the repository (rpc_create_group), not a direct insert', () async {
    final ok = await container
        .read(groupOnboardingControllerProvider.notifier)
        .createGroup(name: 'Umoja Wamama', description: 'A savings group');

    expect(ok, isTrue);
    expect(fakeGroups.createGroupCalls, hasLength(1));
    expect(fakeGroups.createGroupCalls.single.name, 'Umoja Wamama');
    expect(fakeGroups.createGroupCalls.single.description, 'A savings group');
  });

  test(
    'a blank group name is rejected before calling the repository',
    () async {
      final ok = await container
          .read(groupOnboardingControllerProvider.notifier)
          .createGroup(name: '   ');

      expect(ok, isFalse);
      expect(fakeGroups.createGroupCalls, isEmpty);
      expect(
        container.read(groupOnboardingControllerProvider).error,
        GroupOnboardingError.nameRequired,
      );
    },
  );

  test('an empty description is normalized to null', () async {
    await container
        .read(groupOnboardingControllerProvider.notifier)
        .createGroup(name: 'Umoja Vijana', description: '   ');

    expect(fakeGroups.createGroupCalls.single.description, isNull);
  });

  test(
    'a failed creation surfaces a safe error and leaves state resettable',
    () async {
      fakeGroups.failure = Exception('network down');

      final ok = await container
          .read(groupOnboardingControllerProvider.notifier)
          .createGroup(name: 'Umoja Wamama');

      expect(ok, isFalse);
      final state = container.read(groupOnboardingControllerProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.error, GroupOnboardingError.saveFailed);
    },
  );
}
