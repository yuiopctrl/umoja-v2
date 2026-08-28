import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/data/contribution_failure.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets(
    'choosing "Increase Obligation" sends a positive signed amount to '
    'rpc_create_contribution_adjustment',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionChargeAdjustPath('charge-1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('adjustmentAmountField')),
        '20000',
      );
      await tester.enterText(
        find.byKey(const Key('adjustmentReasonField')),
        'Undercharged last month',
      );
      await tester.tap(find.text('Wasilisha Marekebisho'));
      await tester.pumpAndSettle();

      expect(fakeRepo.createContributionAdjustmentCalls, hasLength(1));
      expect(fakeRepo.createContributionAdjustmentCalls.single.amount, 20000);
    },
  );

  testWidgets(
    'choosing "Reduce Obligation" sends a negative signed amount — the '
    'user never types a raw signed number',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionChargeAdjustPath('charge-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Punguza Deni'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('adjustmentAmountField')),
        '30000',
      );
      await tester.enterText(
        find.byKey(const Key('adjustmentReasonField')),
        'Overcharged, correcting',
      );
      await tester.tap(find.text('Wasilisha Marekebisho'));
      await tester.pumpAndSettle();

      expect(fakeRepo.createContributionAdjustmentCalls, hasLength(1));
      expect(fakeRepo.createContributionAdjustmentCalls.single.amount, -30000);
    },
  );

  testWidgets('submitting with a blank amount never calls the repository', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextChargeDetail = fakeContributionChargeDetail();

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.contributionChargeAdjustPath('charge-1'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('adjustmentReasonField')),
      'Some reason',
    );
    await tester.tap(find.text('Wasilisha Marekebisho'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createContributionAdjustmentCalls, isEmpty);
  });

  testWidgets(
    'a backend rejection (would-make-negative) shows the localized error, '
    'never a raw error code',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail(baseAmount: 100000);

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionChargeAdjustPath('charge-1'));
      await tester.pumpAndSettle();

      // Set only after the charge detail has already loaded — the fake
      // applies `failure` to every call, including the initial fetch.
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.adjustmentWouldMakeObligationNegative,
        'would make obligation negative',
      );

      await tester.tap(find.text('Punguza Deni'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('adjustmentAmountField')),
        '999999',
      );
      await tester.enterText(
        find.byKey(const Key('adjustmentReasonField')),
        'too much',
      );
      await tester.tap(find.text('Wasilisha Marekebisho'));
      await tester.pumpAndSettle();

      expect(
        find.text('Marekebisho haya yangefanya deni kuwa hasi.'),
        findsOneWidget,
      );
      expect(find.textContaining('ADJUSTMENT_WOULD_MAKE'), findsNothing);
    },
  );
}
