import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';
import 'package:umoja/features/payments/domain/wallet_entry_page.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 07 UAT-FIX-02 regression coverage: the "Salio la Mwanachama"
/// member picker (`/wallet`) previously crashed during layout
/// ("RenderFlex children have non-zero flex but incoming height
/// constraints are unbounded") because `WalletMemberPickerScreen` never
/// set `scrollable: false` on `UmojaPage`, so `MemberSearchPicker`'s
/// internal `Expanded` was given unbounded height by the default
/// `SingleChildScrollView` wrapper. The screen never even reached the
/// point of calling any provider/RPC — this was a pure Flutter layout
/// bug, not a backend/permission/parsing issue.
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

  // A/F. Opening Wallet with no preselected member shows the member
  // picker (no crash), and the detail route works as a direct,
  // standalone deep-link (membershipId lives in the path, never in a
  // transient `extra`).
  testWidgets('A: opening /wallet with no preselected member shows the member '
      'picker without any layout exception', (tester) async {
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
      language: AppLanguage.english,
    );
    router.go(AppRoutes.walletMemberPicker);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets(
    'F: /wallet/:membershipId loads correctly as a direct, standalone '
    'deep-link — the membership id lives in the route path, never a '
    'transient extra that could disappear on refresh',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextWalletEntriesPage = WalletEntryPage(
          items: const [],
          totalCount: 0,
          limit: 10,
          offset: 0,
          walletBalance: 0,
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      // Simulates a fresh deep-link / page refresh landing directly on
      // this route with no prior navigation history.
      router.go(AppRoutes.walletDetailPath('m1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fakeRepo.listMemberWalletEntriesCalls.single.membershipId, 'm1');
    },
  );

  // B. The full picker -> detail flow shows the authoritative non-zero
  // balance.
  testWidgets('B: selecting a member with a 30,000 wallet balance through the '
      'full picker flow shows TSh 30,000', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: [
          fakeWalletEntry(
            entryType: 'PAYMENT_CREDIT',
            amount: 30000,
            sourceType: 'PAYMENT',
            sourceId: 'payment-1',
            sourceReceiptNumber: 'UMOJA-RCP-2026-000001',
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
        walletBalance: 30000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      fakeMemberRepo: fakeMemberRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.walletMemberPicker);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('30,000'), findsOneWidget);
  });

  // C. A member with zero wallet entries shows TSh 0, never an
  // infinite spinner.
  testWidgets(
    'C: a member with no wallet entries shows TSh 0 immediately, never '
    'a permanent loading state',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..nextWalletEntriesPage = WalletEntryPage(
          items: const [],
          totalCount: 0,
          limit: 10,
          offset: 0,
          walletBalance: 0,
        );

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.walletDetailPath('m1'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('0'), findsOneWidget);
    },
  );

  // D. PAYMENT_CREDIT shows a localized, meaningful label and its
  // source receipt — never the raw enum.
  testWidgets('D: a PAYMENT_CREDIT ledger row shows the localized "Credit from '
      'payment" wording and its source receipt number', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: [
          fakeWalletEntry(
            entryType: 'PAYMENT_CREDIT',
            amount: 30000,
            sourceType: 'PAYMENT',
            sourceId: 'payment-1',
            sourceReceiptNumber: 'UMOJA-RCP-2026-000001',
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
        walletBalance: 30000,
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    expect(find.text('Credit from payment'), findsOneWidget);
    expect(find.text('PAYMENT_CREDIT'), findsNothing);
    expect(find.text('Receipt UMOJA-RCP-2026-000001'), findsOneWidget);
  });

  // G. A backend/RPC error resolves to a localized error state with
  // retry — never an infinite spinner.
  testWidgets(
    'G: a wallet RPC failure shows a localized error with retry, never '
    'an infinite spinner',
    (tester) async {
      final fakeRepo = FakePaymentRepository()
        ..failure = const PaymentFailure(PaymentFailureType.unexpected, 'boom');

      final router = await pumpPaymentsApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.go(AppRoutes.walletDetailPath('m1'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      // Recovering and retrying actually refetches.
      fakeRepo.failure = null;
      fakeRepo.nextWalletEntriesPage = WalletEntryPage(
        items: const [],
        totalCount: 0,
        limit: 10,
        offset: 0,
        walletBalance: 0,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    },
  );

  // H. The backend permission check is the real defense — a denied
  // request never leaks wallet data, and the UI surfaces it as a clean
  // error rather than partial/garbled content.
  testWidgets('H: a permission-denied response from the backend never renders '
      'wallet data', (tester) async {
    final fakeRepo = FakePaymentRepository()
      ..failure = const PaymentFailure(
        PaymentFailureType.permissionDenied,
        'not authorized',
      );

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.walletDetailPath('m1'));
    await tester.pumpAndSettle();

    expect(find.text('30,000'), findsNothing);
    expect(find.byKey(const Key('walletAllocateAction')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  // I. No overflow at mobile width through the full picker -> detail
  // flow (the exact path that previously crashed).
  testWidgets('I: no layout overflow at mobile width (360) through the full '
      'picker -> detail flow', (tester) async {
    final fakeMemberRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [janeDoe()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      );
    final fakeRepo = FakePaymentRepository()
      ..nextWalletEntriesPage = WalletEntryPage(
        items: [fakeWalletEntry(entryType: 'PAYMENT_CREDIT', amount: 30000)],
        totalCount: 1,
        limit: 10,
        offset: 0,
        walletBalance: 30000,
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
    router.go(AppRoutes.walletMemberPicker);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('walletAllocateAction')), findsOneWidget);
  });
}
