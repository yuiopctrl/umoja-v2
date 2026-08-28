import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../providers/receipt_provider.dart';
import 'widgets/payment_labels.dart';

/// `/payments/:paymentId/receipt`: a view-only receipt (section 62) —
/// always exactly one per payment, remains valid and viewable after
/// later debt changes, and after a reversal (clearly labeled, never
/// hidden).
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final receiptAsync = ref.watch(receiptProvider(paymentId));

    return UmojaPage(
      title: l10n.receiptTitle,
      maxWidth: 600,
      backTo: AppRoutes.paymentDetailPath(paymentId),
      backLabel: l10n.paymentDetailTitle,
      body: receiptAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(receiptProvider(paymentId)),
        ),
        data: (receipt) => UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      receipt.receiptNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (receipt.isReversed) ...[
                    const SizedBox(width: UmojaSpacing.md),
                    UmojaStatusBadge(
                      label: paymentStatusLabel(l10n, receipt.status),
                      semantic: UmojaStatusSemantic.neutral,
                    ),
                  ],
                ],
              ),
              const Divider(height: UmojaSpacing.xxl),
              _Row(
                label: l10n.receiptMemberLabel,
                value: receipt.memberDisplayName,
              ),
              _Row(
                label: l10n.recordPaymentDateLabel,
                value: formatKiswahiliDate(receipt.effectiveAt),
              ),
              _Row(
                label: l10n.recordPaymentMethodLabel,
                value: paymentMethodLabel(l10n, receipt.paymentMethod),
              ),
              _Row(
                label: l10n.recordPaymentAccountLabel,
                value: receipt.financialAccountName,
              ),
              const Divider(height: UmojaSpacing.xxl),
              Text(
                l10n.paymentPreviewWillSettleLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final line in receipt.allocations)
                Padding(
                  padding: const EdgeInsets.only(top: UmojaSpacing.xs),
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
              const Divider(height: UmojaSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.paymentAmountLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    formatAmount(receipt.amount),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
