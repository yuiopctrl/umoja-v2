import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/payments/domain/payment_detail.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

/// Prompt 09E-UAT-BLOCKER-03: `rpc_get_payment_detail` returns
/// `due_date: null` for a LOAN_PRINCIPAL_PREPAYMENT allocation row —
/// deliberately, since a 09E lump-sum principal prepayment is never
/// tied to a single installment (the locked invariant: it must never
/// impersonate an ordinary installment allocation). `PaymentDetail`/
/// `PaymentAllocationLine.fromJson` previously assumed every
/// allocation's `due_date` was non-null (`json['due_date'] as
/// String`), crashing with `type 'Null' is not a subtype of type
/// 'String'` the first time a physical device opened Payment Details
/// for a prepayment payment. These tests parse the exact realistic
/// payload shapes `rpc_get_payment_detail` returns (see
/// `20260909096000_fix_allocation_line_ordering.sql`), never a
/// Dart-constructed shortcut, so they actually exercise `fromJson`.
Map<String, dynamic> _basePaymentJson({
  required String paymentId,
  required List<Map<String, dynamic>> allocations,
  String status = 'POSTED',
  double amount = 100000,
  String? reversedAt,
  String? reversalReason,
  Map<String, dynamic>? walletCredit,
}) {
  return {
    'payment_id': paymentId,
    'membership_id': 'm1',
    'member_display_name': 'Amina Juma',
    'member_number': 'UMJ-2026-0001',
    'financial_account_id': 'acct-1',
    'financial_account_name': 'Main Cash',
    'amount': amount,
    'effective_at': '2026-09-01',
    'payment_method': 'CASH',
    'external_reference': null,
    'notes': null,
    'receipt_number': 'RCT-0001',
    'status': status,
    'created_at': '2026-09-01T09:00:00Z',
    'reversed_at': reversedAt,
    'reversed_by': reversedAt == null ? null : 'u-admin',
    'reversal_reason': reversalReason,
    'allocations': allocations,
    'wallet_credit': walletCredit,
    'cashbook_entry': status == 'REVERSED'
        ? null
        : {'entry_id': 'entry-1', 'entry_type': 'INFLOW', 'amount': amount},
  };
}

