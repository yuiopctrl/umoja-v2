import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/member_payments/data/my_payments_repository.dart';
import 'package:umoja/features/member_payments/domain/my_payment.dart';
import 'package:umoja/features/member_payments/providers/my_payments_repository_provider.dart';
import 'package:umoja/features/member_statement/providers/member_statement_repository_provider.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/membership_claim/providers/membership_claim_repository_provider.dart';
import 'package:umoja/features/my_contributions/providers/my_contributions_repository_provider.dart';

import 'fakes/fake_member_profile_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_member_statement_repository.dart';
import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/fake_my_contributions_repository.dart';
import 'fakes/fake_my_payments_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 09G-B6-C §AB/§AO: My Payments is scoped to the selected group.
/// These tests drive the real selected-group notifier and the real
/// list/detail/receipt providers. The SAME payment id exists in both
/// groups with different data, so any stale cache entry would show up
/// as the wrong group's figures.
class _GroupScopedMyPaymentsRepository implements MyPaymentsRepository {
  _GroupScopedMyPaymentsRepository(this.byGroup);

  final Map<String, FakeMyPaymentsRepository> byGroup;
  final List<String> trace = [];

  FakeMyPaymentsRepository _forGroup(String groupId) {
    trace.add(groupId);
    final repo = byGroup[groupId];
    if (repo == null) throw StateError('no fixture for group $groupId');
    return repo;
  }

  @override
  Future<MyPaymentsPage> getMyPayments({
    required String groupId,
    MyPaymentStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  }) => _forGroup(groupId).getMyPayments(
    groupId: groupId,
    status: status,
    fromDate: fromDate,
    toDate: toDate,
    limit: limit,
    offset: offset,
  );

  @override
  Future<MyPaymentDetail> getMyPaymentDetail({
    required String groupId,
    required String paymentId,
  }) =>
      _forGroup(groupId)
          .getMyPaymentDetail(groupId: groupId, paymentId: paymentId);

  @override
  Future<MyReceipt> getMyReceipt({
    required String groupId,
    required String paymentId,
  }) => _forGroup(groupId).getMyReceipt(groupId: groupId, paymentId: paymentId);
}

MembershipContext _groupMembership({
  required String membershipId,
  required String groupId,
  required String groupName,
}) {
  return MembershipContext(
    membershipId: membershipId,
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Member Caller',
    roleCodes: const ['MEMBER'],
    permissionCodes: const ['group.view', 'payment.self_view'],
  );
}

class _FixedLanguage extends LanguageNotifier {
  @override
  AppLanguage build() => AppLanguage.english;
}

