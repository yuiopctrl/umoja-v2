import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_item.dart';
import 'package:umoja/features/contributions/domain/contribution_opening_balance_page.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets('the entry card and Import action are visible with '
      'contribution.opening_balance.manage', (tester) async {
    final fakeRepo = FakeContributionRepository();

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionsHome);
    await tester.pumpAndSettle();

    expect(find.text('Madeni ya Mwanzo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('contributionOpeningBalancesEntry')));
    await tester.pumpAndSettle();

    // Lands on the opening-balances list (its own title is also
    // "Madeni ya Mwanzo"). On the default mobile test viewport the
    // Import action renders as the FAB, not the header button.
    expect(find.byKey(const Key('openingBalanceImportFab')), findsOneWidget);
  });

  testWidgets(
    'the entry card is hidden without contribution.opening_balance.manage',
    (tester) async {
      final fakeRepo = FakeContributionRepository();

      final router = await pumpContributionsApp(
        tester,
        fakeRepo: fakeRepo,
        membership: contributionMembership(
          roles: const ['SECRETARY'],
          permissions: const ['group.view', 'contribution.view'],
        ),
      );
      router.go(AppRoutes.contributionsHome);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contributionOpeningBalancesEntry')),
        findsNothing,
      );
    },
  );

  testWidgets('an empty opening-balances list shows the empty state', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextOpeningBalancesPage = ContributionOpeningBalancePage.empty;

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionOpeningBalancesList);
    await tester.pumpAndSettle();

    expect(find.text('Hakuna Deni la Mwanzo'), findsOneWidget);
  });

  testWidgets('a populated opening-balances list shows each member row', (
    tester,
  ) async {
    final fakeRepo = FakeContributionRepository()
      ..nextOpeningBalancesPage = ContributionOpeningBalancePage(
        items: [
          ContributionOpeningBalanceItem(
            chargeId: 'charge-ob-1',
            membershipId: 'm1',
            memberNumberSnapshot: 'UM-0009',
            memberNameSnapshot: 'Ob Member One',
            effectiveAt: DateTime.utc(2027, 1, 1),
            contributionTypeName: 'Dues',
            category: 'GENERAL',
            accountingTreatment: 'GROUP_INCOME',
            openingBalanceAmount: 75000,
            netAssessed: 75000,
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

    final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.contributionOpeningBalancesList);
    await tester.pumpAndSettle();

    expect(find.text('Ob Member One'), findsOneWidget);
    expect(find.textContaining('75,000'), findsOneWidget);
  });
}
