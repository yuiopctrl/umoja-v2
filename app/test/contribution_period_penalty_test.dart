import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_penalty_controller.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge_page.dart';
import 'package:umoja/features/contributions/providers/contribution_period_charges_provider.dart';
import 'package:umoja/features/contributions/providers/contribution_period_detail_provider.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets('the Assess Penalties action is visible on an OPEN period with a '
      'penalty policy, for a caller with contribution.penalty.assess', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(
        status: 'OPEN',
        snapshotAmountMode: 'FIXED',
        snapshotPenaltyMode: 'FIXED_ONCE',
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Tathmini Adhabu'), findsOneWidget);
  });

  testWidgets('the Assess Penalties action is hidden without contribution.penalty.assess, '
      'even on an OPEN period with a penalty policy', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(
        status: 'OPEN',
        snapshotAmountMode: 'FIXED',
        snapshotPenaltyMode: 'FIXED_ONCE',
      );

    final router = await pumpContributionsApp(
      tester,
      fakeRepo: fakeRepo,
      membership: contributionMembership(
        roles: const ['CHAIRPERSON'],
        permissions: const [
          'group.view',
          'contribution.view',
          'contribution.period.open',
          'contribution.period.close',
        ],
      ),
    );
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Tathmini Adhabu'), findsNothing);
  });

  testWidgets('the Assess Penalties action is absent on an OPEN period with no '
      'penalty policy, which instead shows a clear no-policy message', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(
        status: 'OPEN',
        snapshotAmountMode: 'FIXED',
        snapshotPenaltyMode: 'NONE',
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Tathmini Adhabu'), findsNothing);
    expect(
      find.text('Hakuna kanuni ya adhabu iliyowekwa kwa kipindi hiki.'),
      findsOneWidget,
    );
    // No pointless RPC call was ever made.
    expect(fakeRepo.assessContributionPeriodPenaltiesCalls, isEmpty);
  });

  testWidgets(
    'the Assess Penalties action is hidden on a DRAFT period even with a '
    'penalty policy and full permissions',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(
          status: 'DRAFT',
          snapshotPenaltyMode: 'FIXED_ONCE',
        )
        ..nextSetup = fakeContributionSetup();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Tathmini Adhabu'), findsNothing);
    },
  );

  testWidgets(
    'confirming assessment calls rpc_assess_contribution_penalties and '
    'shows the server-computed result',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(
          status: 'OPEN',
          snapshotAmountMode: 'FIXED',
          snapshotPenaltyMode: 'FIXED_ONCE',
        )
        ..nextPenaltyAssessmentResult = fakeContributionPenaltyAssessmentResult(
          penaltiesCreatedCount: 2,
          alreadyCurrentChargeCount: 3,
          totalPenaltyAssessedThisRun: 1500,
        );

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Tathmini Adhabu'));
      await tester.tap(find.text('Tathmini Adhabu'));
      await tester.pumpAndSettle();
      // Confirmation sheet.
      await tester.ensureVisible(find.text('Tathmini Adhabu').last);
      await tester.tap(find.text('Tathmini Adhabu').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.assessContributionPeriodPenaltiesCalls, hasLength(1));
      expect(
        fakeRepo.assessContributionPeriodPenaltiesCalls.single.periodId,
        'period-1',
      );

      // Regression coverage for the live UAT failure: the action
      // omitted assessmentDate entirely, so the repository sent an
      // explicit JSON `null` for p_assessment_date — which PostgREST
      // does not fall back to the RPC's own `default current_date`
      // for, only an omitted argument gets that — so the backend's own
      // "Assessment date is required" validation fired every time. The
      // UI must always supply today's local date explicitly.
      final sentDate =
          fakeRepo.assessContributionPeriodPenaltiesCalls.single.assessmentDate;
      expect(sentDate, isNotNull);
      final today = DateTime.now();
      expect(sentDate!.year, today.year);
      expect(sentDate.month, today.month);
      expect(sentDate.day, today.day);

      // Server-computed result dialog, never client-calculated.
      expect(find.text('Adhabu Mpya Zilizowekwa: 2'), findsOneWidget);
      expect(find.text('Zilizokuwa Sahihi Tayari: 3'), findsOneWidget);
      expect(find.textContaining('1,500'), findsOneWidget);
    },
  );

  testWidgets(
    'assessment refreshes an already-warm period detail and charges view '
    '— the new penalty total appears immediately, without restart',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(
          status: 'OPEN',
          snapshotAmountMode: 'FIXED',
          snapshotPenaltyMode: 'FIXED_ONCE',
          totalPenaltyAssessed: 0,
        )
        ..nextChargesPage = MemberContributionChargePage.empty;

      await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // Warm both caches with the pre-assessment (zero-penalty) state.
      final detailBefore = await container.read(
        contributionPeriodDetailProvider('period-1').future,
      );
      expect(detailBefore.totalPenaltyAssessed, 0);

      const query = (periodId: 'period-1', search: '', limit: 10);
      final chargesBefore = await container.read(
        contributionPeriodChargesProvider(query).future,
      );
      expect(chargesBefore.items, isEmpty);

      // The assessment "changes" server state — the fake mimics that.
      fakeRepo.nextPeriod = fakeContributionPeriod(
        status: 'OPEN',
        snapshotAmountMode: 'FIXED',
        snapshotPenaltyMode: 'FIXED_ONCE',
        totalPenaltyAssessed: 500,
      );
      fakeRepo.nextChargesPage = MemberContributionChargePage(
        items: [
          MemberContributionCharge(
            chargeId: 'c1',
            membershipId: 'm1',
            memberNumberSnapshot: 'G-0001',
            memberNameSnapshot: 'Amina Juma',
            effectiveAt: DateTime.utc(2026, 1, 1),
            dueDate: DateTime.utc(2026, 1, 5),
            createdAt: DateTime.utc(2026, 1, 1),
            baseAmount: 10000,
            penaltyAmount: 500,
            penaltyCount: 1,
            totalAmount: 10500,
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

      await container
          .read(contributionPeriodPenaltyControllerProvider.notifier)
          .assess(groupId: 'g1', periodId: 'period-1');

      final detailAfter = await container.read(
        contributionPeriodDetailProvider('period-1').future,
      );
      expect(detailAfter.totalPenaltyAssessed, 500);

      final chargesAfter = await container.read(
        contributionPeriodChargesProvider(query).future,
      );
      expect(chargesAfter.items, hasLength(1));
      expect(chargesAfter.items.single.penaltyAmount, 500);
    },
  );

  testWidgets(
    'the Assess Penalties action reads in English when the language is '
    'set to English',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(
          status: 'OPEN',
          snapshotAmountMode: 'FIXED',
          snapshotPenaltyMode: 'FIXED_ONCE',
        );

      final router = await pumpContributionsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Assess Penalties'), findsOneWidget);
    },
  );

  testWidgets('repeated assessment does not add a duplicate result dialog or a '
      'second action button', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(
        status: 'OPEN',
        snapshotAmountMode: 'FIXED',
        snapshotPenaltyMode: 'FIXED_ONCE',
      )
      ..nextPenaltyAssessmentResult = fakeContributionPenaltyAssessmentResult(
        penaltiesCreatedCount: 0,
        alreadyCurrentChargeCount: 1,
        totalPenaltyAssessedThisRun: 0,
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Tathmini Adhabu'));
      await tester.tap(find.text('Tathmini Adhabu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tathmini Adhabu').last);
      await tester.tap(find.text('Tathmini Adhabu').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Funga'));
      await tester.tap(find.text('Funga'));
      await tester.pumpAndSettle();
    }

    expect(fakeRepo.assessContributionPeriodPenaltiesCalls, hasLength(2));
    // Exactly one action button remains — no duplicate entries piled up.
    expect(find.text('Tathmini Adhabu'), findsOneWidget);
  });
}
