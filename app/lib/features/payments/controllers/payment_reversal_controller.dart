import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../contributions/providers/contribution_charge_detail_provider.dart';
import '../../contributions/providers/contribution_period_charges_provider.dart';
import '../../contributions/providers/member_contribution_summary_provider.dart';
import '../../financial_accounts/providers/financial_account_detail_provider.dart';
import '../../financial_accounts/providers/financial_account_entries_provider.dart';
import '../data/payment_failure.dart';
import '../providers/member_contribution_statement_provider.dart';
import '../providers/member_wallet_provider.dart';
import '../providers/payment_detail_provider.dart';
import '../providers/payment_repository_provider.dart';
import '../providers/payments_list_provider.dart';
import '../providers/receipt_provider.dart';

final _log = Logger('PaymentReversalController');

class PaymentReversalState {
  const PaymentReversalState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;
  final PaymentFailureType? errorType;
}

/// Reverses the books-recorded receipt of cash for one payment
/// (section 46-48) — never edits/deletes the original payment or its
/// allocations. Strong, specific error surfacing for the two known
/// business-rule blocks (already reversed / wallet credit consumed) —
/// never collapsed to a generic failure message.
class PaymentReversalController extends Notifier<PaymentReversalState> {
  @override
  PaymentReversalState build() => const PaymentReversalState();

  Future<bool> reverse({
    required String groupId,
    required String paymentId,
    required String financialAccountId,
    required String reversalReason,
  }) async {
    if (state.isSubmitting) return false;

    state = const PaymentReversalState(isSubmitting: true);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .reversePayment(
            groupId: groupId,
            paymentId: paymentId,
            reversalReason: reversalReason,
          );

      ref.invalidate(paymentsListProvider);
      ref.invalidate(paymentDetailProvider(paymentId));
      ref.invalidate(receiptProvider(paymentId));
      ref.invalidate(memberContributionSummaryProvider);
      ref.invalidate(memberContributionStatementProvider);
      ref.invalidate(contributionChargeDetailProvider);
      ref.invalidate(contributionPeriodChargesProvider);
      ref.invalidate(memberWalletEntriesProvider);
      ref.invalidate(financialAccountDetailProvider(financialAccountId));
      ref.invalidate(financialAccountEntriesProvider);

      state = const PaymentReversalState();
      return true;
    } on PaymentFailure catch (error) {
      state = PaymentReversalState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to reverse payment', error, stackTrace);
      state = const PaymentReversalState(
        errorType: PaymentFailureType.unexpected,
      );
      return false;
    }
  }
}

final paymentReversalControllerProvider =
    NotifierProvider<PaymentReversalController, PaymentReversalState>(
      PaymentReversalController.new,
    );
