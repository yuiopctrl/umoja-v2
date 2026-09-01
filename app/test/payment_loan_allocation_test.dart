import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/payments/domain/payment_allocation_line.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09C: loan repayment allocations surfaced through the
/// EXISTING Payment Engine UI — payment preview and receipt — never a
/// second payment implementation. See docs/product/loans.md.
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

  testWidgets('a mixed contribution + loan payment preview shows both kinds of '
      'obligation, each with its own semantic label', (tester) async {
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
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 20000,
            contributionTypeName: 'Ada',
            periodLabel: 'Oktoba 2026',
            periodPurpose: 'NORMAL',
          ),
          PaymentAllocationLine(
            componentType: 'INTEREST',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 50000,
            obligationKind: 'LOAN_INTEREST',
            loanAccountId: 'loan-1',
            loanInstallmentId: 'inst-1',
            loanNumber: 'STD-LN-2026-0001',
            installmentNumber: 1,
          ),
          PaymentAllocationLine(
            componentType: 'PRINCIPAL',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 250000,
            obligationKind: 'LOAN_PRINCIPAL',
            loanAccountId: 'loan-1',
            loanInstallmentId: 'inst-1',
            loanNumber: 'STD-LN-2026-0001',
            installmentNumber: 1,
          ),
        ],
        totalAllocated: 320000,
        walletCreditAmount: 0,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
    );
    router.go(AppRoutes.paymentRecord);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recordPaymentAmountField')),
      '320000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('recordPaymentAccountField')),
    );
    await tester.tap(find.byKey(const Key('recordPaymentAccountField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main Cash (Taslimu)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('recordPaymentPreviewAction')),
    );
    await tester.tap(find.byKey(const Key('recordPaymentPreviewAction')));
    await tester.pumpAndSettle();

    // Contribution line — unchanged context/component labels.
    expect(find.text('Ada — Oktoba 2026'), findsOneWidget);
    expect(find.text('Deni Msingi'), findsOneWidget);

    // Loan lines — loan number + installment context, Riba/Mtaji
    // labels, never a bare LOAN_INTEREST/LOAN_PRINCIPAL/INTEREST/
    // PRINCIPAL enum.
    expect(find.text('STD-LN-2026-0001'), findsOneWidget);
    expect(find.textContaining('Awamu 1'), findsOneWidget);
    expect(find.text('Riba'), findsOneWidget);
    expect(find.text('Mtaji'), findsOneWidget);
    expect(find.text('INTEREST'), findsNothing);
    expect(find.text('PRINCIPAL'), findsNothing);
    expect(find.text('LOAN_INTEREST'), findsNothing);
  });

  testWidgets('a payment receipt with loan allocations shows the loan number, '
      'installment, and Riba/Mtaji labels — one receipt, not a separate '
      'loan receipt', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextReceipt = fakeReceipt(
        allocations: [
          PaymentAllocationLine(
            componentType: 'INTEREST',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 50000,
            obligationKind: 'LOAN_INTEREST',
            loanNumber: 'STD-LN-2026-0001',
            installmentNumber: 1,
          ),
          PaymentAllocationLine(
            componentType: 'PRINCIPAL',
            dueDate: DateTime.utc(2026, 10, 1),
            amount: 250000,
            obligationKind: 'LOAN_PRINCIPAL',
            loanNumber: 'STD-LN-2026-0001',
            installmentNumber: 1,
          ),
        ],
      );

    final router = await pumpPaymentsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.paymentReceiptPath('payment-1'));
    await tester.pumpAndSettle();

    expect(find.text('STD-LN-2026-0001'), findsOneWidget);
    expect(find.textContaining('Awamu 1'), findsOneWidget);
    expect(find.text('Riba'), findsOneWidget);
    expect(find.text('Mtaji'), findsOneWidget);
  });
}
