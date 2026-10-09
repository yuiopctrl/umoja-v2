import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/member_payments/data/my_payments_failure.dart';
import 'package:umoja/features/member_payments/data/supabase_my_payments_repository.dart';
import 'package:umoja/features/member_payments/domain/my_payment.dart';

import 'fakes/fake_my_payments_repository.dart';

/// Prompt 09G-B6-C §AI/§AJ: repository + model contract. Asserts the
/// exact RPC names and payloads (never membership_id/user_id), the
/// deployed JSON field names for list/detail/receipt, every allocation
/// target type, contribution BASE/PENALTY, wallet credit (plain and
/// reversed), and reversed-payment/receipt parsing. Financial values are
/// asserted as the backend returned them — never recomputed here.
void main() {
  group('RPC payloads', () {
    test(
      'list calls rpc_get_my_payments with exactly six parameters',
      () async {
        String? rpcName;
        Map<String, dynamic>? params;
        final repo = SupabaseMyPaymentsRepository.withInvoker((
          function,
          payload,
        ) async {
          rpcName = function;
          params = payload;
          return myPaymentsPageFixture().toJsonForTest();
        });

        await repo.getMyPayments(
          groupId: 'g1',
          status: MyPaymentStatus.reversed,
          fromDate: DateTime(2026, 4, 1),
          toDate: DateTime(2026, 4, 30),
          limit: 40,
          offset: 20,
        );

        expect(rpcName, 'rpc_get_my_payments');
        expect(params, {
          'p_group_id': 'g1',
          'p_status': 'REVERSED',
          'p_from_date': '2026-04-01',
          'p_to_date': '2026-04-30',
          'p_limit': 40,
          'p_offset': 20,
        });
        expect(params!.keys, hasLength(6));
      },
    );

    test('list sends null for "All" status and no dates', () async {
      Map<String, dynamic>? params;
      final repo = SupabaseMyPaymentsRepository.withInvoker((_, payload) async {
        params = payload;
        return myPaymentsPageFixture().toJsonForTest();
      });

      await repo.getMyPayments(groupId: 'g1', limit: 20, offset: 0);

      expect(params!['p_status'], isNull);
      expect(params!['p_from_date'], isNull);
      expect(params!['p_to_date'], isNull);
    });

    test('detail sends exactly group + payment id', () async {
      String? rpcName;
      Map<String, dynamic>? params;
      final repo = SupabaseMyPaymentsRepository.withInvoker((
        function,
        payload,
      ) async {
        rpcName = function;
        params = payload;
        return myPaymentDetailJson();
      });

      await repo.getMyPaymentDetail(groupId: 'g1', paymentId: 'p9');

      expect(rpcName, 'rpc_get_my_payment_detail');
      expect(params, {'p_group_id': 'g1', 'p_payment_id': 'p9'});
    });

    test('receipt calls rpc_get_my_receipt, never the officer RPC', () async {
      String? rpcName;
      Map<String, dynamic>? params;
      final repo = SupabaseMyPaymentsRepository.withInvoker((
        function,
        payload,
      ) async {
        rpcName = function;
        params = payload;
        return myReceiptJson();
      });

      await repo.getMyReceipt(groupId: 'g1', paymentId: 'p9');

      expect(rpcName, 'rpc_get_my_receipt');
      expect(params, {'p_group_id': 'g1', 'p_payment_id': 'p9'});
    });

    test('no payload ever carries a membership, user, or officer id', () async {
      final sent = <Map<String, dynamic>>[];
      final repo = SupabaseMyPaymentsRepository.withInvoker((
        function,
        payload,
      ) async {
        sent.add(payload);
        if (function == 'rpc_get_my_payment_detail') {
          return myPaymentDetailJson();
        }
        if (function == 'rpc_get_my_receipt') {
          return myReceiptJson();
        }
        return myPaymentsPageFixture().toJsonForTest();
      });

      await repo.getMyPayments(groupId: 'g1', limit: 20, offset: 0);
      await repo.getMyPaymentDetail(groupId: 'g1', paymentId: 'p1');
      await repo.getMyReceipt(groupId: 'g1', paymentId: 'p1');

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
    });
  });

  group('failure mapping', () {
    Future<MyPaymentsFailure> failureFrom(
      Object error, {
      bool detail = false,
      bool receipt = false,
    }) async {
      final repo = SupabaseMyPaymentsRepository.withInvoker((_, _) async {
        throw error;
      });
      try {
        if (detail) {
          await repo.getMyPaymentDetail(groupId: 'g1', paymentId: 'p1');
        } else if (receipt) {
          await repo.getMyReceipt(groupId: 'g1', paymentId: 'p1');
        } else {
          await repo.getMyPayments(groupId: 'g1', limit: 20, offset: 0);
        }
      } on MyPaymentsFailure catch (failure) {
        return failure;
      }
      fail('expected a MyPaymentsFailure');
    }

    test('42501 and 28000 map to notAuthorized', () async {
      for (final code in ['42501', '28000']) {
        final failure = await failureFrom(
          PostgrestException(message: 'denied', code: code),
        );
        expect(failure.type, MyPaymentsFailureType.notAuthorized);
      }
    });

    test('list 22023 on p_from_date maps to invalidDateRange', () async {
      final failure = await failureFrom(
        PostgrestException(
          message: 'p_from_date must not be after p_to_date',
          code: '22023',
        ),
      );
      expect(failure.type, MyPaymentsFailureType.invalidDateRange);
    });

    test(
      'detail 22023 maps to notFound (never another member\'s data)',
      () async {
        final failure = await failureFrom(
          PostgrestException(message: 'Payment not found', code: '22023'),
          detail: true,
        );
        expect(failure.type, MyPaymentsFailureType.notFound);
      },
    );

    test('receipt 22023 maps to notFound', () async {
      final failure = await failureFrom(
        PostgrestException(message: 'Payment not found', code: '22023'),
        receipt: true,
      );
      expect(failure.type, MyPaymentsFailureType.notFound);
    });

    test('a payload that breaks the contract maps to unexpected', () async {
      final repo = SupabaseMyPaymentsRepository.withInvoker(
        (_, _) async => {'items': 'not-a-list'},
      );
      expect(
        () => repo.getMyPayments(groupId: 'g1', limit: 20, offset: 0),
        throwsA(
          isA<MyPaymentsFailure>().having(
            (f) => f.type,
            'type',
            MyPaymentsFailureType.unexpected,
          ),
        ),
      );
    });

    test('a non-Postgrest error is a network failure', () async {
      final failure = await failureFrom(StateError('socket closed'));
      expect(failure.type, MyPaymentsFailureType.network);
    });
  });

  group('list model parsing', () {
    test('parses the live top-level keys', () {
      final page = myPaymentsPageFixture(
        items: [myPaymentItemJson()],
        hasMore: true,
        totalCount: 8,
      );
      final item = page.items.single;
      expect(item.paymentId, 'p1');
      expect(item.amount, 15000);
      expect(item.status, MyPaymentStatus.posted);
      expect(item.paymentMethod, MyPaymentMethod.cash);
      expect(item.receiptNumber, 'RCPT-0001');
      expect(item.allocationCount, 1);
      expect(page.pagination.totalCount, 8);
      expect(page.pagination.hasMore, isTrue);
    });

    test('an unknown status/method never throws — falls back to unknown', () {
      final item = MyPayment.fromJson(
        myPaymentItemJson(status: 'PENDING', paymentMethod: 'CRYPTO'),
      );
      expect(item.status, MyPaymentStatus.unknown);
      expect(item.paymentMethod, MyPaymentMethod.unknown);
    });

    test('amount is the backend value, never recomputed', () {
      final item = MyPayment.fromJson(myPaymentItemJson(amount: 62000));
      expect(item.amount, 62000);
    });
  });

  group('detail model parsing — allocation targets', () {
    test('every documented target type parses distinctly', () {
      const targets = [
        'CONTRIBUTION_COMPONENT',
        'LOAN_PRINCIPAL',
        'LOAN_INTEREST',
        'LOAN_PENALTY',
        'LOAN_PRINCIPAL_PREPAYMENT',
        'LOAN_RECOVERY_PRINCIPAL',
        'LOAN_RECOVERY_INTEREST',
        'LOAN_RECOVERY_PENALTY',
      ];
      final detail = myPaymentDetailFixture(
        allocations: [
          for (final t in targets)
            myPaymentAllocationJson(allocationId: t, targetType: t),
        ],
      );
      expect(detail.allocations, hasLength(targets.length));
      for (var i = 0; i < targets.length; i++) {
        expect(
          detail.allocations[i].targetType.wire,
          targets[i],
          reason: targets[i],
        );
      }
    });

    test('an unknown target type never throws and never drops the line', () {
      final detail = myPaymentDetailFixture(
        allocations: [
          myPaymentAllocationJson(targetType: 'SOMETHING_NEW_FUTURE'),
        ],
      );
      expect(
        detail.allocations.single.targetType,
        MyPaymentAllocationTargetType.unknown,
      );
    });

    test(
      'loan targets are distinguished from contribution via isLoanTarget',
      () {
        expect(
          MyPaymentAllocationTargetType.loanPrincipal.isLoanTarget,
          isTrue,
        );
        expect(
          MyPaymentAllocationTargetType.loanRecoveryPenalty.isLoanTarget,
          isTrue,
        );
        expect(
          MyPaymentAllocationTargetType.contributionComponent.isLoanTarget,
          isFalse,
        );
      },
    );

    test('contribution BASE and PENALTY components parse distinctly', () {
      final detail = myPaymentDetailFixture(
        amount: 18000,
        allocations: [
          myPaymentAllocationJson(
            allocationId: 'a1',
            amount: 15000,
            componentType: 'BASE',
          ),
          myPaymentAllocationJson(
            allocationId: 'a2',
            amount: 3000,
            componentType: 'PENALTY',
          ),
        ],
      );
      expect(detail.allocations[0].componentType, 'BASE');
      expect(detail.allocations[1].componentType, 'PENALTY');
      // Prompt §S: one payment amount, never duplicated across lines.
      expect(detail.payment.amount, 18000);
    });

    test(
      'a cross-domain payment keeps ONE amount with both domains present',
      () {
        final detail = myPaymentDetailFixture(
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
              loanProductName: 'Standard Loan',
            ),
          ],
        );
        expect(detail.payment.amount, 60000);
        expect(detail.allocations, hasLength(2));
        expect(
          detail.allocations[1].targetType,
          MyPaymentAllocationTargetType.loanPrincipal,
        );
        expect(detail.allocations[1].loanNumber, 'LN-001');
      },
    );

    test('loan metadata (number/product/installment) parses, no raw ids', () {
      final detail = myPaymentDetailFixture(
        allocations: [
          myPaymentAllocationJson(
            targetType: 'LOAN_INTEREST',
            loanNumber: 'LN-042',
            loanProductName: 'Emergency Loan',
            installmentNumber: 3,
            componentType: null,
            contributionTypeName: null,
            periodLabel: null,
            periodPurpose: null,
          ),
        ],
      );
      final allocation = detail.allocations.single;
      expect(allocation.loanNumber, 'LN-042');
      expect(allocation.loanProductName, 'Emergency Loan');
      expect(allocation.installmentNumber, 3);
    });
  });

  group('detail model parsing — amount/date/wallet/reversal', () {
    test(
      'canonical amount/date come from the payment object, not allocations',
      () {
        final detail = myPaymentDetailFixture(amount: 62000);
        expect(detail.payment.amount, 62000);
        expect(detail.payment.effectiveAt, DateTime.parse('2026-04-01'));
      },
    );

    test('a payment-created wallet credit parses as part of this detail', () {
      final detail = myPaymentDetailFixture(
        amount: 200000,
        allocations: [myPaymentAllocationJson(amount: 150000)],
        walletCredit: {
          'amount': 50000,
          'is_reversed': false,
          'reversed_at': null,
        },
      );
      expect(detail.walletCredit, isNotNull);
      expect(detail.walletCredit!.amount, 50000);
      expect(detail.walletCredit!.isReversed, isFalse);
      // Still one payment amount.
      expect(detail.payment.amount, 200000);
    });

    test(
      'a reversed wallet credit is distinguished via reverses_entry_id state',
      () {
        final detail = myPaymentDetailFixture(
          walletCredit: {
            'amount': 20000,
            'is_reversed': true,
            'reversed_at': '2026-04-08',
          },
        );
        expect(detail.walletCredit!.isReversed, isTrue);
        expect(detail.walletCredit!.reversedAt, DateTime.parse('2026-04-08'));
      },
    );

    test('no wallet credit is null, never a fabricated zero entry', () {
      final detail = myPaymentDetailFixture();
      expect(detail.walletCredit, isNull);
    });

    test('a reversed payment stays visible with status and reason', () {
      final detail = myPaymentDetailFixture(
        status: 'REVERSED',
        reversedAt: '2026-04-09T10:00:00Z',
        reversalReason: 'Entered in error',
      );
      expect(detail.payment.status, MyPaymentStatus.reversed);
      expect(detail.payment.reversalReason, 'Entered in error');
      expect(detail.payment.reversedAt, isNotNull);
    });
  });

  group('receipt model parsing', () {
    test('parses the flat receipt shape', () {
      final receipt = myReceiptFixture();
      expect(receipt.receiptNumber, 'RCPT-0001');
      expect(receipt.amount, 15000);
      expect(receipt.status, MyPaymentStatus.posted);
      expect(receipt.groupName, 'Umoja Demo');
      expect(receipt.memberDisplayName, 'Test Member');
    });

    test('a reversed receipt carries status and reason, same as detail', () {
      final receipt = myReceiptFixture(
        status: 'REVERSED',
        reversalReason: 'Entered in error',
      );
      expect(receipt.status, MyPaymentStatus.reversed);
      expect(receipt.reversalReason, 'Entered in error');
    });

    test('receipt wallet credit parses the same shape as detail', () {
      final receipt = myReceiptFixture(
        walletCredit: {
          'amount': 5000,
          'is_reversed': false,
          'reversed_at': null,
        },
      );
      expect(receipt.walletCredit!.amount, 5000);
    });
  });
}

extension on MyPaymentsPage {
  /// Round-trip helper: rebuilds the JSON map a fixture page was parsed
  /// from, so repository tests can feed the same shape back through.
  Map<String, dynamic> toJsonForTest() => {
    'items': const <Map<String, dynamic>>[],
    'pagination': {
      'limit': pagination.limit,
      'offset': pagination.offset,
      'total_count': pagination.totalCount,
      'has_more': pagination.hasMore,
    },
  };
}
