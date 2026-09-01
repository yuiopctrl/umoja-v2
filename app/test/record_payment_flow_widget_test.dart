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

void main() {
  testWidgets(
    'the full record-payment flow: pick member -> fill form -> preview -> '
    'confirm -> success -> view receipt',
    (tester) async {
      final fakeMemberRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [
            _fakeGroupMember(membershipId: 'm1', displayName: 'Jane Doe'),
          ],
          totalCount: 1,
          limit: 25,
          offset: 0,
        );
      final fakeRepo = FakePaymentRepository()
        ..nextPaymentPreview = fakePaymentAllocationPreview(
          membershipId: 'm1',
          financialAccountId: 'account-1',
          financialAccountName: 'Main Cash',
          amount: 10000,
          allocations: [
            PaymentAllocationLine(
              chargeId: 'c1',
              componentId: 'comp1',
              componentType: 'BASE',
              dueDate: DateTime.utc(2026, 1, 15),
              amount: 10000,
            ),
          ],
          totalAllocated: 10000,
          walletCreditAmount: 0,
        )
        ..nextPostResult = fakePaymentPostResult(
          paymentId: 'payment-new',
          receiptNumber: 'UMOJA-RCP-2026-000099',
          totalAllocated: 10000,
        )
        ..nextReceipt = fakeReceipt(
          paymentId: 'payment-new',
          receiptNumber: 'UMOJA-RCP-2026-000099',
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        fakeMemberRepo: fakeMemberRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.paymentRecord);
      await tester.pumpAndSettle();

      // Step 1: member picker.
      await tester.tap(find.text('Jane Doe'));
      await tester.pumpAndSettle();

      // Step 2: form.
      expect(find.text('Jane Doe'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('recordPaymentAmountField')),
        '10000',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('recordPaymentAccountField')),
      );
      await tester.tap(find.byKey(const Key('recordPaymentAccountField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash (Cash)').last);
      await tester.pumpAndSettle();
      // The member financial summary + outstanding obligations
      // (UAT-FIX-01) push the Preview button below the fold at mobile
      // width — scroll it into view before tapping, since a plain
      // tap() only hit-tests the offset the widget WOULD occupy if
      // already visible.
      await tester.ensureVisible(
        find.byKey(const Key('recordPaymentPreviewAction')),
      );
      await tester.tap(find.byKey(const Key('recordPaymentPreviewAction')));
      await tester.pumpAndSettle();

      // Step 3: preview.
      expect(fakeRepo.previewPaymentAllocationCalls, hasLength(1));
      expect(fakeRepo.previewPaymentAllocationCalls.single.amount, 10000);
      expect(find.text('Will Settle'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recordPaymentConfirmAction')));
      await tester.pumpAndSettle();

      // Step 4: success.
      expect(fakeRepo.postPaymentCalls, hasLength(1));
      expect(find.text('Payment recorded successfully.'), findsOneWidget);
      expect(find.text('UMOJA-RCP-2026-000099'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recordPaymentViewReceiptAction')));
      await tester.pumpAndSettle();

      expect(find.text('Receipt'), findsOneWidget);
    },
  );

  testWidgets('an invalid amount shows a local validation error and never '
      'calls the preview RPC', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [_fakeGroupMember(membershipId: 'm1', displayName: 'Jane Doe')],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository();

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

    // Leave the amount field blank and try to preview.
    await tester.ensureVisible(
      find.byKey(const Key('recordPaymentPreviewAction')),
    );
    await tester.tap(find.byKey(const Key('recordPaymentPreviewAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.previewPaymentAllocationCalls, isEmpty);
    expect(
      find.text('Enter a valid amount, member, and financial account.'),
      findsOneWidget,
    );
  });
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
