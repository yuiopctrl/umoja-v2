import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/theme/umoja_colors.dart';
import 'package:umoja/features/auth/data/auth_failure.dart';
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

// Prompt 05E-A: regression coverage for the PIN-setup button-state,
// retry, and layout/theme fixes — complements pin_flow_test.dart
// (which covers the enter/confirm/mismatch happy paths) and
// pin_recovery_navigation_test.dart (which covers the recovery reuse).

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

Future<FakeAuthRepository> _pumpPinSetup(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeAuth = FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        authUserIdProvider.overrideWithValue('u1'),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        // Reactive, not a fixed `false`: `PinSetupController.submitConfirm`
        // invalidates this provider on a *successful* setup-pin call, and
        // the retry test below needs that to actually flip true so the
        // router can navigate into the app — a static override would
        // never let that be observed.
        hasPinCredentialProvider.overrideWith(
          (ref) async =>
              fakeAuth.setupPinCalls.isNotEmpty &&
              fakeAuth.setupPinFailure == null,
        ),
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
  return fakeAuth;
}

FilledButton _filledButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  testWidgets('the Continue button is disabled until the PIN is complete', (
    tester,
  ) async {
    await _pumpPinSetup(tester);
    expect(_filledButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(
      _filledButton(tester).onPressed,
      isNull,
      reason: '3 digits is still incomplete',
    );
  });

  testWidgets(
    'the button keeps its enabled (deep-red, not pale-disabled) visual '
    'with a loading indicator while a setup-pin request is in flight',
    (tester) async {
      final fakeAuth = await _pumpPinSetup(tester);
      final gate = Completer<void>();
      fakeAuth.setupPinGate = gate;

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      // Single frame only — the request is deliberately held open by
      // `gate`, so pumpAndSettle would hang waiting for it to resolve.
      await tester.pump();

      expect(
        _filledButton(tester).onPressed,
        isNotNull,
        reason: 'in flight must not fall back to the disabled style',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a server failure shows a retryable error, never navigates into the '
    'app, and resubmitting the same PIN succeeds',
    (tester) async {
      final fakeAuth = await _pumpPinSetup(tester);
      fakeAuth.setupPinFailure = const AuthFailure(
        AuthFailureType.network,
        'Network error. Check your connection and try again.',
      );

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      expect(
        find.text('Imeshindikana kuhifadhi PIN. Jaribu tena.'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(fakeAuth.setupPinCalls, ['1234']);
      expect(
        _filledButton(tester).onPressed,
        isNotNull,
        reason: 'a failure must leave the button usable for retry',
      );

      fakeAuth.setupPinFailure = null;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(fakeAuth.setupPinCalls, ['1234', '1234']);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('remains usable with no layout overflow at 360x800 and 390x844', (
    tester,
  ) async {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      await _pumpPinSetup(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsOneWidget);
    }
  });

  testWidgets(
    'auth screens use the light Umoja theme even when the platform is in '
    'dark mode (prompt 05E-A §8 — dark mode has no polished target yet)',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _pumpPinSetup(tester);

      final scheme = Theme.of(tester.element(find.byType(Scaffold).first))
          .colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, UmojaColors.primary);
    },
  );
}
