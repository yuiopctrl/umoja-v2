import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_form_controller.dart';
import 'package:umoja/features/contributions/domain/contribution_period_page.dart';
import 'package:umoja/features/contributions/domain/contribution_setup_page.dart';
import 'package:umoja/features/contributions/domain/contribution_type_page.dart';
import 'package:umoja/features/contributions/providers/contribution_setup_picker_provider.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

// These tests exercise the real widget tree end-to-end (list screen ->
// push create form -> submit -> pop) rather than asserting on providers
// in isolation. `FakeContributionRepository`'s create* methods append the
// newly created row into the corresponding next*Page (see its comments)
// so these tests only pass if the app genuinely invalidates and refetches
// the affected provider — a fake that just "remembers the latest thing
// created" regardless of caching would not distinguish a real fix from a
// stale-cache bug.
void main() {
  testWidgets(
    'a newly created Contribution Type appears in the list immediately, '
    'without restart',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextTypesPage = ContributionTypePage.empty
        ..nextType = fakeContributionType(id: 'type-new', name: 'Ada Mpya');

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionTypesList);
      await tester.pumpAndSettle();

      // Starts empty.
      expect(find.text('Ada Mpya'), findsNothing);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ada Mpya');
      await tester.pump();
      await tester.ensureVisible(find.text('Hifadhi'));
      await tester.tap(find.text('Hifadhi'));
      await tester.pumpAndSettle();

      // Back on the list, with no restart/reload action taken by the
      // test — the new type must already be visible.
      expect(find.text('Ada Mpya'), findsOneWidget);
    },
  );

  testWidgets(
    'a newly created Contribution Setup appears in the list immediately, '
    'without restart',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextTypesPage = ContributionTypePage(
          items: [fakeContributionType()],
          totalCount: 1,
          limit: 10,
          offset: 0,
        )
        ..nextSetupsPage = ContributionSetupPage.empty
        ..nextSetup = fakeContributionSetup(
          id: 'setup-new',
          name: 'Mchango Mpya',
        );

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionSetupsList);
      await tester.pumpAndSettle();

      expect(find.text('Mchango Mpya'), findsNothing);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('contributionSetupTypeField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fakeContributionType().name).last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Mchango Mpya');
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('contributionSetupFixedAmountField')),
        '1000',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Hifadhi'));
      await tester.tap(find.text('Hifadhi'));
      await tester.pumpAndSettle();

      expect(find.text('Mchango Mpya'), findsOneWidget);
    },
  );

  testWidgets('a newly created Contribution Setup appears in the Period create '
      "form's setup picker immediately, without restart", (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextTypesPage = ContributionTypePage(
        items: [fakeContributionType()],
        totalCount: 1,
        limit: 10,
        offset: 0,
      )
      ..nextSetupsPage = ContributionSetupPage.empty
      ..nextSetup = fakeContributionSetup(
        id: 'setup-new',
        name: 'Mchango Mpya',
        scheduleMode: 'ON_DEMAND',
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // Warm the picker's cache with the OLD (empty) setups list first —
    // otherwise a picker that has never been read before would fetch
    // fresh data regardless of whether create-setup invalidation is
    // wired up at all, and this test would pass even with the
    // invalidation missing entirely.
    await container.read(contributionActiveSetupsForPickerProvider.future);
    expect(
      container.read(contributionActiveSetupsForPickerProvider).value,
      isEmpty,
    );

    // Now create the setup.
    router.push(AppRoutes.contributionSetupNew);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contributionSetupTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fakeContributionType().name).last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('contributionSetupScheduleModeField')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inapohitajika').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Mchango Mpya');
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('contributionSetupFixedAmountField')),
      '1000',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Hifadhi'));
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();

    // Now open the Period create form — the picker must already offer
    // the setup just created, with no restart.
    router.push(AppRoutes.contributionPeriodNew);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contributionPeriodSetupField')));
    await tester.pumpAndSettle();

    expect(find.text('Mchango Mpya (Inapohitajika)'), findsOneWidget);
  });

  testWidgets(
    'a newly created Contribution Period appears in the list immediately, '
    'without restart',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriodsPage = ContributionPeriodPage.empty
        ..nextPeriod = fakeContributionPeriod(
          id: 'period-new',
          label: 'Tukio Jipya',
        );

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodsList);
      await tester.pumpAndSettle();

      expect(find.text('Tukio Jipya'), findsNothing);

      // Drives the same controller a real Save button would, without
      // coupling this test to the raw Material date-picker interaction
      // (which the create form uses for period_start/period_end) — what
      // this test actually verifies is that the list screen, already
      // mounted underneath, refreshes after invalidation, not how the
      // create form gathers its dates.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(contributionPeriodFormControllerProvider.notifier)
          .createPeriod(
            groupId: 'g1',
            contributionSetupId: 'setup-1',
            label: 'Tukio Jipya',
            periodStart: DateTime.utc(2026, 3, 1),
            periodEnd: DateTime.utc(2026, 3, 31),
          );
      await tester.pumpAndSettle();

      // Back on the already-mounted list screen, with no restart/reload
      // action taken by the test — the new period must already be
      // visible.
      expect(find.text('Tukio Jipya'), findsOneWidget);
    },
  );
}
