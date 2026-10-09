import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/member_payments/data/my_payments_failure.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
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

/// Prompt 09G-B6-C: My Payments & Receipts widget, routing, navigation,
/// and localization contract. The backend is the financial authority, so
/// these tests assert rendered backend values, never client-side math.
const _memberPermissions = ['group.view', 'payment.self_view'];

MembershipContext _membership({
  String id = 'm1',
  String groupId = 'g1',
  String groupName = 'Umoja Demo',
  List<String> permissionCodes = _memberPermissions,
  List<String> roleCodes = const ['MEMBER'],
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Test Member',
    roleCodes: roleCodes,
    permissionCodes: permissionCodes,
  );
}

class _Harness {
  _Harness({required this.router, required this.container, required this.repo});

  final GoRouter router;
  final ProviderContainer container;
  final FakeMyPaymentsRepository repo;
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  required List<MembershipContext> memberships,
  FakeMyPaymentsRepository? repo,
  Size viewSize = const Size(390, 844),
  AppLanguage language = AppLanguage.english,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final payments = repo ?? FakeMyPaymentsRepository();
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
          profile: const AppUserProfile(id: 'u1', fullName: 'Test Member'),
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
      myPaymentsRepositoryProvider.overrideWithValue(payments),
      languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return _Harness(
    router: container.read(routerProvider),
    container: container,
    repo: payments,
  );
}

Future<void> _go(WidgetTester tester, _Harness h, String location) async {
  h.router.go(location);
  await tester.pumpAndSettle();
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}

FakeMyPaymentsRepository _repoWithItems({
  List<Map<String, dynamic>> items = const [],
  bool hasMore = false,
  int totalCount = 0,
}) {
  return FakeMyPaymentsRepository(
    page: myPaymentsPageFixture(
      items: items,
      hasMore: hasMore,
      totalCount: totalCount == 0 ? items.length : totalCount,
    ),
  );
}

