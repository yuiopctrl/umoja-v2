import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../../../loans/presentation/widgets/loan_labels.dart';
import '../../../payments/presentation/widgets/payment_labels.dart';
import '../../domain/member_financial_statement.dart';

final _dateFormat = DateFormat('d MMM yyyy');

IconData _domainIcon(String domain) => switch (domain) {
  'CONTRIBUTION' => Icons.volunteer_activism_outlined,
  'PAYMENT' => Icons.payments_outlined,
  'LOAN' => Icons.request_quote_outlined,
  'WALLET' => Icons.account_balance_wallet_outlined,
  _ => Icons.receipt_long_outlined,
};

String _eventTitle(AppLocalizations l10n, MemberStatementActivityItem item) {
  return switch (item.domain) {
    'CONTRIBUTION' => contributionComponentTypeLabel(l10n, item.eventType),
    'PAYMENT' => l10n.statementPaymentActivityTitle,
    'WALLET' => walletEntryTypeLabel(l10n, item.eventType),
    'LOAN' => switch (item.eventType) {
      'DISBURSEMENT' => l10n.statementEventLoanDisbursed,
      'WRITE_OFF' => l10n.statementEventWriteOff,
      'REVERSAL' => l10n.statementEventObligationAdjustmentReversed,
      'WAIVER' => l10n.statementEventObligationWaiver,
      'CORRECTION_INCREASE' => l10n.statementEventObligationCorrectionIncrease,
      'CORRECTION_DECREASE' => l10n.statementEventObligationCorrectionDecrease,
      'PENALTY_ASSESSED' => l10n.statementEventPenaltyAssessed,
      'RESTRUCTURED' => l10n.statementEventLoanRestructured,
      _ => item.eventType,
    },
    _ => item.eventType,
  };
}

/// One row of the financial activity timeline — rendered in the EXACT
/// order the backend returns (`activity.items`), never re-sorted
/// client-side (Prompt 09G-B3-C §J). A PAYMENT item's allocations are
/// shown nested underneath, as detail only — never as separate
/// top-level activity records (§L: no double-counting).
class StatementActivityTile extends StatelessWidget {
  const StatementActivityTile({super.key, required this.item});

  final MemberStatementActivityItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return UmojaCard(
      key: Key('statementActivityItem_${item.eventId}'),
      padding: const EdgeInsets.all(UmojaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_domainIcon(item.domain), color: scheme.onSurfaceVariant),
              const SizedBox(width: UmojaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _eventTitle(l10n, item),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (item.isReversed)
                          Container(
                            key: const Key('statementActivityReversedBadge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10n.paymentStatusReversed,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onErrorContainer),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateFormat.format(item.effectiveDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.domain == 'CONTRIBUTION' &&
                        item.periodLabel != null)
                      Text(
                        item.periodLabel!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.domain == 'LOAN' && item.loanNumber != null)
                      Text(
                        item.loanNumber!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.domain == 'PAYMENT' && item.receiptNumber != null)
                      Text(
                        item.receiptNumber!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: UmojaSpacing.sm),
              Text(
                formatAmount(item.amount),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          if (item.domain == 'PAYMENT' && item.allocations.isNotEmpty) ...[
            const SizedBox(height: UmojaSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              l10n.statementAllocationsLabel,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: UmojaSpacing.xs),
            for (final allocation in item.allocations)
              Padding(
                padding: const EdgeInsets.only(
                  left: UmojaSpacing.xl,
                  top: 2,
                  bottom: 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        allocation.isContribution
                            ? l10n.contributionsTitle
                            : loanComponentTypeLabel(
                                l10n,
                                allocation.targetType,
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      formatAmount(allocation.amount),
                      style: Theme.of(context).textTheme.bodySmall,
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
