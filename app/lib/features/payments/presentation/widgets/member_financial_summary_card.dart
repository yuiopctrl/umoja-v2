import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../../domain/member_contribution_statement.dart';
import '../../providers/member_contribution_statement_provider.dart';
import 'payment_labels.dart';

const _collapsedObligationLimit = 3;

/// The authoritative "before payment" summary (UAT-FIX-01, sections
/// 1/2/9) — member identity, Deni Lililobaki (total outstanding),
/// Salio la Mwanachama (wallet balance), and the specific obligations
/// making up that debt. Shown immediately after selecting a member in
/// Record Payment, before any amount is entered. Every figure is
/// server-derived (`rpc_get_member_contribution_statement`) — never
/// computed here.
class MemberFinancialSummaryCard extends ConsumerStatefulWidget {
  const MemberFinancialSummaryCard({super.key, required this.membershipId});

  final String membershipId;

  @override
  ConsumerState<MemberFinancialSummaryCard> createState() =>
      _MemberFinancialSummaryCardState();
}

class _MemberFinancialSummaryCardState
    extends ConsumerState<MemberFinancialSummaryCard> {
  bool _obligationsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statementAsync = ref.watch(
      memberContributionStatementProvider(widget.membershipId),
    );

    return statementAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: UmojaSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
      data: (statement) => _buildSummary(context, l10n, statement),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    AppLocalizations l10n,
    MemberContributionStatement statement,
  ) {
    // Flatten to one row per still-outstanding component — each row
    // repeats its charge's contribution/period context, matching the
    // UAT spec's row-per-component examples (never a bare "Base
    // 20,000 / Base 10,000").
    final rows = <(OutstandingCharge, OutstandingComponent)>[
      for (final charge in statement.charges)
        for (final component in charge.components) (charge, component),
    ];
    final visibleRows = _obligationsExpanded
        ? rows
        : rows.take(_collapsedObligationLimit).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          key: const Key('memberFinancialSummaryCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                label: l10n.paymentSummaryOutstandingLabel,
                value: formatAmount(statement.totalOutstanding),
              ),
              const SizedBox(height: UmojaSpacing.sm),
              _SummaryRow(
                key: const Key('memberFinancialSummaryWalletRow'),
                label: l10n.memberWalletTitle,
                value: formatAmount(statement.walletBalance),
              ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Text(
          l10n.outstandingObligationsSectionTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        if (rows.isEmpty)
          Text(l10n.outstandingObligationsEmptyMessage)
        else ...[
          for (final (charge, component) in visibleRows)
            Padding(
              padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obligationContextLabel(
                            contributionTypeName: charge.contributionTypeName,
                            periodLabel: charge.periodLabel,
                            periodPurpose: charge.periodPurpose,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          contributionComponentTypeLabel(
                            l10n,
                            component.componentType,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(formatAmount(component.outstanding)),
                ],
              ),
            ),
          if (rows.length > _collapsedObligationLimit && !_obligationsExpanded)
            OutlinedButton(
              key: const Key('viewAllObligationsAction'),
              onPressed: () => setState(() => _obligationsExpanded = true),
              child: Text(l10n.viewAllObligationsAction),
            ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
