import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/widgets/umoja_buttons.dart';
import 'package:umoja/features/loans/domain/loan_migration_preview.dart';
import 'package:umoja/features/loans/domain/loan_product.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09D-UAT-BLOCKER-01/02/03: Existing/Opening Loan onboarding —
/// entry-point distinction from ordinary loan creation, the Simple vs
/// Detailed import mode selector (Simple is the default), the
/// mandatory Schedule Preview step BEFORE any posting can happen, the
/// Review & Confirm step's zero-cash/zero-income accounting impact and
/// confirmation safety message, and that posting calls
/// `rpc_create_migrated_loan` (never the ordinary draft/disbursement
/// pipeline) with the raw contract inputs — never a client-computed
/// total — in Simple mode.
void main() {
  FakeMemberRepository memberRepo() {
    return FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [
          GroupMember(
            membershipId: 'm5',
            groupId: 'g1',
            displayName: 'Jane Borrower',
            status: 'ACTIVE',
            createdAt: DateTime.utc(2026, 1, 1),
            isLoginLinked: false,
          ),
        ],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
  }

  Future<void> pickMemberAndProduct(WidgetTester tester) async {
    await tester.tap(find.text('Jane Borrower'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Migration Product'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Key key) async {
    // A settle here (rather than relying on the previous enterText's own
    // single pump) guarantees any onChanged-triggered setState — e.g.
    // Simple Import's live reconciliation check enabling this very
    // button — has fully rebuilt before ensureVisible/tap inspect the
    // current element tree.
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  LoanMigrationPreviewInstallment historicalRow(String dueDate) {
    return LoanMigrationPreviewInstallment(
      dueDate: DateTime.parse(dueDate),
      principalOutstanding: 1667272.72,
      interestOutstanding: 166727.27,
      openingPenaltyOutstanding: 64921.20,
      totalContractualAmount: 1898921.19,
      status: 'OVERDUE',
    );
  }

  LoanMigrationPreviewInstallment futureRow(String dueDate) {
    return LoanMigrationPreviewInstallment(
      dueDate: DateTime.parse(dueDate),
      principalOutstanding: 1666233.77,
      interestOutstanding: 166623.38,
      openingPenaltyOutstanding: 0,
      totalContractualAmount: 1832857.15,
      status: 'UPCOMING',
    );
  }

  final realScenarioPreview = fakeLoanMigrationPreview(
    mode: 'SIMPLE',
    historicalInstallments: [
      historicalRow('2026-04-27'),
      historicalRow('2026-05-27'),
      historicalRow('2026-06-27'),
      historicalRow('2026-07-27'),
      historicalRow('2026-08-27'),
    ],
    futureInstallments: [
      futureRow('2026-09-27'),
      futureRow('2026-10-27'),
      futureRow('2026-11-27'),
      futureRow('2026-12-27'),
      futureRow('2027-01-27'),
      futureRow('2027-02-27'),
      futureRow('2027-03-27'),
    ],
    contractualHistoricalArrears: 9170000,
    legacyPenaltyTotal: 324606,
    historicalPrincipalTotal: 8336363.64,
    historicalInterestTotal: 833636.36,
    historicalPenaltyTotal: 324606,
    totalHistoricalArrears: 9494606,
    openingPrincipalOutstanding: 20000000,
    futureScheduledPrincipal: 11663636.36,
    futureScheduledInterest: 1166363.64,
    futureContractualTotal: 12838000,
  );

  testWidgets('Loans home shows BOTH "New Loan" (via Loan Accounts) and "Add '
      'Existing Loan" as clearly separate entry points, never a checkbox '
      'on the same form', (tester) async {
    final fakeRepo = FakeLoanRepository();

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.loansHome);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanAccountsEntry')), findsOneWidget);
    expect(find.byKey(const Key('addExistingLoanEntry')), findsOneWidget);
    expect(find.text('Ingiza Mkopo Uliopo'), findsOneWidget);
  });

  testWidgets('a user without loan_opening.create never sees the Add Existing '
      'Loan entry', (tester) async {
    final fakeRepo = FakeLoanRepository();

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      membership: loanMembership(
        roles: const ['CHAIRPERSON'],
        permissions: loanChairpersonPermissions,
      ),
    );
    router.go(AppRoutes.loansHome);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addExistingLoanEntry')), findsNothing);
  });

  testWidgets(
    'Simple Import is selected by default; Detailed Import is selectable '
    'and shows the repeatable arrears list instead',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
          totalCount: 1,
          limit: 20,
          offset: 0,
        );
      final fakeMemberRepo = memberRepo();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newExistingLoanAccount);
      await tester.pumpAndSettle();
      await pickMemberAndProduct(tester);

      // Simple by default: Simple-only fields visible, Detailed's
      // repeatable list is not.
      expect(
        find.byKey(const Key('migratedLoanContractedInterestField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('migratedLoanAddArrearsInstallmentAction')),
        findsNothing,
      );

      // No Post/Create action is ever reachable from the data-entry step
      // — only "Preview Schedule".
      expect(
        find.byKey(const Key('migratedLoanPreviewScheduleAction')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('migratedLoanPostAction')), findsNothing);

      await tester.tap(find.byKey(const Key('migratedLoanImportModeSelector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingiza kwa Maelezo'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('migratedLoanContractedInterestField')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('migratedLoanAddArrearsInstallmentAction')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Simple Import shows live derived contractual arrears and legacy '
      'penalty as the user types, before any preview is requested', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextProductsPage = LoanProductPage(
        items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
        totalCount: 1,
        limit: 20,
        offset: 0,
      );
    final fakeMemberRepo = memberRepo();

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
    );
    router.push(AppRoutes.newExistingLoanAccount);
    await tester.pumpAndSettle();
    await pickMemberAndProduct(tester);

    await tester.enterText(
      find.byKey(const Key('migratedLoanMonthlyInstallmentField')),
      '1834000',
    );
    await tester.enterText(
      find.byKey(const Key('migratedLoanHistoricalUnpaidCountField')),
      '5',
    );
    await tester.enterText(
      find.byKey(const Key('migratedLoanTotalHistoricalArrearsField')),
      '9494606',
    );
    await tester.pump();

    expect(
      tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(
                    const Key('migratedLoanSimpleContractualArrearsRow'),
                  ),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data,
      '9,170,000',
    );
    expect(
      tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(
                    const Key('migratedLoanSimpleLegacyPenaltyRow'),
                  ),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data,
      '324,606',
    );
  });

  testWidgets(
    'the full Simple Import flow: Preview Schedule shows the historical '
    'and future installments separately BEFORE Review, Review shows the '
    'real-scenario summary and zero cash/income impact plus the '
    'confirmation safety message, and Confirm posts with the raw '
    'contract inputs — never a client-computed total',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
          totalCount: 1,
          limit: 20,
          offset: 0,
        )
        ..nextMigrationPreview = realScenarioPreview
        ..nextAccount = fakeLoanAccount(
          id: 'loan-migrated-1',
          loanNumber: 'MIG-LN-2026-0001',
          loanOrigin: 'MIGRATED',
          status: 'ACTIVE',
        );
      final fakeMemberRepo = memberRepo();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newExistingLoanAccount);
      await tester.pumpAndSettle();
      await pickMemberAndProduct(tester);

      await tester.enterText(
        find.byKey(const Key('migratedLoanOriginalPrincipalField')),
        '20000000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanContractedInterestField')),
        '2000000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanMonthlyInstallmentField')),
        '1834000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanOriginalTermField')),
        '12',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanHistoricalUnpaidCountField')),
        '5',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanTotalHistoricalArrearsField')),
        '9494606',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanRemainingInstallmentCountField')),
        '7',
      );

      await tapVisible(tester, const Key('migratedLoanPreviewScheduleAction'));

      expect(fakeRepo.previewMigratedLoanCalls, hasLength(1));
      expect(fakeRepo.previewMigratedLoanCalls.single.mode, 'SIMPLE');

      // Now on the Schedule Preview step — historical and future
      // sections are visually separate, and no Post action exists here.
      expect(
        find.byKey(const Key('schedulePreviewHistoricalRow_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('schedulePreviewHistoricalRow_4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('schedulePreviewFutureRow_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('schedulePreviewFutureRow_6')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('migratedLoanPostAction')), findsNothing);

      await tapVisible(tester, const Key('schedulePreviewContinueAction'));

      // Now on Review & Confirm.
      expect(find.byKey(const Key('migratedLoanReviewCard')), findsOneWidget);
      expect(find.textContaining('9,170,000'), findsWidgets);
      expect(find.textContaining('324,606'), findsWidgets);
      expect(find.textContaining('9,494,606'), findsWidgets);
      expect(find.textContaining('12,838,000'), findsWidgets);
      expect(find.textContaining('20,000,000'), findsWidgets);
      expect(
        find.byKey(const Key('migratedLoanConfirmationSafetyCard')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('migratedLoanCashbookImpactRow')),
                    matching: find.byType(Text),
                  )
                  .last,
            )
            .data,
        '0',
      );
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('migratedLoanIncomeImpactRow')),
                    matching: find.byType(Text),
                  )
                  .last,
            )
            .data,
        '0',
      );

      await tapVisible(tester, const Key('migratedLoanPostAction'));

      expect(fakeRepo.createMigratedLoanCalls, hasLength(1));
      final call = fakeRepo.createMigratedLoanCalls.single;
      expect(call.mode, 'SIMPLE');
      expect(call.originalPrincipal, 20000000);
      expect(call.contractedInterestAmount, 2000000);
      expect(call.monthlyInstallmentAmount, 1834000);
      expect(call.historicalUnpaidCount, 5);
      expect(call.totalHistoricalArrears, 9494606);
      expect(fakeRepo.createDraftLoanAccountCalls, isEmpty);
      expect(find.text('MIG-LN-2026-0001'), findsOneWidget);
    },
  );

  testWidgets('the user can return from Schedule Preview to edit the form, and '
      'from Review back to Schedule Preview', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextProductsPage = LoanProductPage(
        items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
        totalCount: 1,
        limit: 20,
        offset: 0,
      )
      ..nextMigrationPreview = realScenarioPreview;
    final fakeMemberRepo = memberRepo();

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
    );
    router.push(AppRoutes.newExistingLoanAccount);
    await tester.pumpAndSettle();
    await pickMemberAndProduct(tester);

    await tester.enterText(
      find.byKey(const Key('migratedLoanOriginalPrincipalField')),
      '20000000',
    );
    await tester.enterText(
      find.byKey(const Key('migratedLoanMonthlyInstallmentField')),
      '1834000',
    );
    await tester.enterText(
      find.byKey(const Key('migratedLoanOriginalTermField')),
      '12',
    );
    await tapVisible(tester, const Key('migratedLoanPreviewScheduleAction'));

    await tapVisible(tester, const Key('schedulePreviewEditAction'));
    expect(
      find.byKey(const Key('migratedLoanPreviewScheduleAction')),
      findsOneWidget,
    );

    await tapVisible(tester, const Key('migratedLoanPreviewScheduleAction'));
    await tapVisible(tester, const Key('schedulePreviewContinueAction'));
    await tapVisible(tester, const Key('migratedLoanReviewBackAction'));
    expect(
      find.byKey(const Key('schedulePreviewContinueAction')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Detailed Import still works: each historical installment entered by '
    'the user is previewed, reviewed, and posted separately',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
          totalCount: 1,
          limit: 20,
          offset: 0,
        )
        ..nextMigrationPreview = fakeLoanMigrationPreview(
          mode: 'DETAILED',
          historicalInstallments: [historicalRow('2026-08-01')],
          historicalPrincipalTotal: 400000,
          historicalInterestTotal: 80000,
          historicalPenaltyTotal: 20000,
          totalHistoricalArrears: 500000,
          openingPrincipalOutstanding: 4000000,
        )
        ..nextAccount = fakeLoanAccount(
          id: 'loan-detailed-1',
          loanNumber: 'MIG-LN-2026-0002',
          loanOrigin: 'MIGRATED',
          status: 'ACTIVE',
        );
      final fakeMemberRepo = memberRepo();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newExistingLoanAccount);
      await tester.pumpAndSettle();
      await pickMemberAndProduct(tester);

      await tester.tap(find.byKey(const Key('migratedLoanImportModeSelector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingiza kwa Maelezo'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('migratedLoanOriginalPrincipalField')),
        '10000000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanOpeningPrincipalOutstandingField')),
        '4000000',
      );

      await tapVisible(
        tester,
        const Key('migratedLoanAddArrearsInstallmentAction'),
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanArrearsDialogPrincipalField')),
        '400000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanArrearsDialogInterestField')),
        '80000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanArrearsDialogPenaltyField')),
        '20000',
      );
      await tester.tap(
        find.byKey(const Key('migratedLoanArrearsDialogSaveAction')),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, const Key('migratedLoanPreviewScheduleAction'));
      expect(fakeRepo.previewMigratedLoanCalls.single.mode, 'DETAILED');

      await tapVisible(tester, const Key('schedulePreviewContinueAction'));
      await tapVisible(tester, const Key('migratedLoanPostAction'));

      expect(fakeRepo.createMigratedLoanCalls, hasLength(1));
      final call = fakeRepo.createMigratedLoanCalls.single;
      expect(call.mode, 'DETAILED');
      expect(call.historicalArrearsInstallments, hasLength(1));
      final installment = call.historicalArrearsInstallments.single;
      expect(installment.principalOutstanding, 400000);
      expect(installment.interestOutstanding, 80000);
      expect(installment.openingPenaltyOutstanding, 20000);
      expect(find.text('MIG-LN-2026-0002'), findsOneWidget);
    },
  );

  testWidgets(
    'the migrated loan detail shows a MIGRATED badge, the opening position, '
    'and each historical arrears installment separately — never a fake '
    '"Disbursed by Umoja" claim',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          loanOrigin: 'MIGRATED',
          openingPosition: fakeLoanOpeningPosition(),
          installments: [
            fakeLoanInstallment(
              installmentNumber: 1,
              dueDate: DateTime.utc(2026, 6, 27),
              principalDue: 1000000,
              interestDue: 200000,
            ),
            fakeLoanInstallment(
              installmentNumber: 2,
              dueDate: DateTime.utc(2026, 7, 27),
              principalDue: 1000000,
              interestDue: 200000,
            ),
            fakeLoanInstallment(
              installmentNumber: 3,
              dueDate: DateTime.utc(2026, 9, 27),
              principalDue: 500000,
              interestDue: 50000,
            ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanMigratedBadge')), findsOneWidget);
      expect(find.byKey(const Key('loanOpeningPositionCard')), findsOneWidget);
      expect(find.textContaining('4,000,000'), findsWidgets);
      expect(find.textContaining('Disbursed by Umoja'), findsNothing);

      expect(
        find.byKey(const Key('loanHistoricalArrearsCard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('loanHistoricalArrearsRow_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('loanHistoricalArrearsRow_1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('loanHistoricalArrearsRow_2')), findsNothing);
    },
  );

  group('Prompt 09D-UAT-BLOCKER-04: Original Loan Term', () {
    Future<void> enterCommonSimpleFields(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('migratedLoanOriginalPrincipalField')),
        '20000000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanContractedInterestField')),
        '2008000',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanMonthlyInstallmentField')),
        '1834000',
      );
    }

    testWidgets(
      'the Original Loan Term field is visible in Simple Import, with '
      'integer-only input and helper text',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextProductsPage = LoanProductPage(
            items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
            totalCount: 1,
            limit: 20,
            offset: 0,
          );
        final fakeMemberRepo = memberRepo();

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          fakeMemberRepo: fakeMemberRepo,
        );
        router.push(AppRoutes.newExistingLoanAccount);
        await tester.pumpAndSettle();
        await pickMemberAndProduct(tester);

        final field = tester.widget<TextField>(
          find.byKey(const Key('migratedLoanOriginalTermField')),
        );
        expect(field.keyboardType, TextInputType.number);
        expect(field.decoration?.helperText, isNotNull);
      },
    );

    testWidgets(
      'omitting the Original Loan Term keeps Preview Schedule disabled '
      '(required validation)',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextProductsPage = LoanProductPage(
            items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
            totalCount: 1,
            limit: 20,
            offset: 0,
          );
        final fakeMemberRepo = memberRepo();

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          fakeMemberRepo: fakeMemberRepo,
        );
        router.push(AppRoutes.newExistingLoanAccount);
        await tester.pumpAndSettle();
        await pickMemberAndProduct(tester);
        await enterCommonSimpleFields(tester);
        await tester.enterText(
          find.byKey(const Key('migratedLoanHistoricalUnpaidCountField')),
          '0',
        );
        await tester.enterText(
          find.byKey(const Key('migratedLoanRemainingInstallmentCountField')),
          '7',
        );
        await tester.pumpAndSettle();

        final button = tester.widget<UmojaPrimaryButton>(
          find.byKey(const Key('migratedLoanPreviewScheduleAction')),
        );
        expect(button.onPressed, isNull);
      },
    );

    Future<int?> paidBeforeUmojaAfterEntering(
      WidgetTester tester, {
      required String originalTerm,
      required String historicalUnpaid,
      required String remainingFuture,
    }) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
          totalCount: 1,
          limit: 20,
          offset: 0,
        );
      final fakeMemberRepo = memberRepo();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newExistingLoanAccount);
      await tester.pumpAndSettle();
      await pickMemberAndProduct(tester);
      await enterCommonSimpleFields(tester);
      await tester.enterText(
        find.byKey(const Key('migratedLoanOriginalTermField')),
        originalTerm,
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanHistoricalUnpaidCountField')),
        historicalUnpaid,
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanTotalHistoricalArrearsField')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('migratedLoanRemainingInstallmentCountField')),
        remainingFuture,
      );
      await tester.pumpAndSettle();

      final row = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(
                    const Key('migratedLoanSimplePaidBeforeUmojaRow'),
                  ),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data;
      return row == null || row == '—' ? null : int.parse(row);
    }

    testWidgets('12 term + 0 overdue + 7 future shows 5 paid before Umoja', (
      tester,
    ) async {
      expect(
        await paidBeforeUmojaAfterEntering(
          tester,
          originalTerm: '12',
          historicalUnpaid: '0',
          remainingFuture: '7',
        ),
        5,
      );
    });

    testWidgets('12 term + 5 overdue + 7 future shows 0 paid before Umoja', (
      tester,
    ) async {
      expect(
        await paidBeforeUmojaAfterEntering(
          tester,
          originalTerm: '12',
          historicalUnpaid: '5',
          remainingFuture: '7',
        ),
        0,
      );
    });

    testWidgets('12 term + 2 overdue + 7 future shows 3 paid before Umoja', (
      tester,
    ) async {
      expect(
        await paidBeforeUmojaAfterEntering(
          tester,
          originalTerm: '12',
          historicalUnpaid: '2',
          remainingFuture: '7',
        ),
        3,
      );
    });

    testWidgets(
      'counts exceeding the original term (invalid totals) block Schedule '
      'Preview',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextProductsPage = LoanProductPage(
            items: [fakeLoanProduct(id: 'p1', name: 'Migration Product')],
            totalCount: 1,
            limit: 20,
            offset: 0,
          );
        final fakeMemberRepo = memberRepo();

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          fakeMemberRepo: fakeMemberRepo,
        );
        router.push(AppRoutes.newExistingLoanAccount);
        await tester.pumpAndSettle();
        await pickMemberAndProduct(tester);
        await enterCommonSimpleFields(tester);
        await tester.enterText(
          find.byKey(const Key('migratedLoanOriginalTermField')),
          '5',
        );
        await tester.enterText(
          find.byKey(const Key('migratedLoanHistoricalUnpaidCountField')),
          '5',
        );
        await tester.enterText(
          find.byKey(const Key('migratedLoanRemainingInstallmentCountField')),
          '7',
        );
        await tester.pumpAndSettle();

        final button = tester.widget<UmojaPrimaryButton>(
          find.byKey(const Key('migratedLoanPreviewScheduleAction')),
        );
        expect(button.onPressed, isNull);
        expect(fakeRepo.previewMigratedLoanCalls, isEmpty);
      },
    );
  });
}
