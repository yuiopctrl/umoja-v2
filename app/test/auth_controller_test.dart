import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_controller_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';

import 'fakes/fake_auth_repository.dart';

void main() {
  test(
    'signing out calls the repository and invalidates app-context state',
    () async {
      final fakeAuth = FakeAuthRepository();
      var fetchCount = 0;

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          appContextProvider.overrideWith((ref) async {
            fetchCount++;
            return const AppContext(
              userId: 'u1',
              profile: AppUserProfile(id: 'u1', fullName: 'Amina'),
              memberships: [],
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appContextProvider.future);
      expect(fetchCount, 1);

      await container.read(authControllerProvider).signOut();

      expect(fakeAuth.signOutCallCount, 1);

      // Invalidation means the next read recomputes rather than reusing
      // the previous (now stale) value.
      await container.read(appContextProvider.future);
      expect(fetchCount, 2);
    },
  );
}
