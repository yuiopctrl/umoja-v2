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
import 'package:umoja/features/security/providers/has_pin_credential_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';

/// Prompt 05E-B §11/§16: a fresh OTP verify for an identity that
/// *already* has a PIN credential configured server-side must never
/// show PIN setup again — OTP alone already re-proved possession of
/// the phone, so it goes straight into the app. This is the specific
/// scenario `pin_flow_test.dart`'s "already configured" test covers in
/// isolation (starting already signed in); this file instead drives it
/// end-to-end from the signed-out login screen through the real OTP
/// verify screen, so the transition itself — not just the resulting
/// steady state — is exercised.
User _fakeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class _FakeUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  void set(User? user) => state = user;
}

final _fakeUserProvider = NotifierProvider<_FakeUserNotifier, User?>(
  _FakeUserNotifier.new,
);

MembershipContext _membership(String uid) => MembershipContext(
  membershipId: 'm-$uid',
  group: const GroupContext(
    groupId: 'g1',
    groupName: 'Umoja Wamama',
    groupStatus: 'ACTIVE',
  ),
  membershipStatus: 'ACTIVE',
  displayName: 'Member $uid',
  roleCodes: const ['ADMIN'],
  permissionCodes: const ['member.view'],
);

void main() {
  testWidgets(
    'OTP verify success for an identity that already has a PIN credential '
    'goes straight to the app — never shows PIN setup, never loops',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSupabaseConfiguredProvider.overrideWithValue(true),
            currentSupabaseUserProvider.overrideWith(
              (ref) => ref.watch(_fakeUserProvider),
            ),
            authRepositoryProvider.overrideWithValue(fakeAuth),
            // The identity already has a PIN credential — this is the
            // whole point of the scenario.
            hasPinCredentialProvider.overrideWith((ref) async => true),
            appContextProvider.overrideWith((ref) async {
              final user = ref.watch(_fakeUserProvider);
              if (user == null) {
                throw StateError('appContextProvider read while signed out');
              }
              return AppContext(
                userId: user.id,
                profile: AppUserProfile(id: user.id, fullName: 'Test User'),
                memberships: [_membership(user.id)],
              );
            }),
            memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(UmojaApp)),
      );

      // Reach OTP verify the normal way: phone entry -> "Mara ya
      // kwanza? Thibitisha namba kwa OTP".
      await tester.enterText(find.byType(TextField).first, '0712345678');
      await tester.tap(find.text('Mara ya kwanza? Thibitisha namba kwa OTP'));
      await tester.pumpAndSettle();
      expect(find.text('Thibitisha'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();
      expect(fakeAuth.verifiedOtps, [('+255712345678', '123456')]);

      // Verifying the OTP establishes a real Supabase session — the
      // fake repository itself never drives auth state (matching the
      // real AuthRepository abstraction), so this simulates the
      // resulting signedIn event the same way the rest of the suite
      // does.
      container.read(_fakeUserProvider.notifier).set(_fakeUser('u1'));
      await tester.pumpAndSettle();

      expect(find.text('Tengeneza PIN'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
