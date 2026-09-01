import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 07 UAT-FIX-01 regression coverage: member debt/wallet
/// visibility before payment, semantic allocation labels (never a
/// bare BASE/PENALTY/OPENING_BALANCE/ADJUSTMENT enum), and the zero
/// wallet state rendering as a valid balance rather than missing data.
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

  // A. Selected member displays the authoritative outstanding balance.
  testWidgets('A: selecting a member shows the server-derived Outstanding '
      'Balance and Member Balance before any amount is entered', (
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
        totalOutstanding: 30000,
        walletBalance: 0,
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

    final outstandingRow = find.byKey(
      const Key('memberFinancialSummaryOutstandingRow'),
    );
    expect(
      find.descendant(
        of: outstandingRow,
        matching: find.text('Outstanding Balance'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: outstandingRow, matching: find.text('30,000')),
      findsOneWidget,
    );
    expect(fakeRepo.getMemberContributionStatementCalls, hasLength(1));
    expect(
      fakeRepo.getMemberContributionStatementCalls.single.membershipId,
      'm1',
    );
  });

  // B. Zero wallet balance renders as a valid "0", never a missing/empty
  // state.
  testWidgets('B: a member with a zero wallet balance shows "0", never an '
      'empty/missing-data state', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository()
      ..nextStatement = fakeMemberContributionStatement(walletBalance: 0);

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

    final walletRow = find.byKey(const Key('memberFinancialSummaryWalletRow'));
    expect(walletRow, findsOneWidget);
    expect(
      find.descendant(of: walletRow, matching: find.text('0')),
      findsOneWidget,
    );
  });

  // C/D. Preview allocation lines carry contribution+period context, and
  // two BASE components from different periods are visually
  // distinguishable.
  testWidgets('C/D: two BASE allocation lines from different periods each show '
      'their own contribution + period context, never anonymous duplicate '
      '"Base" rows', (tester) async {
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
            chargeId: 'c1',
            componentId: 'comp1',
            componentType: 'BASE',
            dueDate: DateTime.utc(2026, 7, 15),
            amount: 20000,
            contributionTypeName: 'Ada',
            periodLabel: 'Julai 2026',
            periodPurpose: 'NORMAL',
          ),
          PaymentAllocationLine(
            chargeId: 'c2',
            componentId: 'comp2',
            componentType: 'BASE',
            dueDate: DateTime.utc(2026, 8, 15),
            amount: 10000,
            contributionTypeName: 'Ada',
            periodLabel: 'Agosti 2026',
            periodPurpose: 'NORMAL',
          ),
        ],
        totalAllocated: 30000,
        walletCreditAmount: 0,
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
      '30000',
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

    expect(find.text('Ada — Julai 2026'), findsOneWidget);
    expect(find.text('Ada — Agosti 2026'), findsOneWidget);
    // Both are the same component type — distinguishable only by
    // the context line above each, never a raw enum.
    expect(find.text('Base'), findsNWidgets(2));
    expect(find.text('BASE'), findsNothing);
  });

  // E. PENALTY label is localized.
  testWidgets('E: a PENALTY allocation line shows the localized label, '
      'never the raw enum', (tester) async {
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
            chargeId: 'c1',
            componentId: 'comp1',
            componentType: 'PENALTY',
            dueDate: DateTime.utc(2026, 7, 15),
            amount: 5000,
            contributionTypeName: 'Ada',
            periodLabel: 'Julai 2026',
            periodPurpose: 'NORMAL',
          ),
        ],
        totalAllocated: 5000,
        walletCreditAmount: 0,
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
      '5000',
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

    expect(find.text('Penalty'), findsOneWidget);
    expect(find.text('PENALTY'), findsNothing);
  });

  // F. OPENING_BALANCE label is localized, and omits the period suffix
  // (per the UAT spec's own example: "Ada" alone, no " — period").
  testWidgets(
    'F: an OPENING_BALANCE allocation line shows the localized label with '
    'no period suffix',
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
              chargeId: 'c1',
              componentId: 'comp1',
              componentType: 'OPENING_BALANCE',
              dueDate: DateTime.utc(2025, 12, 1),
              amount: 50000,
              contributionTypeName: 'Ada',
              periodLabel: 'Ada Opening Balances — 2025-12-01',
              periodPurpose: 'OPENING_BALANCE',
            ),
          ],
          totalAllocated: 50000,
          walletCreditAmount: 0,
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
        '50000',
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

      expect(find.text('Opening Balance'), findsOneWidget);
      expect(find.text('OPENING_BALANCE'), findsNothing);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.textContaining('Ada —'), findsNothing);
    },
  );

  // G. The receipt preserves meaningful allocation context — never a
  // bare component type.
  testWidgets('G: the receipt shows contribution + period context for '
      'each allocation, never a bare component type', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextReceipt = fakeReceipt(
        allocations: [
          PaymentAllocationLine(
            componentType: 'BASE',
            dueDate: DateTime.utc(2026, 7, 15),
            amount: 20000,
            contributionTypeName: 'Ada',
            periodLabel: 'Julai 2026',
            periodPurpose: 'NORMAL',
          ),
          PaymentAllocationLine(
            componentType: 'BASE',
            dueDate: DateTime.utc(2026, 8, 15),
            amount: 10000,
            contributionTypeName: 'Ada',
            periodLabel: 'Agosti 2026',
            periodPurpose: 'NORMAL',
          ),
        ],
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentReceiptPath('payment-1'));
    await tester.pumpAndSettle();

    expect(find.text('Ada — Julai 2026'), findsOneWidget);
    expect(find.text('Ada — Agosti 2026'), findsOneWidget);
    expect(find.text('Base'), findsNWidgets(2));
    expect(find.text('BASE'), findsNothing);
  });

  // J. No raw enum text leaks anywhere on the member summary/preview.
  testWidgets(
    'J: no raw BASE/PENALTY/ADJUSTMENT/OPENING_BALANCE enum text ever '
    'appears on the member summary',
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
          charges: [
            fakeOutstandingCharge(
              components: [
                fakeOutstandingComponent(componentType: 'BASE'),
                fakeOutstandingComponent(
                  componentType: 'PENALTY',
                  outstanding: 500,
                ),
              ],
            ),
          ],
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

      expect(find.text('BASE'), findsNothing);
      expect(find.text('PENALTY'), findsNothing);
      expect(find.text('ADJUSTMENT'), findsNothing);
      expect(find.text('OPENING_BALANCE'), findsNothing);
    },
  );

  // K. No overflow at a realistic small Android width with the new
  // summary + obligations content.
  testWidgets('K: no layout overflow at mobile width (360) with the '
      'member summary and outstanding obligations shown', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository()
      ..nextStatement = fakeMemberContributionStatement(
        charges: [
          fakeOutstandingCharge(
            contributionTypeName: 'Ada',
            periodLabel: 'Julai 2026',
          ),
          fakeOutstandingCharge(
            chargeId: 'charge-2',
            contributionTypeName: 'Ada',
            periodLabel: 'Agosti 2026',
            dueDate: DateTime.utc(2026, 8, 15),
          ),
          fakeOutstandingCharge(
            chargeId: 'charge-3',
            contributionTypeName: 'Ada',
            periodLabel: 'Septemba 2026',
            dueDate: DateTime.utc(2026, 9, 15),
          ),
          fakeOutstandingCharge(
            chargeId: 'charge-4',
            contributionTypeName: 'Ada',
            periodLabel: 'Oktoba 2026',
            dueDate: DateTime.utc(2026, 10, 15),
          ),
        ],
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
      language: AppLanguage.english,
    );
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.paymentRecord);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // More than the collapsed limit — "View All" must be offered
    // rather than rendering everything and overflowing.
    expect(find.byKey(const Key('viewAllObligationsAction')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('viewAllObligationsAction')),
    );
    await tester.tap(find.byKey(const Key('viewAllObligationsAction')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
