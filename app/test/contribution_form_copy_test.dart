import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

// Regression coverage for the UAT-reported wording bugs: the Contribution
// Type/Setup forms wrongly reused the Members feature's "Member
// Information" section heading, and PASS_THROUGH's raw-enum-sounding
// label was shown to normal users.
void main() {
  testWidgets(
    'the Contribution Type form does not say "Member Information" and '
    'shows its own section heading (Swahili default)',
    (tester) async {
      final fakeRepo = FakeContributionRepository();
      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionTypeNew);
      await tester.pumpAndSettle();

      expect(find.text('Taarifa za Mwanachama'), findsNothing);
      expect(find.text('Member Information'), findsNothing);
      expect(find.text('Taarifa za Aina ya Mchango'), findsOneWidget);
    },
  );

  testWidgets(
    'the Contribution Setup form does not say "Member Information" and '
    'shows its own section heading (Swahili default)',
    (tester) async {
      final fakeRepo = FakeContributionRepository();
      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionSetupNew);
      await tester.pumpAndSettle();

      expect(find.text('Taarifa za Mwanachama'), findsNothing);
      expect(find.text('Member Information'), findsNothing);
      expect(find.text('Taarifa za Mpangilio'), findsOneWidget);
    },
  );

  testWidgets('the Contribution Type form does not say "Member Information" in '
      'English either', (tester) async {
    final fakeRepo = FakeContributionRepository();
    final router = await pumpContributionsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.push(AppRoutes.contributionTypeNew);
    await tester.pumpAndSettle();

    expect(find.text('Member Information'), findsNothing);
    expect(find.text('Contribution Type Details'), findsOneWidget);
  });

  testWidgets(
    'PASS_THROUGH renders as "Si Pato la Kikundi" in Swahili, never the '
    'raw enum',
    (tester) async {
      final fakeRepo = FakeContributionRepository();
      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.contributionTypeNew);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('contributionTypeTreatmentField')));
      await tester.pumpAndSettle();

      expect(find.text('Si Pato la Kikundi'), findsWidgets);
      expect(find.text('PASS_THROUGH'), findsNothing);
      expect(find.text('Kupitisha Fedha'), findsNothing);
    },
  );

  testWidgets(
    'PASS_THROUGH renders as "Not Group Income" in English, never the raw '
    'enum',
    (tester) async {
      final fakeRepo = FakeContributionRepository();
      final router = await pumpContributionsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.contributionTypeNew);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('contributionTypeTreatmentField')));
      await tester.pumpAndSettle();

      expect(find.text('Not Group Income'), findsWidgets);
      expect(find.text('PASS_THROUGH'), findsNothing);
    },
  );
}
