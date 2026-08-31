import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets(
    'the charge detail screen shows the full component breakdown with '
    'natural Swahili labels — never a raw enum name',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail(
          baseAmount: 100000,
          penaltyAmount: 10000,
          adjustmentAmount: 20000,
          waiverAmount: 5000,
        );

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionChargeDetailPath('charge-1'));
      await tester.pumpAndSettle();

      expect(find.text('Deni Msingi'), findsOneWidget);
      expect(find.text('Adhabu'), findsOneWidget);
      expect(find.text('Marekebisho'), findsOneWidget);
      expect(find.text('Msamaha wa Deni'), findsOneWidget);
      expect(find.text('Jumla ya Deni Lililowekwa'), findsOneWidget);

      // Net assessed = 100,000 + 10,000 + 20,000 - 5,000 = 125,000. The
      // fake charge has no payment allocated against it, so Outstanding
      // (Prompt 07 UAT-FIX-03) equals the same 125,000 figure — hence
      // two matches, not one.
      expect(find.textContaining('125,000'), findsNWidgets(2));

      expect(find.textContaining('BASE'), findsNothing);
      expect(find.textContaining('PENALTY'), findsNothing);
      expect(find.textContaining('ADJUSTMENT'), findsNothing);
      expect(find.textContaining('WAIVER'), findsNothing);
    },
  );

  testWidgets(
    'Add Adjustment and Waive Obligation actions are hidden without the '
    'matching permission',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail();

      final router = await pumpContributionsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: contributionMembership(
          roles: const ['SECRETARY'],
          permissions: const ['group.view', 'contribution.view'],
        ),
      );
      router.go(AppRoutes.contributionChargeDetailPath('charge-1'));
      await tester.pumpAndSettle();

      expect(find.text('Ongeza Marekebisho'), findsNothing);
      expect(find.text('Samehe Deni'), findsNothing);
    },
  );

  testWidgets('Add Adjustment and Waive Obligation actions are visible with '
      'contribution.adjustment.create / contribution.waiver.create', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextChargeDetail = fakeContributionChargeDetail();

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionChargeDetailPath('charge-1'));
    await tester.pumpAndSettle();

    expect(find.text('Ongeza Marekebisho'), findsOneWidget);
    expect(find.text('Samehe Deni'), findsOneWidget);
  });

  testWidgets('the charge detail screen reads in English when selected', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextChargeDetail = fakeContributionChargeDetail();

    final router = await pumpContributionsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.contributionChargeDetailPath('charge-1'));
    await tester.pumpAndSettle();

    expect(find.text('Net Assessed'), findsOneWidget);
    expect(find.text('Add Adjustment'), findsOneWidget);
    expect(find.text('Waive Obligation'), findsOneWidget);
  });
}
