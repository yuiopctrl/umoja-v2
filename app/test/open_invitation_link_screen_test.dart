import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/fake_membership_invitation_repository.dart';
import 'fakes/membership_invitation_test_app.dart';

/// Prompt 09G-B1-E4 §E/§F: `/invite/open`, the in-app paste fallback
/// for a user who received an invitation link via WhatsApp/SMS but is
/// already inside the installed app.
void main() {
  group('OpenInvitationLinkScreen (Prompt 09G-B1-E4 §E/§F)', () {
    testWidgets(
      '15: paste flow while authenticated — a full valid URL navigates '
      'to /invite/:token',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go(AppRoutes.membershipInvitationOpen);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('openInvitationLinkField')),
          'https://umoja.example.org/invite/${'q' * 64}',
        );
        await tester.tap(find.byKey(const Key('openInvitationContinueAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/invite/${'q' * 64}');
      },
    );

    testWidgets('16: paste flow while signed out — a bare /invite/:token path '
        'navigates to the invitation, which then renders its own '
        'sign-in-to-continue state', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedOut,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go(AppRoutes.membershipInvitationOpen);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipInvitationOpen);

      await tester.enterText(
        find.byKey(const Key('openInvitationLinkField')),
        '/invite/${'r' * 64}',
      );
      await tester.tap(find.byKey(const Key('openInvitationContinueAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/invite/${'r' * 64}');
      expect(find.text('Sign in to view this invitation'), findsOneWidget);
    });

    testWidgets('an invalid link shows a friendly inline error, never a '
        'raw FormatException', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go(AppRoutes.membershipInvitationOpen);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('openInvitationLinkField')),
        'not a link at all',
      );
      await tester.tap(find.byKey(const Key('openInvitationContinueAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipInvitationOpen);
      expect(
        find.text(
          "That doesn't look like a valid invitation link. Check it and "
          'try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('FormatException'), findsNothing);
    });

    testWidgets('empty input is rejected with the same friendly error', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go(AppRoutes.membershipInvitationOpen);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openInvitationContinueAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipInvitationOpen);
      expect(
        find.text(
          "That doesn't look like a valid invitation link. Check it and "
          'try again.',
        ),
        findsOneWidget,
      );
    });
  });
}
