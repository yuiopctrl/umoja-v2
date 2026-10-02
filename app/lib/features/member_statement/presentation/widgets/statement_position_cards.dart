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
      child: _PositionCardRow(
        cards: [
          _PositionCard(
            key: const Key('statementCurrentContributions'),
            label: l10n.contributionsTitle,
            amountLabel: l10n.statementCurrentOutstandingLabel,
            amount: summary.contributionsCurrentOutstanding,
          ),
          _PositionCard(
            key: const Key('statementCurrentLoans'),
            label: l10n.loansTitle,
            amountLabel: l10n.statementCurrentOutstandingLabel,
            amount: summary.loansCurrentOutstanding,
          ),
          _PositionCard(
            key: const Key('statementCurrentWallet'),
            label: l10n.statementWalletSectionLabel,
            amountLabel: l10n.walletBalanceLabel,
            amount: summary.walletCurrentBalance,
          ),
        ],
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
      child: _PositionCardRow(
        cards: [
          _PositionCard(
            label: l10n.contributionsTitle,
            amountLabel: l10n.chargeOutstandingLabel,
            amount: position.contributionsOutstanding,
          ),
          _PositionCard(
            label: l10n.loansTitle,
            amountLabel: l10n.chargeOutstandingLabel,
            amount: position.loansOutstanding,
          ),
          _PositionCard(
            label: l10n.statementWalletSectionLabel,
            amountLabel: l10n.walletBalanceLabel,
            amount: position.walletBalance,
          ),
        ],
      ),
    );
  }
}

class _PositionCardRow extends StatelessWidget {
  const _PositionCardRow({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final isMobile = UmojaBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    if (isMobile) {
      return Column(
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: UmojaSpacing.md),
            card,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(width: UmojaSpacing.md),
          Expanded(child: card),
        ],
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    super.key,
    required this.label,
    required this.amountLabel,
    required this.amount,
  });

  final String label;
  final String amountLabel;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return UmojaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            formatAmount(amount),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(amountLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
