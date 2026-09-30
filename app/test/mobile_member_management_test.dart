import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/membership_claim/providers/membership_claim_repository_provider.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_type.dart';
import 'package:umoja/features/membership_invitations/domain/my_membership_invitation.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/fake_membership_invitation_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 09G-B1-F-UAT-FIX-01: reproduces, then guards against
/// regressing, the physical-UAT defect where an officer who reached
/// Members via the Home "Members" shortcut card (rather than the
/// bottom-nav tab) saw NONE of Invite Member/Invitations/Membership
/// Requests on mobile. Root cause: that shortcut used `context.push`,
/// which left Members poppable — `UmojaPage`'s `isShellRoot` (and
/// therefore `showInlineHeader`, which carries every officer action)
/// is false for any poppable, non-mobile-AppBar screen on a narrow
/// viewport. Members is a `primaryOnMobile` shell tab
/// (`shell_destination.dart`), so it must be reached the same way the
/// bottom nav itself reaches it — via `context.go` — never `push`.
/// Fixed in `home_screen.dart`'s `homeMembersShortcut` `onTap`.
MembershipContext _membership({
  String id = 'm-officer',
  String groupId = 'g-officer',
  String groupName = 'Umoja Wamama',
  List<String> roleCodes = const ['ADMIN'],
  List<String> permissionCodes = const [
    'group.view',
    'member.view',
    'member.invite',
    'member.claim.approve',
  ],
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Officer One',
    roleCodes: roleCodes,
    permissionCodes: permissionCodes,
  );
}

Future<
  (GoRouter, FakeMembershipInvitationRepository, FakeMembershipClaimRepository)
>
_pumpHomeApp(
  WidgetTester tester, {
  required List<MembershipContext> memberships,
  Size viewSize = const Size(390, 844),
  AppLanguage? language,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final invitationRepo = FakeMembershipInvitationRepository();
  final claimRepo = FakeMembershipClaimRepository();

  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(membershipInvitationRepository: invitationRepo),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Officer One'),
          memberships: memberships,
        ),
      ),
      memberRepositoryProvider.overrideWithValue(
        FakeMemberRepository()..nextListResult = GroupMemberPage.empty,
      ),
      membershipClaimRepositoryProvider.overrideWithValue(claimRepo),
      if (language != null)
        languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return (container.read(routerProvider), invitationRepo, claimRepo);
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}

/// Reproduces the exact defect path: reach Members via the Home
/// shortcut card, never the bottom-nav tab directly.
Future<void> _goToMembersViaHomeShortcut(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('homeMembersShortcut')));
  await tester.pumpAndSettle();
}

