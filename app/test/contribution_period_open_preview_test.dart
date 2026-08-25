import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/domain/contribution_period_open_preview.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

ContributionPeriodOpenPreview _preview({
  int missingCount = 0,
  bool canOpen = true,
}) {
  return ContributionPeriodOpenPreview(
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
    missingCustomAmountCount: missingCount,
    missingCustomAmountMembers: missingCount == 0
        ? const []
        : const [
            ContributionPreviewMissingAmountMember(
              membershipId: 'm2',
              memberNumber: 'M-002',
              displayName: 'Baraka Msigwa',
            ),
          ],
    expectedTotalAssessment: 5000,
    canOpen: canOpen,
  );
}

void main() {
  testWidgets('the confirm button is disabled and a warning is shown when '
      'missing_custom_amount_count > 0', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
      ..nextPreview = _preview(missingCount: 1, canOpen: false);

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodOpenPreviewPath('period-1'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Weka kiasi kwa wanachama wote kabla ya kufungua kipindi hiki.',
      ),
      findsOneWidget,
    );

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Fungua Kipindi'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(fakeRepo.openContributionPeriodCalls, isEmpty);
  });

  testWidgets(
    'the confirm button is enabled once every eligible member has an amount',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
        ..nextPreview = _preview(missingCount: 0, canOpen: true);

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodOpenPreviewPath('period-1'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Fungua Kipindi'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    },
  );
}
