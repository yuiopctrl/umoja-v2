import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09D: LOAN_PENALTY allocation lines render with full loan
/// context (product/number/installment, "Adhabu ya Mkopo" — never a
/// bare "PENALTY") wherever any other loan allocation already does —
/// Record Payment preview and the receipt, sharing `AllocationLinesList`.
void main() {
  final penaltyThenInterestThenPrincipal = [
    PaymentAllocationLine(
      componentType: 'PENALTY',
      dueDate: DateTime.utc(2026, 9, 1),
      amount: 20000,
      obligationKind: 'LOAN_PENALTY',
      loanNumber: 'UMO-LN-2026-0012',
      loanProductName: 'Mkopo wa Dharura',
      installmentNumber: 2,
      loanPenaltyChargeId: 'penalty-charge-1',
    ),
    PaymentAllocationLine(
      componentType: 'INTEREST',
      dueDate: DateTime.utc(2026, 9, 1),
      amount: 50000,
      obligationKind: 'LOAN_INTEREST',
      loanNumber: 'UMO-LN-2026-0012',
      loanProductName: 'Mkopo wa Dharura',
      installmentNumber: 2,
    ),
    PaymentAllocationLine(
      componentType: 'PRINCIPAL',
      dueDate: DateTime.utc(2026, 9, 1),
      amount: 30000,
      obligationKind: 'LOAN_PRINCIPAL',
      loanNumber: 'UMO-LN-2026-0012',
      loanProductName: 'Mkopo wa Dharura',
      installmentNumber: 2,
    ),
  ];

  testWidgets(
    'Record Payment preview groups penalty/interest/principal under one '
    'loan header, with the localized "Adhabu ya Mkopo" label — never a '
    'bare "PENALTY"',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_fakeGroupMember(membershipId: 'm1', displayName: 'Jane')],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentPreview = fakePaymentAllocationPreview(
          membershipId: 'm1',
          financialAccountId: 'account-1',
          financialAccountName: 'Main Cash',
          amount: 100000,
          allocations: penaltyThenInterestThenPrincipal,
          totalAllocated: 100000,
          walletCreditAmount: 0,
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
      );
      router.go(AppRoutes.paymentRecord);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jane'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recordPaymentAmountField')),
        '100000',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('recordPaymentAccountField')),
      );
      await tester.tap(find.byKey(const Key('recordPaymentAccountField')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Main Cash').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('recordPaymentPreviewAction')),
      );
      await tester.tap(find.byKey(const Key('recordPaymentPreviewAction')));
      await tester.pumpAndSettle();

      expect(find.text('Mkopo wa Dharura'), findsOneWidget);
      expect(find.text('UMO-LN-2026-0012'), findsOneWidget);
      expect(find.text('Adhabu ya Mkopo'), findsOneWidget);
      expect(find.text('Riba'), findsOneWidget);
      expect(find.text('Mtaji'), findsOneWidget);
      expect(find.text('PENALTY'), findsNothing);
      expect(find.text('LOAN_PENALTY'), findsNothing);
    },
  );

  testWidgets(
    'the receipt renders the same penalty/interest/principal grouping',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextReceipt = fakeReceipt(
          allocations: penaltyThenInterestThenPrincipal,
        );

      final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.paymentReceiptPath('payment-1'));
      await tester.pumpAndSettle();

      expect(find.text('Mkopo wa Dharura'), findsOneWidget);
      expect(find.text('Adhabu ya Mkopo'), findsOneWidget);
      expect(find.text('Riba'), findsOneWidget);
      expect(find.text('Mtaji'), findsOneWidget);
    },
  );
}

GroupMember _fakeGroupMember({
  required String membershipId,
  required String displayName,
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