void main() {
  group('Officer action visibility from Members via Home shortcut (mobile)', () {
    testWidgets(
      '1/2/3: full officer (member.invite + member.claim.approve) sees Invite '
      'Member, Invitations, and Membership Requests in the mobile overflow '
      'menu — even after reaching Members via the Home shortcut, never the '
      'bottom-nav tab',
      (tester) async {
        await _pumpHomeApp(tester, memberships: [_membership()]);
        await _goToMembersViaHomeShortcut(tester);

        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.byKey(const Key('inviteMemberNavAction')), findsOneWidget);
        expect(
          find.byKey(const Key('membershipInvitationsNavAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('membershipRequestsNavAction')),
          findsOneWidget,
        );
      },
    );

    testWidgets('4: member.invite only — Invite Member and officer Invitations '
        'visible, Membership Requests hidden', (tester) async {
      await _pumpHomeApp(
        tester,
        memberships: [
          _membership(
            roleCodes: const ['MEMBER'],
            permissionCodes: const [
              'group.view',
              'member.view',
              'member.invite',
            ],
          ),
        ],
      );
      await _goToMembersViaHomeShortcut(tester);
      await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inviteMemberNavAction')), findsOneWidget);
      expect(
        find.byKey(const Key('membershipInvitationsNavAction')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('membershipRequestsNavAction')),
        findsNothing,
      );
    });

    testWidgets(
      '5: member.claim.approve only — Membership Requests visible, Invite '
      'Member/officer Invitations hidden',
      (tester) async {
        await _pumpHomeApp(
          tester,
          memberships: [
            _membership(
              roleCodes: const ['MEMBER'],
              permissionCodes: const [
                'group.view',
                'member.view',
                'member.claim.approve',
              ],
            ),
          ],
        );
        await _goToMembersViaHomeShortcut(tester);
        await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('membershipRequestsNavAction')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('inviteMemberNavAction')), findsNothing);
        expect(
          find.byKey(const Key('membershipInvitationsNavAction')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '6: no relevant permissions — none of the three officer actions are '
      'offered, and the overflow menu itself does not render',
      (tester) async {
        await _pumpHomeApp(
          tester,
          memberships: [
            _membership(
              roleCodes: const ['MEMBER'],
              permissionCodes: const ['group.view', 'member.view'],
            ),
          ],
        );
        await _goToMembersViaHomeShortcut(tester);

        expect(
          find.byKey(const Key('membersHeaderOverflowAction')),
          findsNothing,
        );
        expect(find.byKey(const Key('inviteMemberNavAction')), findsNothing);
        expect(
          find.byKey(const Key('membershipInvitationsNavAction')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('membershipRequestsNavAction')),
          findsNothing,
        );
      },
    );
  });

  group('Tablet/desktop layouts render the same actions directly (§O 7/8)', () {
    for (final size in [const Size(1024, 768), const Size(1440, 900)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: full officer '
          'sees all three actions as labelled buttons, no overflow menu', (
        tester,
      ) async {
        await _pumpHomeApp(
          tester,
          memberships: [_membership()],
          viewSize: size,
        );
        await _goToMembersViaHomeShortcut(tester);

        expect(
          find.byKey(const Key('membersHeaderOverflowAction')),
          findsNothing,
        );
        expect(find.byKey(const Key('inviteMemberNavAction')), findsOneWidget);
        expect(
          find.byKey(const Key('membershipInvitationsNavAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('membershipRequestsNavAction')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Mobile navigation reaches the real officer screens (§O 9/10/11)', () {
    testWidgets('9: Invite Member navigates to the phone-invitation flow, '
        'reachable on Android/mobile — no platform gate blocks it', (
      tester,
    ) async {
      final (router, _, _) = await _pumpHomeApp(
        tester,
        memberships: [_membership()],
      );
      await _goToMembersViaHomeShortcut(tester);
      await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inviteMemberNavAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipInvite);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10: officer Invitations navigates to the group-scoped '
        'history route, distinct from the personal inbox', (tester) async {
      final (router, _, _) = await _pumpHomeApp(
        tester,
        memberships: [_membership()],
      );
      await _goToMembersViaHomeShortcut(tester);
      await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('membershipInvitationsNavAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipInvitationsList);
      expect(router.state.uri.path, isNot(AppRoutes.myInvitations));
      expect(tester.takeException(), isNull);
    });

    testWidgets('11: Membership Requests navigates to the existing '
        'claim-review queue', (tester) async {
      final (router, _, _) = await _pumpHomeApp(
        tester,
        memberships: [_membership()],
      );
      await _goToMembersViaHomeShortcut(tester);
      await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('membershipRequestsNavAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipRequestsList);
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'Personal vs officer invitation route separation (§D/§I, §O 13/14/15)',
    () {
      testWidgets(
        '13/14: the personal /invitations route remains reachable and is a '
        'distinct constant/screen from the officer /members/invitations route',
        (tester) async {
          final (router, _, _) = await _pumpHomeApp(
            tester,
            memberships: [_membership()],
          );

          expect(
            AppRoutes.myInvitations,
            isNot(AppRoutes.membershipInvitationsList),
          );

          router.push(AppRoutes.myInvitations);
          await tester.pumpAndSettle();
          expect(router.state.uri.path, AppRoutes.myInvitations);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '15: dual-role fixture — an officer in Group A who also personally '
        'holds an invitation to Group B sees Group A officer history from '
        'Members, and their OWN invitation to Group B from the personal '
        'inbox — the two data sets are never confused',
        (tester) async {
          final (router, invitationRepo, _) = await _pumpHomeApp(
            tester,
            memberships: [
              _membership(groupId: 'group-a', groupName: 'Group A'),
            ],
          );
          invitationRepo.nextQueueItems = [
            fakeMembershipInvitationQueueItem(
              invitationId: 'officer-history-item',
              type: MembershipInvitationType.phone,
              targetPhoneE164: '+255712000111',
              membershipDisplayName: 'Group A Invitee',
            ),
          ];
          invitationRepo.nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [
              fakeMyMembershipInvitation(
                invitationId: 'personal-inbox-item',
                groupName: 'Group B',
              ),
            ],
            totalCount: 1,
            limit: 50,
            offset: 0,
          );

          await _goToMembersViaHomeShortcut(tester);
          await tester.tap(
            find.byKey(const Key('membersHeaderOverflowAction')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('membershipInvitationsNavAction')),
          );
          await tester.pumpAndSettle();

          expect(router.state.uri.path, AppRoutes.membershipInvitationsList);
          expect(find.text('+255712000111'), findsOneWidget);
          expect(find.text('Group B'), findsNothing);

          router.push(AppRoutes.myInvitations);
          await tester.pumpAndSettle();

          expect(router.state.uri.path, AppRoutes.myInvitations);
          expect(find.text('Group B'), findsOneWidget);
          expect(find.text('+255712000111'), findsNothing);
        },
      );
    },
  );

  group('Localization (§O 17)', () {
    testWidgets('the three officer actions render in Swahili', (tester) async {
      await _pumpHomeApp(
        tester,
        memberships: [_membership()],
        language: AppLanguage.swahili,
      );
      await _goToMembersViaHomeShortcut(tester);
      await tester.tap(find.byKey(const Key('membersHeaderOverflowAction')));
      await tester.pumpAndSettle();

      expect(find.text('Karibisha Mwanachama'), findsOneWidget);
      expect(find.text('Mialiko'), findsOneWidget);
      expect(find.text('Maombi ya Uanachama'), findsOneWidget);
    });
  });
}
