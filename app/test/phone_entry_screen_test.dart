import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/core/widgets/umoja_code_input.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/fake_membership_invitation_repository.dart';
import 'fakes/membership_invitation_test_app.dart';

/// Prompt 09G-B1-E4 §C/§G: `/auth/phone`'s first-time-mode variant and
/// its "Have an invitation?" discoverability link. The ordinary
/// returning-login regression coverage (phone+PIN fields render/accept
/// input, theming) already lives in `auth_theme_test.dart`/
/// `account_switch_pin_cycle_test.dart` — this file covers only what
/// this prompt actually changed.
void main() {
  group('PhoneEntryScreen (Prompt 09G-B1-E4 §C/§G)', () {
    testWidgets('default (no query param): the ordinary phone+PIN login form '
        'renders exactly as before — no regression', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedOut,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go(AppRoutes.authPhone);
      await tester.pumpAndSettle();

      expect(find.byType(UmojaCodeInput), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('First time? Verify by OTP'), findsOneWidget);
    });

    testWidgets('?intent=create: starts in first-time mode — no PIN field, a '
        'single Continue action, and a way back to the login form', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedOut,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go(AppRoutes.authPhoneFirstTimePath);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.authPhone);
      expect(find.byType(UmojaCodeInput), findsNothing);
      expect(
        find.byKey(const Key('authCreateAccountContinueAction')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('switchToSignInAction')));
      await tester.pump();

      expect(find.byType(UmojaCodeInput), findsOneWidget);
    });

    testWidgets(
      'the "Have an invitation? Open Invitation" link is discoverable '
      'here and leads to the paste flow',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedOut,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go(AppRoutes.authPhone);
        await tester.pumpAndSettle();

        expect(find.text('Have an invitation?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('openInvitationAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.membershipInvitationOpen);
      },
    );
  });
}
