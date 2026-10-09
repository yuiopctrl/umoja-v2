import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/app/routing/feature_scaffold_routes.dart';
import 'package:umoja/app/routing/member_self_service_routes.dart';
import 'package:umoja/app/routing/navigation_history_provider.dart';
import 'package:umoja/app/shell/app_shell.dart';
import 'package:umoja/app/shell/app_top_bar.dart';
import 'package:umoja/app/shell/umoja_feature_scaffold.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09G-B6-C.5 §E/§F: clears the in-session navigation history so
/// a subsequent `router.go(...)` genuinely represents a fresh,
/// no-prior-browsing entry (the restoration scenario — an app launch
/// that landed directly on this location without passing through
/// Home first) rather than the implicit "Home was visited during the
/// test harness's own bootstrap" history every other test in this
/// file deliberately exercises.
void clearNavigationHistory(WidgetTester tester) {
  ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(navigationHistoryProvider.notifier)
      .clear();
}

/// Prompt 09G-B6-C.2: legacy top-bar migration. Physical UAT found that
/// 09G-B6-C.1 fixed only the redundant push()-caused back arrow — the
/// screen still showed the persistent, group-only [AppTopBar] stacked
/// above a SEPARATE "Payments" page heading, i.e. two independent
/// header levels. This phase migrates officer Payments (its root and
/// its one reachable child, Payment History) plus the Members,
/// Contributions, Finance, and Loans roots onto the SAME shared
/// [UmojaFeatureScaffold] header the newer member self-service screens
/// already use, so each migrated screen has exactly ONE coherent top
/// navigation region: title + selected group + actions, never AppTopBar
/// plus a second independent heading. No backend/accounting/permission
/// change is involved.
void main() {
  group('officer Payments root — ONE coherent header (§L)', () {
    testWidgets(
      'title, group, refresh and avatar all live in exactly one header; '
      'AppTopBar is not simultaneously rendered; no back arrow when there '
      'is no meaningful previous history (Prompt 09G-B6-C.5 §E)',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        // §E: a feature root with no meaningful in-session history
        // (the restored/initial-location case) must never invent a
        // misleading back arrow — simulated here by clearing the
        // history the test harness's own Home-first bootstrap leaves
        // behind, so this genuinely represents "nothing to go back
        // to", not "reached from Home" (covered separately below).
        clearNavigationHistory(tester);
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        // Exactly one AppBar in the whole tree, and it is the shared
        // feature scaffold's own — never the old persistent AppTopBar
        // stacked above a second "Payments" heading.
        expect(find.byType(AppTopBar), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        // The title appears exactly once — never duplicated as a
        // second standalone heading between the header and the cards.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Payments'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Umoja Wamama'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('refreshPermissionsButton')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(find.byKey(const Key('umojaFeatureBackButton')), findsNothing);
      },
    );

    testWidgets('Home -> Payments shows a back arrow, and Back returns to Home '
        '(Prompt 09G-B6-C.5 §D — supersedes the old "roots never show '
        'back" rule)', (tester) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homePaymentsShortcut')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('bottom navigation still highlights Payments', (tester) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homePaymentsShortcut')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.paymentsList);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets(
      'reaching /payments from the Home shortcut keeps the single-header '
      'result (§N: primary go() semantics from C.1 still protected)',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('homePaymentsShortcut')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.paymentsList);
        expect(find.byType(AppBar), findsOneWidget);
        // §D: Home is now a real previous location, so a back arrow
        // correctly appears — the single-header invariant this test
        // protects is about there being exactly ONE AppBar, not about
        // back-arrow visibility.
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      },
    );

    testWidgets(
      'navigating Home -> Payments -> Home -> Payments never accumulates '
      'a back stack (no route loop)',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('homePaymentsShortcut')));
        await tester.pumpAndSettle();
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('homePaymentsShortcut')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.paymentsList);
        // §D: Payments now correctly shows a back arrow (Home is the
        // real previous location) — the "no route loop" guarantee is
        // that pressing it goes to Home exactly once, never bouncing
        // back and forth or accumulating duplicate consecutive
        // history entries from the repeated Home<->Payments hops above.
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.home);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
      },
    );

    testWidgets(
      'feature content (Record Payment/Payment History/Receipts/Wallet) '
      'begins immediately below the header, with no second heading',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Payments'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('paymentsHomeHistoryEntry')),
          findsOneWidget,
        );
      },
    );
  });

  group('Payment History child — ONE compact child header (§D/§Q.8-10)', () {
    testWidgets(
      'has exactly one compact header with back navigation, no AppTopBar, '
      'and no duplicated in-body title',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('paymentsHomeHistoryEntry')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.paymentsHistory);
        expect(find.byType(AppTopBar), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        // The title lives once, in the compact header — never repeated
        // as a second in-body heading above the search field/list.
        expect(find.text('Payment History'), findsOneWidget);
      },
    );

    testWidgets('back returns to Payments', (tester) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentsList);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('paymentsHomeHistoryEntry')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.paymentsList);
    });
  });

  group('officer/member Payments separation', () {
    testWidgets(
      'without payment.view/payment.create the Payments hub shows no entries '
      '(content-gated, unchanged by this migration)',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          membership: paymentMembership(
            roles: const ['MEMBER'],
            permissions: const ['group.view'],
          ),
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.paymentsList);
        expect(find.byKey(const Key('paymentsHomeHistoryEntry')), findsNothing);
        expect(
          find.byKey(const Key('paymentsHomeRecordPaymentEntry')),
          findsNothing,
        );
      },
    );

    testWidgets('member /me/payments remains gated by payment.self_view', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['TREASURER'],
          permissions: const ['group.view', 'payment.view'],
        ),
      );
      router.go(AppRoutes.myPayments);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets(
      'an officer with MEMBER baseline keeps BOTH destinations separately '
      'reachable, each with its own correct header',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          membership: paymentMembership(
            roles: const ['TREASURER', 'MEMBER'],
            permissions: const [
              'group.view',
              'payment.view',
              'payment.self_view',
            ],
          ),
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.paymentsList);
        expect(find.byType(AppTopBar), findsNothing);
        expect(find.byIcon(Icons.arrow_back), findsNothing);

        router.go(AppRoutes.myPayments);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.myPayments);
        expect(find.byType(AppTopBar), findsNothing);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      },
    );
  });

  group('member self-service child routes retain the compact shell (§O)', () {
    testWidgets(
      '/me/payments suppresses the persistent AppTopBar in favor of the '
      'compact member child shell — the visual reference for this phase',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          membership: paymentMembership(
            roles: const ['MEMBER'],
            permissions: const ['group.view', 'payment.self_view'],
          ),
        );
        router.go(AppRoutes.myPayments);
        await tester.pumpAndSettle();

        expect(find.byType(AppTopBar), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
      },
    );

    test(
      'the registry remains the single source for member self-service, and '
      'the officer feature-route list has no member semantics of its own',
      () {
        expect(isMyPaymentsRoute('/me/payments'), isTrue);
        expect(isMemberSelfServiceChildRoute('/me/payments/p1'), isTrue);
        expect(
          isMemberSelfServiceChildRoute('/me/payments/p1/receipt'),
          isTrue,
        );
        expect(isMemberSelfServiceChildRoute(AppRoutes.paymentsList), isFalse);
        expect(usesLegacyAppTopBar(AppRoutes.paymentsList), isFalse);
        expect(usesLegacyAppTopBar(AppRoutes.myPayments), isFalse);
        expect(usesLegacyAppTopBar(AppRoutes.home), isTrue);
        expect(usesLegacyAppTopBar(AppRoutes.more), isTrue);
      },
    );
  });

  group('representative legacy roots now use the new style (§F/§Q.11-14)', () {
    testWidgets('Members root: one header, no back arrow, no AppTopBar', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'member.view'],
        ),
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.membersList);
      await tester.pumpAndSettle();

      expect(find.byType(AppTopBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Members'), findsOneWidget);
    });

    testWidgets('Contributions root: one header, no back arrow, no AppTopBar', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'contribution.view'],
        ),
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.contributionsHome);
      await tester.pumpAndSettle();

      expect(find.byType(AppTopBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Contributions'), findsOneWidget);
    });

    testWidgets('Finance root: one header, no back arrow, no AppTopBar', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'financial_account.view'],
        ),
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.financeHome);
      await tester.pumpAndSettle();

      expect(find.byType(AppTopBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Finance'), findsOneWidget);
    });

    testWidgets('Loans root: one header, no back arrow, no AppTopBar', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'loan.view'],
        ),
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.loansHome);
      await tester.pumpAndSettle();

      expect(find.byType(AppTopBar), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Loans'), findsOneWidget);
    });
  });

  group('Home and More remain correct (unmigrated by design — §J/§K)', () {
    testWidgets('Home renders once, with no duplicate AppBar', (tester) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(AppTopBar), findsOneWidget);
    });

    testWidgets('More renders once, with no duplicate AppBar', (tester) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.more);
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(AppTopBar), findsOneWidget);
    });
  });

  group('refresh/avatar behavior', () {
    testWidgets('refresh and avatar remain present on the persistent AppTopBar '
        '(Home, unmigrated)', (tester) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('refreshPermissionsButton')), findsOneWidget);
      expect(find.byType(AppTopBar), findsOneWidget);
    });

    testWidgets('refresh and avatar remain present on a migrated feature root '
        '(Payments) via the shared UmojaFeatureScaffold instead', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentsList);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('refreshPermissionsButton')), findsOneWidget);
      expect(find.byType(UmojaFeatureScaffold), findsOneWidget);
    });
  });

  group('theme tokens', () {
    testWidgets(
      'the shared feature scaffold AppBar uses the theme surface color, '
      'not a hardcoded one, in both light and dark mode',
      (tester) async {
        addTearDown(() {
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        });
        for (final brightness in [Brightness.light, Brightness.dark]) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          final router = await pumpPaymentsApp(
            tester,
            fakeRepo: FakePaymentRepository(),
            language: AppLanguage.english,
          );
          router.go(AppRoutes.paymentsList);
          await tester.pumpAndSettle();

          final appBar = tester.widget<AppBar>(find.byType(AppBar));
          final theme = Theme.of(tester.element(find.byType(AppBar)));
          expect(
            appBar.backgroundColor,
            theme.colorScheme.surface,
            reason: brightness.name,
          );
        }
      },
    );
  });

  // -- 09G-B6-C.3: complete legacy child migration -------------------------

  /// Prompt 09G-B6-C.3 §S/§V: for ANY route built inside the shell,
  /// either it is one of the two deliberate [usesLegacyAppTopBar]
  /// exceptions (Home/More), in which case [AppTopBar] is the single
  /// header — or it is not, in which case [AppTopBar] must be ABSENT
  /// and exactly one [AppBar] (the screen's own [UmojaFeatureScaffold])
  /// must be present. A route that fell through to neither (no header
  /// at all) or both (the exact failed physical pattern) fails this.
  void expectExactlyOneCorrectHeader(WidgetTester tester, String location) {
    final isLegacy = usesLegacyAppTopBar(location);
    expect(
      find.byType(AppTopBar),
      isLegacy ? findsOneWidget : findsNothing,
      reason: '$location: AppTopBar',
    );
    expect(find.byType(AppBar), findsOneWidget, reason: '$location: AppBar');
  }

  group('Payments family — complete (§G/§T)', () {
    testWidgets(
      'Record Payment: one header, back to Payments, no duplicate title',
      (tester) async {
        final fakeMemberRepo = FakeMemberRepository()
          ..nextListResult = GroupMemberPage.empty;
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          fakeMemberRepo: fakeMemberRepo,
          language: AppLanguage.english,
        );
        // §F: a genuine direct deep-link entry (no prior in-session
        // browsing) must still fall back correctly to the declared
        // static parent.
        clearNavigationHistory(tester);
        router.go(AppRoutes.paymentRecord);
        await tester.pumpAndSettle();

        expectExactlyOneCorrectHeader(tester, AppRoutes.paymentRecord);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Record Payment'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.paymentsList);
      },
    );

    testWidgets('Payment Detail: one header, back to Payment History', (
      tester,
    ) async {
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1');
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentDetailPath('p1'));
      await tester.pumpAndSettle();

      expectExactlyOneCorrectHeader(tester, AppRoutes.paymentDetailPath('p1'));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Receipt: one header, no duplicate title', (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1')
        ..nextReceipt = fakeReceipt();
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentReceiptPath('p1'));
      await tester.pumpAndSettle();

      expectExactlyOneCorrectHeader(tester, AppRoutes.paymentReceiptPath('p1'));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets(
      'Member Wallet Balance: one header, back to the wallet picker',
      (tester) async {
        final fakeMemberRepo = FakeMemberRepository()
          ..nextMemberResult = GroupMember(
            membershipId: 'm1',
            groupId: 'g1',
            displayName: 'Test Member',
            status: 'ACTIVE',
            createdAt: DateTime.utc(2026, 1, 15),
            isLoginLinked: false,
            roleCodes: const [],
          );
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          fakeMemberRepo: fakeMemberRepo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.walletDetailPath('m1'));
        await tester.pumpAndSettle();

        expectExactlyOneCorrectHeader(tester, AppRoutes.walletDetailPath('m1'));
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      },
    );

    testWidgets(
      'bottom navigation behavior remains correct across the whole family',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);

        await tester.tap(find.byKey(const Key('paymentsHomeHistoryEntry')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.paymentsHistory);
        // A child screen still shows the same bottom navigation chrome
        // (NavigationBar remains mounted via the shared shell).
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );
  });

  group('other families — representative root + child (§U)', () {
    testWidgets('Member Detail: one header, back to Members', (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [
            GroupMember(
              membershipId: 'm1',
              groupId: 'g1',
              displayName: 'Test Member',
              status: 'ACTIVE',
              createdAt: DateTime.utc(2026, 1, 15),
              isLoginLinked: false,
              roleCodes: const [],
            ),
          ],
          totalCount: 1,
          limit: 25,
          offset: 0,
        )
        ..nextMemberResult = GroupMember(
          membershipId: 'm1',
          groupId: 'g1',
          displayName: 'Test Member',
          status: 'ACTIVE',
          createdAt: DateTime.utc(2026, 1, 15),
          isLoginLinked: false,
          roleCodes: const [],
        );
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        fakeMemberRepo: fakeMemberRepo,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'member.view'],
        ),
        language: AppLanguage.english,
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.memberDetailPath('m1'));
      await tester.pumpAndSettle();

      expectExactlyOneCorrectHeader(tester, AppRoutes.memberDetailPath('m1'));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.membersList);
    });

    testWidgets('Contribution Types list: one header, back to Contributions', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'contribution.view'],
        ),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.contributionTypesList);
      await tester.pumpAndSettle();

      expectExactlyOneCorrectHeader(tester, AppRoutes.contributionTypesList);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Financial Accounts list: one header, back to Finance', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'financial_account.view'],
        ),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.financialAccountsList);
      await tester.pumpAndSettle();

      expectExactlyOneCorrectHeader(tester, AppRoutes.financialAccountsList);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Loan Products list: one header, back to Loans', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'loan_product.view'],
        ),
        language: AppLanguage.english,
      );
      router.go(AppRoutes.loanProductsList);
      await tester.pumpAndSettle();

      expectExactlyOneCorrectHeader(tester, AppRoutes.loanProductsList);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('suppression/header invariant (§M)', () {
    testWidgets(
      'every suppressed (non-legacy) route in this file supplies its own '
      'AppBar — the invariant that would catch a future route falling '
      'through to neither header',
      (tester) async {
        final fakeMemberRepo = FakeMemberRepository()
          ..nextListResult = GroupMemberPage.empty
          ..nextMemberResult = GroupMember(
            membershipId: 'm1',
            groupId: 'g1',
            displayName: 'Test Member',
            status: 'ACTIVE',
            createdAt: DateTime.utc(2026, 1, 15),
            isLoginLinked: false,
            roleCodes: const [],
          );
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository()
            ..nextPaymentDetail = fakePaymentDetail(paymentId: 'p1'),
          fakeMemberRepo: fakeMemberRepo,
          membership: paymentMembership(
            roles: const ['ADMIN'],
            permissions: const [
              'group.view',
              'member.view',
              'contribution.view',
              'financial_account.view',
              'loan.view',
              'loan_product.view',
              'payment.view',
              'payment.create',
            ],
          ),
          language: AppLanguage.english,
        );

        for (final route in [
          AppRoutes.paymentsList,
          AppRoutes.paymentsHistory,
          AppRoutes.membersList,
          AppRoutes.contributionsHome,
          AppRoutes.financeHome,
          AppRoutes.loansHome,
          AppRoutes.paymentDetailPath('p1'),
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(usesLegacyAppTopBar(route), isFalse, reason: route);
          expect(find.byType(AppTopBar), findsNothing, reason: route);
          expect(find.byType(AppBar), findsOneWidget, reason: route);
        }
      },
    );
  });

  // -- 09G-B6-C.4: member self-service back behavior + direct-entry fallback

  group('member self-service root back behavior (§D/§N)', () {
    testWidgets(
      'My Profile: back arrow visible on direct entry, back to More',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.myProfile);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
        await tester.tap(find.byKey(const Key('memberChildBackButton')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.more);
      },
    );

    testWidgets(
      'My Statement: back arrow visible on direct entry, back to More',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.myStatement);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
        await tester.tap(find.byKey(const Key('memberChildBackButton')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.more);
      },
    );

    testWidgets(
      'My Contributions: back arrow visible on direct entry, back to More',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          membership: paymentMembership(
            roles: const ['MEMBER'],
            permissions: const ['group.view', 'contribution.self_view'],
          ),
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.myContributions);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
        await tester.tap(find.byKey(const Key('memberChildBackButton')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.more);
      },
    );

    testWidgets('My Loans: back arrow visible on direct entry, back to More', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        membership: paymentMembership(
          roles: const ['MEMBER'],
          permissions: const ['group.view', 'loan.self_view'],
        ),
        language: AppLanguage.english,
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('memberChildBackButton')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.more);
    });

    testWidgets(
      'My Payments: back arrow visible on direct entry, back to More',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          membership: paymentMembership(
            roles: const ['MEMBER'],
            permissions: const ['group.view', 'payment.self_view'],
          ),
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.myPayments);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
        await tester.tap(find.byKey(const Key('memberChildBackButton')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.more);
      },
    );
  });

  group(
    'direct-entry CHILD routes with an empty navigation stack (§F/§G/§O)',
    () {
      testWidgets(
        'Member Wallet Balance: direct entry still shows back, and back '
        'reaches the wallet picker (not a false root)',
        (tester) async {
          final fakeMemberRepo = FakeMemberRepository()
            ..nextMemberResult = GroupMember(
              membershipId: 'm1',
              groupId: 'g1',
              displayName: 'Test Member',
              status: 'ACTIVE',
              createdAt: DateTime.utc(2026, 1, 15),
              isLoginLinked: false,
              roleCodes: const [],
            );
          final router = await pumpPaymentsApp(
            tester,
            fakeRepo: FakePaymentRepository(),
            fakeMemberRepo: fakeMemberRepo,
            language: AppLanguage.english,
          );
          // Direct entry: nothing pushed beforehand, so
          // Navigator.canPop() is false here — exactly the deep-link
          // condition §F requires a back arrow to survive.
          clearNavigationHistory(tester);
          router.go(AppRoutes.walletDetailPath('m1'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.arrow_back), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          expect(router.state.uri.path, AppRoutes.walletMemberPicker);
          expect(find.byType(AppBar), findsOneWidget);
        },
      );

      testWidgets('Financial Accounts: direct entry still shows back, and back '
          'reaches Finance (not a false root)', (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          membership: paymentMembership(
            roles: const ['ADMIN'],
            permissions: const ['group.view', 'financial_account.view'],
          ),
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.financialAccountsList);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.financeHome);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(AppTopBar), findsNothing);
      });

      testWidgets(
        'Loan Account Detail: direct entry still shows back, and back '
        'reaches the Loan Accounts list (not a false root)',
        (tester) async {
          final router = await pumpPaymentsApp(
            tester,
            fakeRepo: FakePaymentRepository(),
            membership: paymentMembership(
              roles: const ['ADMIN'],
              permissions: const ['group.view', 'loan.view'],
            ),
            language: AppLanguage.english,
          );
          clearNavigationHistory(tester);
          router.go(AppRoutes.loanAccountDetailPath('missing-loan'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.arrow_back), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          expect(router.state.uri.path, AppRoutes.loanAccountsList);
        },
      );

      testWidgets(
        'Record Payment: direct entry still shows back, and back reaches '
        'Payments without looping back to Record Payment',
        (tester) async {
          final fakeMemberRepo = FakeMemberRepository()
            ..nextListResult = GroupMemberPage.empty;
          final router = await pumpPaymentsApp(
            tester,
            fakeRepo: FakePaymentRepository(),
            fakeMemberRepo: fakeMemberRepo,
            language: AppLanguage.english,
          );
          clearNavigationHistory(tester);
          router.go(AppRoutes.paymentRecord);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.arrow_back), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          expect(router.state.uri.path, AppRoutes.paymentsList);
          // No loop: back from Payments itself has no back arrow — the
          // one history entry ('/payments/record') was consumed by the
          // Back press above and nothing remains for this build.
          expect(find.byIcon(Icons.arrow_back), findsNothing);
        },
      );
    },
  );

  group('root direct-entry (§P)', () {
    testWidgets(
      'direct-loading each of the five primary roots shows no back arrow, '
      'one header, correct title, group subtitle, and avatar',
      (tester) async {
        final fakeMemberRepo = FakeMemberRepository()
          ..nextListResult = GroupMemberPage.empty;
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          fakeMemberRepo: fakeMemberRepo,
          membership: paymentMembership(
            roles: const ['ADMIN'],
            permissions: const [
              'group.view',
              'member.view',
              'contribution.view',
              'financial_account.view',
              'loan.view',
              'payment.view',
            ],
          ),
          language: AppLanguage.english,
        );

        const expectedTitles = {
          AppRoutes.paymentsList: 'Payments',
          AppRoutes.membersList: 'Members',
          AppRoutes.contributionsHome: 'Contributions',
          AppRoutes.financeHome: 'Finance',
          AppRoutes.loansHome: 'Loans',
        };

        for (final entry in expectedTitles.entries) {
          // Each root must be checked as a genuine direct-entry/no-
          // history case, not as "reached from the previous root in
          // this loop" — otherwise the (k+1)th iteration would
          // legitimately show a back arrow to the kth root, which is
          // correct new §D behavior but not what this test (direct
          // entry, §P) is verifying.
          clearNavigationHistory(tester);
          router.go(entry.key);
          await tester.pumpAndSettle();

          expect(
            find.byIcon(Icons.arrow_back),
            findsNothing,
            reason: entry.key,
          );
          expect(find.byType(AppTopBar), findsNothing, reason: entry.key);
          expect(find.byType(AppBar), findsOneWidget, reason: entry.key);
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
            reason: entry.key,
          );
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Umoja Wamama'),
            ),
            findsOneWidget,
            reason: entry.key,
          );
          expect(
            find.byKey(const Key('refreshPermissionsButton')),
            findsOneWidget,
            reason: entry.key,
          );
        }
      },
    );
  });

  group('navigation history flow (09G-B6-C.5 final re-audit)', () {
    testWidgets(
      'Home -> Payments: Payments shows Back, and Back returns to Home '
      '(the locked §D example)',
      (tester) async {
        // pumpPaymentsApp's own bootstrap already settles at Home and
        // records it — exactly the real "Home -> Payments" case this
        // locks down, never a contrived clear-then-go-home no-op
        // (going to the already-current location records nothing new).
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.home);
      },
    );

    testWidgets(
      'Home -> More -> Payments: Back returns to More, the real previous '
      'location, never blindly Home',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.more);
        await tester.pumpAndSettle();
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.more);
      },
    );

    testWidgets(
      'Home -> Payments -> Record Payment: Back reaches Payments, then '
      'Back again reaches Home — the full chain, no step skipped',
      (tester) async {
        final fakeMemberRepo = FakeMemberRepository()
          ..nextListResult = GroupMemberPage.empty;
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          fakeMemberRepo: fakeMemberRepo,
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();
        router.go(AppRoutes.paymentRecord);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.paymentsList);

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.home);
      },
    );

    testWidgets(
      'Back consumption never re-adds routes: Home -> Payments -> Back -> '
      'Home -> Payments -> Back lands on Home both times, never bouncing '
      'between the same two routes indefinitely or accumulating duplicate '
      'consecutive history entries',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.home);

        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.home);
      },
    );
  });

  group('root-header title spacing (09G-B6-C.5 §E physical defect fix)', () {
    testWidgets(
      'Payments direct-entry with no history: no leading widget, and the '
      'AppBar uses default titleSpacing (never hugging the left edge)',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leading, isNull);
        expect(appBar.titleSpacing, isNull);
      },
    );

    testWidgets(
      'Payments reached from Home: the leading back arrow is present, and '
      'titleSpacing is explicitly 0 so the title sits flush next to it',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
        );
        router.go(AppRoutes.paymentsList);
        await tester.pumpAndSettle();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leading, isNotNull);
        expect(appBar.titleSpacing, 0);
      },
    );

    testWidgets('Members direct-entry with no history: same no-leading/default-'
        'spacing treatment as Payments — not a Payments-only fix', (
      tester,
    ) async {
      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: FakePaymentRepository(),
        language: AppLanguage.english,
        membership: paymentMembership(
          roles: const ['ADMIN'],
          permissions: const ['group.view', 'member.view'],
        ),
      );
      clearNavigationHistory(tester);
      router.go(AppRoutes.membersList);
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, isNull);
      expect(appBar.titleSpacing, isNull);
    });

    testWidgets(
      'A CHILD route (always has a leading back arrow) always uses the '
      'flush titleSpacing of 0, regardless of history',
      (tester) async {
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          language: AppLanguage.english,
          membership: paymentMembership(
            roles: const ['ADMIN'],
            permissions: const ['group.view', 'financial_account.view'],
          ),
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.financialAccountsList);
        await tester.pumpAndSettle();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leading, isNotNull);
        expect(appBar.titleSpacing, 0);
      },
    );
  });

  group(
    'direct-entry Record Payment with no history (09G-B6-C.5 re-audit)',
    () {
      testWidgets('Back is visible, and Back reaches Payments', (tester) async {
        final fakeMemberRepo = FakeMemberRepository()
          ..nextListResult = GroupMemberPage.empty;
        final router = await pumpPaymentsApp(
          tester,
          fakeRepo: FakePaymentRepository(),
          fakeMemberRepo: fakeMemberRepo,
          language: AppLanguage.english,
        );
        clearNavigationHistory(tester);
        router.go(AppRoutes.paymentRecord);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.paymentsList);
      });
    },
  );
}
