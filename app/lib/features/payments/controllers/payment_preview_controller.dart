import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/payment_failure.dart';
import '../domain/payment_allocation_preview.dart';
import '../providers/payment_repository_provider.dart';

final _log = Logger('PaymentPreviewController');

class PaymentPreviewState {
  const PaymentPreviewState({
    this.isLoading = false,
    this.preview,
    this.errorType,
  });

  final bool isLoading;
  final PaymentAllocationPreview? preview;
  final PaymentFailureType? errorType;
}

/// Drives the non-posting preview step of the Record Payment flow
/// (section 41/58) — never posts anything; `rpc_post_payment` computes
/// its own plan independently using the identical server-side helper.
class PaymentPreviewController extends Notifier<PaymentPreviewState> {
  @override
  PaymentPreviewState build() => const PaymentPreviewState();

  Future<void> preview({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
    required DateTime effectiveAt,
  }) async {
    state = const PaymentPreviewState(isLoading: true);
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .previewPaymentAllocation(
            groupId: groupId,
            membershipId: membershipId,
            financialAccountId: financialAccountId,
            amount: amount,
            effectiveAt: effectiveAt,
          );
      state = PaymentPreviewState(preview: result);
    } on PaymentFailure catch (error) {
      state = PaymentPreviewState(errorType: error.type);
    } catch (error, stackTrace) {
      _log.warning('Failed to preview payment allocation', error, stackTrace);
      state = const PaymentPreviewState(
        errorType: PaymentFailureType.unexpected,
      );
    }
  }

  void reset() => state = const PaymentPreviewState();
}

final paymentPreviewControllerProvider =
    NotifierProvider<PaymentPreviewController, PaymentPreviewState>(
      PaymentPreviewController.new,
    );
