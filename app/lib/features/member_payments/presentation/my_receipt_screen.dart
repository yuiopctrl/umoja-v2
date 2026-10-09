import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/member_child_scaffold.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../data/my_payments_failure.dart';
import '../domain/my_payment.dart';
import '../providers/my_receipt_provider.dart';
import 'my_payments_screen.dart' show myPaymentsFailureMessage;
import 'widgets/my_payment_labels.dart';

/// `/me/payments/:paymentId/receipt`: a member-safe, VIEW-ONLY receipt
/// for one of the caller's OWN payments (Prompt 09G-B6-C §W/§X). Backed
/// only by rpc_get_my_receipt — never the officer rpc_get_receipt, and
/// never gated on payment.receipt.view. No PDF/print/share/thermal
/// control exists here; B6 receipt scope is view only. A reversed
/// payment's receipt remains viewable but is never shown as if it were
/// still an active, valid receipt.
class MyReceiptScreen extends ConsumerWidget {
  const MyReceiptScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final receiptAsync = ref.watch(myReceiptProvider(paymentId));

    return MemberChildScaffold(
      title: l10n.myPaymentsReceiptTitle,
      scrollable: false,
      body: receiptAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: _messageFor(context, error),
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myReceiptProvider(paymentId)),
        ),
        data: (receipt) => _ReceiptContent(receipt: receipt),
      ),
    );
  }
}

String _messageFor(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is MyPaymentsFailure) {
    return myPaymentsFailureMessage(l10n, error, isDetail: true);
  }
  return l10n.myPaymentsReceiptLoadFailedMessage;
}

class _ReceiptContent extends StatelessWidget {
  const _ReceiptContent({required this.receipt});

  final MyReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isReversed = receipt.status == MyPaymentStatus.reversed;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UmojaCard(
            key: const Key('myReceiptCard'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receipt.groupName,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            receipt.memberNumber == null
                                ? receipt.memberDisplayName
                                : '${receipt.memberDisplayName} '
                                      '(${receipt.memberNumber})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    UmojaStatusBadge(
                      key: const Key('myReceiptStatus'),
                      label: myPaymentStatusLabel(l10n, receipt.status),
                      semantic: myPaymentStatusSemantic(receipt.status),
                    ),
                  ],
                ),
                const Divider(height: UmojaSpacing.xl),
                if (receipt.receiptNumber != null)
                  _ReceiptRow(
                    label: l10n.myPaymentsReceiptNumberLabel,
                    value: receipt.receiptNumber!,
                  ),
                _ReceiptRow(
                  label: l10n.myPaymentsDateLabel,
                  value: formatMyPaymentDate(receipt.effectiveAt),
                ),
                _ReceiptRow(
                  label: l10n.myPaymentsAmountLabel,
                  value: formatAmount(receipt.amount),
                  emphasized: true,
                ),
                _ReceiptRow(
                  label: l10n.myPaymentsMethodLabel,
                  value: myPaymentMethodLabel(l10n, receipt.paymentMethod),
                ),
                if (receipt.externalReference != null &&
                    receipt.externalReference!.isNotEmpty)
                  _ReceiptRow(
                    label: l10n.myPaymentsExternalReferenceLabel,
                    value: receipt.externalReference!,
                  ),
                if (isReversed &&
                    receipt.reversalReason != null &&
                    receipt.reversalReason!.isNotEmpty) ...[
                  const Divider(height: UmojaSpacing.xl),
                  Text(
                    l10n.myPaymentsReversedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: UmojaSpacing.xs),
                  Text(
                    receipt.reversalReason!,
                    key: const Key('myReceiptReversalReason'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (receipt.allocations.isNotEmpty) ...[
            const SizedBox(height: UmojaSpacing.xl),
            Text(
              l10n.myPaymentsBreakdownTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaCard(
              key: const Key('myReceiptAllocationsCard'),
              padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < receipt.allocations.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _AllocationRow(allocation: receipt.allocations[i]),
                  ],
                ],
              ),
            ),
          ],
          if (receipt.walletCredit != null) ...[
            const SizedBox(height: UmojaSpacing.xl),
            Text(
              l10n.myPaymentsWalletCreditTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaCard(
              key: const Key('myReceiptWalletCreditCard'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatAmount(receipt.walletCredit!.amount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (receipt.walletCredit!.isReversed)
                    UmojaStatusBadge(
                      label: l10n.myPaymentsReversedTitle,
                      semantic: UmojaStatusSemantic.neutral,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: UmojaSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.allocation});

  final MyPaymentAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isContribution =
        allocation.targetType ==
        MyPaymentAllocationTargetType.contributionComponent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isContribution
                  ? myPaymentComponentLabel(l10n, allocation.componentType)
                  : myPaymentAllocationTargetLabel(l10n, allocation.targetType),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            formatAmount(allocation.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
