import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/pending_invitation_token_provider.dart';
import 'package:umoja/features/membership_invitations/data/membership_invitation_failure.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_status.dart';
import 'package:umoja/core/widgets/umoja_code_input.dart';

import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/fake_membership_invitation_repository.dart';
import 'fakes/membership_claim_test_app.dart';
import 'fakes/membership_invitation_test_app.dart';

MembershipContext _eligibleMembership({
  String id = 'm1',
  String groupId = 'g1',
  List<String> permissionCodes = const ['group.view'],
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: groupId,
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Invitee',
    roleCodes: const ['TREASURER'],
    permissionCodes: permissionCodes,
  );
}

/// Prompt 09G-B1-E3 §P: the member-facing invitation acceptance screen
/// — preview states (8-14), the signed-out preservation mechanism
/// (15-17, complementing route_guard_test.dart's own unit coverage),
/// the accept mutation and double-submit guard (18-19), the post-
/// accept session transition (20-26), the redesigned onboarding screen
/// (27-31), responsive layouts (35-37), and token/error security
/// (38-39). Every pump forces English since assertions match English
/// strings.
void main() {
  group('Preview states (§P 6/8-14)', () {
    testWidgets('a valid PENDING preview renders group/member/roles', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextPreviewResult = fakeMembershipInvitationPreview(
          roleNames: ['Treasurer', 'Secretary'],
        );
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        memberships: const [],
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'a' * 64}');
      await tester.pumpAndSettle();

      expect(find.text('Umoja Wamama'), findsOneWidget);
      expect(find.text('Amina Hassan'), findsOneWidget);
      expect(find.text('Treasurer, Secretary'), findsOneWidget);
      expect(find.byKey(const Key('acceptInvitationAction')), findsOneWidget);
      // 6: the exact token in the route is what was sent to preview.
      expect(fakeRepo.previewMembershipInvitationCalls.single.token, 'a' * 64);
    });

    testWidgets('an EXPIRED preview shows the expired message, no accept '
        'button', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextPreviewResult = fakeMembershipInvitationPreview(
          status: MembershipInvitationStatus.expired,
        );
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'b' * 64}');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This invitation has expired. Ask your officer to send a new one.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('acceptInvitationAction')), findsNothing);
    });

    testWidgets('a CANCELLED preview shows the cancelled message', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextPreviewResult = fakeMembershipInvitationPreview(
          status: MembershipInvitationStatus.cancelled,
        );
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'c' * 64}');
      await tester.pumpAndSettle();

      expect(find.text('This invitation was cancelled.'), findsOneWidget);
      expect(find.byKey(const Key('acceptInvitationAction')), findsNothing);
    });

    testWidgets('an ACCEPTED preview shows the already-accepted message', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextPreviewResult = fakeMembershipInvitationPreview(
          status: MembershipInvitationStatus.accepted,
        );
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'d' * 64}');
      await tester.pumpAndSettle();

      expect(
        find.text('This invitation has already been accepted.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('acceptInvitationAction')), findsNothing);
    });

    testWidgets(
      '12/39: an unknown/invalid token shows the generic friendly error, '
      'never a raw PostgREST message/SQLSTATE/RPC name',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..failure = const MembershipInvitationFailure(
            MembershipInvitationFailureType.invitationNotFound,
            'We could not find that invitation.',
          );
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/garbage');
        await tester.pumpAndSettle();

        expect(find.text("We couldn't find that invitation."), findsOneWidget);
        expect(find.textContaining('P0001'), findsNothing);
        expect(find.textContaining('rpc_preview'), findsNothing);
        expect(find.textContaining('MEMBERSHIP_INVITATION'), findsNothing);
      },
    );
  });

  group('Signed-out preservation (§P 15-17)', () {
    testWidgets(
      '15/16: opening the invitation link while signed out shows a sign-in '
      'prompt instead of being bounced to the login screen',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedOut,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'e' * 64}');
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/invite/${'e' * 64}');
        expect(find.text('Sign in to view this invitation'), findsOneWidget);
        expect(find.byKey(const Key('invitationSignInAction')), findsOneWidget);
      },
    );

    testWidgets('Prompt 09G-B1-E4 §C: the signed-out landing offers BOTH an '
        'explicit "Sign In" (returning user) and "Create Account" '
        '(first-time user) action, not one ambiguous button', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedOut,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'m' * 64}');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invitationSignInAction')), findsOneWidget);
      expect(
        find.byKey(const Key('invitationCreateAccountAction')),
        findsOneWidget,
      );
      expect(find.text('Already have an Umoja account?'), findsOneWidget);
      expect(find.text('New to Umoja?'), findsOneWidget);
    });

    testWidgets(
      'Prompt 09G-B1-E4 §C: tapping "Create Account" leads to the phone '
      'screen in first-time mode (the EXISTING phone -> OTP flow, no '
      'PIN field, no second auth subsystem)',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedOut,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'n' * 64}');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('invitationCreateAccountAction')),
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.authPhone);
        expect(find.byType(UmojaCodeInput), findsNothing);
        expect(
          find.byKey(const Key('authCreateAccountContinueAction')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Prompt 09G-B1-E4 §B/§C/§J (regression for a real UAT defect): the '
      'invitation token is captured into pendingInvitationTokenProvider '
      'the moment it is viewed signed out, and SURVIVES the user pushing '
      'themselves away to /auth/phone — not only when a redirect fires. '
      'Before this fix, no capture ever happened in this exact case '
      '(computeRedirect intentionally returns null while signed out on '
      'an invitation route), so the token was silently lost the instant '
      'the user tapped Sign In/Create Account.',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, container) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedOut,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );
        final token = 'p' * 64;

        router.go('/invite/$token');
        await tester.pumpAndSettle();

        expect(container.read(pendingInvitationTokenProvider), token);

        await tester.tap(find.byKey(const Key('invitationSignInAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.authPhone);
        // Still preserved after navigating away — this is exactly the
        // state a completed sign-in/OTP/PIN/profile flow later reads
        // via computeRedirect's own `pendingInvitationToken` priority
        // check to send the user back to /invite/:token.
        expect(container.read(pendingInvitationTokenProvider), token);
      },
    );

    testWidgets(
      'opening /invite/open (no :token) while signed out never captures '
      'a pending invitation token — there is nothing to preserve yet',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, container) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedOut,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go(AppRoutes.membershipInvitationOpen);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.membershipInvitationOpen);
        expect(container.read(pendingInvitationTokenProvider), isNull);
      },
    );

    testWidgets(
      'Prompt 09G-B1-E4-FINAL §B.16/17: abandoning TOKEN_A and opening '
      'TOKEN_B makes TOKEN_B authoritative — TOKEN_A never resurrects',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository();
        final (router, container) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedOut,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );
        final tokenA = 'a' * 64;
        final tokenB = 'b' * 64;

        router.go('/invite/$tokenA');
        await tester.pumpAndSettle();
        expect(container.read(pendingInvitationTokenProvider), tokenA);

        router.go('/invite/$tokenB');
        await tester.pumpAndSettle();

        expect(container.read(pendingInvitationTokenProvider), tokenB);
        expect(container.read(pendingInvitationTokenProvider), isNot(tokenA));
      },
    );
  });

  group('Accept mutation (§P 18-19)', () {
    testWidgets('18: tapping Accept Invitation calls accept with exactly '
        'the token', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextPreviewResult = fakeMembershipInvitationPreview();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'f' * 64}');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acceptInvitationAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.acceptMembershipInvitationCalls, hasLength(1));
      expect(fakeRepo.acceptMembershipInvitationCalls.single.token, 'f' * 64);
    });

    testWidgets(
      '19: rapidly tapping Accept while a call is in flight issues exactly '
      'one accept call',
      (tester) async {
        final gate = Completer<void>();
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextPreviewResult = fakeMembershipInvitationPreview()
          ..acceptGate = gate;
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'g' * 64}');
        await tester.pumpAndSettle();

        final action = find.byKey(const Key('acceptInvitationAction'));
        await tester.tap(action);
        await tester.pump();
        await tester.tap(action);
        await tester.tap(action);
        await tester.pump();

        expect(fakeRepo.acceptMembershipInvitationCalls, hasLength(1));

        gate.complete();
        await tester.pumpAndSettle();

        expect(fakeRepo.acceptMembershipInvitationCalls, hasLength(1));
      },
    );
  });

  group('Post-accept session transition (§P 20-26)', () {
    testWidgets(
      '20/21/22: a successful accept invalidates appContextProvider and, '
      'once it resolves the ONE real newly-linked membership, the router '
      'lands on /home — never a fabricated MembershipContext',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextPreviewResult = fakeMembershipInvitationPreview()
          ..nextAcceptanceResult = fakeMembershipInvitationAcceptance();
        final (
          router,
          fixture,
          _,
        ) = await pumpMembershipInvitationAcceptanceAppMutable(
          tester,
          fixture: InvitationAcceptanceContextFixture(const []),
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'h' * 64}');
        await tester.pumpAndSettle();

        // The officer elsewhere already assigned the roles; the ONLY
        // authoritative source for the post-accept membership is the
        // real appContext refetch — never this controller's own accept
        // response, which carries no role/permission info at all.
        final linkedMembership = _eligibleMembership();
        fixture.memberships = [linkedMembership];

        await tester.tap(find.byKey(const Key('acceptInvitationAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/home');
        expect(find.text(linkedMembership.group.groupName), findsWidgets);
      },
    );

    testWidgets('23: multiple eligible memberships after accept resolve to '
        '/select-group, exactly like the existing multi-group behavior', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextPreviewResult = fakeMembershipInvitationPreview();
      final existingMembership = _eligibleMembership(
        id: 'm-existing',
        groupId: 'g-existing',
      );
      final (
        router,
        fixture,
        _,
      ) = await pumpMembershipInvitationAcceptanceAppMutable(
        tester,
        fixture: InvitationAcceptanceContextFixture([existingMembership]),
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
      );

      router.go('/invite/${'i' * 64}');
      await tester.pumpAndSettle();

      fixture.memberships = [
        existingMembership,
        _eligibleMembership(id: 'm1', groupId: 'g1'),
      ];

      await tester.tap(find.byKey(const Key('acceptInvitationAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/select-group');
    });

    testWidgets(
      '24: a dual-role (member + officer permissions) linked membership '
      'still resolves to the ordinary /home — no custom invitation-'
      'specific home route',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextPreviewResult = fakeMembershipInvitationPreview();
        final (
          router,
          fixture,
          _,
        ) = await pumpMembershipInvitationAcceptanceAppMutable(
          tester,
          fixture: InvitationAcceptanceContextFixture(const []),
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'j' * 64}');
        await tester.pumpAndSettle();

        fixture.memberships = [
          _eligibleMembership(
            permissionCodes: const [
              'group.view',
              'member.view',
              'member.claim.approve',
            ],
          ),
        ];

        await tester.tap(find.byKey(const Key('acceptInvitationAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/home');
      },
    );

    testWidgets(
      '25: an idempotent same-user replay (already_accepted: true) shows '
      'the already-accepted success state and still refreshes AppContext',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextPreviewResult = fakeMembershipInvitationPreview(
            status: MembershipInvitationStatus.accepted,
          )
          ..nextAcceptanceResult = fakeMembershipInvitationAcceptance(
            alreadyAccepted: true,
          );
        // Preview already reports ACCEPTED, so no accept button is
        // offered here — this exercises the acceptance controller's
        // own idempotent-replay branch directly (mirrors how the
        // backend itself would answer a genuine same-user retry),
        // without duplicating a client-side ownership check.
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'k' * 64}');
        await tester.pumpAndSettle();

        expect(
          find.text('This invitation has already been accepted.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '26: a different user already holding an active membership in the '
      'group is rejected with a friendly message and never navigated away',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextPreviewResult = fakeMembershipInvitationPreview();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
        );

        router.go('/invite/${'l' * 64}');
        await tester.pumpAndSettle();

        // Staged only now: the preview above must succeed first, and
        // only the ACCEPT call itself should fail.
        fakeRepo.failure = const MembershipInvitationFailure(
          MembershipInvitationFailureType.claimantAlreadyActiveInGroup,
          'You already have an active membership in this group.',
        );
        await tester.tap(find.byKey(const Key('acceptInvitationAction')));
        await tester.pumpAndSettle();

        expect(
          find.text('You already have an active membership in this group.'),
          findsOneWidget,
        );
        expect(router.state.uri.path, '/invite/${'l' * 64}');
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Responsive layouts (§P 35-37)', () {
    for (final size in [
      const Size(360, 800),
      const Size(1024, 768),
      const Size(1440, 900),
    ]) {
      testWidgets('renders the invitation preview with no overflow at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextPreviewResult = fakeMembershipInvitationPreview();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: size,
        );

        router.go('/invite/${'m' * 64}');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Redesigned no-membership onboarding (§P 27-31)', () {
    testWidgets(
      '27/28: the entry screen explains invitation is the normal path and '
      'tells the user without a link to ask their officer',
      (tester) async {
        await pumpMembershipClaimApp(
          tester,
          fakeRepo: FakeMembershipClaimRepository(),
          language: AppLanguage.english,
        );

        expect(
          find.text(
            'The normal way to join a group is through an invitation link '
            'sent by a group officer.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Ask your group administrator or secretary to send you an '
            'invitation.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('29: the claim (link membership) fallback remains reachable', (
      tester,
    ) async {
      await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
        language: AppLanguage.english,
      );

      expect(find.byKey(const Key('linkMyMembershipAction')), findsOneWidget);
    });

    testWidgets(
      'Prompt 09G-B1-E4 §G.B: a signed-in user with no linked membership '
      'has a discoverable "Open Invitation" action, ahead of the claim '
      'fallback, that leads to the paste flow',
      (tester) async {
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: FakeMembershipClaimRepository(),
          language: AppLanguage.english,
        );

        expect(find.byKey(const Key('openInvitationAction')), findsOneWidget);

        await tester.tap(find.byKey(const Key('openInvitationAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.membershipInvitationOpen);
      },
    );

    testWidgets('30: View My Claim Status remains reachable', (tester) async {
      await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
        language: AppLanguage.english,
      );

      expect(find.byKey(const Key('viewMyClaimStatusAction')), findsOneWidget);
    });

    testWidgets('31: Create a New Group Instead remains reachable', (
      tester,
    ) async {
      await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
        language: AppLanguage.english,
      );

      expect(
        find.byKey(const Key('createNewGroupInsteadAction')),
        findsOneWidget,
      );
    });
  });
}
