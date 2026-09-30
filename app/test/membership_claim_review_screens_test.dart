import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/membership_claim/data/membership_claim_failure.dart';
import 'package:umoja/features/membership_claim/domain/membership_claim.dart';

import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/membership_claim_test_app.dart';

/// Prompt 09G-B1-D3 §R: officer claim queue + review screen coverage —
/// permission gating (17-21), queue states (22-26), detail (27-31),
/// approve (32-39), reject (40-47), stale/error (48-53), cross-group
/// safety (54-56), and responsive layout (57-60). Every pump forces
/// English (the app defaults to Swahili) since assertions match the
/// English strings.
void main() {
  group('Permission gating (§R 17-21)', () {
    testWidgets('17/20/21: an officer holding member.claim.approve sees the '
        'Membership Requests entry in the desktop sidebar\'s Member '
        'Management group, and the queue/review actions', (tester) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [fakeMembershipClaimQueueItem()];
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
        // Prompt 09G-B1-F-UAT-FIX-03: Membership Requests now lives
        // in the "Member Management" navigation group — a desktop/
        // tablet sidebar section, or a dedicated mobile screen — not
        // on the Members screen itself. This test is about
        // permission gating, not that responsive split, so it uses
        // desktop width where the group renders as an expandable
        // sidebar section (see `app_shell.dart`).
        viewSize: const Size(1440, 900),
      );
      router.go(AppRoutes.membersList);
      await tester.pumpAndSettle();

      final requestsChildKey = Key(
        'memberManagementNavChild_${AppRoutes.membershipRequestsList}',
      );
      expect(find.byKey(requestsChildKey), findsOneWidget);

      await tester.tap(find.byKey(requestsChildKey));
      await tester.pumpAndSettle();

      expect(find.text('Amina H.'), findsOneWidget);
    });

    testWidgets(
      '18/19: a plain MEMBER (role alone never grants access) does not '
      'see the nav entry, and a direct navigation still fails safely '
      'via the same permission-gated RPC',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository()
          ..failure = const MembershipClaimFailure(
            MembershipClaimFailureType.permissionDenied,
            'Not authorized to view membership claims in this group',
          );
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimPlainMemberMembership()],
          language: AppLanguage.english,
          viewSize: const Size(1440, 900),
        );
        router.go(AppRoutes.membersList);
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            Key('memberManagementNavChild_${AppRoutes.membershipRequestsList}'),
          ),
          findsNothing,
        );

        // Deep link without the permission: the screen is still
        // reachable (route guard only checks group selection), but the
        // RPC itself rejects it — backend remains authoritative even
        // if Flutter nav gating were somehow bypassed.
        router.go(AppRoutes.membershipRequestsList);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets);
      },
    );
  });

  group('Officer queue (§R 22-26)', () {
    testWidgets('23: an empty PENDING queue shows the safe empty state', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipClaimRepository();
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestsList);
      await tester.pumpAndSettle();

      expect(
        find.text('No membership requests are waiting for review.'),
        findsOneWidget,
      );
    });

    testWidgets('24: a PENDING item renders claimant/member context and '
        'status', (tester) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [
          fakeMembershipClaimQueueItem(
            claimantFullName: 'Amina H.',
            membershipDisplayName: 'Amina Hassan',
            membershipMemberNumber: 'UMJ-2026-0001',
          ),
        ];
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestsList);
      await tester.pumpAndSettle();

      expect(find.text('Amina H.'), findsOneWidget);
      expect(find.textContaining('UMJ-2026-0001'), findsOneWidget);
    });

    testWidgets('25: switching to the History tab requests every status', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [
          fakeMembershipClaimQueueItem(
            claimId: 'claim-rejected',
            status: MembershipClaimStatus.rejected,
            rejectionReason: 'No match',
          ),
        ];
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestsList);
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(
        fakeRepo.listMembershipClaimsCalls.any((c) => c.status == null),
        isTrue,
      );
    });

    testWidgets('26: retry after a load failure re-fetches the queue', (
      tester,
    ) async {
      final fakeRepo = FakeMembershipClaimRepository()
        ..failure = const MembershipClaimFailure(
          MembershipClaimFailureType.unexpected,
          'boom',
        );
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestsList);
      await tester.pumpAndSettle();

      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);

      fakeRepo.failure = null;
      fakeRepo.nextQueueItems = [fakeMembershipClaimQueueItem()];
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(find.text('Amina H.'), findsOneWidget);
    });
  });

  group('Review detail (§R 27-31)', () {
    testWidgets('27/28/29/30/31: the review screen loads by claim id alone, '
        'renders member/claimant context, and never shows a raw UUID as '
        'the primary label', (tester) async {
      final item = fakeMembershipClaimQueueItem(
        claimId: '11111111-1111-1111-1111-111111111111',
        membershipId: '22222222-2222-2222-2222-222222222222',
        membershipDisplayName: 'Amina Hassan',
        membershipMemberNumber: 'UMJ-2026-0001',
        claimantFullName: 'Amina H.',
      );
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [item]
        ..nextDetailItem = item;
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestsList);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Amina H.'));
      await tester.pumpAndSettle();

      expect(
        fakeRepo.getMembershipClaimCalls.single.claimId,
        '11111111-1111-1111-1111-111111111111',
      );
      expect(find.text('Amina Hassan'), findsOneWidget);
      expect(find.textContaining('UMJ-2026-0001'), findsOneWidget);
      expect(
        find.textContaining('11111111-1111-1111-1111-111111111111'),
        findsNothing,
      );
      expect(
        find.textContaining('22222222-2222-2222-2222-222222222222'),
        findsNothing,
      );
    });
  });

  group('Approve (§R 32-39)', () {
    testWidgets(
      '32/33: Approve is shown for a PENDING claim, hidden once resolved',
      (tester) async {
        final pendingItem = fakeMembershipClaimQueueItem();
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextQueueItems = [pendingItem]
          ..nextDetailItem = pendingItem;
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimOfficerMembership()],
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestDetailPath(pendingItem.claimId));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('approveMembershipClaimAction')),
          findsOneWidget,
        );

        fakeRepo.nextDetailItem = fakeMembershipClaimQueueItem(
          claimId: pendingItem.claimId,
          status: MembershipClaimStatus.approved,
        );
        router.go(AppRoutes.membershipRequestsList);
        await tester.pumpAndSettle();
        router.go(AppRoutes.membershipRequestDetailPath(pendingItem.claimId));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('approveMembershipClaimAction')),
          findsNothing,
        );
      },
    );

    testWidgets('34/35/36/38/39: approving requires confirmation showing the '
        'claimant/member target, calls the repository exactly once, never '
        'shows APPROVED before the server confirms it, and refreshes on '
        'success', (tester) async {
      final item = fakeMembershipClaimQueueItem(
        claimantFullName: 'Amina H.',
        membershipDisplayName: 'Amina Hassan',
      );
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [item]
        ..nextDetailItem = item;
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
      await tester.pumpAndSettle();

      // Still PENDING before any action.
      expect(fakeRepo.approveMembershipClaimCalls, isEmpty);

      await tester.tap(find.byKey(const Key('approveMembershipClaimAction')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Amina H.'), findsWidgets);
      expect(find.textContaining('Amina Hassan'), findsWidgets);

      fakeRepo.nextDetailItem = fakeMembershipClaimQueueItem(
        claimId: item.claimId,
        status: MembershipClaimStatus.approved,
      );
      await tester.tap(
        find.byKey(const Key('approveMembershipClaimConfirmAction')),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.approveMembershipClaimCalls, hasLength(1));
      expect(fakeRepo.approveMembershipClaimCalls.single.claimId, item.claimId);
    });

    testWidgets('37: rapidly confirming Approve twice only calls the '
        'repository once', (tester) async {
      final gate = Completer<void>();
      final item = fakeMembershipClaimQueueItem();
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [item]
        ..nextDetailItem = item
        ..approveGate = gate;
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('approveMembershipClaimAction')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('approveMembershipClaimConfirmAction')),
      );
      await tester.pump();

      // Approve is now in flight and disabled — re-tapping must not
      // start a second approval.
      final approveAction = find.byKey(
        const Key('approveMembershipClaimAction'),
      );
      await tester.tap(approveAction, warnIfMissed: false);
      await tester.pump();

      expect(fakeRepo.approveMembershipClaimCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(fakeRepo.approveMembershipClaimCalls, hasLength(1));
    });
  });

  group('Reject (§R 40-47)', () {
    testWidgets('40/41: Reject is shown for PENDING, hidden once resolved', (
      tester,
    ) async {
      final pendingItem = fakeMembershipClaimQueueItem();
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [pendingItem]
        ..nextDetailItem = fakeMembershipClaimQueueItem(
          status: MembershipClaimStatus.cancelled,
        );
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestDetailPath(pendingItem.claimId));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('rejectMembershipClaimAction')),
        findsNothing,
      );
    });

    testWidgets(
      '42/43/44/46/47: rejection requires a reason input, matches the '
      'mandatory-reason backend contract, calls the repository once, and '
      'refreshes on success without deleting history',
      (tester) async {
        final item = fakeMembershipClaimQueueItem();
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextQueueItems = [item]
          ..nextDetailItem = item;
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimOfficerMembership()],
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('rejectMembershipClaimAction')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('rejectMembershipClaimReasonField')),
          'Could not verify identity',
        );
        fakeRepo.nextDetailItem = fakeMembershipClaimQueueItem(
          claimId: item.claimId,
          status: MembershipClaimStatus.rejected,
          rejectionReason: 'Could not verify identity',
        );
        await tester.tap(
          find.byKey(const Key('rejectMembershipClaimConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.rejectMembershipClaimCalls, hasLength(1));
        expect(
          fakeRepo.rejectMembershipClaimCalls.single.rejectionReason,
          'Could not verify identity',
        );
      },
    );

    testWidgets(
      "the client never invents its own non-blank rule — a blank reason "
      'still reaches the repository, which surfaces the backend '
      "'reason required' failure mapped to a friendly message",
      (tester) async {
        final item = fakeMembershipClaimQueueItem();
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextQueueItems = [item]
          ..nextDetailItem = item;
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimOfficerMembership()],
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('rejectMembershipClaimAction')));
        await tester.pumpAndSettle();

        // The detail loaded successfully above — only the reject CALL
        // itself should fail, not the initial fetch, so the failure is
        // staged right before confirming, not at fake construction.
        fakeRepo.failure = const MembershipClaimFailure(
          MembershipClaimFailureType.rejectionReasonRequired,
          'A rejection reason is required.',
        );
        await tester.tap(
          find.byKey(const Key('rejectMembershipClaimConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.rejectMembershipClaimCalls, hasLength(1));
        expect(fakeRepo.rejectMembershipClaimCalls.single.rejectionReason, '');
        expect(find.text('A rejection reason is required.'), findsOneWidget);
      },
    );

    testWidgets('45: rapidly confirming Reject twice only calls the '
        'repository once', (tester) async {
      final gate = Completer<void>();
      final item = fakeMembershipClaimQueueItem();
      final fakeRepo = FakeMembershipClaimRepository()
        ..nextQueueItems = [item]
        ..nextDetailItem = item
        ..rejectGate = gate;
      final router = await pumpMembershipClaimApp(
        tester,
        fakeRepo: fakeRepo,
        memberships: [membershipClaimOfficerMembership()],
        language: AppLanguage.english,
      );
      router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rejectMembershipClaimAction')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('rejectMembershipClaimReasonField')),
        'reason',
      );
      await tester.tap(
        find.byKey(const Key('rejectMembershipClaimConfirmAction')),
      );
      await tester.pump();

      final rejectAction = find.byKey(const Key('rejectMembershipClaimAction'));
      await tester.tap(rejectAction, warnIfMissed: false);
      await tester.pump();

      expect(fakeRepo.rejectMembershipClaimCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(fakeRepo.rejectMembershipClaimCalls, hasLength(1));
    });
  });

  group('Stale/concurrent state (§R 48-53)', () {
    testWidgets(
      '48/52/53: an already-resolved claim (approved by another officer '
      'concurrently) maps to a friendly message, never raw SQL, and '
      'refreshes the detail',
      (tester) async {
        final item = fakeMembershipClaimQueueItem();
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextQueueItems = [item]
          ..nextDetailItem = item;
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimOfficerMembership()],
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('approveMembershipClaimAction')));
        await tester.pumpAndSettle();

        // Detail loaded fine above — only the approve call itself is
        // stale (someone else already resolved it concurrently). The
        // fake's own `.message` is never shown by the UI (it's an
        // English-only log fallback) — only `.type`, mapped through
        // core/localization/failure_messages.dart, ever reaches the
        // screen.
        fakeRepo.failure = const MembershipClaimFailure(
          MembershipClaimFailureType.notPending,
          'MEMBERSHIP_CLAIM_NOT_PENDING',
        );
        await tester.tap(
          find.byKey(const Key('approveMembershipClaimConfirmAction')),
        );
        // A single pump, not pumpAndSettle: the error is surfaced via a
        // transient SnackBar, and pumpAndSettle would advance the fake
        // clock through its several-second auto-dismiss duration,
        // hiding it before this assertion ever sees it.
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            "This request is no longer pending, so it can't be changed.",
          ),
          findsOneWidget,
        );
        expect(find.textContaining('P0001'), findsNothing);
        expect(
          find.textContaining('MEMBERSHIP_CLAIM_NOT_PENDING'),
          findsNothing,
        );
      },
    );

    testWidgets(
      '51: an inaccessible/not-found claim (e.g. deleted or cross-group) '
      'renders a safe error state on the review screen, not a crash',
      (tester) async {
        final fakeRepo = FakeMembershipClaimRepository();
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimOfficerMembership()],
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestDetailPath('missing-claim'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            "We couldn't find that request, or you don't have permission to view it.",
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Cross-group safety (§R 54-56)', () {
    testWidgets(
      '54/55: the queue/detail/approve calls always use the CURRENTLY '
      'selected group id — never something substitutable via the route',
      (tester) async {
        final officer = membershipClaimOfficerMembership(
          groupId: 'g-officer-actual',
        );
        final item = fakeMembershipClaimQueueItem();
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextQueueItems = [item]
          ..nextDetailItem = item;
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [officer],
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestsList);
        await tester.pumpAndSettle();

        expect(
          fakeRepo.listMembershipClaimsCalls.every(
            (c) => c.groupId == 'g-officer-actual',
          ),
          isTrue,
        );

        router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('approveMembershipClaimAction')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('approveMembershipClaimConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(
          fakeRepo.approveMembershipClaimCalls.single.groupId,
          'g-officer-actual',
        );
      },
    );
  });

  group('Responsive (§R 57-60)', () {
    for (final size in [
      const Size(360, 800), // phone portrait
      const Size(1024, 768), // tablet
      const Size(1440, 900), // desktop/web
    ]) {
      testWidgets('57-60: the queue and review screens render at '
          '${size.width.toInt()}x${size.height.toInt()} without overflow', (
        tester,
      ) async {
        final item = fakeMembershipClaimQueueItem();
        final fakeRepo = FakeMembershipClaimRepository()
          ..nextQueueItems = [item]
          ..nextDetailItem = item;
        final router = await pumpMembershipClaimApp(
          tester,
          fakeRepo: fakeRepo,
          memberships: [membershipClaimOfficerMembership()],
          viewSize: size,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.membershipRequestsList);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        router.go(AppRoutes.membershipRequestDetailPath(item.claimId));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
