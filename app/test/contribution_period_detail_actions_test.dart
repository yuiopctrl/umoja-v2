import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets(
    'a DRAFT period shows every lifecycle action to a caller with full '
    'contribution permissions',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
        ..nextSetup = fakeContributionSetup(amountMode: 'FIXED');

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Hakiki na Fungua'), findsOneWidget);
      expect(find.text('Simamia Walioondolewa'), findsOneWidget);
      expect(find.text('Sitisha Kipindi'), findsOneWidget);
      // FIXED amount mode -> the custom-amount action never appears.
      expect(find.text('Weka Kiasi kwa Kila Mwanachama'), findsNothing);
      // contribution.period.manage -> Edit is visible on a DRAFT period.
      expect(find.text('Hariri'), findsOneWidget);
    },
  );

  testWidgets(
    'a SCHEDULED period shows Edit only with contribution.period.manage',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'SCHEDULED')
        ..nextSetup = fakeContributionSetup();

      final router = await pumpContributionsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: contributionMembership(
          roles: const ['SECRETARY'],
          permissions: const ['group.view', 'contribution.view'],
        ),
      );
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Hariri'), findsNothing);
    },
  );

  testWidgets('Edit is hidden on an OPEN period even with full permissions', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(
        status: 'OPEN',
        snapshotAmountMode: 'FIXED',
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Hariri'), findsNothing);
    // section 6: Manage Exclusions must never appear once OPEN.
    expect(find.text('Simamia Walioondolewa'), findsNothing);
  });

  testWidgets('Edit is hidden on a CLOSED period even with full permissions', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(
        status: 'CLOSED',
        snapshotAmountMode: 'FIXED',
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Hariri'), findsNothing);
    expect(find.text('Simamia Walioondolewa'), findsNothing);
  });

  testWidgets(
    'Edit is hidden on a CANCELLED period even with full permissions',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'CANCELLED')
        ..nextSetup = fakeContributionSetup();

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Hariri'), findsNothing);
      expect(find.text('Simamia Walioondolewa'), findsNothing);
    },
  );

  testWidgets(
    'a DRAFT CUSTOM_PER_MEMBER period shows the configure-amounts action '
    'only with contribution.member_amount.manage',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
        ..nextSetup = fakeContributionSetup(
          amountMode: 'CUSTOM_PER_MEMBER',
          fixedAmount: null,
        );

      final router = await pumpContributionsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: contributionMembership(),
      );
      router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
      await tester.pumpAndSettle();

      expect(find.text('Weka Kiasi kwa Kila Mwanachama'), findsOneWidget);
    },
  );

  testWidgets('a DRAFT period shows no lifecycle action to a caller with only '
      'contribution.view', (tester) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
      ..nextSetup = fakeContributionSetup();

    final router = await pumpContributionsApp(
      tester,
      fakeRepo: fakeRepo,
      membership: contributionMembership(
        roles: const ['SECRETARY'],
        permissions: const ['group.view', 'contribution.view'],
      ),
    );
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Hakiki na Fungua'), findsNothing);
    expect(find.text('Simamia Walioondolewa'), findsNothing);
    expect(find.text('Sitisha Kipindi'), findsNothing);
    expect(find.text('Weka Kiasi kwa Kila Mwanachama'), findsNothing);
  });

  testWidgets(
    'an OPEN period shows Enroll/Close only with the relevant permissions',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(
          status: 'OPEN',
          snapshotAmountMode: 'FIXED',
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

      expect(find.text('Funga Kipindi'), findsOneWidget);
      // No contribution.member_enroll -> Enroll never appears.
      expect(find.text('Andikisha Mwanachama'), findsNothing);
    },
  );

  testWidgets('a CANCELLED period shows no lifecycle actions at all', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextPeriod = fakeContributionPeriod(status: 'CANCELLED')
      ..nextSetup = fakeContributionSetup();

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionPeriodDetailPath('period-1'));
    await tester.pumpAndSettle();

    expect(find.text('Hakiki na Fungua'), findsNothing);
    expect(find.text('Sitisha Kipindi'), findsNothing);
    expect(find.text('Funga Kipindi'), findsNothing);
    expect(find.text('Angalia Malipo Yaliyotozwa'), findsNothing);
  });
}
