import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/supabase/supabase_client_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

MembershipContext _membership() {
  return const MembershipContext(
    membershipId: 'm-admin',
    group: GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin Caller',
    roleCodes: ['ADMIN'],
    permissionCodes: ['member.view'],
  );
}

final _fakeUser = User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class _FakeUserNotifier extends Notifier<User?> {
  @override
  User? build() => _fakeUser;
  void set(User? user) => state = user;
}

final _fakeUserProvider = NotifierProvider<_FakeUserNotifier, User?>(
  _FakeUserNotifier.new,
);

Future<({FakeAuthRepository auth, ProviderContainer container})>
_pumpMoreScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeAuth = FakeAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        isSupabaseConfiguredProvider.overrideWithValue(true),
        currentSupabaseUserProvider.overrideWith(
          (ref) => ref.watch(_fakeUserProvider),
        ),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [_membership()],
          ),
        ),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(UmojaApp)),
  );

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Zaidi'),
    ),
  );
  await tester.pumpAndSettle();

  return (auth: fakeAuth, container: container);
}

/// Prompt 05E §13/§14: "Toka" is the only exit action in More/Usalama,
/// and it is always a real Supabase sign-out — there is no more
/// separate local-only "lock" concept, no "switch account" confirmation
/// dialog, and no PIN-unlock screen to land on. The next screen is
/// always the phone + PIN login screen.
void main() {
  testWidgets('Toka calls Supabase signOut and lands on the phone + PIN '
      'login screen', (tester) async {
    final fakes = await _pumpMoreScreen(tester);

    await tester.tap(find.text('Toka'));
    await tester.pumpAndSettle();

    expect(fakes.auth.signOutCallCount, 1);

    // FakeAuthRepository.signOut() itself never drives auth state
    // (matching how the real AuthRepository abstraction doesn't either
    // — Supabase Auth's own state stream does that) — simulate the
    // resulting signedOut event the same way the rest of the suite
    // does.
    fakes.container.read(_fakeUserProvider.notifier).set(null);
    await tester.pumpAndSettle();

    expect(find.text('Karibu Umoja'), findsOneWidget);
  });
}
