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

/// Prompt 09G-B1-F-UAT-FIX-03: Invite Member/Sent Invitations/
/// Membership Requests moved off the Members screen entirely (no
/// header, no overflow menu, no in-body card — every prior FIX-01/
/// FIX-02 discoverability attempt has been removed) into ONE "Member
/// Management" navigation group: an expandable desktop/tablet sidebar
/// section (`app_shell.dart`), or a dedicated mobile screen reached
/// from More (`member_management_screen.dart`). This file replaces the
/// FIX-01/FIX-02 coverage that tested the now-removed UI with coverage
/// of the current architecture.
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
_pumpApp(
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

Key _sidebarChildKey(String path) => Key('memberManagementNavChild_$path');
Key _mobileRowKey(String path) => Key('memberManagementRow_$path');

/// Desktop-width helper: navigates to `/members` — the Member
/// Management sidebar group auto-expands, since Members is itself the
/// group's first child.
Future<void> _openMembersDesktop(WidgetTester tester, GoRouter router) async {
  router.go(AppRoutes.membersList);
  await tester.pumpAndSettle();
}

/// Mobile-width helper: More → Member Management.
Future<void> _openMemberManagementMobile(
  WidgetTester tester,
  GoRouter router,
) async {
  router.go(AppRoutes.more);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('moreMemberManagementAction')));
  await tester.pumpAndSettle();
}

