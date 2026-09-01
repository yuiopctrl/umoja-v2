import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/payments/domain/member_contribution_statement.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09C-UAT-FIX-01: the Payment Engine is shared across
/// Contributions/Loans/Wallet, so Record Payment/Payment History/
/// Receipts/Member Wallet move to a dedicated "Malipo" (Payments)
/// destination; Opening Balance stays under Contributions (it
/// represents obligation creation/import, never received cash). Also
/// covers the fixed Outstanding Obligations read model (both domains
/// shown before Preview) and the future-installment exclusion.
void main() {
  GroupMember janeDoe() => GroupMember(
    membershipId: 'm1',
    groupId: 'g1',
    displayName: 'Jane Doe',
    memberNumber: 'UMOJA-2026-001',
    status: 'ACTIVE',
    createdAt: DateTime.utc(2026, 1, 1),
    isLoginLinked: false,
  );

  testWidgets('the Payments hub is reachable at /payments and lists Record '
      'Payment, Payment History, Receipts, and Member Wallet', (tester) async {
    final fakeRepo = FakePaymentRepository();
    final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.paymentsList);
    await tester.pumpAndSettle();

    expect(find.text('Malipo'), findsWidgets);
    expect(
      find.byKey(const Key('paymentsHomeRecordPaymentEntry')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('paymentsHomeHistoryEntry')), findsOneWidget);
    expect(find.byKey(const Key('paymentsHomeReceiptsEntry')), findsOneWidget);
    expect(find.byKey(const Key('paymentsHomeWalletEntry')), findsOneWidget);
  });

  testWidgets(
    'tapping Payment History from the Payments hub reaches the actual '
    'payment list at /payments/history',
    (tester) async {
      final fakeRepo = FakePaymentRepository();
      final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.paymentsList);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('paymentsHomeHistoryEntry')));
      await tester.pumpAndSettle();

      expect(find.text('Historia ya Malipo'), findsOneWidget);
    },
  );

  testWidgets(
    'Contributions no longer shows Record Payment, Payment History, or '
    'Member Wallet entries — only contribution-domain functions and '
    'Opening Balance',
    (tester) async {
      final fakeRepo = FakeContributionRepository();
      final router = await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.contributionsHome);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recordPaymentEntry')), findsNothing);
      expect(find.byKey(const Key('paymentsEntry')), findsNothing);
      expect(find.byKey(const Key('memberWalletEntry')), findsNothing);
      // Opening Balance still remains under Contributions — it
      // represents obligation creation/import, never received cash.
      expect(
        find.byKey(const Key('contributionOpeningBalancesEntry')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('contributionTypesEntry')), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a member shows both Contributions and Loans obligations '
    '(overdue/due-now/currently-payable), with an upcoming loan amount '
    'clearly labeled and excluded from Total Payable Now',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [janeDoe()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakePaymentRepository()
        ..nextStatement = fakeMemberContributionStatement(
          totalOutstanding: 20000,
          contributionOverdueAmount: 0,
          contributionDueNowAmount: 20000,
          loans: [
            const MemberLoanObligationSummary(
              loanAccountId: 'loan-1',
              loanNumber: 'STD-LN-2026-0001',
              overdueAmount: 115000,
              dueNowAmount: 115000,
              currentlyPayableAmount: 230000,
              upcomingAmount: 115000,
            ),
          ],
          totalLoansCurrentlyPayableAmount: 230000,
          totalPayableNow: 250000,
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentRecord);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jane Doe'));
      await tester.pumpAndSettle();

      final summaryCard = find.byKey(const Key('memberFinancialSummaryCard'));

      // Contributions breakdown.
      expect(
        find.descendant(of: summaryCard, matching: find.text('Contributions')),
        findsOneWidget,
      );
      expect(find.textContaining('20,000'), findsWidgets);

      // Loans breakdown, including the loan number and the separately-
      // labeled upcoming amount.
      expect(
        find.descendant(of: summaryCard, matching: find.text('Loans')),
        findsOneWidget,
      );
      expect(find.text('STD-LN-2026-0001'), findsOneWidget);
      expect(find.text('Upcoming (Not Yet Due)'), findsOneWidget);

      // Total Payable Now is the combined CURRENTLY payable figure
      // (20,000 + 230,000 = 250,000) — never inflated by the 115,000
      // upcoming amount (which would make it 365,000).
      final totalRow = find.byKey(
        const Key('memberFinancialSummaryTotalPayableNowRow'),
      );
      expect(
        find.descendant(of: totalRow, matching: find.textContaining('250,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: totalRow, matching: find.textContaining('365,000')),
        findsNothing,
      );
    },
  );

  testWidgets('a member with no active loan shows the "no active loan" message '
      'instead of an empty/broken Loans section', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository()
      ..nextStatement = fakeMemberContributionStatement(loans: const []);

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentRecord);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(find.text('This member has no active loan.'), findsOneWidget);
  });

  testWidgets(
    'the allocation preview only ever renders lines the server actually '
    'returned — never fabricates an extra future installment locally, '
    'and shows the wallet-credit remainder',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [janeDoe()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentPreview = fakePaymentAllocationPreview(
          allocations: [
            PaymentAllocationLine(
              componentType: 'INTEREST',
              dueDate: DateTime.utc(2026, 9, 1),
              amount: 15000,
              obligationKind: 'LOAN_INTEREST',
              loanNumber: 'STD-LN-2026-0001',
              installmentNumber: 1,
            ),
            PaymentAllocationLine(
              componentType: 'PRINCIPAL',
              dueDate: DateTime.utc(2026, 9, 1),
              amount: 100000,
              obligationKind: 'LOAN_PRINCIPAL',
              loanNumber: 'STD-LN-2026-0001',
              installmentNumber: 1,
            ),
          ],
          amount: 1000000,
          totalAllocated: 115000,
          walletCreditAmount: 885000,
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentRecord);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jane Doe'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recordPaymentAmountField')),
        '1000000',
      );
      await tester.ensureVisible(
        find.byKey(const Key('recordPaymentAccountField')),
      );
      await tester.tap(find.byKey(const Key('recordPaymentAccountField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash (Cash)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('recordPaymentPreviewAction')),
      );
      await tester.tap(find.byKey(const Key('recordPaymentPreviewAction')));
      await tester.pumpAndSettle();

      // Only installment 1's two lines render — never installment 2/3.
      expect(find.text('STD-LN-2026-0001'), findsOneWidget);
      expect(find.textContaining('Installment 1'), findsOneWidget);
      expect(find.textContaining('Installment 2'), findsNothing);

      final walletRow = find.byKey(
        const Key('paymentPreviewWalletRemainingRow'),
      );
      expect(
        find.descendant(
          of: walletRow,
          matching: find.textContaining('885,000'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Swahili labels render for the Payments hub and the obligation '
      'summary sections', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository();
    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
    );
    router.go(AppRoutes.paymentsList);
    await tester.pumpAndSettle();

    expect(find.text('Rekodi Malipo'), findsOneWidget);
    expect(find.text('Historia ya Malipo'), findsOneWidget);
    expect(find.text('Salio la Mwanachama'), findsOneWidget);

    router.go(AppRoutes.paymentRecord);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    final summaryCard = find.byKey(const Key('memberFinancialSummaryCard'));
    expect(
      find.descendant(of: summaryCard, matching: find.text('Michango')),
      findsOneWidget,
    );
    expect(find.text('Mikopo'), findsOneWidget);
    expect(find.text('Jumla Inayolipwa Sasa'), findsOneWidget);
  });

  testWidgets('no layout overflow at 360px or desktop width with the full '
      'member obligation summary (contributions + loans) shown', (
    tester,
  ) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository()
      ..nextStatement = fakeMemberContributionStatement(
        loans: [
          const MemberLoanObligationSummary(
            loanAccountId: 'loan-1',
            loanNumber: 'STD-LN-2026-0001',
            overdueAmount: 115000,
            dueNowAmount: 115000,
            currentlyPayableAmount: 230000,
            upcomingAmount: 115000,
          ),
        ],
        totalLoansCurrentlyPayableAmount: 230000,
        totalPayableNow: 250000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
    );
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.paymentRecord);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
