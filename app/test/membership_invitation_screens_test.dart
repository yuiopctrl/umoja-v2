import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_status.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_membership_invitation_repository.dart';
import 'fakes/membership_invitation_test_app.dart';

Future<void> _goToMembersList(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('homeMembersShortcut')));
  await tester.pumpAndSettle();
}

/// An eligible invite target: ACTIVE, not yet login-linked.
GroupMemberPage _eligibleMemberPage() {
  return GroupMemberPage(
    items: [
      GroupMember(
        membershipId: 'm1',
        groupId: 'g-officer',
        displayName: 'Test Member',
        status: 'ACTIVE',
        createdAt: DateTime.utc(2026, 1, 15),
        isLoginLinked: false,
        roleCodes: const [],
      ),
    ],
    totalCount: 1,
    limit: 25,
    offset: 0,
  );
}

/// Prompt 09G-B1-E2 §O: officer member-invitation UX — Invite Member
/// flow (member/role selection, review, create, success), the
/// Invitations history screen (list/filter/cancel), Members
/// discoverability, and coexistence with the existing claim workflow.
void main() {
  group('Members discoverability (§O 9-12, 26)', () {
    testWidgets('9/11: an officer without member.invite/'
        'member.claim.approve sees neither action', (tester) async {
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationPlainMemberMembership(),
        fakeInvitationRepo: FakeMembershipInvitationRepository(),
        fakeMemberRepo: FakeMemberRepository(),
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);

      expect(find.text('Invite Member'), findsNothing);
      expect(find.text('Membership Requests'), findsNothing);
    });

    testWidgets('10/12: an officer holding both permissions sees both actions, '
        'explicitly labelled (never icon-only)', (tester) async {
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: FakeMembershipInvitationRepository(),
        fakeMemberRepo: FakeMemberRepository(),
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);

      expect(
        find.widgetWithText(OutlinedButton, 'Invite Member'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Membership Requests'),
        findsOneWidget,
      );
    });

    testWidgets(
      '26: a dual-role officer (also a plain member elsewhere) still sees '
      'both officer actions — permission alone gates visibility',
      (tester) async {
        await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(
            roleCodes: const ['MEMBER'],
          ),
          fakeInvitationRepo: FakeMembershipInvitationRepository(),
          fakeMemberRepo: FakeMemberRepository(),
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        await _goToMembersList(tester);

        // roleCodes is MEMBER, not ADMIN, but permissionCodes still
        // includes member.invite/member.claim.approve — the actual
        // backend-enforced gate.
        expect(
          find.widgetWithText(OutlinedButton, 'Invite Member'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Membership Requests'),
          findsOneWidget,
        );
      },
    );
  });

  group('Invite Member flow (§O 13-17)', () {
    testWidgets('13/14/15/17: select a member, select roles, review, create — '
        'invitation success renders member/roles/status/expiry', (
      tester,
    ) async {
      final memberRepo = FakeMemberRepository()
        ..nextListResult = _eligibleMemberPage();
      final invitationRepo = FakeMembershipInvitationRepository()
        ..nextCreateResult = fakeMembershipInvitation(roleCodes: ['TREASURER']);
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: invitationRepo,
        fakeMemberRepo: memberRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);

      await tester.tap(find.text('Invite Member'));
      await tester.pumpAndSettle();

      // 13: member selection — the picker uses the real
      // rpc_list_group_members contract via FakeMemberRepository.
      expect(find.text('Test Member'), findsOneWidget);
      await tester.tap(find.text('Test Member'));
      await tester.pumpAndSettle();

      // 14: role selection.
      expect(
        find.byKey(const Key('inviteRoleOption_TREASURER')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('inviteRoleOption_TREASURER')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueToReviewAction')),
      );
      await tester.pumpAndSettle();

      // 15: review shows member/roles and the explanatory text.
      expect(find.text('Test Member'), findsOneWidget);
      expect(find.textContaining('expires after 7 days'), findsOneWidget);

      // 17: create — success screen.
      await tester.tap(find.byKey(const Key('createInvitationAction')));
      await tester.pumpAndSettle();

      expect(find.text('Invitation Created'), findsOneWidget);
      expect(find.text('Test Member'), findsOneWidget);
      expect(invitationRepo.createMembershipInvitationCalls, hasLength(1));
      expect(invitationRepo.createMembershipInvitationCalls.single.roleCodes, [
        'TREASURER',
      ]);
    });

    testWidgets(
      '16: double-submit is prevented — a fast double-tap issues exactly '
      'one create call',
      (tester) async {
        final gate = Completer<void>();
        final invitationRepo = FakeMembershipInvitationRepository()
          ..createGate = gate;
        await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(),
          fakeInvitationRepo: invitationRepo,
          fakeMemberRepo: FakeMemberRepository()
            ..nextListResult = _eligibleMemberPage(),
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        await _goToMembersList(tester);

        await tester.tap(find.text('Invite Member'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Member'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inviteRoleOption_MEMBER')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('inviteMemberContinueToReviewAction')),
        );
        await tester.pumpAndSettle();

        final action = find.byKey(const Key('createInvitationAction'));
        await tester.tap(action);
        await tester.pump();
        // The first create call is now held in flight by the gate —
        // rapid re-taps while it's outstanding must not start a second
        // one.
        await tester.tap(action);
        await tester.tap(action);
        await tester.pump();

        expect(invitationRepo.createMembershipInvitationCalls, hasLength(1));

        gate.complete();
        await tester.pumpAndSettle();

        expect(invitationRepo.createMembershipInvitationCalls, hasLength(1));
      },
    );
  });

  group('Invitation token security (§O 18-20)', () {
    testWidgets(
      '18: Copy Invitation Link copies the link and shows a confirmation',
      (tester) async {
        var clipboardText = '';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        final invitationRepo = FakeMembershipInvitationRepository()
          ..nextCreateResult = fakeMembershipInvitation(token: 'b' * 64);
        await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(),
          fakeInvitationRepo: invitationRepo,
          fakeMemberRepo: FakeMemberRepository()
            ..nextListResult = _eligibleMemberPage(),
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        await _goToMembersList(tester);

        await tester.tap(find.text('Invite Member'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Member'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inviteRoleOption_MEMBER')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('inviteMemberContinueToReviewAction')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('createInvitationAction')));
        await tester.pumpAndSettle();

        // Prompt 09G-B1-E4 §H: a `flutter test` run is a VM (non-web)
        // target with no `APP_PUBLIC_WEB_URL` configured — exactly the
        // "not configured" case, which must fail safely (a localized
        // error, clipboard left untouched) rather than ever copying a
        // broken relative URL. The web-origin/native-configured
        // branches of the SAME builder are covered directly in
        // `test/invitation_link_builder_test.dart`, since a widget
        // test run on the VM can never genuinely exercise `kIsWeb`.
        await tester.tap(find.byKey(const Key('copyInvitationLinkAction')));
        await tester.pump();
        await tester.pump();

        expect(clipboardText, isNot(contains('b' * 64)));
        expect(
          find.text(
            "Sharing isn't set up on this device yet. Try again from "
            'the web app, or share the link from there instead.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('19/20: the invitation-created screen never renders a raw '
        'token_hash field, and the plaintext token itself is only ever '
        'embedded inside the copy/share link — never shown as bare text', (
      tester,
    ) async {
      final invitationRepo = FakeMembershipInvitationRepository()
        ..nextCreateResult = fakeMembershipInvitation(token: 'c' * 64);
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: invitationRepo,
        fakeMemberRepo: FakeMemberRepository()
          ..nextListResult = _eligibleMemberPage(),
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);

      await tester.tap(find.text('Invite Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inviteRoleOption_MEMBER')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueToReviewAction')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('createInvitationAction')));
      await tester.pumpAndSettle();

      // The bare 64-char token is never rendered as its own visible
      // Text widget on the success screen (it is only ever embedded
      // inside the link string handed to Clipboard/Share, which this
      // widget test does not render as on-screen text).
      expect(find.text('c' * 64), findsNothing);
      expect(find.textContaining('token_hash'), findsNothing);
    });
  });

  group('Invitations history screen (§O 21-23)', () {
    testWidgets('21: the officer queue renders member/roles/status/dates', (
      tester,
    ) async {
      final invitationRepo = FakeMembershipInvitationRepository()
        ..nextQueueItems = [
          fakeMembershipInvitationQueueItem(
            membershipDisplayName: 'Amina Hassan',
            roleCodes: ['TREASURER'],
          ),
        ];
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: invitationRepo,
        fakeMemberRepo: FakeMemberRepository(),
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);

      await tester.tap(find.text('Invitations'));
      await tester.pumpAndSettle();

      expect(find.text('Amina Hassan'), findsOneWidget);
      expect(find.text('Treasurer'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets(
      '22: cancelling a PENDING invitation requires confirmation, then '
      'calls the real cancel RPC and refreshes the list',
      (tester) async {
        final invitationRepo = FakeMembershipInvitationRepository()
          ..nextQueueItems = [
            fakeMembershipInvitationQueueItem(invitationId: 'invitation-1'),
          ];
        await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(),
          fakeInvitationRepo: invitationRepo,
          fakeMemberRepo: FakeMemberRepository(),
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        await _goToMembersList(tester);

        await tester.tap(find.text('Invitations'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('cancelInvitationAction_invitation-1')),
        );
        await tester.pumpAndSettle();

        // Confirmation dialog is shown; dismissing must NOT call cancel.
        expect(find.text('Cancel Invitation?'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('cancelInvitationDismissAction')),
        );
        await tester.pumpAndSettle();
        expect(invitationRepo.cancelMembershipInvitationCalls, isEmpty);

        await tester.tap(
          find.byKey(const Key('cancelInvitationAction_invitation-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('cancelInvitationConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(invitationRepo.cancelMembershipInvitationCalls, hasLength(1));
        expect(
          invitationRepo.cancelMembershipInvitationCalls.single.invitationId,
          'invitation-1',
        );
      },
    );

    testWidgets('23: a CANCELLED invitation remains visible in history (never '
        'deleted) and offers no Cancel action', (tester) async {
      final invitationRepo = FakeMembershipInvitationRepository()
        ..nextQueueItems = [
          fakeMembershipInvitationQueueItem(
            status: MembershipInvitationStatus.cancelled,
            membershipDisplayName: 'Cancelled Member',
          ),
        ];
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: invitationRepo,
        fakeMemberRepo: FakeMemberRepository(),
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);

      await tester.tap(find.text('Invitations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled Member'), findsOneWidget);
      expect(find.text('Cancel Invitation'), findsNothing);
    });
  });

  group('Responsive layouts (§O 24)', () {
    for (final size in [
      const Size(360, 800),
      const Size(1024, 768),
      const Size(1440, 900),
    ]) {
      testWidgets('renders Members with no overflow at ${size.width.toInt()}x'
          '${size.height.toInt()}', (tester) async {
        await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(),
          fakeInvitationRepo: FakeMembershipInvitationRepository(),
          fakeMemberRepo: FakeMemberRepository(),
          language: AppLanguage.english,
          viewSize: size,
        );

        await _goToMembersList(tester);

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Claim workflow coexistence (§O 25)', () {
    testWidgets(
      '25: existing Membership Requests navigation still works unchanged',
      (tester) async {
        final (router, _) = await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(),
          fakeInvitationRepo: FakeMembershipInvitationRepository(),
          fakeMemberRepo: FakeMemberRepository(),
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        await _goToMembersList(tester);

        await tester.tap(find.text('Membership Requests'));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/members/requests');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
