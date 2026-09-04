import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  group('Submit', () {
    testWidgets(
      'a DRAFT loan shows a Submit action for an authorized user, and '
      'confirming it calls the repository',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

        final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('loanSubmitAction')), findsOneWidget);

        await tester.ensureVisible(find.byKey(const Key('loanSubmitAction')));
        await tester.tap(find.byKey(const Key('loanSubmitAction')));
        await tester.pumpAndSettle();

        // Confirmation summary shown before the RPC is called.
        expect(fakeRepo.submitLoanAccountCalls, isEmpty);
        expect(find.text('Wasilisha kwa Idhini?'), findsOneWidget);

        await tester.tap(find.text('Wasilisha kwa Idhini').last);
        await tester.pumpAndSettle();

        expect(fakeRepo.submitLoanAccountCalls, hasLength(1));
        expect(fakeRepo.submitLoanAccountCalls.single.loanAccountId, 'loan-1');
      },
    );

    testWidgets('the Submit action is hidden without loan.submit', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['CHAIRPERSON'],
          permissions: loanChairpersonPermissions,
        ),
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanSubmitAction')), findsNothing);
    });
  });

  group('Approve/Reject', () {
    testWidgets(
      'a SUBMITTED loan shows Approve/Reject for an authorized approver, '
      'and confirming Approve calls the repository',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'SUBMITTED');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          membership: loanMembership(
            roles: const ['CHAIRPERSON'],
            permissions: loanChairpersonPermissions,
          ),
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('loanApproveAction')), findsOneWidget);
        expect(find.byKey(const Key('loanRejectAction')), findsOneWidget);

        await tester.tap(find.byKey(const Key('loanApproveAction')));
        await tester.pumpAndSettle();
        expect(fakeRepo.approveLoanAccountCalls, isEmpty);
        expect(find.text('Idhinisha Mkopo?'), findsOneWidget);

        await tester.tap(find.text('Idhinisha').last);
        await tester.pumpAndSettle();

        expect(fakeRepo.approveLoanAccountCalls, hasLength(1));
      },
    );

    testWidgets('no Approve/Reject action for a submitter-only (TREASURER) '
        'identity — separation of duties', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'SUBMITTED');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['TREASURER'],
          permissions: loanTreasurerPermissions,
        ),
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanApproveAction')), findsNothing);
      expect(find.byKey(const Key('loanRejectAction')), findsNothing);
    });

    testWidgets('rejecting a submitted loan requires a reason, then calls the '
        'repository with it', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'SUBMITTED');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['CHAIRPERSON'],
          permissions: loanChairpersonPermissions,
        ),
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('loanRejectAction')));
      await tester.tap(find.byKey(const Key('loanRejectAction')));
      await tester.pumpAndSettle();

      // No reason entered yet — confirming must not call the repository.
      await tester.tap(find.byKey(const Key('rejectLoanConfirmAction')));
      await tester.pumpAndSettle();
      expect(fakeRepo.rejectLoanAccountCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('rejectLoanReasonField')),
        'not eligible',
      );
      await tester.tap(find.byKey(const Key('rejectLoanConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.rejectLoanAccountCalls, hasLength(1));
      expect(fakeRepo.rejectLoanAccountCalls.single.reason, 'not eligible');
    });
  });

  group('Cancel (SUBMITTED/APPROVED)', () {
    testWidgets('cancelling an approved loan requires a reason, then calls the '
        'repository with it', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'APPROVED');

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanCancelAction')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('loanCancelAction')));
      await tester.tap(find.byKey(const Key('loanCancelAction')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('cancelLoanReasonField')),
        'borrower withdrew',
      );
      await tester.tap(find.byKey(const Key('cancelLoanConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.cancelLoanAccountCalls, hasLength(1));
      expect(
        fakeRepo.cancelLoanAccountCalls.single.reason,
        'borrower withdrew',
      );
    });
  });

  group('Read-only history', () {
    testWidgets('a REJECTED loan shows no mutation actions and its reason', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'REJECTED',
          events: [
            fakeLoanAccountEvent(
              eventType: 'REJECTED',
              fromStatus: 'SUBMITTED',
              toStatus: 'REJECTED',
              reason: 'insufficient collateral',
            ),
          ],
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanSubmitAction')), findsNothing);
      expect(find.byKey(const Key('loanApproveAction')), findsNothing);
      expect(find.byKey(const Key('loanRejectAction')), findsNothing);
      expect(find.byKey(const Key('loanCancelAction')), findsNothing);
      expect(find.byKey(const Key('loanDisburseAction')), findsNothing);
      expect(find.textContaining('insufficient collateral'), findsOneWidget);
    });

    testWidgets(
      'an ACTIVE (funded/disbursed) loan shows no edit/regenerate/cancel '
      'and shows its disbursement detail',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            disbursement: fakeLoanDisbursement(
              financialAccountName: 'Main Cash',
              amount: 120000,
            ),
          );

        final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('loanEditTermsAction')), findsNothing);
        expect(
          find.byKey(const Key('loanRegenerateScheduleAction')),
          findsNothing,
        );
        expect(find.byKey(const Key('loanCancelAction')), findsNothing);
        expect(find.byKey(const Key('loanCancelDraftAction')), findsNothing);
        expect(find.byKey(const Key('loanDisburseAction')), findsNothing);
        expect(find.text('Main Cash'), findsOneWidget);
      },
    );
  });
}
