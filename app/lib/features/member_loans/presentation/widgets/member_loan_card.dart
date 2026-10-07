import 'package:flutter/material.dart';

import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_loan.dart';
import 'member_loan_labels.dart';

/// One independent loan account. The current total outstanding is the most
/// prominent figure on an ACTIVE loan. Original principal is supporting
/// information. Overdue is labelled plainly and is not alarm-colored.
class MemberLoanCard extends StatelessWidget {
  const MemberLoanCard({super.key, required this.item, required this.onTap});

  final MemberLoanListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final total = item.currentPosition.totalOutstanding;
    final overdue = item.overdueAmount;
    final hasOverdue = overdue != null && overdue > 0;

    return UmojaCard(
      child: InkWell(
        key: Key('myLoanCard_${item.loanAccountId}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(UmojaSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.myLoansLoanNumberLabel} ${item.loanNumber}',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: UmojaSpacing.sm),
                  UmojaStatusBadge(
                    label: memberLoanStatusLabel(l10n, item.status),
                    semantic: memberLoanStatusSemantic(item.status),
                  ),
                ],
              ),
              const SizedBox(height: UmojaSpacing.xs),
              Text(
                item.productName,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.isOpeningPosition) ...[
                const SizedBox(height: UmojaSpacing.xs),
                Text(
                  l10n.myLoansOpeningPositionLabel,
                  key: Key('myLoanOpeningBadge_${item.loanAccountId}'),
                  style: theme.textTheme.labelMedium,
                ),
              ],
              const SizedBox(height: UmojaSpacing.md),
              Text(l10n.myLoansTotalOutstandingLabel, style: muted),
              Text(
                total == null
                    ? l10n.myLoansNotAvailableLabel
                    : formatAmount(total),
                key: Key('myLoanTotal_${item.loanAccountId}'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasOverdue) ...[
                const SizedBox(height: UmojaSpacing.xs),
                Text(
                  '${l10n.myLoansOverdueLabel}: ${formatAmount(overdue)}',
                  key: Key('myLoanOverdue_${item.loanAccountId}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (item.nextDueDate != null) ...[
                const SizedBox(height: UmojaSpacing.xs),
                Text(
                  '${l10n.myLoansNextDueLabel}: ${formatMemberLoanDate(item.nextDueDate!)}',
                  style: muted,
                ),
              ],
              if (item.originalPrincipal != null) ...[
                const SizedBox(height: UmojaSpacing.xs),
                Text(
                  '${l10n.myLoansOriginalPrincipalLabel}: ${formatAmount(item.originalPrincipal!)}',
                  style: muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
