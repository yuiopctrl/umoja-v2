import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../contributions/providers/contribution_charge_detail_provider.dart';
import '../../contributions/providers/contribution_period_charges_provider.dart';
import '../../contributions/providers/member_contribution_summary_provider.dart';
import '../data/payment_failure.dart';
import '../providers/member_contribution_statement_provider.dart';
import '../providers/member_wallet_provider.dart';
import '../providers/payment_repository_provider.dart';

final _log = Logger('WalletAllocationController');

class WalletAllocationState {
  const WalletAllocationState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;
  final PaymentFailureType? errorType;
}

/// Posts a manual wallet allocation (section 33) — atomic, creates no
/// payment/receipt/cashbook entry (invariant C). Never posts before an
/// explicit confirm; the preceding preview step never calls this.
class WalletAllocationController extends Notifier<WalletAllocationState> {
  @override
  WalletAllocationState build() => const WalletAllocationState();

  Future<bool> allocate({
    required String groupId,
    required String membershipId,
    required double amount,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;

    state = const WalletAllocationState(isSubmitting: true);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .allocateMemberWallet(
            groupId: groupId,
            membershipId: membershipId,
            amount: amount,
            idempotencyKey: idempotencyKey,
          );

      ref.invalidate(memberWalletEntriesProvider);
      ref.invalidate(memberContributionSummaryProvider);
      ref.invalidate(memberContributionStatementProvider);
      ref.invalidate(contributionChargeDetailProvider);
      ref.invalidate(contributionPeriodChargesProvider);

      state = const WalletAllocationState();
      return true;
    } on PaymentFailure catch (error) {
      state = WalletAllocationState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to allocate member wallet', error, stackTrace);
      state = const WalletAllocationState(
        errorType: PaymentFailureType.unexpected,
      );
      return false;
    }
  }
}

final walletAllocationControllerProvider =
    NotifierProvider<WalletAllocationController, WalletAllocationState>(
      WalletAllocationController.new,
    );