void main() {
  group('Desktop/tablet Member Management sidebar group (§D)', () {
    testWidgets(
      'both permissions — Members, Invite Member, Sent Invitations, and '
      'Membership Requests all visible as sidebar children',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [_membership()],
          viewSize: const Size(1440, 900),
        );
        await _openMembersDesktop(tester, router);

        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvite)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvitationsList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'member.invite only — Members/Invite Member/Sent Invitations visible, '
      'Membership Requests hidden',
      (tester) async {
        final (router, _, _) = await _pumpApp(
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
          viewSize: const Size(1440, 900),
        );
        await _openMembersDesktop(tester, router);

        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvite)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvitationsList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'member.claim.approve only — Members/Membership Requests visible, '
      'Invite Member/Sent Invitations hidden',
      (tester) async {
        final (router, _, _) = await _pumpApp(
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
          viewSize: const Size(1440, 900),
        );
        await _openMembersDesktop(tester, router);

        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvite)),
          findsNothing,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvitationsList)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an ordinary member (neither permission) still sees Members — the '
      'directory itself is never hidden — but no officer children',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [
            _membership(
              roleCodes: const ['MEMBER'],
              permissionCodes: const ['group.view', 'member.view'],
            ),
          ],
          viewSize: const Size(1440, 900),
        );
        await _openMembersDesktop(tester, router);

        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvite)),
          findsNothing,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipInvitationsList)),
          findsNothing,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
          findsNothing,
        );
      },
    );

    testWidgets('tapping each sidebar child navigates to its own route', (
      tester,
    ) async {
      final (router, _, _) = await _pumpApp(
        tester,
        memberships: [_membership()],
        viewSize: const Size(1440, 900),
      );
      await _openMembersDesktop(tester, router);

      await tester.tap(
        find.byKey(_sidebarChildKey(AppRoutes.membershipInvite)),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipInvite);

      await tester.tap(
        find.byKey(_sidebarChildKey(AppRoutes.membershipInvitationsList)),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipInvitationsList);

      await tester.tap(
        find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipRequestsList);
    });

    testWidgets(
      'the group stays expanded/active while on any of its child routes',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [_membership()],
          viewSize: const Size(1440, 900),
        );
        router.go(AppRoutes.membershipInvite);
        await tester.pumpAndSettle();

        // Auto-expanded on arrival — every child, including Members
        // itself, is visible without needing to tap the group header.
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
          findsOneWidget,
        );
      },
    );

    for (final size in [const Size(1024, 768), const Size(1440, 900)]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()}: sidebar renders '
        'with no overflow',
        (tester) async {
          final (router, _, _) = await _pumpApp(
            tester,
            memberships: [_membership()],
            viewSize: size,
          );
          await _openMembersDesktop(tester, router);

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Mobile Member Management screen, reached from More (§E/§F)', () {
    testWidgets(
      'More shows the Member Management entry when a group is selected',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [_membership()],
        );
        router.go(AppRoutes.more);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('moreMemberManagementAction')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'both permissions — Members, Invite Member, Sent Invitations, and '
      'Membership Requests all visible as rows',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [_membership()],
        );
        await _openMemberManagementMobile(tester, router);

        expect(
          find.byKey(_mobileRowKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipInvite)),
          findsOneWidget,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipInvitationsList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipRequestsList)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('member.invite only — Invite Member/Sent Invitations visible, '
        'Membership Requests hidden', (tester) async {
      final (router, _, _) = await _pumpApp(
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
      await _openMemberManagementMobile(tester, router);

      expect(
        find.byKey(_mobileRowKey(AppRoutes.membershipInvite)),
        findsOneWidget,
      );
      expect(
        find.byKey(_mobileRowKey(AppRoutes.membershipInvitationsList)),
        findsOneWidget,
      );
      expect(
        find.byKey(_mobileRowKey(AppRoutes.membershipRequestsList)),
        findsNothing,
      );
    });

    testWidgets(
      'member.claim.approve only — Membership Requests visible, Invite '
      'Member/Sent Invitations hidden',
      (tester) async {
        final (router, _, _) = await _pumpApp(
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
        await _openMemberManagementMobile(tester, router);

        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipRequestsList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipInvite)),
          findsNothing,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipInvitationsList)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an ordinary member (neither permission) still sees Members but no '
      'officer rows',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [
            _membership(
              roleCodes: const ['MEMBER'],
              permissionCodes: const ['group.view', 'member.view'],
            ),
          ],
        );
        await _openMemberManagementMobile(tester, router);

        expect(
          find.byKey(_mobileRowKey(AppRoutes.membersList)),
          findsOneWidget,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipInvite)),
          findsNothing,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipInvitationsList)),
          findsNothing,
        );
        expect(
          find.byKey(_mobileRowKey(AppRoutes.membershipRequestsList)),
          findsNothing,
        );
      },
    );

    testWidgets('tapping each row navigates to its own route', (tester) async {
      final (router, _, _) = await _pumpApp(
        tester,
        memberships: [_membership()],
      );
      await _openMemberManagementMobile(tester, router);

      await tester.tap(find.byKey(_mobileRowKey(AppRoutes.membershipInvite)));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipInvite);
    });

    for (final size in [
      const Size(360, 800),
      const Size(1024, 768),
      const Size(1440, 900),
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()}: Member Management '
        'screen renders with no overflow',
        (tester) async {
          final (router, _, _) = await _pumpApp(
            tester,
            memberships: [_membership()],
            viewSize: size,
          );
          await _openMemberManagementMobile(tester, router);

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Members screen no longer offers management actions (§C/§I)', () {
    testWidgets(
      'the Members screen has no Invite Member/Sent Invitations/Membership '
      'Requests action anywhere in its own body, header, or an overflow '
      'menu',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [_membership()],
          viewSize: const Size(390, 844),
        );
        router.go(AppRoutes.membersList);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('membersHeaderOverflowAction')),
          findsNothing,
        );
        expect(find.text('Invite Member'), findsNothing);
        expect(find.text('Sent Invitations'), findsNothing);
        expect(find.text('Membership Requests'), findsNothing);
      },
    );
  });

  group(
    'Personal vs officer invitation route separation (§G, §D/§I, §O 13/14/15)',
    () {
      testWidgets('the personal /invitations route remains reachable and is a '
          'distinct constant/screen from the officer /members/invitations '
          'route', (tester) async {
        final (router, _, _) = await _pumpApp(
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
      });

      testWidgets(
        'dual-role fixture — an officer in Group A who also personally '
        'holds an invitation to Group B sees Group A Sent Invitations from '
        'the desktop sidebar, and their OWN invitation to Group B from the '
        'personal inbox — the two data sets are never confused',
        (tester) async {
          final (router, invitationRepo, _) = await _pumpApp(
            tester,
            memberships: [
              _membership(groupId: 'group-a', groupName: 'Group A'),
            ],
            viewSize: const Size(1440, 900),
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

          await _openMembersDesktop(tester, router);
          await tester.tap(
            find.byKey(_sidebarChildKey(AppRoutes.membershipInvitationsList)),
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

  group('Localization (§K)', () {
    testWidgets(
      'the Member Management children render in Swahili in the desktop '
      'sidebar',
      (tester) async {
        final (router, _, _) = await _pumpApp(
          tester,
          memberships: [_membership()],
          viewSize: const Size(1440, 900),
          language: AppLanguage.swahili,
        );
        await _openMembersDesktop(tester, router);

        expect(
          find.descendant(
            of: find.byKey(_sidebarChildKey(AppRoutes.membershipInvite)),
            matching: find.text('Karibisha Mwanachama'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(
              _sidebarChildKey(AppRoutes.membershipInvitationsList),
            ),
            matching: find.text('Mialiko Yaliyotumwa'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_sidebarChildKey(AppRoutes.membershipRequestsList)),
            matching: find.text('Maombi ya Uanachama'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('the Member Management screen renders in Swahili on mobile', (
      tester,
    ) async {
      final (router, _, _) = await _pumpApp(
        tester,
        memberships: [_membership()],
        language: AppLanguage.swahili,
      );
      await _openMemberManagementMobile(tester, router);

      expect(find.text('Usimamizi wa Wanachama'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(_mobileRowKey(AppRoutes.membershipInvite)),
          matching: find.text('Karibisha Mwanachama'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_mobileRowKey(AppRoutes.membershipInvitationsList)),
          matching: find.text('Mialiko Yaliyotumwa'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Home → Members navigation semantics regression (Prompt '
      '09G-B1-F-UAT-FIX-01)', () {
    testWidgets('the Home Members shortcut still uses shell-correct navigation '
        '(context.go), so the Members screen renders as a shell-root screen '
        'on mobile', (tester) async {
      await _pumpApp(tester, memberships: [_membership()]);

      await tester.tap(find.byKey(const Key('homeMembersShortcut')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Wanachama'), findsWidgets);
    });
  });
}
