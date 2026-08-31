import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/data/contribution_failure.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets('the current net assessed and maximum waiver shown are the '
      'backend-authoritative values, never computed client-side', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextChargeDetail = fakeContributionChargeDetail(baseAmount: 100000);

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.contributionChargeWaivePath('charge-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('100,000'), findsWidgets);
  });

  testWidgets('selecting "Full" waiver pre-fills the amount field with the '
      'current net assessed', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextChargeDetail = fakeContributionChargeDetail(baseAmount: 70000);

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.contributionChargeWaivePath('charge-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yote'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('waiverAmountField')),
    );
    expect(field.controller!.text, '70,000');
  });

  testWidgets(
    'submitting a partial waiver sends the exact positive amount typed — '
    'the sign is applied server-side, never here',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail(baseAmount: 100000);

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionChargeWaivePath('charge-1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('waiverAmountField')),
        '30000',
      );
      await tester.enterText(
        find.byKey(const Key('waiverReasonField')),
        'Goodwill partial waiver',
      );
      await tester.tap(find.text('Wasilisha Msamaha'));
      await tester.pumpAndSettle();

      expect(fakeRepo.waiveContributionChargeCalls, hasLength(1));
      expect(fakeRepo.waiveContributionChargeCalls.single.amount, 30000);
    },
  );

  testWidgets(
    'a waiver exceeding net assessed shows the localized error message',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextChargeDetail = fakeContributionChargeDetail(baseAmount: 100000);

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionChargeWaivePath('charge-1'));
      await tester.pumpAndSettle();

      // Set only after the charge detail has already loaded — the fake
      // applies `failure` to every call, including the initial fetch.
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.waiverExceedsNetAssessed,
        'exceeds net assessed',
      );

      await tester.enterText(
        find.byKey(const Key('waiverAmountField')),
        '200000',
      );
      await tester.enterText(
        find.byKey(const Key('waiverReasonField')),
        'too much',
      );
      await tester.tap(find.text('Wasilisha Msamaha'));
      await tester.pumpAndSettle();

      expect(
        find.text('Msamaha huu unazidi jumla ya deni lililowekwa kwa sasa.'),
        findsOneWidget,
      );
    },
  );
}
