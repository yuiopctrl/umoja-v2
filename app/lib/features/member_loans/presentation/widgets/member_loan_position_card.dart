import 'package:flutter/material.dart';

import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_loan.dart';

/// Current Position, exactly as the backend returned it. A null amount is
/// shown as "Not available", never as zero. The total is the backend's
/// canonical value, not a sum computed here.
class MemberLoanPositionCard extends StatelessWidget {
  const MemberLoanPositionCard({super.key, required this.position, this.note});

  final MemberLoanCurrentPosition position;

  /// Optional, explanatory note for a zero or unavailable position.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rows = [
      (l10n.myLoansPrincipalOutstandingLabel, position.principalOutstanding),
      (l10n.myLoansInterestOutstandingLabel, position.interestOutstanding),
      (l10n.myLoansPenaltyOutstandingLabel, position.penaltyOutstanding),
    ];

    return UmojaCard(
      key: const Key('myLoanPositionCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows) ...[
            _Row(
              label: label,
              value: value == null
                  ? l10n.myLoansNotAvailableLabel
                  : formatAmount(value),
            ),
            const Divider(height: UmojaSpacing.lg),
          ],
          _Row(
            label: l10n.myLoansTotalOutstandingLabel,
            value: position.totalOutstanding == null
                ? l10n.myLoansNotAvailableLabel
                : formatAmount(position.totalOutstanding!),
            emphasized: true,
            key: const Key('myLoanPositionTotal'),
          ),
          const SizedBox(height: UmojaSpacing.md),
          Text(
            l10n.myLoansPositionNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: UmojaSpacing.sm),
            Text(note!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
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
    return Row(
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
    );
  }
}
