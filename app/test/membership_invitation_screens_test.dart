import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
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

/// An eligible invite target: ACTIVE, not yet login-linked, no phone
/// on file (the phone step must start empty).
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

/// Same as [_eligibleMemberPage], but the member already has a phone
/// on file — the phone step must prefill it (Prompt 09G-B1-F2 §F).
GroupMemberPage _eligibleMemberWithPhonePage() {
  return GroupMemberPage(
    items: [
      GroupMember(
        membershipId: 'm1',
        groupId: 'g-officer',
        displayName: 'Test Member',
        phone: '0712345678',
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

/// Drives the Invite Member flow through member selection and the
/// phone step, leaving the test at the role-selection step — shared by
/// every test below so the exact same navigation is never duplicated.
Future<void> _selectMemberAndPhone(
  WidgetTester tester, {
  String memberText = 'Test Member',
  String? phoneOverride,
}) async {
  await tester.tap(find.text('Invite Member'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(memberText));
  await tester.pumpAndSettle();
  if (phoneOverride != null) {
    await tester.enterText(
      find.byKey(const Key('invitePhoneField')),
      phoneOverride,
    );
  }
  await tester.tap(
    find.byKey(const Key('inviteMemberContinueFromPhoneAction')),
  );
  await tester.pumpAndSettle();
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

  group('Invite Member flow (§O 13-17, Prompt 09G-B1-F2 phone flow)', () {
    testWidgets('13/14/15/17: select a member, confirm phone, select roles, '
        'review, send — invitation success renders member/phone/roles/expiry '
        '(§Z 5/8/9)', (tester) async {
      final memberRepo = FakeMemberRepository()
        ..nextListResult = _eligibleMemberPage();
      final invitationRepo = FakeMembershipInvitationRepository()
        ..nextCreatePhoneResult = fakeMembershipPhoneInvitation(
          roleCodes: ['TREASURER'],
          targetPhoneE164: '+255712345678',
        );
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

      // 13/5: member selection — the picker uses the real
      // rpc_list_group_members contract via FakeMemberRepository.
      expect(find.text('Test Member'), findsOneWidget);
      await tester.tap(find.text('Test Member'));
      await tester.pumpAndSettle();

      // §Z 7: phone can be entered (no phone was on file for this
      // fixture, so the field starts empty).
      expect(find.byKey(const Key('invitePhoneField')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('invitePhoneField')),
        '0712345678',
      );
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueFromPhoneAction')),
      );
      await tester.pumpAndSettle();

      // 14/8: role selection.
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

      // 15: review shows member/phone/roles and the explanatory text.
      expect(find.text('Test Member'), findsOneWidget);
      expect(find.text('0712345678'), findsOneWidget);
      expect(find.textContaining('expires after 7 days'), findsOneWidget);

      // 17/10: send — success screen. Exact wire contract: group_id,
      // membership_id, phone, role_codes — no user_id, no role_id
      // (structural, the fake's call signature has no such parameter).
      await tester.tap(find.byKey(const Key('createInvitationAction')));
      await tester.pumpAndSettle();

      expect(find.text('Invitation Sent'), findsOneWidget);
      expect(find.text('Test Member'), findsOneWidget);
      expect(find.text('+255712345678'), findsOneWidget);
      expect(invitationRepo.createPhoneInvitationCalls, hasLength(1));
      final call = invitationRepo.createPhoneInvitationCalls.single;
      expect(call.groupId, 'g-officer');
      expect(call.membershipId, 'm1');
      expect(call.phone, '0712345678');
      expect(call.roleCodes, ['TREASURER']);
    });

    testWidgets('6: phone prefills from the selected member\'s recorded '
        'phone, and can still be corrected before sending', (tester) async {
      final invitationRepo = FakeMembershipInvitationRepository();
      await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: invitationRepo,
        fakeMemberRepo: FakeMemberRepository()
          ..nextListResult = _eligibleMemberWithPhonePage(),
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      await _goToMembersList(tester);
      await tester.tap(find.text('Invite Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Member'));
      await tester.pumpAndSettle();

      final phoneField = tester.widget<TextField>(
        find.byKey(const Key('invitePhoneField')),
      );
      expect(phoneField.controller?.text, '0712345678');

      // The officer can still correct it before sending.
      await tester.enterText(
        find.byKey(const Key('invitePhoneField')),
        '0712345999',
      );
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueFromPhoneAction')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inviteRoleOption_MEMBER')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueToReviewAction')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('createInvitationAction')));
      await tester.pumpAndSettle();

      expect(
        invitationRepo.createPhoneInvitationCalls.single.phone,
        '0712345999',
      );
    });

    testWidgets('7: a malformed phone is rejected client-side before the '
        'RPC is ever called', (tester) async {
      final invitationRepo = FakeMembershipInvitationRepository();
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
      await tester.enterText(
        find.byKey(const Key('invitePhoneField')),
        'not-a-phone',
      );
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueFromPhoneAction')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("That doesn't look like a valid Tanzanian mobile number."),
        findsOneWidget,
      );
      expect(invitationRepo.createPhoneInvitationCalls, isEmpty);
    });

    testWidgets(
      '9: ADMIN UX restriction preserved — a non-ADMIN inviter cannot '
      'select the ADMIN role option',
      (tester) async {
        await pumpMembershipInvitationApp(
          tester,
          membership: membershipInvitationOfficerMembership(
            roleCodes: const ['SECRETARY'],
          ),
          fakeInvitationRepo: FakeMembershipInvitationRepository(),
          fakeMemberRepo: FakeMemberRepository()
            ..nextListResult = _eligibleMemberPage(),
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        await _goToMembersList(tester);
        await _selectMemberAndPhone(tester, phoneOverride: '0712345678');

        final adminTile = tester.widget<CheckboxListTile>(
          find.byKey(const Key('inviteRoleOption_ADMIN')),
        );
        expect(adminTile.enabled, isFalse);
      },
    );

    testWidgets(
      '16: double-submit is prevented — a fast double-tap issues exactly '
      'one create call',
      (tester) async {
        final gate = Completer<void>();
        final invitationRepo = FakeMembershipInvitationRepository()
          ..createPhoneGate = gate;
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
        await _selectMemberAndPhone(tester, phoneOverride: '0712345678');
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

        expect(invitationRepo.createPhoneInvitationCalls, hasLength(1));

        gate.complete();
        await tester.pumpAndSettle();

        expect(invitationRepo.createPhoneInvitationCalls, hasLength(1));
      },
    );
  });

  group('Invitation success screen (§O 14-16, Prompt 09G-B1-F2 §G/§I)', () {
    testWidgets(
      '14/15/16: the success screen has NO invitation link, NO raw token, '
      'NO Copy Link, and NO Share Link action',
      (tester) async {
        final invitationRepo = FakeMembershipInvitationRepository()
          ..nextCreatePhoneResult = fakeMembershipPhoneInvitation();
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
        await _selectMemberAndPhone(tester, phoneOverride: '0712345678');
        await tester.tap(find.byKey(const Key('inviteRoleOption_MEMBER')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('inviteMemberContinueToReviewAction')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('createInvitationAction')));
        await tester.pumpAndSettle();

        expect(find.text('Invitation Sent'), findsOneWidget);
        expect(find.byKey(const Key('copyInvitationLinkAction')), findsNothing);
        expect(find.byKey(const Key('shareInvitationAction')), findsNothing);
        expect(find.textContaining('token'), findsNothing);
        expect(find.textContaining('http'), findsNothing);

        // View Invitations / Done, per §G.
        expect(
          find.byKey(const Key('invitationSentViewInvitationsAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('invitationSentDoneAction')),
          findsOneWidget,
        );
      },
    );
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

    testWidgets('59: mobile (360x800) can complete the FULL officer invitation '
        'workflow — member, phone, roles, review, send', (tester) async {
      final invitationRepo = FakeMembershipInvitationRepository()
        ..nextCreatePhoneResult = fakeMembershipPhoneInvitation();
      final (router, _) = await pumpMembershipInvitationApp(
        tester,
        membership: membershipInvitationOfficerMembership(),
        fakeInvitationRepo: invitationRepo,
        fakeMemberRepo: FakeMemberRepository()
          ..nextListResult = _eligibleMemberPage(),
        language: AppLanguage.english,
        viewSize: const Size(360, 800),
      );

      // Matches the real mobile bottom-nav path (a `go`, not a
      // `push` from Home) — a `go`-reached Members has nothing to
      // pop, making it a shell-root screen whose inline header (and
      // therefore the overflow menu) renders on mobile too; see
      // UmojaPage's `isShellRoot`/`showInlineHeader`.
      router.go(AppRoutes.membersList);
      await tester.pumpAndSettle();
      // Mobile collapses officer actions into the overflow menu.
      await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite Member').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Test Member'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(const Key('invitePhoneField')),
        '0712345678',
      );
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueFromPhoneAction')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('inviteRoleOption_MEMBER')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('inviteMemberContinueToReviewAction')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('createInvitationAction')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(invitationRepo.createPhoneInvitationCalls, hasLength(1));
    });
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
