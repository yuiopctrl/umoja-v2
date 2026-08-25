import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/domain/contribution_type_page.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

void main() {
  testWidgets(
    'the fixed-amount field only shows for FIXED amount mode, and penalty '
    'fields only show once penalty mode is not NONE',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextTypesPage = ContributionTypePage(
          items: [fakeContributionType()],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionSetupNew);
      await tester.pumpAndSettle();

      // FIXED is the default amount mode -> the fixed-amount field is
      // visible immediately.
      expect(
        find.byKey(const Key('contributionSetupFixedAmountField')),
        findsOneWidget,
      );
      // NONE is the default penalty mode -> no penalty detail field yet.
      expect(
        find.byKey(const Key('contributionSetupPenaltyValueField')),
        findsNothing,
      );

      // Switch amount mode to CUSTOM_PER_MEMBER -> fixed-amount field
      // disappears.
      await tester.tap(
        find.byKey(const Key('contributionSetupAmountModeField')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiasi Tofauti kwa Kila Mwanachama').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contributionSetupFixedAmountField')),
        findsNothing,
      );

      // Switch penalty mode away from NONE -> penalty detail fields
      // appear. The field is further down the (scrollable) form than
      // the current viewport, so scroll it into view before tapping.
      await tester.ensureVisible(
        find.byKey(const Key('contributionSetupPenaltyModeField')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('contributionSetupPenaltyModeField')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiasi Maalum (Mara Moja)').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contributionSetupPenaltyValueField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('contributionSetupPenaltyGraceDaysField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('contributionSetupPenaltyCapAmountField')),
        findsOneWidget,
      );
    },
  );
}
