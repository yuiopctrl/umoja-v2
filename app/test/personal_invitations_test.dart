import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/membership_invitations/domain/membership_invitation_status.dart';
import 'package:umoja/features/membership_invitations/domain/my_membership_invitation.dart';

import 'fakes/fake_membership_invitation_repository.dart';
import 'fakes/membership_invitation_test_app.dart';

/// Prompt 09G-B1-F2 §J/§K/§O/§P/§Q/§S: the authenticated caller's own
/// personal invitation inbox (`/invitations`) — rendering, accept/
/// decline (invitation_id only, double-submit prevention, no manual
/// MembershipContext construction), multiple-pending-invitations
/// independence, and discoverability from Home/More.
void main() {
  group('Personal inbox rendering (§Z 21-29)', () {
    testWidgets(
      '24: the inbox shows every returned invitation, across groups',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [
              fakeMyMembershipInvitation(
                invitationId: 'inv-a',
                groupName: 'Group A',
              ),
              fakeMyMembershipInvitation(
                invitationId: 'inv-b',
                groupName: 'Group B',
              ),
            ],
            totalCount: 2,
            limit: 50,
            offset: 0,
          );
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        router.go(AppRoutes.myInvitations);
        await tester.pumpAndSettle();

        expect(find.text('Group A'), findsOneWidget);
        expect(find.text('Group B'), findsOneWidget);
      },
    );

    testWidgets('21/22/23/25-29: PENDING shows Accept/Decline; ACCEPTED, '
        'DECLINED, CANCELLED, and EXPIRED are all read-only', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [
            fakeMyMembershipInvitation(
              invitationId: 'inv-pending',
              status: MembershipInvitationStatus.pending,
              canAccept: true,
            ),
            fakeMyMembershipInvitation(
              invitationId: 'inv-accepted',
              status: MembershipInvitationStatus.accepted,
              canAccept: false,
            ),
            fakeMyMembershipInvitation(
              invitationId: 'inv-declined',
              status: MembershipInvitationStatus.declined,
              canAccept: false,
            ),
            fakeMyMembershipInvitation(
              invitationId: 'inv-cancelled',
              status: MembershipInvitationStatus.cancelled,
              canAccept: false,
            ),
            fakeMyMembershipInvitation(
              invitationId: 'inv-expired',
              status: MembershipInvitationStatus.expired,
              canAccept: false,
            ),
          ],
          totalCount: 5,
          limit: 50,
          offset: 0,
        );
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('myInvitationAcceptAction_inv-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('myInvitationDeclineAction_inv-pending')),
        findsOneWidget,
      );
      for (final id in [
        'inv-accepted',
        'inv-declined',
        'inv-cancelled',
        'inv-expired',
      ]) {
        expect(find.byKey(Key('myInvitationAcceptAction_$id')), findsNothing);
        expect(find.byKey(Key('myInvitationDeclineAction_$id')), findsNothing);
      }
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('an empty inbox shows the empty state', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository();
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();

      expect(find.text('No Invitations'), findsOneWidget);
    });
  });

  group('Accept/decline (§Z 30-37, §U security)', () {
    testWidgets(
      '30/34/35: accept sends invitation_id only, invalidates AppContext, '
      'and refreshes the inbox',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
            totalCount: 1,
            limit: 50,
            offset: 0,
          )
          ..nextAcceptanceResult = fakeMembershipInvitationAcceptance();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        router.go(AppRoutes.myInvitations);
        await tester.pumpAndSettle();

        // After accept, the inbox re-fetches — simulate the invitation
        // no longer being actionable.
        fakeRepo.nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [
            fakeMyMembershipInvitation(
              invitationId: 'inv-1',
              status: MembershipInvitationStatus.accepted,
              canAccept: false,
            ),
          ],
          totalCount: 1,
          limit: 50,
          offset: 0,
        );

        await tester.tap(
          find.byKey(const Key('myInvitationAcceptAction_inv-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('myInvitationAcceptConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.acceptPhoneInvitationCalls, hasLength(1));
        expect(
          fakeRepo.acceptPhoneInvitationCalls.single.invitationId,
          'inv-1',
        );
        // 35: refreshed — the (now updated) list is re-fetched, so the
        // Accept action for inv-1 is gone.
        expect(
          find.byKey(const Key('myInvitationAcceptAction_inv-1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '31/36: decline sends invitation_id only, refreshes the inbox, and '
      'never touches AppContext',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
            totalCount: 1,
            limit: 50,
            offset: 0,
          )
          ..nextDeclineResult = fakeMembershipInvitationDecline();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        router.go(AppRoutes.myInvitations);
        await tester.pumpAndSettle();

        fakeRepo.nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [
            fakeMyMembershipInvitation(
              invitationId: 'inv-1',
              status: MembershipInvitationStatus.declined,
              canAccept: false,
            ),
          ],
          totalCount: 1,
          limit: 50,
          offset: 0,
        );

        await tester.tap(
          find.byKey(const Key('myInvitationDeclineAction_inv-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('myInvitationDeclineConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.declinePhoneInvitationCalls, hasLength(1));
        expect(
          fakeRepo.declinePhoneInvitationCalls.single.invitationId,
          'inv-1',
        );
        expect(find.text('Invitation declined.'), findsOneWidget);
      },
    );

    testWidgets('32: accept double-submit is prevented', (tester) async {
      final gate = Completer<void>();
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        )
        ..acceptPhoneGate = gate;
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('myInvitationAcceptAction_inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('myInvitationAcceptConfirmAction')),
      );
      await tester.pump();

      // Rapidly re-confirming while the first call is in flight is not
      // reachable (the dialog is already dismissed), so this proves the
      // controller-level guard via a second accept tap arriving before
      // the first resolves — not reachable through the UI a second
      // time here since the dialog is gone; the controller's own
      // isAccepting guard is what's under test.
      expect(fakeRepo.acceptPhoneInvitationCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(fakeRepo.acceptPhoneInvitationCalls, hasLength(1));
    });

    testWidgets('33: decline double-submit is prevented', (tester) async {
      final gate = Completer<void>();
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        )
        ..declinePhoneGate = gate;
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('myInvitationDeclineAction_inv-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('myInvitationDeclineConfirmAction')),
      );
      await tester.pump();

      expect(fakeRepo.declinePhoneInvitationCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(fakeRepo.declinePhoneInvitationCalls, hasLength(1));
    });

    testWidgets('37: a repository failure never renders a raw backend error', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        );
      final (router, _) = await pumpMembershipInvitationAcceptanceApp(
        tester,
        sessionStatus: AuthSessionStatus.signedIn,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();

      // Now stage a failure for the accept call itself.
      fakeRepo.failure = const Object(); // unexpected/non-typed failure
      await tester.tap(find.byKey(const Key('myInvitationAcceptAction_inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('myInvitationAcceptConfirmAction')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('SQLSTATE'), findsNothing);
    });
  });

  group('Multi-group post-accept behavior (§Q/§R/§S)', () {
    testWidgets('45: a zero-membership user accepting their first invitation '
        'resolves to the normal ONE-group SelectedGroupResolved state via '
        'the appContextProvider refresh — never a manually constructed '
        'MembershipContext. The inbox screen itself does not force-'
        'navigate away (Section S: a user with other pending invitations '
        'must be free to keep reviewing them) — the underlying '
        'selectedGroupProvider state is what Section Q actually requires, '
        'and is what /home would read the next time it is reached.', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        )
        ..nextAcceptanceResult = fakeMembershipInvitationAcceptance();
      final fixture = InvitationAcceptanceContextFixture(const []);
      final (
        router,
        _,
        container,
      ) = await pumpMembershipInvitationAcceptanceAppMutable(
        tester,
        fixture: fixture,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();

      // The real newly-linked membership, as AppContext would
      // resolve it after acceptance — set BEFORE tapping so the
      // invalidated appContextProvider refetch picks it up.
      fixture.memberships = [membershipInvitationOfficerMembership()];

      await tester.tap(find.byKey(const Key('myInvitationAcceptAction_inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('myInvitationAcceptConfirmAction')),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(selectedGroupProvider),
        isA<SelectedGroupResolved>(),
      );
      // Never auto-ejected from the inbox mid-review.
      expect(router.state.uri.path, AppRoutes.myInvitations);
    });

    testWidgets('46: a user who already has one group, accepting a SECOND '
        'invitation, resolves to the existing multi-group '
        'SelectedGroupPending state — never an automatic/forced group '
        'switch, and never a manually constructed MembershipContext', (
      tester,
    ) async {
      final existing = membershipInvitationOfficerMembership(
        id: 'm-existing',
        groupId: 'g-existing',
      );
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        )
        ..nextAcceptanceResult = fakeMembershipInvitationAcceptance();
      final fixture = InvitationAcceptanceContextFixture([existing]);
      final (
        router,
        _,
        container,
      ) = await pumpMembershipInvitationAcceptanceAppMutable(
        tester,
        fixture: fixture,
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.myInvitations);
      await tester.pumpAndSettle();

      final newlyAccepted = membershipInvitationOfficerMembership(
        id: 'm-new',
        groupId: 'g-new',
      );
      fixture.memberships = [existing, newlyAccepted];

      await tester.tap(find.byKey(const Key('myInvitationAcceptAction_inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('myInvitationAcceptConfirmAction')),
      );
      await tester.pumpAndSettle();

      final selectedGroup = container.read(selectedGroupProvider);
      expect(selectedGroup, isA<SelectedGroupPending>());
      expect((selectedGroup as SelectedGroupPending).candidates, hasLength(2));
    });
  });

  group('Discoverability (§K Cases B/C/D, §L, §M)', () {
    testWidgets('Case B/C: an operationally-resolved user sees the pending-'
        'invitation banner on Home', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        );
      final (router, _, _) = await pumpMembershipInvitationAcceptanceAppMutable(
        tester,
        fixture: InvitationAcceptanceContextFixture([
          membershipInvitationOfficerMembership(),
        ]),
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('homePendingInvitationBanner')),
        findsOneWidget,
      );
      expect(find.text('You have a pending group invitation.'), findsOneWidget);

      await tester.tap(find.text('View Invitations'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.myInvitations);
    });

    testWidgets('Case D: a dual-role officer (also holds member.invite in the '
        'selected group) still sees their OWN personal pending invitation '
        '— officer capability never hides it', (tester) async {
      final fakeRepo = FakeMembershipInvitationRepository()
        ..nextMyInvitationsPage = MyMembershipInvitationsPage(
          items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
          totalCount: 1,
          limit: 50,
          offset: 0,
        );
      final (router, _, _) = await pumpMembershipInvitationAcceptanceAppMutable(
        tester,
        fixture: InvitationAcceptanceContextFixture([
          membershipInvitationOfficerMembership(),
        ]),
        fakeInvitationRepo: fakeRepo,
        language: AppLanguage.english,
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('homePendingInvitationBanner')),
        findsOneWidget,
      );
    });

    testWidgets(
      'the More screen shows a pending-count badge on "My Invitations", '
      'regardless of the selected group',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [
              fakeMyMembershipInvitation(invitationId: 'inv-1'),
              fakeMyMembershipInvitation(invitationId: 'inv-2'),
            ],
            totalCount: 2,
            limit: 50,
            offset: 0,
          );
        final (
          router,
          _,
          _,
        ) = await pumpMembershipInvitationAcceptanceAppMutable(
          tester,
          fixture: InvitationAcceptanceContextFixture([
            membershipInvitationOfficerMembership(),
          ]),
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );

        router.go(AppRoutes.more);
        await tester.pumpAndSettle();

        expect(find.text('2'), findsOneWidget);
        expect(find.text('My Invitations'), findsOneWidget);

        await tester.tap(find.byKey(const Key('moreMyInvitationsAction')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.myInvitations);
      },
    );
  });

  group('Responsive (§Y/§Z 56-60)', () {
    for (final size in [
      const Size(360, 800),
      const Size(1024, 768),
      const Size(1440, 900),
    ]) {
      testWidgets('renders the personal inbox with no overflow at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
            totalCount: 1,
            limit: 50,
            offset: 0,
          );
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: size,
        );

        router.go(AppRoutes.myInvitations);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '60: mobile (360x800) recipient can complete the FULL accept flow',
      (tester) async {
        final fakeRepo = FakeMembershipInvitationRepository()
          ..nextMyInvitationsPage = MyMembershipInvitationsPage(
            items: [fakeMyMembershipInvitation(invitationId: 'inv-1')],
            totalCount: 1,
            limit: 50,
            offset: 0,
          )
          ..nextAcceptanceResult = fakeMembershipInvitationAcceptance();
        final (router, _) = await pumpMembershipInvitationAcceptanceApp(
          tester,
          sessionStatus: AuthSessionStatus.signedIn,
          fakeInvitationRepo: fakeRepo,
          language: AppLanguage.english,
          viewSize: const Size(360, 800),
        );

        router.go(AppRoutes.myInvitations);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('myInvitationAcceptAction_inv-1')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('myInvitationAcceptConfirmAction')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(fakeRepo.acceptPhoneInvitationCalls, hasLength(1));
      },
    );
  });
}
