import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

// Regression test for the unbounded-height crash: ContributionSetupFormScreen
// used to show its edit-mode loading state via `UmojaLoadingState` (a
// `ListView`) as the lone `UmojaPage` body inside the default scrollable
// (unbounded-height) wrapper — the exact same layout pattern that crashed
// `ContributionPeriodFormScreen` (fixed in 06A-CLOSEOUT). `pumpAndSettle`
// below renders the transient loading frame before the fake repository's
// future resolves, so it would surface the "Vertical viewport was given
// unbounded height" assertion here if the bug regressed.
void main() {
  testWidgets(
    'opening Contribution Setup edit does not throw a layout exception '
    'while loading, and resolves into the form correctly',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextSetup = fakeContributionSetup(name: 'Mchango wa Mwezi');

      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionSetupEditPath('setup-1'));

      // No layout exception thrown while the loading state is rendered.
      await tester.pumpAndSettle();

      // Resolves from loading into the prefilled form.
      expect(find.text('Hariri Mpangilio'), findsOneWidget);
      expect(find.text('Mchango wa Mwezi'), findsOneWidget);
    },
  );
}
