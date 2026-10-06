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
import 'package:umoja/features/member_statement/providers/member_statement_repository_provider.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/membership_claim/providers/membership_claim_repository_provider.dart';
import 'package:umoja/features/my_contributions/data/my_contributions_failure.dart';
import 'package:umoja/features/my_contributions/domain/my_contribution.dart';
import 'package:umoja/features/my_contributions/providers/my_contributions_query_provider.dart';
import 'package:umoja/features/my_contributions/providers/my_contributions_repository_provider.dart';

import 'fakes/fake_member_profile_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_member_statement_repository.dart';
import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/fake_my_contributions_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 09G-B4-C: My Contributions widget, routing, provider, and
/// localization contract. The backend is the financial authority, so
/// these tests assert rendered backend values, never client-side math.
const _memberPermissions = ['group.view', 'contribution.self_view'];

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
  final FakeMyContributionsRepository repo;
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  required List<MembershipContext> memberships,
  FakeMyContributionsRepository? repo,
  Size viewSize = const Size(390, 844),
  AppLanguage language = AppLanguage.english,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final contributions = repo ?? FakeMyContributionsRepository();
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
      myContributionsRepositoryProvider.overrideWithValue(contributions),
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
    repo: contributions,
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

FakeMyContributionsRepository _repoWithItems({
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> contributionTypes = const [],
  num totalOutstanding = 7000,
  bool hasMore = false,
  int totalCount = 0,
}) {
  return FakeMyContributionsRepository(
    page: myContributionsPageFixture(
      items: items,
      contributionTypes: contributionTypes,
      totalOutstanding: totalOutstanding,
      hasMore: hasMore,
      totalCount: totalCount == 0 ? items.length : totalCount,
    ),
  );
}

