import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets(
    'submitting the edit form persists changes via rpc_update_contribution_period',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(
          status: 'DRAFT',
          label: 'March Dues',
        )
        ..nextSetup = fakeContributionSetup();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionPeriodEditPath('period-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contributionPeriodLabelField')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('contributionPeriodLabelField')),
        'March Dues (Renamed)',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Hifadhi'));
      await tester.tap(find.text('Hifadhi'));
      await tester.pumpAndSettle();

      // UAT failure E's root cause was suspected to be the edit screen
      // calling rpc_create_contribution_period instead of
      // rpc_update_contribution_period — assert both explicitly.
      expect(fakeRepo.updateContributionPeriodCalls, hasLength(1));
      expect(fakeRepo.createContributionPeriodCalls, isEmpty);
      expect(
        fakeRepo.updateContributionPeriodCalls.single.periodId,
        'period-1',
      );
      expect(
        fakeRepo.updateContributionPeriodCalls.single.label,
        'March Dues (Renamed)',
      );
    },
  );

  testWidgets(
    'the edit screen shows the read-only setup field and every editable date',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'SCHEDULED')
        ..nextSetup = fakeContributionSetup(name: 'Monthly Dues Setup');

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionPeriodEditPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Dues Setup'), findsOneWidget);
    },
  );

  testWidgets('the edit screen title/labels are in English when the '
      'language is set to English', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
      ..nextSetup = fakeContributionSetup();

    final router = await pumpContributionsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.contributionPeriodEditPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Contribution Period'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the edit screen title/labels are in Swahili by default', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
      ..nextSetup = fakeContributionSetup();

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodEditPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Hariri Kipindi'), findsOneWidget);
  });
}
