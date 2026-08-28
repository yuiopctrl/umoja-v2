import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../contributions/providers/contribution_charge_detail_provider.dart';
import '../../contributions/providers/contribution_period_charges_provider.dart';
import '../../contributions/providers/contribution_periods_list_provider.dart';
import '../../contributions/providers/member_contribution_summary_provider.dart';
import '../../financial_accounts/providers/financial_account_detail_provider.dart';
import '../../financial_accounts/providers/financial_account_entries_provider.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../data/payment_failure.dart';
import '../domain/payment_post_result.dart';
import '../providers/member_contribution_statement_provider.dart';
import '../providers/member_wallet_provider.dart';
import '../providers/payment_repository_provider.dart';
import '../providers/payments_list_provider.dart';

final _log = Logger('PaymentPostController');

class PaymentPostState {
  const PaymentPostState({
    this.isSubmitting = false,
    this.errorType,
    this.result,
  });

  final bool isSubmitting;
  final PaymentFailureType? errorType;
  final PaymentPostResult? result;
}

/// Posts an external payment (section 42) — the only path from
/// preview to an atomic payment + allocations + optional wallet credit
/// + exactly one cashbook INFLOW. Never posts before an explicit
/// confirm; the preceding preview step never calls this.
///
/// On success, invalidates every provider whose displayed totals this
/// payment could have changed — the whole-family invalidation pattern
/// established for 08A (never a single specific key, since this
/// controller has no reason to know every screen currently mounted).
class PaymentPostController extends Notifier<PaymentPostState> {
  @override
  PaymentPostState build() => const PaymentPostState();

  Future<bool> post({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
    required DateTime effectiveAt,
    required String paymentMethod,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;

    state = const PaymentPostState(isSubmitting: true);
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .postPayment(
            groupId: groupId,
            membershipId: membershipId,
            financialAccountId: financialAccountId,
            amount: amount,
            effectiveAt: effectiveAt,
            paymentMethod: paymentMethod,
            externalReference: externalReference,
            notes: notes,
            idempotencyKey: idempotencyKey,
          );

      ref.invalidate(paymentsListProvider);
      ref.invalidate(memberContributionSummaryProvider);
      ref.invalidate(memberContributionStatementProvider);
      ref.invalidate(contributionChargeDetailProvider);
      ref.invalidate(contributionPeriodChargesProvider);
      ref.invalidate(contributionPeriodsListProvider);
      ref.invalidate(memberWalletEntriesProvider);
      ref.invalidate(financialAccountDetailProvider(financialAccountId));
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialAccountEntriesProvider);

      state = PaymentPostState(result: result);
      return true;
    } on PaymentFailure catch (error) {
      state = PaymentPostState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to post payment', error, stackTrace);
      state = const PaymentPostState(errorType: PaymentFailureType.unexpected);
      return false;
    }
  }
}

final paymentPostControllerProvider =
    NotifierProvider<PaymentPostController, PaymentPostState>(
      PaymentPostController.new,
    );
