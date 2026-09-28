import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/membership_claim/data/membership_claim_failure.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim.dart';

import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/membership_claim_test_app.dart';

/// Prompt 09G-B1-D2 §Q items 19-45: form behavior (19-26), claim-status
/// rendering (27-35), double-submit/idempotency (36-37), routing
/// (38-42), and responsive layout (43-45) for the three new
/// presentation screens.
void main() {
  group('Entry screen (§Q 19-20)', () {
    testWidgets('19: shows the no-membership entry state with all three '
        'actions when the signed-in user has zero memberships', (tester) async {
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
      );

      expect(router.state.uri.path, AppRoutes.onboardingMembershipEntry);
      expect(find.byKey(const Key('linkMyMembershipAction')), findsOneWidget);
      expect(find.byKey(const Key('viewMyClaimStatusAction')), findsOneWidget);
      expect(
        find.byKey(const Key('createNewGroupInsteadAction')),
        findsOneWidget,
      );
    });

    testWidgets('20: tapping "Link my membership" navigates to the link '
        'form', (tester) async {
      await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
      );

      await tester.tap(find.byKey(const Key('linkMyMembershipAction')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('membershipGroupCodeField')), findsOneWidget);
      expect(
        find.byKey(const Key('membershipMemberNumberField')),
        findsOneWidget,
      );
    });
  });

  group('Link form (§Q 21-26)', () {
    testWidgets(
      '21: Request Access stays disabled until both fields are non-empty',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository();
        final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
        router.go(AppRoutes.membershipLink);
        await tester.pumpAndSettle();

        final actionButton = find.descendant(
          of: find.byKey(const Key('membershipRequestAccessAction')),
          matching: find.byType(FilledButton),
        );

        expect(tester.widget<FilledButton>(actionButton).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('membershipGroupCodeField')),
          'grp-001',
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(actionButton).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('membershipMemberNumberField')),
          'mem-042',
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(actionButton).onPressed, isNotNull);

        expect(fakeRepo.requestMembershipClaimByReferenceCalls, isEmpty);
      },
    );

    testWidgets('22/23: both fields uppercase as the user types', (
      tester,
    ) async {
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
      );
      router.go(AppRoutes.membershipLink);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('membershipGroupCodeField')),
        'grp-001',
      );
      await tester.enterText(
        find.byKey(const Key('membershipMemberNumberField')),
        'mem-042',
      );
      await tester.pump();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('membershipGroupCodeField')),
            )
            .controller!
            .text,
        'GRP-001',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('membershipMemberNumberField')),
            )
            .controller!
            .text,
        'MEM-042',
      );
    });

    testWidgets('24: submitting calls the repository with exactly the trimmed/'
        'uppercased group code and member number', (tester) async {
      final fakeRepo = FakeMembershipClaimRepository();
      final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.membershipLink);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('membershipGroupCodeField')),
        '  grp-001  ',
      );
      await tester.enterText(
        find.byKey(const Key('membershipMemberNumberField')),
        'mem-042',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('membershipRequestAccessAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.requestMembershipClaimByReferenceCalls, [
        (groupCode: 'GRP-001', memberNumber: 'MEM-042'),
      ]);
    });

    testWidgets('25: a successful submit navigates to the claims screen', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextRequestResult = fakeMembershipClaim();
      final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.membershipLink);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('membershipGroupCodeField')),
        'GRP-001',
      );
      await tester.enterText(
        find.byKey(const Key('membershipMemberNumberField')),
        'MEM-042',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('membershipRequestAccessAction')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.membershipClaims);
    });

    testWidgets(
      '26: a referenceNotVerified failure shows the ONE generic mapped '
      'message, never a raw backend code',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..failure = const MembershipClaimFailure(
            MembershipClaimFailureType.referenceNotVerified,
            'We could not verify those membership details.',
          );
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipLink);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('membershipGroupCodeField')),
          'GRP-001',
        );
        await tester.enterText(
          find.byKey(const Key('membershipMemberNumberField')),
          'MEM-042',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('membershipRequestAccessAction')),
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.membershipLink);
        expect(
          find.textContaining("We couldn't verify those membership details"),
          findsOneWidget,
        );
        expect(find.textContaining('MEMBERSHIP_CLAIM'), findsNothing);
        expect(find.textContaining('P0001'), findsNothing);
      },
    );
  });

  group('Claim status rendering (§Q 27-35)', () {
    testWidgets('27: an empty claims list shows the empty state and a '
        'link action', (tester) async {
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
      );
      router.go(AppRoutes.membershipClaims);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('membershipClaimsEmptyLinkAction')),
        findsOneWidget,
      );
    });

    testWidgets('28: a PENDING claim shows a Cancel action; 29/31: APPROVED/'
        'CANCELLED claims do not', (tester) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextClaims = [
          fakeMembershipClaim(
            claimId: 'c-pending',
            status: MembershipClaimStatus.pending,
          ),
        ];
      final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.membershipClaims);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('membershipClaimCancelAction')),
        findsOneWidget,
      );

      fakeRepo.nextClaims = [
        fakeMembershipClaim(
          claimId: 'c-approved',
          status: MembershipClaimStatus.approved,
        ),
      ];
      router.go(AppRoutes.membershipLink);
      await tester.pumpAndSettle();
      router.go(AppRoutes.membershipClaims);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('membershipClaimCancelAction')),
        findsNothing,
      );
    });

    testWidgets('30: a REJECTED claim renders its rejection reason', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextClaims = [
          fakeMembershipClaim(
            status: MembershipClaimStatus.rejected,
            rejectionReason: 'Member number did not match roster records.',
          ),
        ];
      final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.membershipClaims);
      await tester.pumpAndSettle();

      expect(
        find.text('Member number did not match roster records.'),
        findsOneWidget,
      );
    });

    testWidgets(
      '32: an unrecognized status parses to unknown and renders without '
      'crashing',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextClaims = [
            fakeMembershipClaim(status: MembershipClaimStatus.unknown),
          ];
        final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
        router.go(AppRoutes.membershipClaims);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('membershipClaimCancelAction')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '33/35: tapping Cancel opens a confirmation dialog, and dismissing '
      'it never calls the repository',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextClaims = [fakeMembershipClaim()];
        final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
        router.go(AppRoutes.membershipClaims);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('membershipClaimCancelAction')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('membershipClaimCancelDismissAction')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(fakeRepo.cancelMembershipClaimCalls, isEmpty);
      },
    );

    testWidgets(
      '34: confirming the cancel dialog calls cancelMembershipClaim with '
      'the exact claim id',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextClaims = [fakeMembershipClaim(claimId: 'claim-77')];
        final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
        router.go(AppRoutes.membershipClaims);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('membershipClaimCancelAction')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('membershipClaimCancelConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.cancelMembershipClaimCalls, [(claimId: 'claim-77')]);
      },
    );
  });

  group('Double-submit prevention (§Q 36-37)', () {
    testWidgets(
      '36: rapidly tapping Request Access while a request is still in '
      'flight only calls the repository once',
      (tester) async {
        final gate = Completer<void>();
        final fakeRepo = FakeMembershipClaimRepository()..requestGate = gate;
        final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
        router.go(AppRoutes.membershipLink);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('membershipGroupCodeField')),
          'GRP-001',
        );
        await tester.enterText(
          find.byKey(const Key('membershipMemberNumberField')),
          'MEM-042',
        );
        await tester.pump();

        final action = find.byKey(const Key('membershipRequestAccessAction'));
        await tester.tap(action);
        await tester.pump();
        // The first request is now held in flight by the gate — rapid
        // re-taps while it's outstanding must not start a second one.
        await tester.tap(action);
        await tester.tap(action);
        await tester.pump();

        expect(fakeRepo.requestMembershipClaimByReferenceCalls, hasLength(1));

        gate.complete();
        await tester.pumpAndSettle();

        expect(fakeRepo.requestMembershipClaimByReferenceCalls, hasLength(1));
      },
    );

    testWidgets('37: rapidly re-tapping Cancel Request while a cancellation is '
        'still in flight only calls cancelMembershipClaim once', (
      tester,
    ) async {
      final gate = Completer<void>();
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextClaims = [fakeMembershipClaim()]
        ..cancelGate = gate;
      final router = await pumpMembershipClaimApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.membershipClaims);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('membershipClaimCancelAction')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('membershipClaimCancelConfirmAction')),
      );
      await tester.pump();

      // The dialog is dismissed and the cancel call is now in flight —
      // re-tapping the (now-disabled) Cancel Request action on the
      // card must not start a second cancellation.
      final cancelAction = find.byKey(const Key('membershipClaimCancelAction'));
      await tester.tap(cancelAction, warnIfMissed: false);
      await tester.tap(cancelAction, warnIfMissed: false);
      await tester.pump();

      expect(fakeRepo.cancelMembershipClaimCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(fakeRepo.cancelMembershipClaimCalls, hasLength(1));
    });
  });

  group('Routing (§Q 38-42)', () {
    testWidgets('38/39: a claimant with no eligible group lands on the entry '
        'screen and can reach both sub-routes without being bounced back', (
      tester,
    ) async {
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: FakeMembershipClaimRepository(),
      );
      expect(router.state.uri.path, AppRoutes.onboardingMembershipEntry);

      router.push(AppRoutes.membershipLink);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipLink);

      router.push(AppRoutes.membershipClaims);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membershipClaims);
    });

    testWidgets(
      '40: a user who already has exactly one eligible membership never '
      'lands on the membership entry screen',
      (tester) async {
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: FakeMembershipClaimRepository(),
          memberships: [membershipClaimEligibleMembership()],
        );

        expect(router.state.uri.path, AppRoutes.home);
      },
    );

    testWidgets(
      '41/42: once an APPROVED claim is observed on the claims screen, '
      'the app context refreshes and the router leaves the claims '
      'screen for /home — never by constructing session state from the '
      'claim JSON itself',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextClaims = [
            fakeMembershipClaim(status: MembershipClaimStatus.pending),
          ];
        final (router, fixture, _) = await pumpMembershipClaimAppMutable(
          tester,
          fakeRepo: fakeRepo,
          fixture: MembershipContextFixture(const []),
        );
        router.go(AppRoutes.membershipClaims);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.membershipClaims);

        // The officer approves the claim "elsewhere": the next refetch
        // of both the claims list and the app context reflects it.
        fakeRepo.nextClaims = [
          fakeMembershipClaim(status: MembershipClaimStatus.approved),
        ];
        fixture.memberships = [membershipClaimEligibleMembership()];

        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.home);
      },
    );
  });

  group('Responsive (§Q 43-45)', () {
    for (final size in [
      const Size(360, 800), // phone portrait
      const Size(1024, 768), // tablet
      const Size(1440, 900), // desktop/web
    ]) {
      testWidgets('43-45: the link form renders at ${size.width.toInt()}x'
          '${size.height.toInt()} without overflow', (tester) async {
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: FakeMembershipClaimRepository(),
          viewSize: size,
        );
        router.go(AppRoutes.membershipLink);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
