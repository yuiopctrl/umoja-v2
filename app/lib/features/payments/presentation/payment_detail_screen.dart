import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../domain/payment_detail.dart';
import '../providers/payment_detail_provider.dart';
import 'widgets/payment_labels.dart';

/// `/payments/:paymentId`: full payment detail — metadata, member,
/// financial account, allocations, wallet credit, cashbook linkage,
/// reversal status. Never reconstructs totals client-side.
class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detailAsync = ref.watch(paymentDetailProvider(paymentId));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canReverse = membership?.hasPermission('payment.reverse') ?? false;
    final canViewReceipt =
        membership?.hasPermission('payment.receipt.view') ?? false;

    return UmojaPage(
      title: l10n.paymentDetailTitle,
      maxWidth: 700,
      backTo: AppRoutes.paymentsList,
      backLabel: l10n.paymentsTitle,
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(paymentDetailProvider(paymentId)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          canReverse: canReverse,
          canViewReceipt: canViewReceipt,
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.canReverse,
    required this.canViewReceipt,
  });

  final PaymentDetail detail;
  final bool canReverse;
  final bool canViewReceipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                detail.memberDisplayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            UmojaStatusBadge(
              label: paymentStatusLabel(context.l10n, detail.status),
              semantic: detail.isReversed
                  ? UmojaStatusSemantic.neutral
                  : UmojaStatusSemantic.success,
            ),
          ],
        ),
        Text(
          detail.receiptNumber,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueRow(
                label: l10n.paymentAmountLabel,
                value: formatAmount(detail.amount),
              ),
              _KeyValueRow(
                label: l10n.recordPaymentDateLabel,
                value: formatKiswahiliDate(detail.effectiveAt),
              ),
              _KeyValueRow(
                label: l10n.recordPaymentMethodLabel,
                value: paymentMethodLabel(l10n, detail.paymentMethod),
              ),
              _KeyValueRow(
                label: l10n.recordPaymentAccountLabel,
                value: detail.financialAccountName,
              ),
              if (detail.externalReference != null)
                _KeyValueRow(
                  label: l10n.recordPaymentReferenceLabel,
                  value: detail.externalReference!,
                ),
              if (detail.walletCreditAmount != null)
                _KeyValueRow(
                  label: l10n.paymentPreviewWalletRemainingLabel,
                  value: formatAmount(detail.walletCreditAmount!),
                ),
              if (detail.isReversed && detail.reversalReason != null)
                _KeyValueRow(
                  label: l10n.reversalReasonLabel,
                  value: detail.reversalReason!,
                ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaSection(
          title: l10n.paymentAllocationsTitle,
          child: Column(
            children: [
              for (final line in detail.allocations)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              obligationContextLabel(
                                contributionTypeName: line.contributionTypeName,
                                periodLabel: line.periodLabel,
                                periodPurpose: line.periodPurpose,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              contributionComponentTypeLabel(
                                l10n,
                                line.componentType,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(formatAmount(line.amount)),
                    ],
                  ),
                ),
              if (detail.allocations.isEmpty)
                Text(l10n.paymentPreviewNoOutstandingMessage),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        Wrap(
          spacing: UmojaSpacing.md,
          runSpacing: UmojaSpacing.md,
          children: [
            if (canViewReceipt)
              OutlinedButton.icon(
                key: const Key('paymentDetailViewReceiptAction'),
                onPressed: () => context.push(
                  AppRoutes.paymentReceiptPath(detail.paymentId),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(l10n.viewReceiptAction),
              ),
            if (canReverse && !detail.isReversed)
              UmojaDangerButton(
                key: const Key('paymentDetailReverseAction'),
                label: l10n.reversePaymentAction,
                onPressed: () => context.push(
                  AppRoutes.paymentReversePath(detail.paymentId),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: UmojaSpacing.md),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