void main() {
  test('1: ordinary contribution payment parses with no null cast', () {
    final json = _basePaymentJson(
      paymentId: 'p1',
      allocations: [
        {
          'allocation_id': 'a1',
          'allocation_target_type': 'CONTRIBUTION_COMPONENT',
          'charge_id': 'charge-1',
          'component_id': 'comp-1',
          'component_type': 'BASE',
          'due_date': '2026-09-01',
          'amount': 20000,
          'contribution_type_name': 'Monthly Savings',
          'period_label': 'September 2026',
          'period_purpose': 'NORMAL',
          'loan_account_id': null,
          'loan_number': null,
          'loan_product_name': null,
          'loan_installment_id': null,
          'installment_number': null,
          'loan_penalty_charge_id': null,
        },
      ],
    );

    final detail = PaymentDetail.fromJson(json);

    expect(detail.allocations, hasLength(1));
    final line = detail.allocations.single;
    expect(line.obligationKind, 'CONTRIBUTION');
    expect(line.isPrincipalPrepayment, isFalse);
    expect(line.dueDate, DateTime.parse('2026-09-01'));
    expect(line.amount, 20000.0);
    expect(line.contributionTypeName, 'Monthly Savings');
  });

  test('2: normal loan repayment parses with no null cast', () {
    final json = _basePaymentJson(
      paymentId: 'p2',
      amount: 60000,
      allocations: [
        {
          'allocation_id': 'a1',
          'allocation_target_type': 'LOAN_INTEREST',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_INTEREST',
          'due_date': '2026-09-01',
          'amount': 10000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-1',
          'installment_number': 1,
          'loan_penalty_charge_id': null,
        },
        {
          'allocation_id': 'a2',
          'allocation_target_type': 'LOAN_PRINCIPAL',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_PRINCIPAL',
          'due_date': '2026-09-01',
          'amount': 50000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-1',
          'installment_number': 1,
          'loan_penalty_charge_id': null,
        },
      ],
    );

    final detail = PaymentDetail.fromJson(json);

    expect(detail.allocations, hasLength(2));
    expect(detail.allocations[0].isLoanInterest, isTrue);
    expect(detail.allocations[0].dueDate, DateTime.parse('2026-09-01'));
    expect(detail.allocations[1].obligationKind, 'LOAN_PRINCIPAL');
    expect(detail.allocations[1].isPrincipalPrepayment, isFalse);
    expect(detail.allocations[1].installmentNumber, 1);
  });

  test('3: principal prepayment parses with a null due_date and is never a '
      'fake installment association', () {
    final json = _basePaymentJson(
      paymentId: 'p3',
      amount: 200000,
      allocations: [
        {
          'allocation_id': 'a1',
          'allocation_target_type': 'LOAN_PRINCIPAL_PREPAYMENT',
          'charge_id': null,
          'component_id': null,
          // Backend coalesce fallback when no contribution component
          // join matches: pa.allocation_target_type itself.
          'component_type': 'LOAN_PRINCIPAL_PREPAYMENT',
          // The exact field that crashed physical-device UAT —
          // legitimately null because a prepayment is never tied to
          // one installment.
          'due_date': null,
          'amount': 200000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          // Deliberately null — a prepayment must never impersonate
          // an ordinary installment allocation.
          'loan_installment_id': null,
          'installment_number': null,
          'loan_penalty_charge_id': null,
        },
      ],
    );

    // The actual regression: this must not throw
    // "type 'Null' is not a subtype of type 'String'".
    final detail = PaymentDetail.fromJson(json);

    expect(detail.allocations, hasLength(1));
    final line = detail.allocations.single;
    expect(line.isPrincipalPrepayment, isTrue);
    expect(line.dueDate, isNull);
    expect(line.loanInstallmentId, isNull);
    expect(line.installmentNumber, isNull);
    expect(line.loanNumber, 'STD-LN-2026-0001');
    expect(line.loanProductName, 'Standard Loan');
    expect(line.amount, 200000.0);
  });

  test('4: early settlement parses principal/interest/penalty distinctly', () {
    final json = _basePaymentJson(
      paymentId: 'p4',
      amount: 133000,
      allocations: [
        {
          'allocation_id': 'a1',
          'allocation_target_type': 'LOAN_PENALTY',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_PENALTY',
          'due_date': '2026-08-01',
          'amount': 3000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-1',
          'installment_number': 1,
          'loan_penalty_charge_id': 'penalty-1',
        },
        {
          'allocation_id': 'a2',
          'allocation_target_type': 'LOAN_INTEREST',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_INTEREST',
          'due_date': '2026-08-01',
          'amount': 10000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-1',
          'installment_number': 1,
          'loan_penalty_charge_id': null,
        },
        // Early settlement pays PRINCIPAL for every remaining
        // installment, regardless of due date — a second installment's
        // principal row, never merged into the first's group.
        {
          'allocation_id': 'a3',
          'allocation_target_type': 'LOAN_PRINCIPAL',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_PRINCIPAL',
          'due_date': '2026-08-01',
          'amount': 50000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-1',
          'installment_number': 1,
          'loan_penalty_charge_id': null,
        },
        {
          'allocation_id': 'a4',
          'allocation_target_type': 'LOAN_PRINCIPAL',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_PRINCIPAL',
          'due_date': '2026-09-01',
          'amount': 70000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-2',
          'installment_number': 2,
          'loan_penalty_charge_id': null,
        },
      ],
    );

    final detail = PaymentDetail.fromJson(json);

    expect(detail.allocations, hasLength(4));
    expect(detail.allocations[0].isLoanPenalty, isTrue);
    expect(detail.allocations[1].isLoanInterest, isTrue);
    expect(detail.allocations[2].obligationKind, 'LOAN_PRINCIPAL');
    expect(detail.allocations[2].installmentNumber, 1);
    expect(detail.allocations[3].installmentNumber, 2);
    // Never merged into one misleading generic income line — every
    // component keeps its own exact amount.
    expect(detail.allocations[0].amount, 3000.0);
    expect(detail.allocations[1].amount, 10000.0);
    expect(detail.allocations[2].amount, 50000.0);
    expect(detail.allocations[3].amount, 70000.0);
  });

  test('5: reversed payment parses with reversal state intact', () {
    final json = _basePaymentJson(
      paymentId: 'p5',
      status: 'REVERSED',
      reversedAt: '2026-09-02T10:00:00Z',
      reversalReason: 'entered in error',
      allocations: [
        {
          'allocation_id': 'a1',
          'allocation_target_type': 'LOAN_PRINCIPAL',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_PRINCIPAL',
          'due_date': '2026-09-01',
          'amount': 100000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': 'inst-1',
          'installment_number': 1,
          'loan_penalty_charge_id': null,
        },
      ],
    );

    final detail = PaymentDetail.fromJson(json);

    expect(detail.status, 'REVERSED');
    expect(detail.isReversed, isTrue);
    expect(detail.reversedAt, DateTime.parse('2026-09-02T10:00:00Z'));
    expect(detail.reversalReason, 'entered in error');
    expect(detail.hasCashbookEntry, isFalse);
  });

  testWidgets('Payment Details renders Principal Prepayment for a prepayment '
      'payment — no fake installment reference, no crash', (tester) async {
    final json = _basePaymentJson(
      paymentId: 'p3',
      amount: 200000,
      allocations: [
        {
          'allocation_id': 'a1',
          'allocation_target_type': 'LOAN_PRINCIPAL_PREPAYMENT',
          'charge_id': null,
          'component_id': null,
          'component_type': 'LOAN_PRINCIPAL_PREPAYMENT',
          'due_date': null,
          'amount': 200000,
          'contribution_type_name': null,
          'period_label': null,
          'period_purpose': null,
          'loan_account_id': 'loan-1',
          'loan_number': 'STD-LN-2026-0001',
          'loan_product_name': 'Standard Loan',
          'loan_installment_id': null,
          'installment_number': null,
          'loan_penalty_charge_id': null,
        },
      ],
    );

    final fakeRepo = FakePaymentRepository()
      ..nextPaymentDetail = PaymentDetail.fromJson(json);

    final router = await pumpPaymentsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.paymentDetailPath('p3'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Principal Prepayment'), findsOneWidget);
    expect(find.text('STD-LN-2026-0001'), findsOneWidget);
    // Never a fabricated "Installment 1" / due-date line for a
    // payment that was never tied to a specific installment.
    expect(find.textContaining('Installment'), findsNothing);
  });
}
