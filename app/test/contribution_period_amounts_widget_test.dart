import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/domain/contribution_period_open_preview.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets('editing member amounts and saving batches every row into one '
      'rpc_set_contribution_period_member_amounts call', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPreview = ContributionPeriodOpenPreview(
        periodId: 'period-1',
        status: 'DRAFT',
        dueDate: DateTime.utc(2026, 2, 5),
        amountMode: 'CUSTOM_PER_MEMBER',
        eligibleCount: 2,
        eligibleMembers: const [
          ContributionPreviewEligibleMember(
            membershipId: 'm1',
            memberNumber: 'M-001',
            displayName: 'Amina Juma',
            amount: 5000,
          ),
          ContributionPreviewEligibleMember(
            membershipId: 'm2',
            memberNumber: 'M-002',
            displayName: 'Baraka Msigwa',
          ),
        ],
        excludedCount: 0,
        excludedMembers: const [],
        missingCustomAmountCount: 1,
        missingCustomAmountMembers: const [
          ContributionPreviewMissingAmountMember(
            membershipId: 'm2',
            memberNumber: 'M-002',
            displayName: 'Baraka Msigwa',
          ),
        ],
        expectedTotalAssessment: 5000,
        canOpen: false,
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.contributionPeriodAmountsPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Amina Juma'), findsOneWidget);
    expect(find.text('Baraka Msigwa'), findsOneWidget);

    // TextField index 0 is the search field; index 1 is Amina's amount
    // field; index 2 is Baraka's — starts empty (missing) — fill it in.
    await tester.enterText(find.byType(TextField).at(2), '6000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hifadhi Kiasi'));
    await tester.pumpAndSettle();

    expect(fakeRepo.setContributionPeriodMemberAmountsCalls, hasLength(1));
    // Both rows are sent in the one batched call (Amina's unchanged
    // amount is preserved, Baraka's newly-entered amount is included).
    expect(
      fakeRepo.setContributionPeriodMemberAmountsCalls.single.amountsCount,
      2,
    );
  });

  testWidgets(
    'searching "fred" matches an eligible member named Frederick, and all '
    'eligible members are listed before typing',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPreview = ContributionPeriodOpenPreview(
          periodId: 'period-1',
          status: 'DRAFT',
          dueDate: DateTime.utc(2026, 2, 5),
          amountMode: 'CUSTOM_PER_MEMBER',
          eligibleCount: 2,
          eligibleMembers: const [
            ContributionPreviewEligibleMember(
              membershipId: 'm1',
              memberNumber: 'M-001',
              displayName: 'Amina Juma',
              amount: 5000,
            ),
            ContributionPreviewEligibleMember(
              membershipId: 'm2',
              memberNumber: 'M-002',
              displayName: 'Frederick Mtui',
            ),
          ],
          excludedCount: 0,
          excludedMembers: const [],
          missingCustomAmountCount: 1,
          missingCustomAmountMembers: const [
            ContributionPreviewMissingAmountMember(
              membershipId: 'm2',
              memberNumber: 'M-002',
              displayName: 'Frederick Mtui',
            ),
          ],
          expectedTotalAssessment: 5000,
          canOpen: false,
        );

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionPeriodAmountsPath('period-1'));
      await tester.pumpAndSettle();

      // Listed before typing anything.
      expect(find.text('Amina Juma'), findsOneWidget);
      expect(find.text('Frederick Mtui'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'fred');
      await tester.pumpAndSettle();

      expect(find.text('Amina Juma'), findsNothing);
      expect(find.text('Frederick Mtui'), findsOneWidget);
    },
  );

  testWidgets('member-number search matches consistently with name search', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPreview = ContributionPeriodOpenPreview(
        periodId: 'period-1',
        status: 'DRAFT',
        dueDate: DateTime.utc(2026, 2, 5),
        amountMode: 'CUSTOM_PER_MEMBER',
        eligibleCount: 2,
        eligibleMembers: const [
          ContributionPreviewEligibleMember(
            membershipId: 'm1',
            memberNumber: 'M-001',
            displayName: 'Amina Juma',
            amount: 5000,
          ),
          ContributionPreviewEligibleMember(
            membershipId: 'm2',
            memberNumber: 'M-002',
            displayName: 'Frederick Mtui',
          ),
        ],
        excludedCount: 0,
        excludedMembers: const [],
        missingCustomAmountCount: 1,
        missingCustomAmountMembers: const [
          ContributionPreviewMissingAmountMember(
            membershipId: 'm2',
            memberNumber: 'M-002',
            displayName: 'Frederick Mtui',
          ),
        ],
        expectedTotalAssessment: 5000,
        canOpen: false,
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.contributionPeriodAmountsPath('period-1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'M-002');
    await tester.pumpAndSettle();

    expect(find.text('Amina Juma'), findsNothing);
    expect(find.text('Frederick Mtui'), findsOneWidget);
  });
}