Future<ProviderContainer> _pumpTwoGroups(
  WidgetTester tester, {
  required MyPaymentsRepository repository,
  required List<MembershipContext> memberships,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(
        memberProfileRepository: FakeMemberProfileRepository(),
      ),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
          memberships: memberships,
        ),
      ),
      memberRepositoryProvider.overrideWithValue(
        FakeMemberRepository()..nextListResult = GroupMemberPage.empty,
      ),
      membershipClaimRepositoryProvider.overrideWithValue(
        FakeMembershipClaimRepository(),
      ),
      memberStatementRepositoryProvider.overrideWithValue(
        FakeMemberStatementRepository(),
      ),
      myContributionsRepositoryProvider.overrideWithValue(
        FakeMyContributionsRepository(),
      ),
      myPaymentsRepositoryProvider.overrideWithValue(repository),
      languageProvider.overrideWith(_FixedLanguage.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  const shared = 'shared-payment';

  FakeMyPaymentsRepository groupA() => FakeMyPaymentsRepository(
    page: myPaymentsPageFixture(
      items: [
        myPaymentItemJson(
          paymentId: shared,
          amount: 15000,
          receiptNumber: 'A-RCPT',
          effectiveAt: '2026-04-01',
        ),
      ],
      hasMore: false,
      totalCount: 1,
    ),
    details: {shared: myPaymentDetailFixture(paymentId: shared, amount: 15000)},
    receipts: {shared: myReceiptFixture(receiptNumber: 'A-RCPT')},
  );

  FakeMyPaymentsRepository groupB() => FakeMyPaymentsRepository(
    page: myPaymentsPageFixture(
      items: [
        myPaymentItemJson(
          paymentId: shared,
          amount: 90000,
          receiptNumber: 'B-RCPT',
          effectiveAt: '2026-05-01',
        ),
      ],
      hasMore: false,
      totalCount: 1,
    ),
    details: {shared: myPaymentDetailFixture(paymentId: shared, amount: 90000)},
    receipts: {shared: myReceiptFixture(receiptNumber: 'B-RCPT')},
  );

  Future<ProviderContainer> pumpTwoGroups(WidgetTester tester) {
    return _pumpTwoGroups(
      tester,
      repository: _GroupScopedMyPaymentsRepository({
        'gA': groupA(),
        'gB': groupB(),
      }),
      memberships: [
        _groupMembership(
          membershipId: 'm-a',
          groupId: 'gA',
          groupName: 'Group A',
        ),
        _groupMembership(
          membershipId: 'm-b',
          groupId: 'gB',
          groupName: 'Group B',
        ),
      ],
    );
  }

  /// The app's real "Change Group" path: return to the pending
  /// multi-group selection (which routes to /select-group), then select
  /// the target group.
  void switchGroup(ProviderContainer container, String membershipId) {
    final notifier = container.read(selectedGroupProvider.notifier);
    notifier.requireReselection([
      _groupMembership(
        membershipId: 'm-a',
        groupId: 'gA',
        groupName: 'Group A',
      ),
      _groupMembership(
        membershipId: 'm-b',
        groupId: 'gB',
        groupName: 'Group B',
      ),
    ]);
    notifier.selectGroup(membershipId);
  }

  testWidgets(
    'the payment list is scoped to the selected group, and switching back is correct',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myPayments);
      await tester.pumpAndSettle();

      expect(find.textContaining('A-RCPT'), findsOneWidget);
      expect(find.textContaining('B-RCPT'), findsNothing);

      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();
      expect(find.textContaining('B-RCPT'), findsOneWidget);
      expect(find.textContaining('A-RCPT'), findsNothing);

      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      expect(find.textContaining('A-RCPT'), findsOneWidget);
      expect(find.textContaining('B-RCPT'), findsNothing);
    },
  );

  testWidgets(
    'a Group A payment detail never remains visible as Group B detail after a switch',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myPaymentDetailPath(shared));
      await tester.pumpAndSettle();
      expect(find.text('15,000'), findsOneWidget);

      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();
      expect(find.text('90,000'), findsOneWidget);
      expect(find.text('15,000'), findsNothing);
    },
  );

  testWidgets(
    'a Group A receipt never remains visible as Group B receipt after a switch',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myPaymentReceiptPath(shared));
      await tester.pumpAndSettle();
      expect(find.textContaining('A-RCPT'), findsOneWidget);

      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();
      expect(find.textContaining('B-RCPT'), findsOneWidget);
      expect(find.textContaining('A-RCPT'), findsNothing);
    },
  );

  testWidgets(
    'filters/pagination state from Group A does not carry into Group B',
    (tester) async {
      final container = await pumpTwoGroups(tester);
      final router = container.read(routerProvider);
      switchGroup(container, 'm-a');
      await tester.pumpAndSettle();
      router.go(AppRoutes.myPayments);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('myPaymentsFiltersAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('myPaymentsStatusChip_REVERSED')));
      await tester.tap(find.byKey(const Key('myPaymentsApplyFiltersAction')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('myPaymentsActiveFilter_status')),
        findsOneWidget,
      );

      switchGroup(container, 'm-b');
      await tester.pumpAndSettle();

      // Prompt §AB: the filter/pagination Notifier is invalidated on
      // every group switch (selected_group_provider.dart), so Group B
      // starts from "All statuses", never Group A's REVERSED filter.
      expect(
        find.byKey(const Key('myPaymentsActiveFilter_status')),
        findsNothing,
      );
    },
  );
}
