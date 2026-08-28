import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../controllers/payment_reversal_controller.dart';
import '../providers/payment_detail_provider.dart';

/// `/payments/:paymentId/reverse`: Payment Detail → Reverse Payment →
/// mandatory reason → confirmation → atomic backend reversal (section
/// 63). Strong warning copy; there is no Edit/Delete Payment anywhere.
class PaymentReversalScreen extends ConsumerStatefulWidget {
  const PaymentReversalScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentReversalScreen> createState() =>
      _PaymentReversalScreenState();
}

class _PaymentReversalScreenState extends ConsumerState<PaymentReversalScreen> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm(String groupId, String financialAccountId) async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(paymentReversalControllerProvider.notifier)
        .reverse(
          groupId: groupId,
          paymentId: widget.paymentId,
          financialAccountId: financialAccountId,
          reversalReason: reason,
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reversePaymentSuccessMessage)),
      );
      context.go(AppRoutes.paymentDetailPath(widget.paymentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detailAsync = ref.watch(paymentDetailProvider(widget.paymentId));
    final reversalState = ref.watch(paymentReversalControllerProvider);

    return UmojaPage(
      title: l10n.reversePaymentTitle,
      maxWidth: 600,
      backTo: AppRoutes.paymentDetailPath(widget.paymentId),
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(paymentDetailProvider(widget.paymentId)),
        ),
        data: (detail) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UmojaCard(
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: UmojaSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.reversePaymentWarningMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('paymentReversalReasonField'),
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.reversalReasonLabel),
            ),
            if (reversalState.errorType != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                paymentFailureMessage(context.l10n, reversalState.errorType!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaDangerButton(
              key: const Key('paymentReversalConfirmAction'),
              label: l10n.reversePaymentConfirmAction,
              expand: true,
              isLoading: reversalState.isSubmitting,
              onPressed: () =>
                  _confirm(detail.membershipId, detail.financialAccountId),
            ),
          ],
        ),
      ),
    );
  }
}
