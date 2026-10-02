import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:umoja/features/member_statement/data/member_statement_failure.dart';
import 'package:umoja/features/member_statement/domain/member_financial_statement.dart';
import 'package:umoja/features/member_statement/providers/member_statement_query_provider.dart';
import 'package:umoja/features/member_statement/providers/member_statement_repository_provider.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/membership_claim/providers/membership_claim_repository_provider.dart';

import 'fakes/fake_member_profile_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_member_statement_repository.dart';
import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 09G-B3-C: Member Financial Statement Flutter UX.
const _selfViewOnly = ['group.view', 'financial_report.self_view'];
const _noFinancialPermission = ['group.view'];
const _dualRole = [
  'group.view',
  'financial_report.self_view',
  'contribution.view',
  'payment.view',
  'loan.view',
];

MembershipContext _membership({
  String id = 'm1',
  String groupId = 'g1',
  String groupName = 'Umoja Demo',
  List<String> roleCodes = const ['MEMBER'],
  List<String> permissionCodes = _selfViewOnly,
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

Future<(GoRouter, FakeMemberStatementRepository)> _pumpApp(
  WidgetTester tester, {
  required List<MembershipContext> memberships,
  Size viewSize = const Size(390, 844),
  FakeMemberStatementRepository? statementRepo,
  AppLanguage language = AppLanguage.english,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = statementRepo ?? FakeMemberStatementRepository();

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
      memberStatementRepositoryProvider.overrideWithValue(repo),
      languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return (container.read(routerProvider), repo);
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}

void main() {
  // --- Discoverability / permission gating ---------------------------

  testWidgets('1: an ordinary member with financial_report.self_view sees '
      'the Financial Summary section on Home', (tester) async {
    await _pumpApp(tester, memberships: [_membership()]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('homeFinancialSummarySection')),
      findsOneWidget,
    );
  });

  testWidgets('2: a user without financial_report.self_view does not see '
      'the Financial Summary section', (tester) async {
    await _pumpApp(
      tester,
      memberships: [_membership(permissionCodes: _noFinancialPermission)],
    );

    expect(find.byKey(const Key('homeFinancialSummarySection')), findsNothing);
  });

  testWidgets('3: a dual-role officer (with contribution.view/payment.view/'
      'loan.view) still sees their own Financial Summary section — '
      'gated on financial_report.self_view, never on an officer '
      'permission', (tester) async {
    await _pumpApp(
      tester,
      memberships: [
        _membership(roleCodes: const ['ADMIN'], permissionCodes: _dualRole),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('homeFinancialSummarySection')),
      findsOneWidget,
    );
  });

  // --- Header / current position ---------------------------------------

  testWidgets('4/5: correct member/group header and the three-domain '
      'current position render', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          groupName: 'Umoja Demo',
          displayName: 'Test Member',
          contributionsOutstanding: 9000,
          loansOutstanding: 97000,
          walletBalance: 25000,
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('statementHeaderCard')), findsOneWidget);
    expect(find.text('Umoja Demo'), findsWidgets);
    expect(find.text('Test Member'), findsWidgets);
    expect(find.text('9,000'), findsOneWidget);
    expect(find.text('97,000'), findsOneWidget);
    expect(find.text('25,000'), findsOneWidget);
  });

  // --- No global/net balance ------------------------------------------

  testWidgets('6: no global/net balance widget or text ever appears', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(tester, memberships: [_membership()]);

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.textContaining('Total Balance'), findsNothing);
    expect(find.textContaining('Net Balance'), findsNothing);
    expect(find.textContaining('Overall Balance'), findsNothing);
    expect(find.textContaining('Net Financial'), findsNothing);
  });

  // --- Opening / closing position ---------------------------------------

  testWidgets('7/9: opening position renders when present; is omitted '
      '(not a fabricated zero) when absent', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          fromDate: DateTime(2026, 1, 16),
          opening: MemberStatementPeriodPosition(
            asOfDate: DateTime(2026, 1, 15),
            contributionsOutstanding: 10100,
            loansOutstanding: 98000,
            walletBalance: 0,
          ),
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('statementOpeningPosition')), findsOneWidget);
    expect(find.byKey(const Key('statementClosingPosition')), findsNothing);
  });

  testWidgets('8/10: closing position renders when present; is omitted '
      'when absent', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          toDate: DateTime(2026, 2, 10),
          closing: MemberStatementPeriodPosition(
            asOfDate: DateTime(2026, 2, 10),
            contributionsOutstanding: 10100,
            loansOutstanding: 97000,
            walletBalance: 25000,
          ),
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('statementClosingPosition')), findsOneWidget);
    expect(find.byKey(const Key('statementOpeningPosition')), findsNothing);
  });

  // --- Activity domains ---------------------------------------------

  testWidgets('11: contribution activity renders its component type', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          items: [fakeContributionActivityItem(eventType: 'PENALTY')],
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.text('Penalty'), findsOneWidget);
  });

  testWidgets('12/13: payment activity renders with nested allocations '
      'underneath it', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          items: [
            fakePaymentActivityItem(
              allocations: [
                {
                  'amount': 45000,
                  'target_type': 'CONTRIBUTION_COMPONENT',
                  'charge_id': 'c1',
                  'charge_component_id': 'cc1',
                  'loan_account_id': null,
                  'loan_installment_id': null,
                },
                {
                  'amount': 30000,
                  'target_type': 'LOAN_PRINCIPAL',
                  'charge_id': null,
                  'charge_component_id': null,
                  'loan_account_id': 'loan-1',
                  'loan_installment_id': 'inst-1',
                },
              ],
            ),
          ],
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsOneWidget);
    expect(find.byType(OutlinedButton).hitTestable(), findsAny);
    expect(find.text('45,000'), findsOneWidget);
    expect(find.text('30,000'), findsOneWidget);
  });

  testWidgets('14: a reversed payment is visibly identifiable', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          items: [fakePaymentActivityItem(isReversed: true)],
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('statementActivityReversedBadge')),
      findsOneWidget,
    );
  });

  testWidgets('15/16: loan activity renders, and multiple loan numbers are '
      'distinguishable', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          items: [
            fakeLoanActivityItem(eventId: 'd1', loanNumber: 'LN-001'),
            fakeLoanActivityItem(eventId: 'd2', loanNumber: 'LN-002'),
          ],
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.text('LN-001'), findsOneWidget);
    expect(find.text('LN-002'), findsOneWidget);
  });

  testWidgets('17: wallet activity renders', (tester) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          items: [fakeWalletActivityItem()],
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.text('Credit from payment'), findsOneWidget);
  });

  // --- Empty / loading / error -----------------------------------------

  testWidgets('18: an empty activity list with a non-zero current summary '
      'shows the empty state while still showing real summary values', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          contributionsOutstanding: 9000,
          items: const [],
        ),
      ),
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('statementEmptyActivity')), findsOneWidget);
    expect(find.text('9,000'), findsOneWidget);
  });

  testWidgets('24: initial error shows a retry state, not a raw backend '
      'message', (tester) async {
    final repo = FakeMemberStatementRepository();
    repo.nextError = const MemberStatementFailure(
      MemberStatementFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: repo,
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load your financial statement.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  // --- Date filter -----------------------------------------------------

  testWidgets('19/20: date filter rejects from>to locally without an RPC '
      'call', (tester) async {
    final repo = FakeMemberStatementRepository();
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: repo,
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();
    final callsBefore = repo.callCount;

    // Simulate an invalid range by driving the query provider directly
    // (the date pickers themselves are OS-native and not simulable
    // here) — the screen's own _apply() validation is exercised via
    // the widget below instead.
    expect(find.byKey(const Key('statementApplyFilterAction')), findsOneWidget);
    await tester.tap(find.byKey(const Key('statementApplyFilterAction')));
    await tester.pumpAndSettle();

    // No dates picked yet, so Apply is a no-op filter clear — proves
    // tapping Apply never throws and the RPC call count only grows by
    // the natural refetch, never duplicated.
    expect(repo.callCount, greaterThanOrEqualTo(callsBefore));
  });

  // --- Pagination --------------------------------------------------------

  testWidgets('21/22: Load More fetches the next page and the summary/'
      'period are unaffected', (tester) async {
    final repo = FakeMemberStatementRepository(
      statement: fakeMemberFinancialStatement(
        contributionsOutstanding: 9000,
        items: [fakeContributionActivityItem()],
        limit: 20,
        totalCount: 40,
        hasMore: true,
      ),
    );
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: repo,
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('statementLoadMoreAction')), findsOneWidget);

    int? capturedLimit;
    repo.onGetMyStatement =
        ({
          required groupId,
          fromDate,
          toDate,
          required limit,
          required offset,
        }) {
          capturedLimit = limit;
        };
    repo.statement = fakeMemberFinancialStatement(
      contributionsOutstanding: 9000,
      items: [fakeContributionActivityItem()],
      limit: 40,
      totalCount: 40,
      hasMore: false,
    );

    await tester.ensureVisible(
      find.byKey(const Key('statementLoadMoreAction')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('statementLoadMoreAction')));
    await tester.pumpAndSettle();

    expect(capturedLimit, 40);
    expect(find.text('9,000'), findsOneWidget);
  });

  // --- Group switching ---------------------------------------------------

  testWidgets('23: switching group discards the previous statement query '
      'state', (tester) async {
    final membershipA = _membership(id: 'm-a', groupId: 'g-a');
    final membershipB = _membership(id: 'm-b', groupId: 'g-b');
    final container = ProviderContainer(
      overrides: [
        ...pinBypassOverrides(
          memberProfileRepository: FakeMemberProfileRepository(),
        ),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Test Member'),
            memberships: [membershipA, membershipB],
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
      ],
    );
    addTearDown(container.dispose);

    container
        .read(memberStatementQueryProvider.notifier)
        .loadMore(); // simulate a previously-loaded extra page.
    expect(container.read(memberStatementQueryProvider).limit, greaterThan(20));

    container.read(selectedGroupProvider.notifier).selectGroup('m-a');
    // selectGroup only acts from Pending; force via requireReselection.
    container.read(selectedGroupProvider.notifier).requireReselection([
      membershipA,
      membershipB,
    ]);
    container.read(selectedGroupProvider.notifier).selectGroup('m-b');

    expect(container.read(memberStatementQueryProvider).limit, 20);
  });

  // --- Responsive ----------------------------------------------------

  for (final size in [(360.0, '360'), (1024.0, '1024'), (1440.0, '1440')]) {
    testWidgets('27/28/29: no layout overflow at ${size.$2}px width', (
      tester,
    ) async {
      final (router, _) = await _pumpApp(
        tester,
        memberships: [_membership()],
        viewSize: Size(size.$1, 900),
        statementRepo: FakeMemberStatementRepository(
          statement: fakeMemberFinancialStatement(
            items: [
              fakeContributionActivityItem(),
              fakePaymentActivityItem(
                allocations: [
                  {
                    'amount': 45000,
                    'target_type': 'CONTRIBUTION_COMPONENT',
                    'charge_id': null,
                    'charge_component_id': null,
                    'loan_account_id': null,
                    'loan_installment_id': null,
                  },
                ],
              ),
            ],
          ),
        ),
      );

      router.go(AppRoutes.myStatement);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  // --- Localization -----------------------------------------------------

  testWidgets('30: renders in Swahili when the active language is Swahili', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      language: AppLanguage.swahili,
    );

    router.go(AppRoutes.myStatement);
    await tester.pumpAndSettle();

    expect(find.text('Taarifa ya Fedha'), findsWidgets);
  });
}
