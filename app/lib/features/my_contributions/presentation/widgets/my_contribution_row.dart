import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../domain/my_contribution.dart';
import 'my_contribution_labels.dart';

/// One flat, tappable contribution row (Prompt 09G-B4-C §I/§M). Shows
/// the backend's canonical net assessed / allocated / outstanding values
/// exactly as returned. "Allocated" is the backend's allocated_amount —
/// it may include wallet-sourced settlement, so it is never described
/// as cash paid.
class MyContributionRow extends StatelessWidget {
  const MyContributionRow({super.key, required this.item, required this.onTap});

  final MyContribution item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final periodContext = myContributionPeriodContext(
      l10n,
      purpose: item.periodPurpose,
      periodLabel: item.periodLabel,
    );
    final dueDate = item.dueDate;

    return InkWell(
      key: Key('myContributionRow_${item.chargeId}'),
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
                        myContributionTypeLabel(
                          l10n,
                          item.contributionTypeName,
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (periodContext != null)
                        Text(periodContext, style: theme.textTheme.bodySmall),
                      Text(
                        dueDate == null
                            ? '${l10n.myContributionsEffectiveDateLabel}: '
                                  '${formatMyContributionDate(item.effectiveAt)}'
                            : '${l10n.myContributionsEffectiveDateLabel}: '
                                  '${formatMyContributionDate(item.effectiveAt)}'
                                  '  •  '
                                  '${l10n.myContributionsDueDateLabel}: '
                                  '${formatMyContributionDate(dueDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: UmojaSpacing.sm),
                UmojaStatusBadge(
                  key: Key('myContributionStatus_${item.chargeId}'),
                  label: myContributionStatusLabel(l10n, item.status),
                  semantic: myContributionStatusSemantic(item.status),
                ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _RowMetric(
                    label: l10n.myContributionsNetAssessedLabel,
                    value: formatAmount(item.netAssessed),
                  ),
                ),
                Expanded(
                  child: _RowMetric(
                    label: l10n.myContributionsAllocatedLabel,
                    value: formatAmount(item.allocatedAmount),
                  ),
                ),
                Expanded(
                  child: _RowMetric(
                    label: l10n.myContributionsOutstandingLabel,
                    value: formatAmount(item.outstanding),
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowMetric extends StatelessWidget {
  const _RowMetric({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