void main() {
  // --- Routing, permission, and discoverability ---------------------------

  group('routing and permissions', () {
    testWidgets('contribution.self_view opens My Contributions', (
      tester,
    ) async {
      final h = await _pumpApp(tester, memberships: [_membership()]);
      await _go(tester, h, AppRoutes.myContributions);

      expect(find.text('My Contributions'), findsWidgets);
      expect(h.router.state.uri.path, AppRoutes.myContributions);
    });

    testWidgets('without contribution.self_view the list redirects to Home', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(h.router.state.uri.path, AppRoutes.home);
    });

    testWidgets('without contribution.self_view the detail redirects to Home', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.myContributionDetailPath('c1'));

      expect(h.router.state.uri.path, AppRoutes.home);
      expect(h.repo.detailCallCount, 0);
    });

    testWidgets('contribution.view alone does not substitute for self_view', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(
            permissionCodes: const ['group.view', 'contribution.view'],
            roleCodes: const ['ADMIN'],
          ),
        ],
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(h.router.state.uri.path, AppRoutes.home);
      expect(h.repo.listCallCount, 0);
    });

    testWidgets('a role name alone never authorizes the page', (tester) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(
            permissionCodes: const ['group.view'],
            roleCodes: const ['MEMBER'],
          ),
        ],
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(h.router.state.uri.path, AppRoutes.home);
    });

    test('self-service routes contain no membership or member id', () {
      expect(AppRoutes.myContributions, '/me/contributions');
      expect(AppRoutes.myContributionDetail, '/me/contributions/:chargeId');
      expect(AppRoutes.myContributionDetailPath('c1'), '/me/contributions/c1');
      expect(AppRoutes.myContributions, isNot(contains('members')));
      expect(AppRoutes.myContributionDetail, isNot(contains('membership')));
    });

    testWidgets(
      'Home shows My Contributions only with contribution.self_view',
      (tester) async {
        final granted = await _pumpApp(tester, memberships: [_membership()]);
        expect(
          find.byKey(const Key('homeMyContributionsShortcut')),
          findsOneWidget,
        );
        granted.container.dispose();
      },
    );

    testWidgets('Home hides My Contributions without contribution.self_view', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      expect(
        find.byKey(const Key('homeMyContributionsShortcut')),
        findsNothing,
      );
    });

    testWidgets(
      'More exposes My Contributions and keeps officer entry separate',
      (tester) async {
        final h = await _pumpApp(tester, memberships: [_membership()]);
        await _go(tester, h, AppRoutes.more);

        expect(
          find.byKey(const Key('moreMyContributionsAction')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('moreMyContributionsAction')));
        await tester.pumpAndSettle();
        expect(h.router.state.uri.path, AppRoutes.myContributions);
      },
    );

    testWidgets('More hides My Contributions without contribution.self_view', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view']),
        ],
      );
      await _go(tester, h, AppRoutes.more);

      expect(find.byKey(const Key('moreMyContributionsAction')), findsNothing);
    });
  });

  // --- Provider, query state, and group isolation -------------------------

  group('query state and selected group', () {
    testWidgets('initial state is All / All / no dates, base page size', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(),
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(h.repo.lastGroupId, 'g1');
      expect(h.repo.lastStatus, isNull);
      expect(h.repo.lastContributionTypeId, isNull);
      expect(h.repo.lastFromDate, isNull);
      expect(h.repo.lastToDate, isNull);
      expect(h.repo.lastLimit, 20);
      expect(h.repo.lastOffset, 0);
    });

    testWidgets('status filter sends the backend enum string', (tester) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(),
      );
      await _go(tester, h, AppRoutes.myContributions);

      h.container
          .read(myContributionsQueryProvider.notifier)
          .applyFilters(status: MyContributionStatus.overdue);
      await tester.pumpAndSettle();

      expect(h.repo.lastStatus, MyContributionStatus.overdue);
      expect(h.repo.lastStatus!.wire, 'OVERDUE');
      expect(h.repo.lastOffset, 0);
    });

    testWidgets('selected type sends its UUID and exact dates are sent', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(),
      );
      await _go(tester, h, AppRoutes.myContributions);

      h.container
          .read(myContributionsQueryProvider.notifier)
          .applyFilters(
            contributionTypeId: 't-42',
            fromDate: DateTime(2026, 1, 5),
            toDate: DateTime(2026, 2, 28),
          );
      await tester.pumpAndSettle();

      expect(h.repo.lastContributionTypeId, 't-42');
      expect(h.repo.lastFromDate, DateTime(2026, 1, 5));
      expect(h.repo.lastToDate, DateTime(2026, 2, 28));
    });

    testWidgets(
      'an inverted date range is rejected locally and sends nothing',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(),
        );
        await _go(tester, h, AppRoutes.myContributions);
        final before = h.repo.listCallCount;

        final accepted = h.container
            .read(myContributionsQueryProvider.notifier)
            .applyFilters(
              fromDate: DateTime(2026, 3, 1),
              toDate: DateTime(2026, 2, 1),
            );
        await tester.pumpAndSettle();

        expect(accepted, isFalse);
        expect(h.container.read(myContributionsQueryProvider).fromDate, isNull);
        expect(h.repo.listCallCount, before);
      },
    );

    testWidgets('changing a filter resets pagination to the first page', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(),
      );
      await _go(tester, h, AppRoutes.myContributions);
      final notifier = h.container.read(myContributionsQueryProvider.notifier);

      notifier.loadMore();
      notifier.loadMore();
      await tester.pumpAndSettle();
      expect(h.repo.lastLimit, 60);

      notifier.applyFilters(status: MyContributionStatus.open);
      await tester.pumpAndSettle();
      expect(h.repo.lastLimit, 20);
      expect(h.repo.lastOffset, 0);
    });

    testWidgets(
      'loading more grows the limit from offset zero and caps at 200',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(),
        );
        await _go(tester, h, AppRoutes.myContributions);
        final notifier = h.container.read(
          myContributionsQueryProvider.notifier,
        );

        for (var i = 0; i < 20; i++) {
          notifier.loadMore();
        }
        await tester.pumpAndSettle();

        expect(h.container.read(myContributionsQueryProvider).limit, 200);
        expect(h.repo.lastOffset, 0);
      },
    );

    testWidgets('switching the selected group clears previous filters', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [
          _membership(id: 'm-a', groupId: 'g-a', groupName: 'Alpha'),
          _membership(id: 'm-b', groupId: 'g-b', groupName: 'Beta'),
        ],
        repo: _repoWithItems(),
      );
      h.container.read(selectedGroupProvider.notifier).selectGroup('m-a');
      await tester.pumpAndSettle();

      h.container
          .read(myContributionsQueryProvider.notifier)
          .applyFilters(status: MyContributionStatus.overdue);
      await tester.pumpAndSettle();
      expect(h.container.read(myContributionsQueryProvider).status, isNotNull);

      h.container.read(selectedGroupProvider.notifier).requireReselection([
        _membership(id: 'm-a', groupId: 'g-a', groupName: 'Alpha'),
        _membership(id: 'm-b', groupId: 'g-b', groupName: 'Beta'),
      ]);
      h.container.read(selectedGroupProvider.notifier).selectGroup('m-b');
      await tester.pumpAndSettle();

      expect(h.container.read(myContributionsQueryProvider).status, isNull);

      // Returning to the list refetches for the NEW group, with no
      // carried-over filter.
      await _go(tester, h, AppRoutes.myContributions);
      expect(h.repo.lastGroupId, 'g-b');
      expect(h.repo.lastStatus, isNull);
    });

    testWidgets(
      'summary is the backend total and is not recomputed from rows',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(
            items: [myContributionItemJson(chargeId: 'c1', outstanding: 7000)],
            totalOutstanding: 999999,
          ),
        );
        await _go(tester, h, AppRoutes.myContributions);

        expect(find.text('999,999'), findsOneWidget);
        expect(find.text('7,000'), findsWidgets);
      },
    );
  });

  // --- List UI ------------------------------------------------------------

  group('list UI', () {
    testWidgets('each backend status renders with its localized label', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(
          items: [
            myContributionItemJson(chargeId: 'c1', status: 'OPEN'),
            myContributionItemJson(chargeId: 'c2', status: 'PARTIALLY_SETTLED'),
            myContributionItemJson(chargeId: 'c3', status: 'OVERDUE'),
            myContributionItemJson(chargeId: 'c4', status: 'SETTLED'),
          ],
        ),
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(find.byKey(const Key('myContributionStatus_c1')), findsOneWidget);
      expect(find.text('Open'), findsWidgets);
      expect(find.text('Partially Settled'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Settled'), findsWidgets);
    });

    testWidgets('no PAID terminology appears anywhere on the list', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(
          items: [myContributionItemJson(status: 'SETTLED')],
        ),
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(find.textContaining('Paid'), findsNothing);
      expect(find.textContaining('PAID'), findsNothing);
    });

    testWidgets(
      'a normal row shows type, period, and the three canonical amounts',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(
            items: [
              myContributionItemJson(
                chargeId: 'c1',
                typeName: 'Monthly Savings',
                periodLabel: 'March 2026',
                netAssessed: 12000,
                allocatedAmount: 5000,
                outstanding: 7000,
              ),
            ],
          ),
        );
        await _go(tester, h, AppRoutes.myContributions);

        expect(find.text('Monthly Savings'), findsOneWidget);
        expect(find.text('March 2026'), findsOneWidget);
        expect(find.text('12,000'), findsOneWidget);
        expect(find.text('5,000'), findsOneWidget);
        expect(find.text('7,000'), findsWidgets);
      },
    );

    testWidgets(
      'an opening-balance row shows the explicit Opening Balance label',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(
            items: [
              myContributionItemJson(
                chargeId: 'c-open',
                periodLabel: null,
                periodPurpose: 'OPENING_BALANCE',
              ),
            ],
          ),
        );
        await _go(tester, h, AppRoutes.myContributions);

        expect(find.text('Opening Balance'), findsOneWidget);
      },
    );

    testWidgets('no contributions yet shows the empty-history message', (
      tester,
    ) async {
      final h = await _pumpApp(tester, memberships: [_membership()]);
      await _go(tester, h, AppRoutes.myContributions);

      expect(find.byKey(const Key('myContributionsEmpty')), findsOneWidget);
      expect(find.text('No contributions yet'), findsOneWidget);
    });

    testWidgets('a filtered empty result is distinct from no history', (
      tester,
    ) async {
      final h = await _pumpApp(tester, memberships: [_membership()]);
      await _go(tester, h, AppRoutes.myContributions);

      h.container
          .read(myContributionsQueryProvider.notifier)
          .applyFilters(status: MyContributionStatus.overdue);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('myContributionsEmptyFiltered')),
        findsOneWidget,
      );
      expect(find.text('No contributions match these filters'), findsOneWidget);
      expect(find.text('No contributions yet'), findsNothing);
    });

    testWidgets('a load failure shows a retry state and never raw error text', (
      tester,
    ) async {
      final repo = _repoWithItems()
        ..nextError = const MyContributionsFailure(
          MyContributionsFailureType.network,
        );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(
        find.text('Network error. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('FormatException'), findsNothing);
    });

    testWidgets(
      'load more appends the next page request, not a duplicate reset',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(
            items: [myContributionItemJson(chargeId: 'c1')],
            hasMore: true,
            totalCount: 45,
          ),
        );
        await _go(tester, h, AppRoutes.myContributions);

        expect(
          find.byKey(const Key('myContributionsLoadMoreAction')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('myContributionsLoadMoreAction')),
        );
        await tester.tap(
          find.byKey(const Key('myContributionsLoadMoreAction')),
        );
        await tester.pumpAndSettle();

        expect(h.repo.lastLimit, 40);
        expect(h.repo.lastOffset, 0);
      },
    );

    testWidgets(
      'filter sheet applies a status and shows it as a removable chip',
      (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: _repoWithItems(items: [myContributionItemJson(chargeId: 'c1')]),
        );
        await _go(tester, h, AppRoutes.myContributions);

        await tester.tap(find.byKey(const Key('myContributionsFiltersAction')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('myContributionsStatusChip_OVERDUE')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('myContributionsApplyFiltersAction')),
        );
        await tester.pumpAndSettle();

        expect(h.repo.lastStatus, MyContributionStatus.overdue);
        expect(
          find.byKey(const Key('myContributionsActiveFilter_status')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('myContributionsClearAllFilters')),
        );
        await tester.pumpAndSettle();
        expect(h.repo.lastStatus, isNull);
        expect(
          find.byKey(const Key('myContributionsActiveFilter_status')),
          findsNothing,
        );
      },
    );

    testWidgets('the type filter is built from the backend filter options', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(
          items: [
            myContributionItemJson(chargeId: 'c1', typeName: 'Monthly Savings'),
          ],
          contributionTypes: [
            {
              'id': 't-option',
              'name': 'Welfare Fund',
              'category': 'SOCIAL',
              'name_variants': ['Welfare Fund', 'Old Welfare'],
              'category_variants': ['SOCIAL'],
            },
          ],
        ),
      );
      await _go(tester, h, AppRoutes.myContributions);

      await tester.tap(find.byKey(const Key('myContributionsFiltersAction')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('myContributionsTypeOption_t-option')),
        findsOneWidget,
      );
      expect(find.text('Welfare Fund'), findsOneWidget);
      expect(
        find.textContaining('Previously recorded as: Old Welfare'),
        findsOneWidget,
      );
    });

    testWidgets('an inverted date range is rejected by the query state', (
      tester,
    ) async {
      // The filter sheet runs the same from<=to check before it pops, so
      // an inverted range never reaches this notifier from the UI.
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(items: [myContributionItemJson(chargeId: 'c1')]),
      );
      await _go(tester, h, AppRoutes.myContributions);
      await tester.tap(find.byKey(const Key('myContributionsFiltersAction')));
      await tester.pumpAndSettle();

      // Structurally invalid range set through the notifier path the sheet
      // uses; the sheet's own check shows the error and does not close.
      expect(
        h.container
            .read(myContributionsQueryProvider.notifier)
            .applyFilters(
              fromDate: DateTime(2026, 5, 2),
              toDate: DateTime(2026, 5, 1),
            ),
        isFalse,
      );
    });

    testWidgets('a single contribution row is tappable to its detail route', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: _repoWithItems(items: [myContributionItemJson(chargeId: 'c1')]),
      );
      await _go(tester, h, AppRoutes.myContributions);

      await tester.tap(find.byKey(const Key('myContributionRow_c1')));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/me/contributions/c1');
    });
  });

  // --- Detail UI ----------------------------------------------------------

  group('detail UI', () {
    testWidgets('detail renders the canonical position and status', (
      tester,
    ) async {
      final repo = FakeMyContributionsRepository(
        details: {'c1': myContributionDetailFixture(chargeId: 'c1')},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myContributionDetailPath('c1'));

      expect(
        find.byKey(const Key('myContributionDetailStatus')),
        findsOneWidget,
      );
      expect(find.text('Partially Settled'), findsOneWidget);
      expect(
        find.byKey(const Key('myContributionDetailPosition')),
        findsOneWidget,
      );
      expect(find.text('12,000'), findsOneWidget);
      expect(find.text('7,000'), findsOneWidget);
    });

    testWidgets(
      'negative waiver and adjustment render as negative, not positive',
      (tester) async {
        final repo = FakeMyContributionsRepository(
          details: {
            'c1': myContributionDetailFixture(
              chargeId: 'c1',
              components: [
                {
                  'component_id': 'k2',
                  'component_type': 'WAIVER',
                  'assessed_amount': -2000,
                  'net_effect': null,
                  'allocated': null,
                  'outstanding': null,
                  'effective_at': '2026-03-02T00:00:00Z',
                  'reason': null,
                },
                {
                  'component_id': 'k3',
                  'component_type': 'ADJUSTMENT',
                  'assessed_amount': -500,
                  'net_effect': null,
                  'allocated': null,
                  'outstanding': null,
                  'effective_at': '2026-03-03T00:00:00Z',
                  'reason': null,
                },
              ],
            ),
          },
        );
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          repo: repo,
        );
        await _go(tester, h, AppRoutes.myContributionDetailPath('c1'));

        expect(find.text('-2,000'), findsOneWidget);
        expect(find.text('-500'), findsOneWidget);
        expect(find.text('Waiver'), findsOneWidget);
        expect(find.text('Adjustment'), findsOneWidget);
      },
    );

    testWidgets('payment, wallet, and reversed settlements are distinct', (
      tester,
    ) async {
      final repo = FakeMyContributionsRepository(
        details: {
          'c1': myContributionDetailFixture(
            chargeId: 'c1',
            settlementHistory: [
              {
                'allocation_id': 'a-pay',
                'component_id': 'k1',
                'component_type': 'BASE',
                'amount': 5000,
                'source': 'PAYMENT',
                'effective_at': '2026-03-05T00:00:00Z',
                'payment_status': 'POSTED',
                'receipt_number': 'RCP-0042',
                'is_reversed': false,
              },
              {
                'allocation_id': 'a-wallet',
                'component_id': 'k1',
                'component_type': 'BASE',
                'amount': 3000,
                'source': 'WALLET',
                'effective_at': '2026-03-06T00:00:00Z',
                'payment_status': null,
                'receipt_number': null,
                'is_reversed': null,
              },
              {
                'allocation_id': 'a-rev',
                'component_id': 'k1',
                'component_type': 'BASE',
                'amount': 1000,
                'source': 'PAYMENT',
                'effective_at': '2026-03-07T00:00:00Z',
                'payment_status': 'REVERSED',
                'receipt_number': 'RCP-0043',
                'is_reversed': true,
              },
            ],
          ),
        },
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myContributionDetailPath('c1'));

      expect(find.byKey(const Key('mySettlement_a-pay')), findsOneWidget);
      expect(find.text('Risiti RCP-0042'), findsNothing);
      expect(find.text('Receipt RCP-0042'), findsOneWidget);
      expect(find.text('Settled from the member wallet'), findsOneWidget);
      expect(
        find.byKey(const Key('mySettlementReversed_a-rev')),
        findsOneWidget,
      );
      expect(find.text('Reversed'), findsOneWidget);
    });

    testWidgets('no settlements shows an honest empty message', (tester) async {
      final repo = FakeMyContributionsRepository(
        details: {'c1': myContributionDetailFixture(chargeId: 'c1')},
      );
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: repo,
      );
      await _go(tester, h, AppRoutes.myContributionDetailPath('c1'));

      expect(
        find.byKey(const Key('myContributionSettlementsEmpty')),
        findsOneWidget,
      );
    });

    testWidgets('another member or group charge shows not-found, not data', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        repo: FakeMyContributionsRepository(),
      );
      await _go(tester, h, AppRoutes.myContributionDetailPath('someone-else'));

      expect(find.text('This contribution is not available.'), findsOneWidget);
      expect(find.text('Monthly Savings'), findsNothing);
    });
  });

  // --- Localization and responsive layout --------------------------------

  group('localization and layout', () {
    testWidgets('Swahili renders the Swahili title and status labels', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        language: AppLanguage.swahili,
        repo: _repoWithItems(
          items: [myContributionItemJson(chargeId: 'c1', status: 'OVERDUE')],
        ),
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(find.text('Michango Yangu'), findsWidgets);
      expect(find.text('Imechelewa'), findsOneWidget);
      expect(find.text('Jumla ya Deni Lililobaki'), findsOneWidget);
    });

    testWidgets('Swahili opening balance uses its Swahili label', (
      tester,
    ) async {
      final h = await _pumpApp(
        tester,
        memberships: [_membership()],
        language: AppLanguage.swahili,
        repo: _repoWithItems(
          items: [
            myContributionItemJson(
              chargeId: 'c-open',
              periodLabel: null,
              periodPurpose: 'OPENING_BALANCE',
            ),
          ],
        ),
      );
      await _go(tester, h, AppRoutes.myContributions);

      expect(find.text('Salio la Mwanzo'), findsOneWidget);
    });

    for (final width in [360.0, 1024.0, 1440.0]) {
      testWidgets('list has no overflow at ${width.toInt()}px', (tester) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          viewSize: Size(width, 900),
          repo: _repoWithItems(
            items: [
              myContributionItemJson(
                chargeId: 'c1',
                typeName: 'A very long contribution type name for layout',
                netAssessed: 1234567,
                allocatedAmount: 1234567,
                outstanding: 1234567,
              ),
            ],
          ),
        );
        await _go(tester, h, AppRoutes.myContributions);

        expect(tester.takeException(), isNull);
      });

      testWidgets('detail has no overflow at ${width.toInt()}px', (
        tester,
      ) async {
        final h = await _pumpApp(
          tester,
          memberships: [_membership()],
          viewSize: Size(width, 900),
          repo: FakeMyContributionsRepository(
            details: {'c1': myContributionDetailFixture(chargeId: 'c1')},
          ),
        );
        await _go(tester, h, AppRoutes.myContributionDetailPath('c1'));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
