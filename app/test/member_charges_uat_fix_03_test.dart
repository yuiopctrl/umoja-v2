import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/contributions/presentation/contribution_charge_detail_screen.dart';
import 'package:umoja/features/contributions/providers/contribution_repository_provider.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_repository_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/payments/controllers/payment_post_controller.dart';
import 'package:umoja/features/payments/providers/member_contribution_charges_provider.dart';
import 'package:umoja/features/payments/providers/payment_repository_provider.dart';

import 'fakes/fake_contribution_repository.dart';
import 'fakes/fake_financial_account_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 07 UAT-FIX-03 regression coverage: the member-centric
/// Charges/Madeni view. Before this, the only way to see all charges
/// for one member was opening each contribution period individually.
void main() {
  // A. Member Detail exposes a Charges/Madeni entry point, gated by
  // contribution.view + payment.view.
  testWidgets('A: Member Detail shows a Charges/Madeni entry point with '
      'contribution.view + payment.view, and hides it without', (tester) async {
    final fakeMemberRepo = FakeMemberRepository();
    final fakeRepo = FakePaymentRepository();

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.memberDetailPath('m1'));
    await tester.pumpAndSettle();

    expect(find.text('Charges'), findsOneWidget);
    expect(find.text('View Charges'), findsOneWidget);
  });

  testWidgets(
    'A: the Charges/Madeni entry point is hidden without payment.view',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository();
      final fakeRepo = FakePaymentRepository();

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['SECRETARY'],
          permissions: const ['group.view', 'contribution.view'],
        ),
      );
      router.go(AppRoutes.memberDetailPath('m1'));
      await tester.pumpAndSettle();

      expect(find.text('View Charges'), findsNothing);
    },
  );

  // B. A member with charges across multiple periods sees all of them
  // in one list (ALL filter).
  testWidgets('B: a member with charges in two different periods sees both in '
      'one list under the All filter', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage(
        filter: 'ALL',
        items: [
          fakeMemberCharge(
            chargeId: 'charge-jul',
            periodLabel: 'Julai 2026',
            outstanding: 0,
          ),
          fakeMemberCharge(
            chargeId: 'charge-aug',
            periodLabel: 'Agosti 2026',
            outstanding: 20000,
          ),
        ],
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Julai 2026'), findsOneWidget);
    expect(find.textContaining('Agosti 2026'), findsOneWidget);
  });

  // C. The default filter is Outstanding, and the screen requests it
  // by default without the user having to choose it.
  testWidgets('C: the Charges screen defaults to the Outstanding filter', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage(filter: 'OUTSTANDING');

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    expect(fakeRepo.listMemberContributionChargesCalls, isNotEmpty);
    expect(
      fakeRepo.listMemberContributionChargesCalls.first.filter,
      'OUTSTANDING',
    );
  });

  // D. Switching to All/Settled requests that filter from the backend
  // — never re-filtered client-side from a cached Outstanding page.
  testWidgets('D: selecting the Settled filter requests it from the backend', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage();

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settled'));
    await tester.pumpAndSettle();

    expect(fakeRepo.listMemberContributionChargesCalls.last.filter, 'SETTLED');
  });

  // E. An overdue charge shows the Overdue badge.
  testWidgets('E: an overdue charge displays the Overdue badge', (
    tester,
  ) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage(
        items: [fakeMemberCharge(isOverdue: true)],
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    // "Overdue" appears twice: once as the filter chip label (always
    // rendered) and once as this charge's status badge.
    expect(find.text('Overdue'), findsNWidgets(2));
  });

  // F. A WAIVER component reduces the obligation and is never labeled
  // as a payment.
  testWidgets(
    'F: a WAIVER component shows as its own reducing line, never as a '
    'payment',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextChargesPage = fakeMemberChargesPage(
          items: [
            fakeMemberCharge(
              netAssessed: 17000,
              allocated: 17000,
              outstanding: 0,
              components: [
                fakeMemberChargeComponent(componentType: 'BASE', amount: 20000),
                fakeMemberChargeComponent(
                  componentType: 'WAIVER',
                  amount: -3000,
                ),
              ],
            ),
          ],
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.memberChargesPath('m1'));
      await tester.pumpAndSettle();
      // Outstanding-default hides a fully-settled charge — switch to
      // All to see it.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Waiver'), findsOneWidget);
      expect(find.textContaining('-3,000'), findsOneWidget);
    },
  );

  // G. An opening-balance charge shows the contribution type alone,
  // never "Type — Period".
  testWidgets('G: an opening-balance charge shows only the contribution type, '
      'no period suffix', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage(
        items: [
          fakeMemberCharge(
            contributionTypeName: 'Ada',
            periodLabel: 'Opening',
            periodPurpose: 'OPENING_BALANCE',
          ),
        ],
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.textContaining('Ada —'), findsNothing);
  });

  // H. Tapping a charge row opens the EXISTING Contribution Charge
  // Detail screen — no duplicate implementation.
  testWidgets('H: tapping a charge row navigates to the existing Contribution '
      'Charge Detail screen', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage(
        items: [fakeMemberCharge(chargeId: 'charge-42')],
      );
    final fakeContributionRepo = FakeContributionRepository();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(
              id: 'u1',
              fullName: 'Treasurer Caller',
            ),
            memberships: [paymentMembership()],
          ),
        ),
        paymentRepositoryProvider.overrideWithValue(fakeRepo),
        contributionRepositoryProvider.overrideWithValue(fakeContributionRepo),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
        financialAccountRepositoryProvider.overrideWithValue(
          FakeFinancialAccountRepository()
            ..nextAccountsPage = const FinancialAccountPage(
              items: [],
              totalCount: 0,
              limit: 100,
              offset: 0,
            ),
        ),
        languageProvider.overrideWith(
          () => _FixedTestLanguage(AppLanguage.english),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const UmojaApp()),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Ada').first);
    await tester.pumpAndSettle();

    expect(find.byType(ContributionChargeDetailScreen), findsOneWidget);
  });

  // I. Rekodi Malipo opens the EXISTING Record Payment flow with the
  // member already selected — the picker step is skipped.
  testWidgets(
    'I: Rekodi Malipo opens Record Payment with the member preselected, '
    'skipping the picker step',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository();
      final fakeRepo = FakePaymentRepository()
        ..nextChargesPage = fakeMemberChargesPage();

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.memberChargesPath('m1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();

      expect(fakeMemberRepo.getMemberCalls.single.membershipId, 'm1');
      // The member-picker search field never appears — the flow lands
      // directly on the amount-entry form.
      expect(find.byKey(const Key('recordPaymentAmountField')), findsOneWidget);
    },
  );

  // J. A SUSPENDED/EXITED member's historical charges remain fully
  // visible — no client-side status filtering.
  testWidgets(
    'J: a SUSPENDED member\'s historical charges remain visible on this '
    'screen',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextChargesPage = fakeMemberChargesPage(
          membershipStatus: 'SUSPENDED',
          filter: 'ALL',
          items: [fakeMemberCharge(chargeId: 'charge-old')],
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.memberChargesPath('m1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ada'), findsOneWidget);
    },
  );

  // K. No layout overflow at mobile width.
  testWidgets('K: no layout overflow at mobile width (360)', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextChargesPage = fakeMemberChargesPage(
        items: [
          fakeMemberCharge(isOverdue: true),
          fakeMemberCharge(chargeId: 'charge-2'),
        ],
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.memberChargesPath('m1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // L. Posting a payment invalidates the member charges list provider
  // so the outstanding total refreshes without an app restart.
  test('L: a successful payment post invalidates the member charges list '
      'provider', () async {
    final fakeRepo = FakePaymentRepository();
    final container = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(fakeRepo),
        selectedGroupProvider.overrideWith(_FixedSelectedGroup.new),
      ],
    );
    addTearDown(container.dispose);

    const query = (membershipId: 'm1', filter: 'OUTSTANDING', limit: 10);

    var builds = 0;
    container.listen(
      memberContributionChargesProvider(query),
      (_, _) => builds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final before = builds;

    await container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 10000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );
    await Future<void>.delayed(Duration.zero);

    expect(builds, greaterThan(before));
  });
}

class _FixedSelectedGroup extends SelectedGroupNotifier {
  @override
  SelectedGroupState build() => SelectedGroupResolved(paymentMembership());
}

class _FixedTestLanguage extends LanguageNotifier {
  _FixedTestLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
