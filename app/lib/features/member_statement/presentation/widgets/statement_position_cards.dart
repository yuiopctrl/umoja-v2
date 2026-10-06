import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_breakpoints.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../../core/widgets/umoja_section.dart';
import '../../domain/member_financial_statement.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// `summary` — the three independent CURRENT positions. Never a
/// fourth, netted figure (Prompt 09G-B3-C §H: "do NOT produce Total
/// Balance/Net Balance/Overall Balance").
class StatementCurrentPositionSection extends StatelessWidget {
  const StatementCurrentPositionSection({super.key, required this.summary});

  final MemberStatementSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaSection(
      title: l10n.statementCurrentPositionSectionTitle,
      child: UmojaCard(
        child: StatementPositionMetrics(
          contributionsOutstanding: summary.contributionsCurrentOutstanding,
          loansOutstanding: summary.loansCurrentOutstanding,
          walletBalance: summary.walletCurrentBalance,
          contributionsKey: const Key('statementCurrentContributions'),
          loansKey: const Key('statementCurrentLoans'),
          walletKey: const Key('statementCurrentWallet'),
        ),
      ),
    );
  }
}

/// One of `period.opening`/`period.closing` — only rendered when the
/// backend actually returned it (never a fabricated zero for a bound
/// that wasn't requested — see the caller in `member_statement_screen.dart`).
class StatementPeriodPositionSection extends StatelessWidget {
  const StatementPeriodPositionSection({
    super.key,
    required this.title,
    required this.position,
  });

  final String title;
  final MemberStatementPeriodPosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaSection(
      title: title,
      trailing: Text(
        l10n.statementAsOfLabel(_dateFormat.format(position.asOfDate)),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: UmojaCard(
        child: StatementPositionMetrics(
          contributionsOutstanding: position.contributionsOutstanding,
          loansOutstanding: position.loansOutstanding,
          walletBalance: position.walletBalance,
        ),
      ),
    );
  }
}

/// Prompt 09G-B3-UX-01 §F: the ONE reusable position component shared
/// by Home's current position, Statement's Current Position, and
/// Statement's Opening/Closing positions — three independent rows
/// (never a fourth, netted figure) inside whatever single surface the
/// caller wraps this in, rather than each domain getting its own
/// narrow bordered card. Mobile stacks the three as label/amount rows
/// using the surface's full width (so large values like
/// "33,921,875" never need to shrink to fit); tablet/desktop may use
/// a 3-column layout within that SAME surface.
class StatementPositionMetrics extends StatelessWidget {
  const StatementPositionMetrics({
    super.key,
    required this.contributionsOutstanding,
    required this.loansOutstanding,
    required this.walletBalance,
    this.contributionsKey,
    this.loansKey,
    this.walletKey,
  });

  final double contributionsOutstanding;

  /// `null` renders as the localized "Not available" value (09G-B5-A3 §T).
  final double? loansOutstanding;
  final double walletBalance;
  final Key? contributionsKey;
  final Key? loansKey;
  final Key? walletKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMobile = UmojaBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    final metrics = <(Key?, String, double?)>[
      (
        contributionsKey,
        l10n.statementContributionsOutstandingLabel,
        contributionsOutstanding,
      ),
      (loansKey, l10n.statementLoansOutstandingLabel, loansOutstanding),
      (walletKey, l10n.statementWalletBalanceLabel, walletBalance),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, m) in metrics.indexed) ...[
            if (i > 0) const SizedBox(height: UmojaSpacing.sm),
            _MetricRow(
              key: m.$1,
              label: m.$2,
              amount: m.$3,
              unavailableLabel: l10n.statementAmountUnavailableLabel,
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, m) in metrics.indexed) ...[
          if (i > 0) const SizedBox(width: UmojaSpacing.xl),
          Expanded(
            child: _MetricColumn(
              key: m.$1,
              label: m.$2,
              amount: m.$3,
              unavailableLabel: l10n.statementAmountUnavailableLabel,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    super.key,
    required this.label,
    required this.amount,
    required this.unavailableLabel,
  });

  final String label;
  final double? amount;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: UmojaSpacing.sm),
        Text(
          amount == null ? unavailableLabel : formatAmount(amount!),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    super.key,
    required this.label,
    required this.amount,
    required this.unavailableLabel,
  });

  final String label;
  final double? amount;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: UmojaSpacing.xs),
        Text(
          amount == null ? unavailableLabel : formatAmount(amount!),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
