import 'package:flutter/widgets.dart';
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

    expect(find.byKey(const Key('loanRegenerateScheduleAction')), findsNothing);
    expect(find.byKey(const Key('loanCancelDraftAction')), findsNothing);
  });

  testWidgets('regenerating the schedule calls the repository', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

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
      expect(
        find.byKey(const Key('loanRegenerateScheduleAction')),
        findsNothing,
      );
      expect(find.byKey(const Key('loanCancelDraftAction')), findsNothing);
    },
  );

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
}
