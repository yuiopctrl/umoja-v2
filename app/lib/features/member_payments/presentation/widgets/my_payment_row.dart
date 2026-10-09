import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../domain/my_payment.dart';
import 'my_payment_labels.dart';

/// One flat, tappable payment row (Prompt 09G-B6-C §I/§J). Shows the
/// backend's canonical amount and economic date exactly as returned —
/// never a derived sum of allocations. Allocations are never listed
/// here; [item.allocationCount] is a breakdown-line count only, not a
/// second payment indicator.
class MyPaymentRow extends StatelessWidget {
  const MyPaymentRow({super.key, required this.item, required this.onTap});

  final MyPayment item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      key: Key('myPaymentRow_${item.paymentId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAmount(item.amount),
                        key: Key('myPaymentAmount_${item.paymentId}'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(formatMyPaymentDate(item.effectiveAt), style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: UmojaSpacing.sm),
                UmojaStatusBadge(
                  key: Key('myPaymentStatus_${item.paymentId}'),
                  label: myPaymentStatusLabel(l10n, item.status),
                  semantic: myPaymentStatusSemantic(item.status),
                ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              myPaymentMethodLabel(l10n, item.paymentMethod),
              style: theme.textTheme.bodyMedium,
            ),
            if (item.receiptNumber != null) ...[
              const SizedBox(height: UmojaSpacing.xs),
              Text(
                l10n.myPaymentsReceiptLabel(item.receiptNumber!),
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
