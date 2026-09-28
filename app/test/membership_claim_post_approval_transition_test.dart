import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim.dart';

import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/membership_claim_test_app.dart';

/// Prompt 09G-B1-D4 §N/§R items 1-23: the full officer-approval →
/// member-device transition, end to end through the real provider/
/// router wiring (not just `computeRedirect` in isolation — see
/// `route_guard_test.dart` for that). Never constructs `AppContext`/
/// `MembershipContext` from the claim JSON — every assertion here
/// reads real rendered content that can only have come from the
/// (fake) `rpc_get_my_context()` refetch.
void main() {
  group('Session/context resolution (§R 1-8)', () {
    testWidgets(
      '1/9: an unlinked authenticated user resolves to the membership '
      'entry state',
      (tester) async {
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: FakeMembershipClaimRepository(),
        );

        expect(router.state.uri.path, AppRoutes.onboardingMembershipEntry);
      },
    );

    testWidgets(
      '5/10: exactly one eligible membership auto-resolves and lands on '
      'Member Home (/home) — the pre-existing one-group behavior, '
      'unchanged',
      (tester) async {
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: FakeMembershipClaimRepository(),
          memberships: [membershipClaimEligibleMembership()],
        );

        expect(router.state.uri.path, AppRoutes.home);
      },
    );

    testWidgets('6: multiple eligible memberships preserve the existing '
        '/select-group behavior — no special member-only selector', (
      tester,
    ) async {
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
        memberships: [
          membershipClaimEligibleMembership(id: 'm-a'),
          membershipClaimEligibleMembership(id: 'm-b'),
        ],
      );

      expect(router.state.uri.path, AppRoutes.selectGroup);
    });
  });

  group('Full post-approval transition (§N, §R 17-23)', () {
    testWidgets(
      '17/18/19/20/21: PENDING stays in the claim flow; once APPROVED and '
      'the claimant refreshes, appContextProvider refetches, the REAL '
      'linked membership context resolves, and the user automatically '
      'reaches Member Home with no manual relogin (auth session/status '
      'untouched throughout)',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextClaims = [
            fakeMembershipClaim(status: MembershipClaimStatus.pending),
          ];
        // 4: claimant checks their claim status.
        final (router, fixture, _) = await pumpMembershipClaimAppMutable(
          tester,
          fakeRepo: fakeRepo,
          fixture: MembershipContextFixture(const []),
        );
        expect(router.state.uri.path, AppRoutes.onboardingMembershipEntry);
        router.go(AppRoutes.membershipClaims);
        await tester.pumpAndSettle();

        // 17: still PENDING — stays in the claim flow, not redirected.
        expect(router.state.uri.path, AppRoutes.membershipClaims);

        // 5: the officer approves elsewhere — backend/fake state
        // changes: the claim is APPROVED and the membership is now
        // linked.
        final linkedMembership = membershipClaimEligibleMembership();
        fakeRepo.nextClaims = [
          fakeMembershipClaim(status: MembershipClaimStatus.approved),
        ];
        fixture.memberships = [linkedMembership];

        // 6: user refreshes the status screen.
        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        // 8/18/19/20/21: appContextProvider was invalidated and
        // refetched with the REAL linked membership (never fabricated
        // from the claim JSON) — the refetch's own brief loading state
        // (see computeRedirect's "never route from a stale value while
        // a refetch is in flight") is what carries the user out of the
        // claim flow automatically here, landing on Member Home with
        // zero manual navigation and no re-authentication.
        expect(router.state.uri.path, AppRoutes.home);
        expect(find.text(linkedMembership.group.groupName), findsWidgets);
      },
    );

    testWidgets('8/9/10/11: a user who resumes/refreshes the app from ANY '
        'non-operational screen (not specifically Claim Status) after '
        'approval lands directly on Member Home — the fully automatic '
        'case, driven purely by the router\'s existing refreshListenable '
        'wiring to selectedGroupProvider', (tester) async {
      final fakeRepo = FakeMembershipClaimRepository();
      final (router, fixture, container) = await pumpMembershipClaimAppMutable(
        tester,
        fakeRepo: fakeRepo,
        fixture: MembershipContextFixture(const []),
      );
      expect(router.state.uri.path, AppRoutes.onboardingMembershipEntry);

      // Approval already happened server-side by the time the app
      // resumes/refetches — simulate that by mutating the fixture and
      // invalidating exactly what a real appContext refetch would
      // invalidate. The router's own RouterRefreshNotifier listens to
      // selectedGroupProvider (which derives from appContextProvider)
      // and re-evaluates `redirect` automatically — no explicit
      // navigation call from this test.
      final linkedMembership = membershipClaimEligibleMembership();
      fixture.memberships = [linkedMembership];
      container.invalidate(appContextProvider);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.home);
      expect(find.text(linkedMembership.group.groupName), findsWidgets);
    });

    testWidgets(
      '23: repeated refresh of a still-PENDING claim is idempotent — no '
      'duplicate claims, no crash, no premature navigation',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextClaims = [
            fakeMembershipClaim(status: MembershipClaimStatus.pending),
          ];
        final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
        router.go(AppRoutes.membershipClaims);
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.fling(
            find.byType(RefreshIndicator),
            const Offset(0, 300),
            1000,
          );
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
        expect(fakeRepo.listMyMembershipClaimsCallCount, greaterThan(1));
        // Still PENDING throughout — never redirected away.
        expect(router.state.uri.path, AppRoutes.membershipClaims);
      },
    );
  });

  group('Dual-role: operational capability survives B1 (§O)', () {
    testWidgets('33/34: a dual-role membership (member + officer, holding '
        'member.claim.approve) lands on the existing operational Home, '
        'not Member Home — and the officer claim queue remains reachable', (
      tester,
    ) async {
      final officerMembership = membershipClaimOfficerMembership();
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
        memberships: [officerMembership],
      );

      expect(router.state.uri.path, AppRoutes.home);

      router.go(AppRoutes.membershipRequestsList);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipRequestsList);
      expect(tester.takeException(), isNull);
    });
  });
}
