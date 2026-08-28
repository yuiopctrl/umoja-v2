import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/payment_failure.dart';
import '../domain/wallet_allocation_preview.dart';
import '../providers/payment_repository_provider.dart';

final _log = Logger('WalletAllocationPreviewController');

class WalletAllocationPreviewState {
  const WalletAllocationPreviewState({
    this.isLoading = false,
    this.preview,
    this.errorType,
  });

  final bool isLoading;
  final WalletAllocationPreview? preview;
  final PaymentFailureType? errorType;
}

/// Drives the non-posting preview step of the wallet-allocation flow
/// (section 32) — no cash-account selection, no receipt, no external
/// payment.
class WalletAllocationPreviewController
    extends Notifier<WalletAllocationPreviewState> {
  @override
  WalletAllocationPreviewState build() => const WalletAllocationPreviewState();

  Future<void> preview({
    required String groupId,
    required String membershipId,
    required double amount,
  }) async {
    state = const WalletAllocationPreviewState(isLoading: true);
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .previewWalletAllocation(
            groupId: groupId,
            membershipId: membershipId,
            amount: amount,
          );
      state = WalletAllocationPreviewState(preview: result);
    } on PaymentFailure catch (error) {
      state = WalletAllocationPreviewState(errorType: error.type);
    } catch (error, stackTrace) {
      _log.warning('Failed to preview wallet allocation', error, stackTrace);
      state = const WalletAllocationPreviewState(
        errorType: PaymentFailureType.unexpected,
      );
    }
  }

  void reset() => state = const WalletAllocationPreviewState();
}

final walletAllocationPreviewControllerProvider =
    NotifierProvider<
      WalletAllocationPreviewController,
      WalletAllocationPreviewState
    >(WalletAllocationPreviewController.new);
