import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/features/auth/data/auth_failure.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/pin_bypass_overrides.dart';
import 'fakes/fake_auth_repository.dart';

MembershipContext _membership(
  String id,
  String groupName, {
  String status = 'ACTIVE',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'g-$id',
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: status,
    displayName: 'Member',
    roleCodes: const ['ADMIN'],
    permissionCodes: const ['group.view', 'group.manage'],
  );
}

void main() {
  testWidgets('a signed-out user lands on the phone-entry screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedOut,
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // "v2" is an implementation/project concept, never shown to users
    // (prompt 05A §10) — the brand wordmark artwork is shown instead.
    expect(find.text('Umoja v2'), findsNothing);
    expect(find.text('Karibu Umoja'), findsOneWidget);
    expect(find.text('Endelea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('an incomplete profile routes to profile onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith(
            (ref) async => const AppContext(
              userId: 'u1',
              profile: AppUserProfile(id: 'u1'),
              memberships: [],
            ),
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kamilisha Wasifu Wako'), findsOneWidget);
  });

  testWidgets('a complete profile with no group routes to group onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith(
            (ref) async => const AppContext(
              userId: 'u1',
              profile: AppUserProfile(id: 'u1', fullName: 'Amina'),
              memberships: [],
            ),
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tengeneza Kikundi Chako'), findsOneWidget);
  });

  testWidgets('one eligible group routes straight to home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith(
            (ref) async => AppContext(
              userId: 'u1',
              profile: const AppUserProfile(id: 'u1', fullName: 'Amina'),
              memberships: [_membership('m1', 'Umoja Wamama')],
            ),
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Umoja Wamama'), findsOneWidget);
    expect(find.text('Application foundation ready'), findsNothing);
    expect(find.textContaining('Permissions:'), findsNothing);
    // No fabricated financial data — those modules do not exist yet.
    expect(find.textContaining('Balance'), findsNothing);
    expect(find.textContaining('TZS'), findsNothing);
    expect(find.textContaining('Outstanding'), findsNothing);
    expect(find.textContaining('Collections'), findsNothing);
  });

  testWidgets('an inactive profile routes to the account-disabled screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith(
            (ref) async => const AppContext(
              userId: 'u1',
              profile: AppUserProfile(
                id: 'u1',
                fullName: 'Amina',
                isActive: false,
              ),
              memberships: [],
            ),
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ufikiaji wa akaunti umezimwa'), findsOneWidget);
    expect(find.text('Toka'), findsOneWidget);
  });

  testWidgets('a context load failure shows Retry, not a forced sign-out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith((ref) async {
            throw Exception('network down');
          }),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imeshindikana kupakia akaunti'), findsOneWidget);
    expect(find.text('Jaribu Tena'), findsOneWidget);
    expect(find.text('Toka'), findsOneWidget);
  });

  testWidgets(
    'a SUSPENDED-only membership shows the restricted screen with a create-group option',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...pinBypassOverrides(),
            authSessionStatusProvider.overrideWithValue(
              AuthSessionStatus.signedIn,
            ),
            appContextProvider.overrideWith(
              (ref) async => AppContext(
                userId: 'u1',
                profile: const AppUserProfile(id: 'u1', fullName: 'Amina'),
                memberships: [
                  _membership('m1', 'Old Group', status: 'SUSPENDED'),
                ],
              ),
            ),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uanachama umezuiwa'), findsOneWidget);
      expect(find.text('Tengeneza Kikundi Kipya'), findsOneWidget);
    },
  );

  testWidgets(
    'entering a valid phone and continuing moves to the OTP verify screen',
    (tester) async {
      final fakeAuth = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...pinBypassOverrides(),
            authSessionStatusProvider.overrideWithValue(
              AuthSessionStatus.signedOut,
            ),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0712345678');
      await tester.tap(find.text('Endelea'));
      await tester.pumpAndSettle();

      expect(fakeAuth.sentOtpTo, ['+255712345678']);
      expect(find.textContaining('+255 712 345 678'), findsOneWidget);
      expect(find.text('Thibitisha'), findsOneWidget);
    },
  );

  testWidgets(
    'an invalid OTP shows a safe inline error and stays on the verify screen',
    (tester) async {
      final fakeAuth = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...pinBypassOverrides(),
            authSessionStatusProvider.overrideWithValue(
              AuthSessionStatus.signedOut,
            ),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0712345678');
      await tester.tap(find.text('Endelea'));
      await tester.pumpAndSettle();

      fakeAuth.verifyOtpFailure = const AuthFailure(
        AuthFailureType.invalidOtp,
        'That code is not correct. Please check and try again.',
      );
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle(); // auto-verifies at 6 digits

      expect(
        find.text('Thibitisha'),
        findsOneWidget,
      ); // still on the verify screen
      expect(find.text('Namba ya uthibitisho si sahihi.'), findsOneWidget);
    },
  );
}
