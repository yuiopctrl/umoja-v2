import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../domain/member_financial_statement.dart';
import '../providers/member_statement_provider.dart';
import '../providers/member_statement_query_provider.dart';
import 'widgets/statement_activity_tile.dart';
import 'widgets/statement_position_cards.dart';

/// `/me/statement`: the caller's own cross-domain financial statement
/// (contributions/payments/loans/wallet) for the currently selected
/// group (Prompt 09G-B3-C). Every figure is rendered exactly as
/// `rpc_get_my_member_statement` returns it — this screen never
/// recalculates, re-sorts, or nets a balance; see
/// `member_financial_statement.dart`'s own locked contract.
class MemberStatementScreen extends ConsumerWidget {
  const MemberStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statementAsync = ref.watch(myMemberStatementProvider);

    return UmojaPage(
      title: l10n.financialStatementTitle,
      scrollable: false,
      body: statementAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.statementLoadFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myMemberStatementProvider),
        ),
        data: (statement) => _MemberStatementContent(statement: statement),
      ),
    );
  }
}

class _MemberStatementContent extends ConsumerStatefulWidget {
  const _MemberStatementContent({required this.statement});

  final MemberFinancialStatement statement;

  @override
  ConsumerState<_MemberStatementContent> createState() =>
      _MemberStatementContentState();
}

class _MemberStatementContentState
    extends ConsumerState<_MemberStatementContent> {
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    ref.read(memberStatementQueryProvider.notifier).loadMore();
    try {
      await ref.read(myMemberStatementProvider.future);
    } catch (_) {
      // Surfaced via the provider's own AsyncValue.error on next watch;
      // the already-loaded page stays visible underneath (§R).
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _refresh() async {
    ref.read(memberStatementQueryProvider.notifier).resetPageSize();
    ref.invalidate(myMemberStatementProvider);
    await ref.read(myMemberStatementProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statement = widget.statement;
    final nextPageAsync = ref.watch(myMemberStatementProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prompt 09G-B3-UX-01 §E: a compact identity block — no
            // card border (§J: a border communicates grouping; plain
            // identity text doesn't need one). Member name is the
            // prominent line; member number + group are secondary,
            // combined onto one line.
            Column(
              key: const Key('statementHeaderCard'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statement.member.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (statement.member.memberNumber != null) ...[
                      Text(
                        statement.member.memberNumber!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '  •  ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    Text(
                      statement.group.groupName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.xl),
            const _DateRangeFilter(),
            const SizedBox(height: UmojaSpacing.xxl),
            StatementCurrentPositionSection(summary: statement.summary),
            if (statement.period.opening != null) ...[
              const SizedBox(height: UmojaSpacing.xxl),
              StatementPeriodPositionSection(
                key: const Key('statementOpeningPosition'),
                title: l10n.statementOpeningPositionSectionTitle,
                position: statement.period.opening!,
              ),
            ],
            if (statement.period.closing != null) ...[
              const SizedBox(height: UmojaSpacing.xxl),
              StatementPeriodPositionSection(
                key: const Key('statementClosingPosition'),
                title: l10n.statementClosingPositionSectionTitle,
                position: statement.period.closing!,
              ),
            ],
            const SizedBox(height: UmojaSpacing.xxl),
            Text(
              l10n.statementActivityTimelineTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: UmojaSpacing.md),
            if (statement.activity.items.isEmpty)
              UmojaEmptyState(
                key: const Key('statementEmptyActivity'),
                icon: Icons.receipt_long_outlined,
                title:
                    statement.period.fromDate != null ||
                        statement.period.toDate != null
                    ? l10n.statementNoActivityFilteredMessage
                    : l10n.statementNoActivityMessage,
              )
            else ...[
              UmojaCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: UmojaSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildActivityRows(statement.activity.items),
                ),
              ),
              if (nextPageAsync.hasError && _loadingMore == false)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.sm,
                  ),
                  child: Text(
                    l10n.statementNextPageFailedMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (statement.activity.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.lg,
                  ),
                  child: Center(
                    child: OutlinedButton(
                      key: const Key('statementLoadMoreAction'),
                      onPressed: _loadingMore ? null : _loadMore,
                      child: _loadingMore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.loadMoreAction),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Builds the activity feed's rows: a month-group heading whenever the
/// month changes, a thin divider between consecutive items (never
/// around every item — Prompt 09G-B3-UX-01 §G/§J), and one
/// [StatementActivityTile] per item — in the EXACT order [items] is
/// already in (never re-sorted/re-grouped/filtered; this only inserts
/// presentational headers/dividers between them).
List<Widget> _buildActivityRows(List<MemberStatementActivityItem> items) {
  final rows = <Widget>[];
  DateTime? lastMonth;
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final month = DateTime(item.effectiveDate.year, item.effectiveDate.month);
    if (lastMonth == null || month != lastMonth) {
      rows.add(StatementMonthHeader(month: month));
    } else {
      rows.add(const Divider(height: 1));
    }
    rows.add(StatementActivityTile(item: item));
    lastMonth = month;
  }
  return rows;
}

class _DateRangeFilter extends ConsumerStatefulWidget {
  const _DateRangeFilter();

  @override
  ConsumerState<_DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends ConsumerState<_DateRangeFilter> {
  DateTime? _from;
  DateTime? _to;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final query = ref.read(memberStatementQueryProvider);
    _from = query.fromDate;
    _to = query.toDate;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _apply() {
    final l10n = context.l10n;
    final from = _from;
    final to = _to;
    if (from != null && to != null && from.isAfter(to)) {
      setState(() => _localError = l10n.statementFromAfterToError);
      return;
    }
    setState(() => _localError = null);
    ref
        .read(memberStatementQueryProvider.notifier)
        .setDateRange(fromDate: from, toDate: to);
  }

  void _clear() {
    setState(() {
      _from = null;
      _to = null;
      _localError = null;
    });
    ref
        .read(memberStatementQueryProvider.notifier)
        .setDateRange(fromDate: null, toDate: null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statementPeriodLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Wrap(
            spacing: UmojaSpacing.md,
            runSpacing: UmojaSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('statementFromDateAction'),
                onPressed: () => _pickDate(isFrom: true),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _from == null
                      ? l10n.statementFromDateLabel
                      : '${l10n.statementFromDateLabel}: ${_from!.year}-${_from!.month.toString().padLeft(2, '0')}-${_from!.day.toString().padLeft(2, '0')}',
                ),
              ),
              OutlinedButton.icon(
                key: const Key('statementToDateAction'),
                onPressed: () => _pickDate(isFrom: false),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _to == null
                      ? l10n.statementToDateLabel
                      : '${l10n.statementToDateLabel}: ${_to!.year}-${_to!.month.toString().padLeft(2, '0')}-${_to!.day.toString().padLeft(2, '0')}',
                ),
              ),
              FilledButton(
                key: const Key('statementApplyFilterAction'),
                onPressed: _apply,
                child: Text(l10n.statementApplyFilterAction),
              ),
              if (_from != null || _to != null)
                TextButton(
                  key: const Key('statementClearFilterAction'),
                  onPressed: _clear,
                  child: Text(l10n.statementAllActivityAction),
                ),
            ],
          ),
          if (_localError != null) ...[
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              _localError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