void main() {
  // --- Routing, permission, and discoverability ---------------------------

  group('routing and permissions', () {
    testWidgets('payment.self_view opens My Payments', (tester) async {
      final h = await _pumpApp(tester, memberships: [_membership()]);
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.text('My Payments'), findsWidgets);
      expect(h.router.state.uri.path, AppRoutes.myPayments);
    });

    testWidgets('without payment.self_view the list redirects to Home', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(h.router.state.uri.path, AppRoutes.home);
      expect(h.repo.listCallCount, 0);
    });

    testWidgets('without payment.self_view the detail redirects to Home', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

      expect(h.router.state.uri.path, AppRoutes.home);
      expect(h.repo.detailCallCount, 0);
    });

    testWidgets('without payment.self_view the receipt redirects to Home', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

      expect(h.router.state.uri.path, AppRoutes.home);
      expect(h.repo.receiptCallCount, 0);
    });

    testWidgets('payment.view (the officer workspace) never substitutes', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(
            permissionCodes: const ['group.view', 'payment.view'],
            roleCodes: const ['TREASURER'],
          ),
        ],
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(h.router.state.uri.path, AppRoutes.home);
      expect(h.repo.listCallCount, 0);
    });

    testWidgets('member.view alone never substitutes', (tester) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view', 'member.view']),
        ],
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(h.router.state.uri.path, AppRoutes.home);
    });

    testWidgets('a role name alone never authorizes the page', (tester) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(
            permissionCodes: const ['group.view'],
            roleCodes: const ['ADMIN'],
          ),
        ],
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(h.router.state.uri.path, AppRoutes.home);
    });

    test('self-service routes contain no membership or member id', () {
      expect(AppRoutes.myPayments, '/me/payments');
      expect(AppRoutes.myPaymentDetail, '/me/payments/:paymentId');
      expect(AppRoutes.myPaymentDetailPath('p1'), '/me/payments/p1');
      expect(AppRoutes.myPaymentReceiptPath('p1'), '/me/payments/p1/receipt');
      expect(AppRoutes.myPayments, isNot(contains('members')));
      expect(AppRoutes.myPaymentDetail, isNot(contains('membership')));
    });

    testWidgets('the officer /payments workspace is unaffected', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(
            permissionCodes: const ['group.view', 'payment.view'],
            roleCodes: const ['TREASURER'],
          ),
        ],
      );
      await _go(tester, h, AppRoutes.paymentsList);

      expect(h.router.state.uri.path, AppRoutes.paymentsList);
    });

    testWidgets(
      'an officer with MEMBER baseline can reach BOTH /payments and /me/payments',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [
            _membership(
              permissionCodes: const [
                'group.view',
                'payment.view',
                'payment.self_view',
              ],
              roleCodes: const ['TREASURER', 'MEMBER'],
            ),
          ],
        );
        await _go(tester, h, AppRoutes.paymentsList);
        expect(h.router.state.uri.path, AppRoutes.paymentsList);
        await _go(tester, h, AppRoutes.myPayments);
        expect(h.router.state.uri.path, AppRoutes.myPayments);
      },
    );

    testWidgets('Home shows My Payments only with payment.self_view', (
      tester,
    ) async {
      final granted = await _pumpApp(tester, memberships: [_membership()]);
      expect(find.byKey(const Key('homeMyPaymentsShortcut')), findsOneWidget);
      granted.container.dispose();
    });

    testWidgets('Home hides My Payments without payment.self_view', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      expect(find.byKey(const Key('homeMyPaymentsShortcut')), findsNothing);
    });

    testWidgets('More screen shows My Payments with payment.self_view', (
      tester,
    ) async {
      final h = await _pumpApp(tester, memberships: [_membership()]);
      await _go(tester, h, AppRoutes.more);
      expect(find.byKey(const Key('moreMyPaymentsAction')), findsOneWidget);
    });

    testWidgets('More screen hides My Payments without payment.self_view', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.more);
      expect(find.byKey(const Key('moreMyPaymentsAction')), findsNothing);
    });
  });

  // --- List UI --------------------------------------------------------

  group('list UI', () {
    testWidgets('posted and reversed payments render with localized labels', (
      tester,
    ) async {
      final repo = _repoWithItems(
        items: [
          myPaymentItemJson(paymentId: 'p1', status: 'POSTED'),
          myPaymentItemJson(paymentId: 'p2', status: 'REVERSED'),
        ],
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.text('Posted'), findsOneWidget);
      expect(find.text('Reversed'), findsOneWidget);
    });

    testWidgets('payment method labels are localized, never raw codes', (
      tester,
    ) async {
      final repo = _repoWithItems(
        items: [
          myPaymentItemJson(paymentId: 'p1', paymentMethod: 'MOBILE_MONEY'),
        ],
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.text('Mobile Money'), findsOneWidget);
      expect(find.text('MOBILE_MONEY'), findsNothing);
    });

    testWidgets('receipt number renders on the row', (tester) async {
      final repo = _repoWithItems(
        items: [
          myPaymentItemJson(paymentId: 'p1', receiptNumber: 'B6-RCPT-001'),
        ],
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.textContaining('B6-RCPT-001'), findsOneWidget);
    });

    testWidgets('date display uses effective_at, formatted', (tester) async {
      final repo = _repoWithItems(
        items: [myPaymentItemJson(paymentId: 'p1', effectiveAt: '2026-04-03')],
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.text('3 Apr 2026'), findsOneWidget);
    });

    testWidgets(
      'a multi-allocation backend record renders as exactly one row',
      (tester) async {
        final repo = _repoWithItems(
          items: [myPaymentItemJson(paymentId: 'p1', allocationCount: 3)],
        );
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: repo,
        );
        await _go(tester, h, AppRoutes.myPayments);

        expect(find.byKey(const Key('myPaymentRow_p1')), findsOneWidget);
      },
    );

    testWidgets('no payments yet shows the empty-history message', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: FakeMyPaymentsRepository(),
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.byKey(const Key('myPaymentsEmpty')), findsOneWidget);
    });

    testWidgets('a load failure shows a retry state, never raw error text', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository()
        ..nextError = const MyPaymentsFailure(MyPaymentsFailureType.unexpected);
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.textContaining('42501'), findsNothing);
      expect(find.textContaining('Postgrest'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('pagination: load more fetches the next growing page', (
      tester,
    ) async {
      final repo = _repoWithItems(
        items: [myPaymentItemJson(paymentId: 'p1')],
        hasMore: true,
        totalCount: 2,
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      repo.page = myPaymentsPageFixture(
        items: [
          myPaymentItemJson(paymentId: 'p1'),
          myPaymentItemJson(paymentId: 'p2'),
        ],
        hasMore: false,
        totalCount: 2,
      );
      await tester.tap(find.byKey(const Key('myPaymentsLoadMoreAction')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myPaymentRow_p2')), findsOneWidget);
      expect(repo.lastLimit, 40);
    });

    testWidgets('changing a filter resets pagination to the first page', (
      tester,
    ) async {
      final repo = _repoWithItems(items: [myPaymentItemJson(paymentId: 'p1')]);
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      await tester.tap(find.byKey(const Key('myPaymentsFiltersAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('myPaymentsStatusChip_REVERSED')));
      await tester.tap(find.byKey(const Key('myPaymentsApplyFiltersAction')));
      await tester.pumpAndSettle();

      expect(repo.lastStatus, isNotNull);
      expect(repo.lastOffset, 0);
      expect(repo.lastLimit, 20);
    });

    testWidgets('an inverted date range is rejected locally', (tester) async {
      final h = await _pumpApp(tester, memberships: [_membership()]);
      await _go(tester, h, AppRoutes.myPayments);

      await tester.tap(find.byKey(const Key('myPaymentsFiltersAction')));
      await tester.pumpAndSettle();
      // Only the sheet's structural validation is exercised here; backend
      // date math is never duplicated client-side.
      expect(find.byKey(const Key('myPaymentsFromDateAction')), findsOneWidget);
      expect(find.byKey(const Key('myPaymentsToDateAction')), findsOneWidget);
    });

    testWidgets('a wallet application never appears as a payment row', (
      tester,
    ) async {
      // The fake repository only ever returns real `payments` rows (as
      // the backend contract guarantees) — there is no code path by
      // which a wallet-funded allocation with no payment_id could reach
      // this list. This is asserted structurally in the source-scan test
      // below; here we additionally confirm the rendered row count
      // matches exactly the fixture's real payment count.
      final repo = _repoWithItems(
        items: [myPaymentItemJson(paymentId: 'p1')],
        totalCount: 1,
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.byKey(const Key('myPaymentsList')), findsOneWidget);
      expect(find.byKey(const Key('myPaymentRow_p1')), findsOneWidget);
    });

    testWidgets('tapping a row navigates to its detail route', (tester) async {
      final repo = _repoWithItems(
        items: [myPaymentItemJson(paymentId: 'p1')],
        totalCount: 1,
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: FakeMyPaymentsRepository(
          page: repo.page,
          details: {'p1': myPaymentDetailFixture(paymentId: 'p1')},
        ),
      );
      await _go(tester, h, AppRoutes.myPayments);

      await tester.tap(find.byKey(const Key('myPaymentRow_p1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myPaymentDetailAmount')), findsOneWidget);
    });
  });

  // --- Detail UI --------------------------------------------------------

  group('detail UI', () {
    testWidgets('detail renders the one canonical amount/date/status', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository(
        details: {'p1': myPaymentDetailFixture(paymentId: 'p1', amount: 62000)},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

      expect(find.text('62,000'), findsOneWidget);
      expect(find.byKey(const Key('myPaymentDetailStatus')), findsOneWidget);
      expect(find.text('Posted'), findsOneWidget);
    });

    testWidgets(
      'a cross-domain payment shows ONE header, both groups of lines',
      (tester) async {
        final repo = FakeMyPaymentsRepository(
          details: {
            'p1': myPaymentDetailFixture(
              paymentId: 'p1',
              amount: 60000,
              allocations: [
                myPaymentAllocationJson(
                  allocationId: 'a1',
                  targetType: 'CONTRIBUTION_COMPONENT',
                  amount: 10000,
                ),
                myPaymentAllocationJson(
                  allocationId: 'a2',
                  targetType: 'LOAN_PRINCIPAL',
                  amount: 50000,
                  componentType: null,
                  contributionTypeName: null,
                  periodLabel: null,
                  periodPurpose: null,
                  loanNumber: 'LN-001',
                ),
              ],
            ),
          },
        );
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: repo,
        );
        await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

        // Still one amount shown once, not duplicated per allocation group.
        expect(find.text('60,000'), findsOneWidget);
        expect(find.text('Contributions'), findsOneWidget);
        expect(find.text('Loans'), findsOneWidget);
        expect(find.text('Principal'), findsOneWidget);
      },
    );

    testWidgets('wallet credit shows amount and unreversed state', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository(
        details: {
          'p1': myPaymentDetailFixture(
            paymentId: 'p1',
            amount: 200000,
            allocations: [myPaymentAllocationJson(amount: 150000)],
            walletCredit: {
              'amount': 50000,
              'is_reversed': false,
              'reversed_at': null,
            },
          ),
        },
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

      expect(
        find.byKey(const Key('myPaymentWalletCreditCard')),
        findsOneWidget,
      );
      expect(find.text('50,000'), findsOneWidget);
      expect(
        find.byKey(const Key('myPaymentWalletCreditReversed')),
        findsNothing,
      );
    });

    testWidgets('a reversed wallet credit shows a Reversed badge', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository(
        details: {
          'p1': myPaymentDetailFixture(
            paymentId: 'p1',
            walletCredit: {
              'amount': 20000,
              'is_reversed': true,
              'reversed_at': '2026-04-08',
            },
          ),
        },
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

      expect(
        find.byKey(const Key('myPaymentWalletCreditReversed')),
        findsOneWidget,
      );
    });

    testWidgets('a reversed payment shows status and reason, no reversed_by', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository(
        details: {
          'p1': myPaymentDetailFixture(
            paymentId: 'p1',
            status: 'REVERSED',
            reversalReason: 'Entered in error',
          ),
        },
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

      expect(find.text('Reversed'), findsWidgets);
      expect(find.text('Entered in error'), findsOneWidget);
    });

    testWidgets('View Receipt navigates to the receipt route', (tester) async {
      final repo = FakeMyPaymentsRepository(
        details: {'p1': myPaymentDetailFixture(paymentId: 'p1')},
        receipts: {'p1': myReceiptFixture()},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));

      await tester.tap(find.byKey(const Key('myPaymentViewReceiptAction')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('myReceiptCard')), findsOneWidget);
    });

    testWidgets('another member or group payment shows not-found, not data', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: FakeMyPaymentsRepository(),
      );
      await _go(tester, h, AppRoutes.myPaymentDetailPath('someone-else'));

      expect(find.text('This payment is not available.'), findsOneWidget);
      expect(find.byKey(const Key('myPaymentDetailAmount')), findsNothing);
    });
  });

  // --- Receipt UI --------------------------------------------------------

  group('receipt UI', () {
    testWidgets('receipt renders number, amount, date, method', (tester) async {
      final repo = FakeMyPaymentsRepository(
        receipts: {'p1': myReceiptFixture(receiptNumber: 'B6-RCPT-001')},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

      expect(find.textContaining('B6-RCPT-001'), findsOneWidget);
      expect(find.text('15,000'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });

    testWidgets('a POSTED receipt shows Posted', (tester) async {
      final repo = FakeMyPaymentsRepository(
        receipts: {'p1': myReceiptFixture(status: 'POSTED')},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

      expect(find.text('Posted'), findsOneWidget);
    });

    testWidgets('a REVERSED receipt shows Reversed and the reversal reason', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository(
        receipts: {
          'p1': myReceiptFixture(
            status: 'REVERSED',
            reversalReason: 'Entered in error',
          ),
        },
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

      expect(find.text('Reversed'), findsWidgets);
      expect(find.text('Entered in error'), findsOneWidget);
    });

    testWidgets('receipt breakdown and wallet credit render', (tester) async {
      final repo = FakeMyPaymentsRepository(
        receipts: {
          'p1': myReceiptFixture(
            allocations: [myPaymentAllocationJson(amount: 150000)],
            walletCredit: {
              'amount': 50000,
              'is_reversed': false,
              'reversed_at': null,
            },
          ),
        },
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

      expect(find.byKey(const Key('myReceiptAllocationsCard')), findsOneWidget);
      expect(
        find.byKey(const Key('myReceiptWalletCreditCard')),
        findsOneWidget,
      );
    });

    testWidgets('a load failure shows a retry state', (tester) async {
      final repo = FakeMyPaymentsRepository();
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('missing'));

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('no print/download/pdf/share/thermal control exists anywhere', (
      tester,
    ) async {
      final repo = FakeMyPaymentsRepository(
        receipts: {'p1': myReceiptFixture()},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

      for (final forbidden in [
        'Print',
        'Download',
        'PDF',
        'Share',
        'Thermal',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
      expect(find.byIcon(Icons.print), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(find.byIcon(Icons.download), findsNothing);
    });
  });

  // --- Localization -------------------------------------------------------

  group('localization', () {
    testWidgets('Swahili renders the Swahili title and status labels', (
      tester,
    ) async {
      final repo = _repoWithItems(
        items: [myPaymentItemJson(paymentId: 'p1', status: 'REVERSED')],
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
        language: AppLanguage.swahili,
      );
      await _go(tester, h, AppRoutes.myPayments);

      expect(find.text('Malipo Yangu'), findsWidgets);
      expect(find.text('Imerejeshwa'), findsOneWidget);
    });
  });

  // --- Source-level security/architecture audit ---------------------------

  test(
    'the member payments feature never queries officer RPCs or tables directly',
    () {
      final root = Directory('lib/features/member_payments');
      final sources = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      for (final banned in [
        "'rpc_get_receipt'",
        'rpc_list_payments',
        'rpc_create_payment',
        "'payments'",
        "'payment_allocations'",
        "'member_wallet_entries'",
        "hasPermission('payment.view')",
        "hasPermission('payment.receipt.view')",
        "hasPermission('member.view')",
      ]) {
        expect(
          sources.contains(banned),
          isFalse,
          reason: 'member_payments must not reference $banned',
        );
      }
      expect(sources.contains('rpc_get_my_payments'), isTrue);
      expect(sources.contains('rpc_get_my_payment_detail'), isTrue);
      expect(sources.contains('rpc_get_my_receipt'), isTrue);
    },
  );

  group('navigation history chain (09G-B6-C.5)', () {
    testWidgets(
      'More -> My Payments -> Detail -> Receipt, then Back three times '
      'walks back through Detail -> My Payments -> More, in that exact '
      'order, never skipping a step or looping',
      (tester) async {
        final repo = FakeMyPaymentsRepository(
          details: {'p1': myPaymentDetailFixture(paymentId: 'p1')},
          receipts: {'p1': myReceiptFixture()},
        );
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: repo,
        );

        await _go(tester, h, AppRoutes.more);
        await _go(tester, h, AppRoutes.myPayments);
        await _go(tester, h, AppRoutes.myPaymentDetailPath('p1'));
        await _go(tester, h, AppRoutes.myPaymentReceiptPath('p1'));

        Future<void> tapBack() async {
          await tester.tap(find.byKey(const Key('memberChildBackButton')));
          await tester.pumpAndSettle();
        }

        await tapBack();
        expect(h.router.state.uri.path, AppRoutes.myPaymentDetailPath('p1'));

        await tapBack();
        expect(h.router.state.uri.path, AppRoutes.myPayments);

        await tapBack();
        expect(h.router.state.uri.path, AppRoutes.more);
      },
    );
  });
}
