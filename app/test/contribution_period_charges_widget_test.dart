import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/contributions/data/contribution_repository.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge_page.dart';

import 'fakes/contribution_test_app.dart';

/// A [ContributionRepository] fake backed by a real in-memory list of
/// charges, so `listContributionPeriodCharges(limit: ...)` genuinely
/// returns more rows as the requested limit grows — mirrors
/// `members_pagination_test.dart`'s `_PaginatedMemberRepository`.
class _PaginatedChargesRepository implements ContributionRepository {
  _PaginatedChargesRepository(int totalCharges)
    : _all = List.generate(
        totalCharges,
        (i) => MemberContributionCharge(
          chargeId: 'c-${i + 1}',
          membershipId: 'm-${i + 1}',
          memberNumberSnapshot: 'M-${(i + 1).toString().padLeft(3, '0')}',
          memberNameSnapshot: 'Member ${(i + 1).toString().padLeft(2, '0')}',
          effectiveAt: DateTime.utc(2026, 1, 1),
          dueDate: DateTime.utc(2026, 1, 5),
          createdAt: DateTime.utc(2026, 1, 1),
          baseAmount: 5000,
        ),
      );

  final List<MemberContributionCharge> _all;
  final List<int> requestedLimits = [];

  @override
  Future<MemberContributionChargePage> listContributionPeriodCharges({
    required String groupId,
    required String periodId,
    String? search,
    int limit = 10,
    int offset = 0,
  }) async {
    requestedLimits.add(limit);
    final items = _all.take(limit).toList(growable: false);
    return MemberContributionChargePage(
      items: items,
      totalCount: _all.length,
      limit: limit,
      offset: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('the charges list requests exactly 10 charges on first load', (
    tester,
  ) async {
    final repo = _PaginatedChargesRepository(25);
    // pumpContributionsApp expects a FakeContributionRepository for its
    // typed parameter, but only the ContributionRepository interface is
    // actually used at runtime — construct the app manually instead.
    final router = await pumpContributionsAppWithRepository(
      tester,
      repository: repo,
    );
    router.go(AppRoutes.contributionPeriodChargesPath('period-1'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Onyesha Zaidi'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(repo.requestedLimits, [10]);
    expect(find.text('Member 10'), findsOneWidget);
    expect(find.text('Member 11'), findsNothing);
    expect(find.text('Onyesha Zaidi'), findsOneWidget);

    await tester.tap(find.text('Onyesha Zaidi'));
    await tester.pumpAndSettle();

    expect(repo.requestedLimits, [10, 20]);
    await tester.dragUntilVisible(
      find.text('Member 20'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Member 20'), findsOneWidget);

    // No paid/unpaid/balance concept anywhere on the charges list.
    expect(find.textContaining('Amelipa'), findsNothing);
    expect(find.textContaining('Balance'), findsNothing);
    expect(find.textContaining('Salio'), findsNothing);
  });
}
