import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../../../loans/presentation/widgets/loan_labels.dart';
import '../../../payments/presentation/widgets/payment_labels.dart';
import '../../domain/member_financial_statement.dart';

final _dateFormat = DateFormat('d MMM');
final _monthFormat = DateFormat('MMMM yyyy');

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

/// Prompt 09G-B3-UX-01-FIX-01 §G: `loanComponentTypeLabel` (shared
/// with other, non-B3 screens — loan recovery, officer allocation
/// detail) collapses LOAN_PRINCIPAL_PREPAYMENT into the same generic
/// "Principal" as a plain LOAN_PRINCIPAL allocation. A member-facing
/// payment allocation needs that distinction (a prepayment is a
/// materially different event from an ordinary installment payment),
/// so this is a narrow, B3-only wrapper — it never touches the shared
/// helper or its other call sites. Reuses the existing
/// `statementEventPrincipalPrepayment` key (already "Principal
/// Prepayment" in both languages) rather than adding a duplicate.
String _allocationLoanLabel(AppLocalizations l10n, String targetType) {
  if (targetType == 'LOAN_PRINCIPAL_PREPAYMENT') {
    return l10n.statementEventPrincipalPrepayment;
  }
  return loanComponentTypeLabel(l10n, targetType);
}

/// A month-group heading for the activity feed (Prompt 09G-B3-UX-01
/// §G) — purely a visual grouping pass over `activity.items` in the
/// EXACT order the backend already returned them; it never reorders,
/// filters, or drops an item.
class StatementMonthHeader extends StatelessWidget {
  const StatementMonthHeader({super.key, required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: UmojaSpacing.lg,
        bottom: UmojaSpacing.xs,
      ),
      child: Text(
        _monthFormat.format(month).toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// One row of the financial activity timeline — rendered in the EXACT
/// order the backend returns (`activity.items`), never re-sorted
/// client-side (Prompt 09G-B3-C §J). A compact transaction-feed row
/// (icon, title/date, right-aligned amount) rather than its own
/// bordered card (Prompt 09G-B3-UX-01 §G/§J). A PAYMENT item's
/// allocations are nested detail — never separate top-level activity
/// records (§L: no double-counting) — and, when present, START
/// COLLAPSED (§H, mandatory): a payment with many allocations must
/// never consume most of the screen by default. Purely local Flutter
/// expand/collapse state; no backend change, no new activity row.
class StatementActivityTile extends StatefulWidget {
  const StatementActivityTile({super.key, required this.item});

  final MemberStatementActivityItem item;

  @override
  State<StatementActivityTile> createState() => _StatementActivityTileState();
}

class _StatementActivityTileState extends State<StatementActivityTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final hasAllocations =
        item.domain == 'PAYMENT' && item.allocations.isNotEmpty;

    return Padding(
      key: Key('statementActivityItem_${item.eventId}'),
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _domainIcon(item.domain),
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isReversed) ...[
                          const SizedBox(width: UmojaSpacing.xs),
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
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _dateFormat.format(item.effectiveDate),
                        if (item.domain == 'CONTRIBUTION' &&
                            item.periodLabel != null)
                          item.periodLabel!,
                        if (item.domain == 'LOAN' && item.loanNumber != null)
                          item.loanNumber!,
                        if (item.domain == 'PAYMENT' &&
                            item.receiptNumber != null)
                          item.receiptNumber!,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasAllocations) ...[
                      const SizedBox(height: 2),
                      InkWell(
                        key: const Key('statementAllocationsToggle'),
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.statementAllocationsCount(
                                item.allocations.length,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.primary),
                            ),
                            const SizedBox(width: UmojaSpacing.xs),
                            Text(
                              _expanded
                                  ? l10n.statementHideDetailsAction
                                  : l10n.statementViewDetailsAction,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
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
          if (hasAllocations && _expanded)
            Padding(
              padding: const EdgeInsets.only(
                left: UmojaSpacing.xxl,
                top: UmojaSpacing.xs,
              ),
              child: Column(
                key: const Key('statementAllocationsDetail'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final allocation in item.allocations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _AllocationLabel(allocation: allocation),
                          ),
                          const SizedBox(width: UmojaSpacing.sm),
                          Text(
                            formatAmount(allocation.amount),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Prompt 09G-B3-UX-01-FIX-01 §D/§F/§G: what a payment allocation
/// settled, in plain language — never a bare "Contribution"/"Loan"
/// repeated for every row. A contribution allocation's PRIMARY line is
/// the real persisted charge/period title (`period_label` — the exact
/// business text an officer typed when creating that period, e.g.
/// "Ada ya mwezi"; NEVER translated/replaced); its SECONDARY line is
/// the localized BASE/PENALTY/ADJUSTMENT/WAIVER/OPENING_BALANCE
/// classification. `period_label`/`component_type` are null for a
/// response from before the additive enrichment reached this caller's
/// environment — that falls back to exactly the prior single-line
/// generic rendering, never a crash or a fabricated title. A loan
/// allocation (never missing its classification — `target_type` alone
/// is always sufficient) renders as a single line: Principal/Interest/
/// Penalty/Principal Prepayment, never collapsed to generic "Loan".
class _AllocationLabel extends StatelessWidget {
  const _AllocationLabel({required this.allocation});

  final MemberStatementAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    if (allocation.isLoan) {
      return Text(
        _allocationLoanLabel(l10n, allocation.targetType),
        style: bodySmall,
      );
    }

    final periodLabel = allocation.periodLabel;
    final componentType = allocation.componentType;
    if (periodLabel == null) {
      // Defensive fallback only — see class doc.
      return Text(
        componentType == null
            ? l10n.contributionsTitle
            : contributionComponentTypeLabel(l10n, componentType),
        style: bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(periodLabel, style: bodySmall),
        if (componentType != null)
          Text(
            contributionComponentTypeLabel(l10n, componentType),
            style: bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
