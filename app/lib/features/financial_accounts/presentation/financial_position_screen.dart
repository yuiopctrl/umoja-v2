import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../domain/financial_position.dart';
import '../providers/financial_position_provider.dart';
import 'widgets/financial_account_labels.dart';

/// `/finance/position`: Hali ya Fedha — the Financial Position read
/// model (Prompt 08B, sections 23-25/35). Deliberately NOT titled or
/// presented as a full accounting balance sheet.
class FinancialPositionScreen extends ConsumerStatefulWidget {
  const FinancialPositionScreen({super.key});

  @override
  ConsumerState<FinancialPositionScreen> createState() =>
      _FinancialPositionScreenState();
}

class _FinancialPositionScreenState
    extends ConsumerState<FinancialPositionScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    final query = (dateFrom: _dateFrom, dateTo: _dateTo);
    ref.invalidate(financialPositionProvider(query));
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  void _clearRange() => setState(() {
    _dateFrom = null;
    _dateTo = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = (dateFrom: _dateFrom, dateTo: _dateTo);
    final positionAsync = ref.watch(financialPositionProvider(query));

    return UmojaPage(
      title: l10n.financialPositionTitle,
      maxWidth: 900,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('financialPositionDateRangeAction'),
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    _dateFrom == null || _dateTo == null
                        ? l10n.financialPositionPickRangeAction
                        : '${formatKiswahiliDate(_dateFrom!)} - ${formatKiswahiliDate(_dateTo!)}',
                  ),
                ),
              ),
              if (_dateFrom != null)
                TextButton(
                  onPressed: _clearRange,
                  child: Text(l10n.financialPositionClearRangeAction),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          Expanded(
            child: positionAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(financialPositionProvider(query)),
              ),
              data: (position) => SingleChildScrollView(
                child: _PositionBody(position: position),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionBody extends StatelessWidget {
  const _PositionBody({required this.position});

  final FinancialPosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Economic/operating summary cards.
        Wrap(
          spacing: UmojaSpacing.md,
          runSpacing: UmojaSpacing.md,
          children: [
            _SummaryCard(
              key: const Key('financialPositionTotalBalanceCard'),
              label: l10n.financialPositionTotalBalanceLabel,
              value: formatAmount(position.totalFinancialAccountBalance),
            ),
            _SummaryCard(
              key: const Key('financialPositionIncomeCard'),
              label: l10n.financialPositionIncomeLabel,
              value: formatAmount(position.groupIncome),
            ),
            _SummaryCard(
              key: const Key('financialPositionExpenseCard'),
              label: l10n.financialPositionExpenseLabel,
              value: formatAmount(position.expenses),
            ),
            _SummaryCard(
              key: const Key('financialPositionNetResultCard'),
              label: l10n.financialPositionNetResultLabel,
              value: formatAmount(position.netOperatingResult),
            ),
          ],
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        Text(
          l10n.financialPositionAccountsSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final account in position.accounts)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name),
                            Text(
                              financialAccountTypeLabel(
                                l10n,
                                account.accountType,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatAmount(account.balance),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              if (position.accounts.isEmpty)
                Text(l10n.financialPositionNoAccountsMessage),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        Text(
          l10n.financialPositionOtherClassificationsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClassificationRow(
                key: const Key('financialPositionPassThroughRow'),
                label: l10n.financialPositionPassThroughLabel,
                value: formatAmount(position.passThroughReceived),
              ),
              _ClassificationRow(
                key: const Key('financialPositionShareCapitalRow'),
                label: l10n.financialPositionShareCapitalLabel,
                value: formatAmount(position.shareCapitalReceived),
              ),
              _ClassificationRow(
                key: const Key('financialPositionWalletLiabilityRow'),
                label: l10n.financialPositionWalletLiabilityLabel,
                value: formatAmount(position.memberWalletLiability),
              ),
              _ClassificationRow(
                key: const Key('financialPositionOutstandingObligationsRow'),
                label: l10n.financialPositionOutstandingObligationsLabel,
                value: formatAmount(position.totalOutstandingMemberObligations),
              ),
              _ClassificationRow(
                key: const Key('financialPositionFundedLoanPrincipalRow'),
                label: l10n.financialPositionFundedLoanPrincipalLabel,
                value: formatAmount(position.fundedLoanPrincipalReceivable),
              ),
              _ClassificationRow(
                key: const Key('financialPositionScheduledUnearnedInterestRow'),
                label: l10n.financialPositionScheduledUnearnedInterestLabel,
                value: formatAmount(position.scheduledUnearnedInterest),
              ),
              _ClassificationRow(
                key: const Key(
                  'financialPositionRecognizedLoanInterestIncomeRow',
                ),
                label: l10n.financialPositionRecognizedLoanInterestIncomeLabel,
                value: formatAmount(position.recognizedLoanInterestIncome),
              ),
              _ClassificationRow(
                key: const Key('financialPositionLoanPenaltiesOutstandingRow'),
                label: l10n.financialPositionLoanPenaltiesOutstandingLabel,
                value: formatAmount(position.loanPenaltiesOutstanding),
              ),
              _ClassificationRow(
                key: const Key(
                  'financialPositionRecognizedLoanPenaltyIncomeRow',
                ),
                label: l10n.financialPositionRecognizedLoanPenaltyIncomeLabel,
                value: formatAmount(position.recognizedLoanPenaltyIncome),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: UmojaCard(
        padding: const EdgeInsets.all(UmojaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: UmojaSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  const _ClassificationRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
