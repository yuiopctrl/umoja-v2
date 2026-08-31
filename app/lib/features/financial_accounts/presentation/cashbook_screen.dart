import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/financial_account_entry.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_entries_provider.dart';
import 'widgets/financial_account_labels.dart';

const _defaultLimit = 10;
const _sourceFilters = [
  null,
  'PAYMENT',
  'MANUAL_INCOME',
  'EXPENSE',
  'TRANSFER',
  'FINANCIAL_ADJUSTMENT',
];

String _sourceFilterLabel(AppLocalizations l10n, String? sourceType) {
  return switch (sourceType) {
    null => l10n.filterAll,
    'PAYMENT' => l10n.cashbookFilterPayments,
    'MANUAL_INCOME' => l10n.cashbookFilterIncome,
    'EXPENSE' => l10n.cashbookFilterExpense,
    'TRANSFER' => l10n.cashbookFilterTransfers,
    'FINANCIAL_ADJUSTMENT' => l10n.cashbookFilterAdjustments,
    _ => sourceType,
  };
}

/// `/financial-accounts/:accountId/cashbook`: the full, filterable,
/// paginated cashbook for one account (Prompt 08B, sections 20-21).
/// Account Detail itself keeps only a short recent-movements preview —
/// this is the authoritative browsing surface, so it never loads the
/// entire history client-side.
class CashbookScreen extends ConsumerStatefulWidget {
  const CashbookScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends ConsumerState<CashbookScreen> {
  int _limit = _defaultLimit;
  String? _sourceType;

  void _setSourceFilter(String? sourceType) {
    setState(() {
      _sourceType = sourceType;
      _limit = _defaultLimit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(
      financialAccountDetailProvider(widget.accountId),
    );
    final entriesQuery = (
      accountId: widget.accountId,
      limit: _limit,
      dateFrom: null,
      dateTo: null,
      entryType: null,
      sourceType: _sourceType,
      categoryId: null,
    );
    final entriesAsync = ref.watch(
      financialAccountEntriesProvider(entriesQuery),
    );

    return UmojaPage(
      title: l10n.cashbookTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.financialAccountDetailPath(widget.accountId),
      backLabel: accountAsync.value?.name ?? l10n.financialAccountsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in _sourceFilters)
                ChoiceChip(
                  label: Text(_sourceFilterLabel(l10n, filter)),
                  selected: _sourceType == filter,
                  onSelected: (_) => _setSourceFilter(filter),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: entriesAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(
                  financialAccountEntriesProvider(entriesQuery),
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.financialAccountEntriesEmptyMessage,
                  );
                }
                return ListView.separated(
                  itemCount: page.items.length + (page.hasMore ? 1 : 0),
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= page.items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: UmojaSpacing.lg,
                        ),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _limit += _defaultLimit),
                            child: Text(l10n.loadMoreAction),
                          ),
                        ),
                      );
                    }
                    return _CashbookRow(
                      entry: page.items[index],
                      accountId: widget.accountId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CashbookRow extends StatelessWidget {
  const _CashbookRow({required this.entry, required this.accountId});

  final FinancialAccountEntry entry;
  final String accountId;

  bool get _isReversible =>
      (entry.sourceType == 'MANUAL_INCOME' || entry.sourceType == 'EXPENSE') &&
      entry.manualEntryStatus == 'POSTED';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amountText =
        '${entry.isCredit ? '+' : '-'}${formatAmount(entry.amount)}';
    final description = entry.description;
    final reference = entry.reference;
    return UmojaListTile(
      title: financialAccountEntryDisplayLabel(l10n, entry),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatKiswahiliDate(entry.effectiveAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (description != null && description.isNotEmpty)
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          if (reference != null && reference.isNotEmpty)
            Text(
              '${l10n.referenceDisplayLabel}: $reference',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (entry.manualEntryStatus == 'REVERSED')
            Text(
              l10n.cashbookEntryReversedLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Text(
        amountText,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: entry.isCredit ? null : Theme.of(context).colorScheme.error,
        ),
      ),
      onTap: _isReversible && entry.sourceId != null
          ? () => context.push(
              AppRoutes.financialEntryReversePath(entry.sourceId!),
            )
          : null,
    );
  }
}
