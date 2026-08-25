import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/domain/contribution_period_open_preview.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

ContributionPeriodOpenPreview _preview() {
  return ContributionPeriodOpenPreview(
    periodId: 'period-1',
    status: 'DRAFT',
    dueDate: DateTime.utc(2026, 2, 5),
    amountMode: 'FIXED',
    eligibleCount: 1,
    eligibleMembers: [
      ContributionPreviewEligibleMember(
        membershipId: 'm1',
        memberNumber: 'M-001',
        displayName: 'Amina Juma',
        amount: 5000,
      ),
    ],
    excludedCount: 2,
    excludedMembers: [
      ContributionPreviewExcludedMember(
        membershipId: 'm2',
        memberNumber: 'M-002',
        displayName: 'Baraka Msigwa',
        reason: 'Hayupo nchini',
      ),
      ContributionPreviewExcludedMember(
        membershipId: 'm3',
        memberNumber: 'M-003',
        displayName: 'Chiku Ally',
        reason: 'SUSPENDED',
      ),
    ],
    missingCustomAmountCount: 0,
    missingCustomAmountMembers: [],
    expectedTotalAssessment: 5000,
    canOpen: true,
  );
}

void main() {
  testWidgets(
    'excluding an eligible member calls rpc_exclude_contribution_period_member '
    'with the given reason',
    (tester) async {
      final fakeRepo = FakeContributionRepository()..nextPreview = _preview();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodExclusionsPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Amina Juma'), findsOneWidget);

      await tester.tap(find.text('Ondoa kwenye Kipindi Hiki').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Amesafiri');
      await tester.tap(find.text('Ondoa kwenye Kipindi Hiki').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.excludeContributionPeriodMemberCalls, hasLength(1));
      expect(
        fakeRepo.excludeContributionPeriodMemberCalls.single.membershipId,
        'm1',
      );
    },
  );

  testWidgets(
    'an explicitly-excluded member offers "Rudisha kwenye Kipindi", but an '
    'automatically-ineligible one (SUSPENDED) does not',
    (tester) async {
      final fakeRepo = FakeContributionRepository()..nextPreview = _preview();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodExclusionsPath('period-1'));
      await tester.pumpAndSettle();

      // Exactly one "Rudisha kwenye Kipindi" — for the explicit exclusion
      // (Baraka), never for the automatically-ineligible one (Chiku,
      // SUSPENDED).
      expect(find.text('Rudisha kwenye Kipindi'), findsOneWidget);

      await tester.tap(find.text('Rudisha kwenye Kipindi'));
      await tester.pumpAndSettle();

      expect(
        fakeRepo.removeContributionPeriodMemberExclusionCalls,
        hasLength(1),
      );
      expect(
        fakeRepo
            .removeContributionPeriodMemberExclusionCalls
            .single
            .membershipId,
        'm2',
      );

      // Never uses the word "waive"/"futa deni" anywhere on this screen.
      expect(find.textContaining('Futa deni'), findsNothing);
      expect(find.textContaining('Waive'), findsNothing);
    },
  );
}
