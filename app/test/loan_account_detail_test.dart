import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  testWidgets('the loan detail screen shows the loan and its server-generated '
      'schedule, with regenerate/cancel actions for an ADMIN on a DRAFT loan', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(
        id: 'loan-1',
        status: 'DRAFT',
        installments: [
          fakeLoanInstallment(installmentNumber: 1),
          fakeLoanInstallment(
            installmentNumber: 2,
            dueDate: DateTime.utc(2026, 3, 1),
          ),
        ],
      );

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.text('Test Member'), findsOneWidget);
    expect(find.text('STD-LN-2026-0001'), findsOneWidget);
    expect(find.text('Rasimu'), findsOneWidget);
    expect(find.byKey(const Key('loanEditTermsAction')), findsOneWidget);
    expect(
      find.byKey(const Key('loanRegenerateScheduleAction')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('loanCancelDraftAction')), findsOneWidget);
  });

  testWidgets('a view-only membership sees no regenerate/cancel actions on the '
      'same DRAFT loan', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      membership: loanMembership(
        roles: const ['CHAIRPERSON'],
        permissions: loanViewOnlyPermissions,
      ),
    );
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanEditTermsAction')), findsNothing);
    expect(find.byKey(const Key('loanRegenerateScheduleAction')), findsNothing);
    expect(find.byKey(const Key('loanCancelDraftAction')), findsNothing);
  });

  testWidgets('regenerating the schedule calls the repository', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('loanRegenerateScheduleAction')),
    );
    await tester.tap(find.byKey(const Key('loanRegenerateScheduleAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.regenerateLoanScheduleCalls, hasLength(1));
    expect(fakeRepo.regenerateLoanScheduleCalls.single.loanAccountId, 'loan-1');
  });

  testWidgets(
    'cancelling a draft requires confirmation, then calls the repository',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanCancelDraftAction')),
      );
      await tester.tap(find.byKey(const Key('loanCancelDraftAction')));
      await tester.pumpAndSettle();

      // A confirmation sheet appears — cancelling is not yet sent.
      expect(fakeRepo.cancelDraftLoanAccountCalls, isEmpty);
      expect(find.text('Ghairi Rasimu ya Mkopo?'), findsOneWidget);

      await tester.tap(find.text('Ghairi Rasimu').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.cancelDraftLoanAccountCalls, hasLength(1));
      expect(
        fakeRepo.cancelDraftLoanAccountCalls.single.loanAccountId,
        'loan-1',
      );
    },
  );

  testWidgets(
    'a CANCELLED (non-DRAFT) loan shows no regenerate/cancel actions',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'CANCELLED');

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.text('Imeghairiwa'), findsOneWidget);
      expect(find.byKey(const Key('loanEditTermsAction')), findsNothing);
      expect(
        find.byKey(const Key('loanRegenerateScheduleAction')),
        findsNothing,
      );
      expect(find.byKey(const Key('loanCancelDraftAction')), findsNothing);
    },
  );

  testWidgets(
    'Edit Loan -> change term 4 -> 5 -> Save updates the loan and the '
    'detail screen shows the new 5-installment schedule '
    '(Prompt 09A-UAT-FIX-01)',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'DRAFT',
          principalAmount: 1000000,
          term: 4,
          firstRepaymentDate: DateTime.utc(2026, 10, 1),
          installments: [
            for (var i = 1; i <= 4; i++)
              fakeLoanInstallment(
                installmentNumber: i,
                dueDate: DateTime.utc(2026, i + 9, 1),
                principalDue: 250000,
                interestDue: 50000,
              ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('loanEditTermsAction')));
      await tester.tap(find.byKey(const Key('loanEditTermsAction')));
      await tester.pumpAndSettle();

      // Prefilled from the existing loan.
      final termFieldWidget = tester.widget<TextField>(
        find.byKey(const Key('editLoanTermField')),
      );
      expect(termFieldWidget.controller!.text, '4');

      // The 5-installment loan the fake will return once "saved" —
      // proves the detail screen renders whatever the server returns
      // next, not a value it computed itself.
      fakeRepo.nextAccount = fakeLoanAccount(
        id: 'loan-1',
        status: 'DRAFT',
        principalAmount: 1000000,
        term: 5,
        firstRepaymentDate: DateTime.utc(2026, 10, 1),
        installments: [
          for (var i = 1; i <= 5; i++)
            fakeLoanInstallment(
              installmentNumber: i,
              dueDate: DateTime.utc(2026, i + 9, 1),
              principalDue: 200000,
              interestDue: 50000,
            ),
        ],
      );

      await tester.enterText(find.byKey(const Key('editLoanTermField')), '5');
      await tester.tap(find.byKey(const Key('editLoanSaveAction')));
      await tester.pumpAndSettle();

      // A single authoritative call — never update-then-separately-
      // regenerate (rpc_update_draft_loan_terms already regenerates).
      expect(fakeRepo.updateDraftLoanTermsCalls, hasLength(1));
      expect(fakeRepo.updateDraftLoanTermsCalls.single.term, 5);
      expect(fakeRepo.regenerateLoanScheduleCalls, isEmpty);

      // Back on the detail screen, showing the new schedule.
      expect(find.byKey(const Key('editLoanSaveAction')), findsNothing);
      expect(find.text('Awamu 5'), findsOneWidget);
      expect(find.text('Awamu 6'), findsNothing);
    },
  );

  testWidgets('Edit Loan is absent without loan.edit, even on a DRAFT loan', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      membership: loanMembership(
        roles: const ['CHAIRPERSON'],
        permissions: loanViewOnlyPermissions,
      ),
    );
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanEditTermsAction')), findsNothing);
  });

  testWidgets(
    'no layout overflow at a realistic small Android width (360) with a '
    'long combined interest-rate value and several schedule rows '
    '(Prompt 09A-UAT item 12)',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'DRAFT',
          loanProductName: 'Mkopo wa Kawaida',
          interestRateBasis: 'MONTHLY',
          interestMethod: 'REDUCING_BALANCE',
          installments: [
            for (var i = 1; i <= 5; i++)
              fakeLoanInstallment(
                installmentNumber: i,
                dueDate: DateTime.utc(2026, i + 9, 1),
              ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Mkopo wa Kawaida'), findsOneWidget);
    },
  );

  testWidgets(
    'no layout overflow at a desktop width (1280) with the same content',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'DRAFT',
          installments: [
            fakeLoanInstallment(installmentNumber: 1),
            fakeLoanInstallment(
              installmentNumber: 2,
              dueDate: DateTime.utc(2026, 3, 1),
            ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the Edit Loan screen has no layout overflow at 360px or desktop width '
    '(Prompt 09A-UAT-FIX-01 item 10)',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'DRAFT',
          principalAmount: 1000000,
          term: 4,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.push(AppRoutes.loanAccountEditPath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editLoanSaveAction')), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
