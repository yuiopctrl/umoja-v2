import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/member_statement/providers/home_financial_summary_provider.dart';
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

/// Prompt 09G-B3-D: Member Home Financial Summary.
///
/// These tests target exactly what's NOT already covered by
/// `member_statement_screen_test.dart`'s shared `_pumpApp` tests
/// 1/2/3 (discoverability/permission gating of the Home section) —
/// namely [homeFinancialSummaryProvider]'s isolation from
/// [memberStatementQueryProvider], and the Home-specific rendering
/// behaviors (no global balance, real-zero outstanding, last-payment
/// null/populated, navigation to the full statement, responsive,
/// Swahili).
const _selfView = ['group.view', 'financial_report.self_view'];

MembershipContext _membership({
  String id = 'm1',
  String groupId = 'g1',
  String groupName = 'Umoja Demo',
  List<String> permissionCodes = _selfView,
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
    roleCodes: const ['MEMBER'],
    permissionCodes: permissionCodes,
  );
}

Future<(GoRouter, FakeMemberStatementRepository, ProviderContainer)> _pumpApp(
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

  return (container.read(routerProvider), repo, container);
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}

void main() {
  // --- Provider isolation (Section X) -----------------------------------

  testWidgets('1: Home requests the current position only — selected group, '
      'from_date=null, to_date=null, offset=0, the minimum valid limit', (
    tester,
  ) async {
    String? capturedGroupId;
    DateTime? capturedFromDate;
    DateTime? capturedToDate;
    int? capturedLimit;
    int? capturedOffset;

    final repo = FakeMemberStatementRepository()
      ..onGetMyStatement =
          ({
            required groupId,
            fromDate,
            toDate,
            required limit,
            required offset,
          }) {
            capturedGroupId = groupId;
            capturedFromDate = fromDate;
            capturedToDate = toDate;
            capturedLimit = limit;
            capturedOffset = offset;
          };

    await _pumpApp(
      tester,
      memberships: [_membership(groupId: 'g1')],
      statementRepo: repo,
    );

    expect(capturedGroupId, 'g1');
    expect(capturedFromDate, isNull);
    expect(capturedToDate, isNull);
    expect(capturedOffset, 0);
    expect(capturedLimit, 1);
  });

  testWidgets(
    '2: a previously-applied Financial Statement date filter/page size '
    'never leaks into what Home requests',
    (tester) async {
      final repo = FakeMemberStatementRepository();
      final (_, _, container) = await _pumpApp(
        tester,
        memberships: [_membership()],
        statementRepo: repo,
      );

      // Simulate the user having already filtered/paginated the full
      // Financial Statement screen before returning to Home.
      container
          .read(memberStatementQueryProvider.notifier)
          .setDateRange(
            fromDate: DateTime(2026, 1, 1),
            toDate: DateTime(2026, 2, 1),
          );
      container.read(memberStatementQueryProvider.notifier).loadMore();

      String? capturedGroupId;
      DateTime? capturedFromDate;
      int? capturedLimit;
      repo.onGetMyStatement =
          ({
            required groupId,
            fromDate,
            toDate,
            required limit,
            required offset,
          }) {
            capturedGroupId = groupId;
            capturedFromDate = fromDate;
            capturedLimit = limit;
          };

      container.invalidate(homeFinancialSummaryProvider);
      await container.read(homeFinancialSummaryProvider.future);

      expect(capturedGroupId, 'g1');
      expect(capturedFromDate, isNull);
      expect(capturedLimit, 1);
    },
  );

  testWidgets('3: switching the selected group refetches Home with the '
      'new group\'s id', (tester) async {
    final membershipA = _membership(id: 'm-a', groupId: 'g-a');
    final membershipB = _membership(id: 'm-b', groupId: 'g-b');
    final repo = FakeMemberStatementRepository();

    final (_, _, container) = await _pumpApp(
      tester,
      memberships: [membershipA, membershipB],
      statementRepo: repo,
    );

    container.read(selectedGroupProvider.notifier).selectGroup('m-a');
    await tester.pumpAndSettle();

    String? capturedGroupId;
    repo.onGetMyStatement =
        ({
          required groupId,
          fromDate,
          toDate,
          required limit,
          required offset,
        }) {
          capturedGroupId = groupId;
        };

    container.read(selectedGroupProvider.notifier).requireReselection([
      membershipA,
      membershipB,
    ]);
    container.read(selectedGroupProvider.notifier).selectGroup('m-b');
    await tester.pumpAndSettle();

    expect(capturedGroupId, 'g-b');
  });

  testWidgets('4: invalidating the Home provider triggers a fresh fetch '
      'with the same isolated params (refresh never changes what is '
      'requested)', (tester) async {
    final repo = FakeMemberStatementRepository();
    final (_, _, container) = await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: repo,
    );

    final initialCallCount = repo.callCount;
    container.invalidate(homeFinancialSummaryProvider);
    await container.read(homeFinancialSummaryProvider.future);

    expect(repo.callCount, greaterThan(initialCallCount));
  });

  // --- Home UX (Section Y) -----------------------------------------------

  testWidgets('5: the three independent current positions render with no '
      'global/net/total balance text anywhere on Home', (tester) async {
    await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          contributionsOutstanding: 9000,
          loansOutstanding: 97000,
          walletBalance: 25000,
        ),
      ),
    );

    expect(find.text('9,000'), findsOneWidget);
    expect(find.text('97,000'), findsOneWidget);
    expect(find.text('25,000'), findsOneWidget);
    for (final forbidden in [
      'Total Balance',
      'Net Balance',
      'Overall Balance',
      '131,000',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('6: a real zero outstanding is shown as zero, not hidden or '
      'treated as missing data', (tester) async {
    await _pumpApp(
      tester,
      memberships: [_membership()],
      statementRepo: FakeMemberStatementRepository(
        statement: fakeMemberFinancialStatement(
          contributionsOutstanding: 0,
          loansOutstanding: 0,
          walletBalance: 0,
        ),
      ),
    );

    expect(find.text('0'), findsWidgets);
  });

  testWidgets('7: no last payment yet renders the honest empty message, '
      'never a fabricated zero-amount payment', (tester) async {
    await _pumpApp(tester, memberships: [_membership()]);

    expect(find.byKey(const Key('homeLastPaymentCard')), findsOneWidget);
    expect(find.text('No payments yet.'), findsOneWidget);
  });

  testWidgets('8: tapping "View Financial Statement" on Home navigates to '
      'the one Financial Statement screen (no duplicate screen)', (
    tester,
  ) async {
    await _pumpApp(tester, memberships: [_membership()]);

    await tester.ensureVisible(
      find.byKey(const Key('homeViewFinancialStatementAction')),
    );
    await tester.tap(find.byKey(const Key('homeViewFinancialStatementAction')));
    await tester.pumpAndSettle();

    // Prompt 09G-B3-UX-01-FIX-02 §F: renamed to "My Financial
    // Statement" — the self-service screen only.
    expect(find.text('My Financial Statement'), findsOneWidget);
  });

  for (final width in [360.0, 1024.0, 1440.0]) {
    testWidgets('9: no layout overflow on Home at ${width.toInt()}px width', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        memberships: [_membership()],
        viewSize: Size(width, 900),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('10: Home\'s financial summary section renders in Swahili', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      memberships: [_membership()],
      language: AppLanguage.swahili,
    );

    expect(find.text('Hali Yangu ya Fedha'), findsOneWidget);
    expect(find.text('Angalia Taarifa Yangu ya Fedha'), findsOneWidget);
  });

  testWidgets('11: a backend failure on Home shows a retry state, not a '
      'raw backend error', (tester) async {
    final repo = FakeMemberStatementRepository()
      ..nextError = Exception('raw backend failure detail');

    await _pumpApp(tester, memberships: [_membership()], statementRepo: repo);

    expect(find.text('Unable to load financial summary.'), findsOneWidget);
    expect(find.textContaining('raw backend failure detail'), findsNothing);
  });
}
