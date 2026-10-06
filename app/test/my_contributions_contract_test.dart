import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/my_contributions/data/my_contributions_failure.dart';
import 'package:umoja/features/my_contributions/data/supabase_my_contributions_repository.dart';
import 'package:umoja/features/my_contributions/domain/my_contribution.dart';

import 'fakes/fake_my_contributions_repository.dart';

/// Prompt 09G-B4-C §Y: repository + model contract. Asserts the exact
/// RPC names and payloads, the deployed JSON field names, sign
/// preservation, settlement sources, and nullable historical metadata.
/// Financial values are asserted as the backend returned them — never
/// recomputed here.
void main() {
  group('RPC payloads', () {
    test('list sends exactly the seven approved parameters', () async {
      String? rpcName;
      Map<String, dynamic>? params;
      final repo = SupabaseMyContributionsRepository.withInvoker((
        function,
        payload,
      ) async {
        rpcName = function;
        params = payload;
        return myContributionsPageFixture().toJsonForTest();
      });

      await repo.getMyContributions(
        groupId: 'g1',
        status: MyContributionStatus.overdue,
        contributionTypeId: 't1',
        fromDate: DateTime(2026, 1, 5),
        toDate: DateTime(2026, 2, 28),
        limit: 40,
        offset: 0,
      );

      expect(rpcName, 'rpc_get_my_contributions');
      expect(params, {
        'p_group_id': 'g1',
        'p_status': 'OVERDUE',
        'p_contribution_type_id': 't1',
        'p_from_date': '2026-01-05',
        'p_to_date': '2026-02-28',
        'p_limit': 40,
        'p_offset': 0,
      });
      expect(params!.keys, hasLength(7));
    });

    test('list sends null for "All" status, type, and dates', () async {
      Map<String, dynamic>? params;
      final repo = SupabaseMyContributionsRepository.withInvoker((
        _,
        payload,
      ) async {
        params = payload;
        return myContributionsPageFixture().toJsonForTest();
      });

      await repo.getMyContributions(groupId: 'g1', limit: 20, offset: 0);

      expect(params!['p_status'], isNull);
      expect(params!['p_contribution_type_id'], isNull);
      expect(params!['p_from_date'], isNull);
      expect(params!['p_to_date'], isNull);
    });

    test(
      'detail sends exactly group + charge, nothing identity-like',
      () async {
        String? rpcName;
        Map<String, dynamic>? params;
        final repo = SupabaseMyContributionsRepository.withInvoker((
          function,
          payload,
        ) async {
          rpcName = function;
          params = payload;
          return myContributionDetailJson();
        });

        await repo.getMyContributionChargeDetail(groupId: 'g1', chargeId: 'c9');

        expect(rpcName, 'rpc_get_my_contribution_charge_detail');
        expect(params, {'p_group_id': 'g1', 'p_charge_id': 'c9'});
      },
    );

    test(
      'no payload ever carries a membership, user, phone, or officer id',
      () async {
        final sent = <Map<String, dynamic>>[];
        final repo = SupabaseMyContributionsRepository.withInvoker((
          _,
          payload,
        ) async {
          sent.add(payload);
          return payload.containsKey('p_charge_id')
              ? myContributionDetailJson()
              : myContributionsPageFixture().toJsonForTest();
        });

        await repo.getMyContributions(groupId: 'g1', limit: 20, offset: 0);
        await repo.getMyContributionChargeDetail(groupId: 'g1', chargeId: 'c1');

        const forbidden = [
          'p_membership_id',
          'p_user_id',
          'p_member_id',
          'p_phone',
          'p_officer_id',
          'p_membership',
        ];
        for (final payload in sent) {
          for (final key in forbidden) {
            expect(payload.containsKey(key), isFalse, reason: key);
          }
        }
      },
    );
  });

  group('failure mapping', () {
    Future<MyContributionsFailure> failureFrom(
      Object error, {
      bool detail = false,
    }) async {
      final repo = SupabaseMyContributionsRepository.withInvoker((_, _) async {
        throw error;
      });
      try {
        if (detail) {
          await repo.getMyContributionChargeDetail(
            groupId: 'g1',
            chargeId: 'c',
          );
        } else {
          await repo.getMyContributions(groupId: 'g1', limit: 20, offset: 0);
        }
      } on MyContributionsFailure catch (failure) {
        return failure;
      }
      fail('expected a MyContributionsFailure');
    }

    test('42501 and 28000 map to notAuthorized', () async {
      for (final code in ['42501', '28000']) {
        final failure = await failureFrom(
          PostgrestException(message: 'denied', code: code),
        );
        expect(failure.type, MyContributionsFailureType.notAuthorized);
      }
    });

    test('list 22023 on p_from_date maps to invalidDateRange', () async {
      final failure = await failureFrom(
        PostgrestException(
          message: 'p_from_date must not be after p_to_date',
          code: '22023',
        ),
      );
      expect(failure.type, MyContributionsFailureType.invalidDateRange);
    });

    test('list 22023 for an invalid status maps to invalidRequest', () async {
      final failure = await failureFrom(
        PostgrestException(
          message: 'MY_CONTRIBUTIONS_INVALID_STATUS',
          code: '22023',
        ),
      );
      expect(failure.type, MyContributionsFailureType.invalidRequest);
    });

    test(
      'detail 22023 maps to notFound (never another member\'s data)',
      () async {
        final failure = await failureFrom(
          PostgrestException(
            message: 'Contribution charge not found',
            code: '22023',
          ),
          detail: true,
        );
        expect(failure.type, MyContributionsFailureType.notFound);
      },
    );

    test('a payload that breaks the contract maps to unexpected', () async {
      final repo = SupabaseMyContributionsRepository.withInvoker(
        (_, _) async => {'member': 'not-a-map'},
      );
      expect(
        () => repo.getMyContributions(groupId: 'g1', limit: 20, offset: 0),
        throwsA(
          isA<MyContributionsFailure>().having(
            (f) => f.type,
            'type',
            MyContributionsFailureType.unexpected,
          ),
        ),
      );
    });

    test('an unknown status value fails closed as unexpected', () async {
      final repo = SupabaseMyContributionsRepository.withInvoker(
        (_, _) async => myContributionsPageFixture(
          items: [myContributionItemJson(status: 'PAID')],
        ).toJsonForTest(),
      );
      expect(
        () => repo.getMyContributions(groupId: 'g1', limit: 20, offset: 0),
        throwsA(
          isA<MyContributionsFailure>().having(
            (f) => f.type,
            'type',
            MyContributionsFailureType.unexpected,
          ),
        ),
      );
    });

    test('a non-Postgrest error is a network failure', () async {
      final failure = await failureFrom(StateError('socket closed'));
      expect(failure.type, MyContributionsFailureType.network);
    });
  });

  group('list model parsing', () {
    test('parses the live top-level keys and each section', () {
      final page = myContributionsPageFixture(
        totalOutstanding: 7000,
        items: [myContributionItemJson()],
        contributionTypes: [
          {
            'id': 't1',
            'name': 'Monthly Savings',
            'category': 'GENERAL',
            'name_variants': ['Monthly Savings'],
            'category_variants': ['GENERAL'],
          },
        ],
        hasMore: true,
        totalCount: 45,
      );

      expect(page.member.membershipId, 'm1');
      expect(page.group.groupName, 'Umoja Demo');
      expect(page.summary.totalOutstanding, 7000);
      expect(page.contributionTypes.single.id, 't1');
      expect(page.items.single.chargeId, 'c1');
      expect(page.pagination.totalCount, 45);
      expect(page.pagination.hasMore, isTrue);
    });

    test('item amounts are the backend values, never recomputed', () {
      final item = myContributionFixture(
        netAssessed: 12000,
        allocatedAmount: 5000,
        outstanding: 7000,
      );
      expect(item.netAssessed, 12000);
      expect(item.allocatedAmount, 5000);
      expect(item.outstanding, 7000);
    });

    test('there is no PAID status: only the four server statuses parse', () {
      expect(
        MyContributionStatus.values.map((s) => s.wire),
        unorderedEquals(['OPEN', 'PARTIALLY_SETTLED', 'OVERDUE', 'SETTLED']),
      );
      expect(
        () => MyContributionStatus.fromWire('PAID'),
        throwsFormatException,
      );
    });

    test('opening-balance purpose is distinguished from normal periods', () {
      final opening = myContributionFixture(
        periodLabel: null,
        periodPurpose: 'OPENING_BALANCE',
      );
      final normal = myContributionFixture();
      expect(opening.periodPurpose, MyContributionPeriodPurpose.openingBalance);
      expect(normal.periodPurpose, MyContributionPeriodPurpose.normal);
      expect(opening.periodLabel, isNull);
    });

    test('name variants parse, and previouslyRecordedNames excludes the primary name', () {
      final option = MyContributionTypeOption.fromJson({
        'id': 't1',
        'name': 'Monthly Savings',
        'category': 'GENERAL',
        'name_variants': ['Monthly Savings', 'Old Savings'],
        'category_variants': ['GENERAL'],
      });
      expect(option.nameVariants, ['Monthly Savings', 'Old Savings']);
      expect(option.previouslyRecordedNames, ['Old Savings']);
    });

    test('a type with one name has no previously-recorded names', () {
      final option = MyContributionTypeOption.fromJson({
        'id': 't1',
        'name': 'Monthly Savings',
        'category': 'GENERAL',
        'name_variants': ['Monthly Savings'],
        'category_variants': ['GENERAL'],
      });
      expect(option.previouslyRecordedNames, isEmpty);
    });

    test('a null historical name stays null, never a fabricated label', () {
      final item = MyContribution.fromJson(
        myContributionItemJson()..['contribution_type_name'] = null,
      );
      expect(item.contributionTypeName, isNull);
    });
  });

  group('detail model parsing', () {
    test('negative WAIVER and ADJUSTMENT keep their sign and null state', () {
      final detail = myContributionDetailFixture(
        components: [
          {
            'component_id': 'k1',
            'component_type': 'BASE',
            'assessed_amount': 12000,
            'net_effect': 12000,
            'allocated': 5000,
            'outstanding': 7000,
            'effective_at': '2026-03-01T00:00:00Z',
            'reason': null,
          },
          {
            'component_id': 'k2',
            'component_type': 'WAIVER',
            'assessed_amount': -2000,
            'net_effect': null,
            'allocated': null,
            'outstanding': null,
            'effective_at': '2026-03-02T00:00:00Z',
            'reason': 'Hardship',
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
      );

      expect(
        detail.components[1].componentType,
        MyContributionComponentType.waiver,
      );
      expect(detail.components[1].assessedAmount, -2000);
      expect(detail.components[1].netEffect, isNull);
      expect(detail.components[1].outstanding, isNull);
      expect(detail.components[2].assessedAmount, -500);
      expect(detail.components[2].reason, isNull);
    });

    test('OPENING_BALANCE components parse', () {
      final detail = myContributionDetailFixture(
        periodPurpose: 'OPENING_BALANCE',
        periodLabel: null,
        components: [
          {
            'component_id': 'k1',
            'component_type': 'OPENING_BALANCE',
            'assessed_amount': 40000,
            'net_effect': 40000,
            'allocated': 0,
            'outstanding': 40000,
            'effective_at': '2026-01-01T00:00:00Z',
            'reason': 'Imported',
          },
        ],
      );
      expect(
        detail.components.single.componentType,
        MyContributionComponentType.openingBalance,
      );
      expect(detail.periodPurpose, MyContributionPeriodPurpose.openingBalance);
      expect(detail.periodLabel, isNull);
    });

    test('PAYMENT settlement parses with receipt and reversed state', () {
      final detail = myContributionDetailFixture(
        settlementHistory: [
          {
            'allocation_id': 'a1',
            'component_id': 'k1',
            'component_type': 'BASE',
            'amount': 5000,
            'source': 'PAYMENT',
            'effective_at': '2026-03-05T00:00:00Z',
            'payment_status': 'REVERSED',
            'receipt_number': 'RCP-0042',
            'is_reversed': true,
          },
        ],
      );
      final settlement = detail.settlementHistory.single;
      expect(settlement.source, MyContributionSettlementSource.payment);
      expect(settlement.receiptNumber, 'RCP-0042');
      expect(settlement.paymentStatus, 'REVERSED');
      expect(settlement.reversed, isTrue);
    });

    test('WALLET settlement parses with no payment metadata', () {
      final detail = myContributionDetailFixture(
        settlementHistory: [
          {
            'allocation_id': 'a2',
            'component_id': 'k1',
            'component_type': 'BASE',
            'amount': 3000,
            'source': 'WALLET',
            'effective_at': '2026-03-06T00:00:00Z',
            'payment_status': null,
            'receipt_number': null,
            'is_reversed': null,
          },
        ],
      );
      final settlement = detail.settlementHistory.single;
      expect(settlement.source, MyContributionSettlementSource.wallet);
      expect(settlement.receiptNumber, isNull);
      expect(settlement.paymentStatus, isNull);
      expect(settlement.reversed, isFalse);
    });

    test('an unknown settlement source fails closed', () {
      expect(
        () => myContributionDetailFixture(
          settlementHistory: [
            {
              'allocation_id': 'a3',
              'component_id': 'k1',
              'component_type': 'BASE',
              'amount': 1,
              'source': 'CASH_DRAWER',
              'effective_at': '2026-03-06T00:00:00Z',
            },
          ],
        ),
        throwsFormatException,
      );
    });
  });
}

extension on MyContributionsPage {
  /// Round-trip helper: rebuilds the JSON map a fixture page was parsed
  /// from, so repository tests can feed the same shape back through.
  Map<String, dynamic> toJsonForTest() => {
    'member': {
      'membership_id': member.membershipId,
      'display_name': member.displayName,
      'member_number': member.memberNumber,
      'membership_status': member.membershipStatus,
    },
    'group': {
      'group_id': this.group.groupId,
      'group_name': this.group.groupName,
      'group_code': this.group.groupCode,
      'currency': this.group.currency,
    },
    'summary': {'total_outstanding': summary.totalOutstanding},
    'filter_options': {
      'contribution_types': [
        for (final t in contributionTypes)
          {
            'id': t.id,
            'name': t.name,
            'category': t.category,
            'name_variants': t.nameVariants,
            'category_variants': t.categoryVariants,
          },
      ],
    },
    'items': const <Map<String, dynamic>>[],
    'pagination': {
      'limit': pagination.limit,
      'offset': pagination.offset,
      'total_count': pagination.totalCount,
      'has_more': pagination.hasMore,
    },
  };
}
