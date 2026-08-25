import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_enroll_controller.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_lifecycle_controller.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge.dart';
import 'package:umoja/features/contributions/domain/member_contribution_charge_page.dart';
import 'package:umoja/features/contributions/providers/contribution_period_charges_provider.dart';

import 'fakes/contribution_test_app.dart';
import 'fakes/fake_contribution_repository.dart';

// UAT failure A/B: a period detail showed "Members Charged: 1" but
// "View Charges" showed "No Charges Yet"; charges only appeared after
// manually enrolling a member. The backend was proven correct by direct
// SQL inspection (OPEN posts exactly one charge per eligible member); the
// bug was that neither the OPEN nor the ENROLL controller invalidated
// `contributionPeriodChargesProvider`, so an already-warm charges view
// kept showing its pre-mutation snapshot. These tests warm that cache
// first (matching the real user flow: View Charges was already open once)
// and only then trigger the mutation, so they only pass if invalidation
// genuinely happens — not because a brand-new subscription always fetches
// fresh regardless of any caching bug.
const _query = (periodId: 'period-1', search: '', limit: 10);
final _dueDate = DateTime.utc(2026, 8, 31);
final _effectiveAt = DateTime.utc(2026, 8, 1);
final _createdAt = DateTime.utc(2026, 8, 23);

void main() {
  testWidgets(
    'opening a period refreshes an already-warm charges view — the newly '
    'posted charge appears without restart',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'DRAFT')
        ..nextChargesPage = MemberContributionChargePage.empty;

      await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // Warm the charges provider's cache while the period is still
      // DRAFT — this key matches whatever View Charges will later
      // request (periodId, blank search, limit 10).
      final chargesBefore = await container.read(
        contributionPeriodChargesProvider(_query).future,
      );
      expect(chargesBefore.items, isEmpty);

      // OPEN posts a charge — mimics the real backend's effect, proven
      // correct separately via direct SQL inspection against the local
      // database (not re-asserted here).
      fakeRepo.nextChargesPage = MemberContributionChargePage(
        items: [
          MemberContributionCharge(
            chargeId: 'c1',
            membershipId: 'm1',
            memberNumberSnapshot: 'G-0001',
            memberNameSnapshot: 'Amina Juma',
            effectiveAt: _effectiveAt,
            dueDate: _dueDate,
            createdAt: _createdAt,
            baseAmount: 10000,
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

      await container
          .read(contributionPeriodLifecycleControllerProvider.notifier)
          .open(groupId: 'g1', periodId: 'period-1');
      await tester.pumpAndSettle();

      final chargesAfter = await container.read(
        contributionPeriodChargesProvider(_query).future,
      );
      expect(chargesAfter.items, hasLength(1));
      expect(chargesAfter.items.single.memberNameSnapshot, 'Amina Juma');
    },
  );

  testWidgets(
    'explicitly enrolling a member refreshes an already-warm charges view',
    (tester) async {
      final fakeRepo = FakeContributionRepository()
        ..nextPeriod = fakeContributionPeriod(status: 'OPEN')
        ..nextChargesPage = MemberContributionChargePage.empty;

      await pumpContributionsApp(tester, fakeRepo: fakeRepo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      final chargesBefore = await container.read(
        contributionPeriodChargesProvider(_query).future,
      );
      expect(chargesBefore.items, isEmpty);

      fakeRepo.nextChargesPage = MemberContributionChargePage(
        items: [
          MemberContributionCharge(
            chargeId: 'c2',
            membershipId: 'm2',
            memberNumberSnapshot: 'G-0002',
            memberNameSnapshot: 'Baraka Msigwa',
            effectiveAt: _effectiveAt,
            dueDate: _dueDate,
            createdAt: _createdAt,
            baseAmount: 10000,
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

      await container
          .read(contributionPeriodEnrollControllerProvider.notifier)
          .enroll(
            groupId: 'g1',
            periodId: 'period-1',
            membershipId: 'm2',
            isCustomAmount: false,
          );
      await tester.pumpAndSettle();

      final chargesAfter = await container.read(
        contributionPeriodChargesProvider(_query).future,
      );
      expect(chargesAfter.items, hasLength(1));
      expect(chargesAfter.items.single.memberNameSnapshot, 'Baraka Msigwa');
    },
  );
}
