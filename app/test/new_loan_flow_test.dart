import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/loans/domain/loan_product.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/loans_test_app.dart';

GroupMember _activeMember({
  String membershipId = 'm1',
  String displayName = 'Jane Member',
}) {
  return GroupMember(
    membershipId: membershipId,
    groupId: 'g1',
    displayName: displayName,
    status: 'ACTIVE',
    createdAt: DateTime.utc(2026, 1, 1),
    isLoginLinked: false,
  );
}

Future<void> _pickMemberAndProduct(
  WidgetTester tester, {
  GroupMember? member,
}) async {
  await tester.tap(find.text(member?.displayName ?? 'Jane Member'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Standard Loan'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the full New Loan flow: Borrower -> Product -> Terms -> Schedule '
    'Preview -> Save Draft, rendering only server-provided schedule '
    'numbers (never recomputed in Dart)',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_activeMember()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Standard Loan')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        )
        ..nextPreview = fakeLoanSchedulePreview(
          principalAmount: 120000,
          term: 2,
          installments: [
            fakeLoanInstallment(
              installmentNumber: 1,
              dueDate: DateTime.utc(2026, 3, 1),
              principalDue: 60000,
              interestDue: 1200,
            ),
            fakeLoanInstallment(
              installmentNumber: 2,
              dueDate: DateTime.utc(2026, 4, 1),
              principalDue: 60000,
              interestDue: 1200,
            ),
          ],
        )
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          loanNumber: 'STD-LN-2026-0001',
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newLoanAccount);
      await tester.pumpAndSettle();

      // Step 1: Borrower.
      await tester.tap(find.text('Jane Member'));
      await tester.pumpAndSettle();

      // Step 2: Product.
      expect(find.text('Standard Loan'), findsOneWidget);
      await tester.tap(find.text('Standard Loan'));
      await tester.pumpAndSettle();

      // Step 3: Terms.
      await tester.enterText(
        find.byKey(const Key('newLoanPrincipalField')),
        '120000',
      );
      await tester.enterText(find.byKey(const Key('newLoanTermField')), '2');
      await tester.tap(find.byKey(const Key('newLoanPreviewAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.previewLoanScheduleCalls, hasLength(1));
      expect(fakeRepo.previewLoanScheduleCalls.single.principalAmount, 120000);
      expect(fakeRepo.previewLoanScheduleCalls.single.term, 2);

      // Step 4: Schedule Preview — every number shown must come from the
      // fake's canned server response, not a client-side recomputation.
      expect(find.textContaining('1,200'), findsWidgets);
      expect(find.byKey(const Key('loanTotalRepayableRow')), findsOneWidget);

      // No approve/disburse/receive-payment action anywhere in this flow.
      expect(find.textContaining('Idhinisha'), findsNothing);
      expect(find.textContaining('Toa Mkopo'), findsNothing);

      await tester.tap(find.byKey(const Key('newLoanSaveDraftAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.createDraftLoanAccountCalls, hasLength(1));
      expect(fakeRepo.createDraftLoanAccountCalls.single.membershipId, 'm1');
      expect(fakeRepo.createDraftLoanAccountCalls.single.loanProductId, 'p1');
      expect(find.text('STD-LN-2026-0001'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting an inactive member shows an error and does not advance '
    'to the product step',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [
            GroupMember(
              membershipId: 'm2',
              groupId: 'g1',
              displayName: 'Suspended Member',
              status: 'SUSPENDED',
              createdAt: DateTime.utc(2026, 1, 1),
              isLoginLinked: false,
            ),
          ],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newLoanAccount);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suspended Member'));
      await tester.pumpAndSettle();

      expect(
        find.text('Mwanachama huyu si mwanachama anayeendelea wa kikundi.'),
        findsOneWidget,
      );
      // Still on the member picker — never advanced.
      expect(find.text('Suspended Member'), findsOneWidget);
    },
  );

  testWidgets(
    'an invalid principal/term shows the local validation error without '
    'calling the preview RPC',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_activeMember()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Standard Loan')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.push(AppRoutes.newLoanAccount);
      await tester.pumpAndSettle();

      await _pickMemberAndProduct(tester);

      await tester.tap(find.byKey(const Key('newLoanPreviewAction')));
      await tester.pumpAndSettle();

      expect(find.text('Weka kiasi sahihi cha mkopo na muda.'), findsOneWidget);
      expect(fakeRepo.previewLoanScheduleCalls, isEmpty);
    },
  );

  testWidgets(
    'no layout overflow at a realistic small Android width (360) on the '
    'Schedule Preview step, with several installment rows (Prompt '
    '09A-UAT item 12)',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_activeMember()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [fakeLoanProduct(id: 'p1', name: 'Standard Loan')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        )
        ..nextPreview = fakeLoanSchedulePreview(
          principalAmount: 1000000,
          term: 5,
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

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.push(AppRoutes.newLoanAccount);
      await tester.pumpAndSettle();

      await _pickMemberAndProduct(tester);

      await tester.enterText(
        find.byKey(const Key('newLoanPrincipalField')),
        '1000000',
      );
      await tester.enterText(find.byKey(const Key('newLoanTermField')), '5');
      await tester.tap(find.byKey(const Key('newLoanPreviewAction')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('loanTotalRepayableRow')), findsOneWidget);
    },
  );
}
