import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../app/shell/member_child_scaffold.dart';
import '../data/my_contributions_failure.dart';
import '../domain/my_contribution.dart';
import '../providers/my_contributions_provider.dart';
import '../providers/my_contributions_query_provider.dart';
import 'widgets/my_contribution_labels.dart';
import 'widgets/my_contribution_row.dart';
import 'widgets/my_contributions_filter_sheet.dart';

/// `/me/contributions`: the caller's OWN contribution charges for the
/// currently selected group (Prompt 09G-B4-C). Every amount, status, and
/// total is rendered exactly as the backend returns it; nothing here is
/// recalculated from loaded rows. Officer Contribution Management lives
/// separately at `/contributions`.
class MyContributionsScreen extends ConsumerWidget {
  const MyContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pageAsync = ref.watch(myContributionsProvider);

    return MemberChildScaffold(
      title: l10n.myContributionsTitle,
      scrollable: false,
      body: pageAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: _messageFor(context, error),
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myContributionsProvider),
        ),
        data: (page) => _MyContributionsContent(page: page),
      ),
    );
  }
}

String _messageFor(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is MyContributionsFailure) {
    return myContributionsFailureMessage(l10n, error);
  }
  return l10n.myContributionsLoadFailedMessage;
}

class _MyContributionsContent extends ConsumerStatefulWidget {
  const _MyContributionsContent({required this.page});

  final MyContributionsPage page;

  @override
  ConsumerState<_MyContributionsContent> createState() =>
      _MyContributionsContentState();
}

class _MyContributionsContentState
    extends ConsumerState<_MyContributionsContent> {
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    ref.read(myContributionsQueryProvider.notifier).loadMore();
    try {
      await ref.read(myContributionsProvider.future);
    } catch (_) {
      // Surfaced through the provider's AsyncError on the next watch; the
      // already-loaded rows stay visible underneath.
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _refresh() async {
    ref.read(myContributionsQueryProvider.notifier).resetPageSize();
    ref.invalidate(myContributionsProvider);
    await ref.read(myContributionsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = widget.page;
    final query = ref.watch(myContributionsQueryProvider);
    final nextPageAsync = ref.watch(myContributionsProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UmojaCard(
              key: const Key('myContributionsSummary'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.myContributionsTotalOutstandingLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: UmojaSpacing.xs),
                  Text(
                    formatAmount(page.summary.totalOutstanding),
                    key: const Key('myContributionsTotalOutstandingValue'),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            _FilterBar(contributionTypes: page.contributionTypes, query: query),
            const SizedBox(height: UmojaSpacing.lg),
            if (page.items.isEmpty)
              UmojaEmptyState(
                key: Key(
                  query.hasActiveFilters
                      ? 'myContributionsEmptyFiltered'
                      : 'myContributionsEmpty',
                ),
                icon: Icons.volunteer_activism_outlined,
                title: query.hasActiveFilters
                    ? l10n.myContributionsEmptyFilteredTitle
                    : l10n.myContributionsEmptyTitle,
                message: query.hasActiveFilters
                    ? null
                    : l10n.myContributionsEmptyMessage,
              )
            else ...[
              UmojaCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: UmojaSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildRows(context, page.items),
                ),
              ),
              if (nextPageAsync.hasError && !_loadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.sm,
                  ),
                  child: Text(
                    l10n.myContributionsLoadMoreFailedMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (page.pagination.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.lg,
                  ),
                  child: Center(
                    child: OutlinedButton(
                      key: const Key('myContributionsLoadMoreAction'),
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

  List<Widget> _buildRows(BuildContext context, List<MyContribution> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1));
      final item = items[i];
      rows.add(
        MyContributionRow(
          item: item,
          onTap: () =>
              context.push(AppRoutes.myContributionDetailPath(item.chargeId)),
        ),
      );
    }
    return rows;
  }
}

/// Compact filter entry point plus removable chips for each active
/// filter. Removing a chip clears only that filter; "Clear Filters"
/// clears all of them. Every change resets pagination to the first page
/// (handled by the query notifier).
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.contributionTypes, required this.query});

  final List<MyContributionTypeOption> contributionTypes;
  final MyContributionsQuery query;

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final result = await showMyContributionsFilterSheet(
      context,
      current: MyContributionsFilters(
        status: query.status,
        contributionTypeId: query.contributionTypeId,
        fromDate: query.fromDate,
        toDate: query.toDate,
      ),
      contributionTypes: contributionTypes,
    );
    if (result == null) return;
    ref
        .read(myContributionsQueryProvider.notifier)
        .applyFilters(
          status: result.status,
          contributionTypeId: result.contributionTypeId,
          fromDate: result.fromDate,
          toDate: result.toDate,
        );
  }

  void _removeStatus(WidgetRef ref) {
    ref
        .read(myContributionsQueryProvider.notifier)
        .applyFilters(
          contributionTypeId: query.contributionTypeId,
          fromDate: query.fromDate,
          toDate: query.toDate,
        );
  }

  void _removeType(WidgetRef ref) {
    ref
        .read(myContributionsQueryProvider.notifier)
        .applyFilters(
          status: query.status,
          fromDate: query.fromDate,
          toDate: query.toDate,
        );
  }

  void _removeFrom(WidgetRef ref) {
    ref
        .read(myContributionsQueryProvider.notifier)
        .applyFilters(
          status: query.status,
          contributionTypeId: query.contributionTypeId,
          toDate: query.toDate,
        );
  }

  void _removeTo(WidgetRef ref) {
    ref
        .read(myContributionsQueryProvider.notifier)
        .applyFilters(
          status: query.status,
          contributionTypeId: query.contributionTypeId,
          fromDate: query.fromDate,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typeName = query.contributionTypeId == null
        ? null
        : _typeNameFor(query.contributionTypeId!);

    return Wrap(
      spacing: UmojaSpacing.sm,
      runSpacing: UmojaSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('myContributionsFiltersAction'),
          onPressed: () => _openSheet(context, ref),
          icon: const Icon(Icons.tune, size: 18),
          label: Text(l10n.myContributionsFiltersAction),
        ),
        if (query.status != null)
          InputChip(
            key: const Key('myContributionsActiveFilter_status'),
            label: Text(myContributionStatusLabel(l10n, query.status!)),
            tooltip: l10n.myContributionsClearFilterTooltip,
            onDeleted: () => _removeStatus(ref),
          ),
        if (query.contributionTypeId != null)
          InputChip(
            key: const Key('myContributionsActiveFilter_type'),
            label: Text(myContributionTypeLabel(l10n, typeName)),
            tooltip: l10n.myContributionsClearFilterTooltip,
            onDeleted: () => _removeType(ref),
          ),
        if (query.fromDate != null)
          InputChip(
            key: const Key('myContributionsActiveFilter_from'),
            label: Text(
              '${l10n.myContributionsFromLabel}: '
              '${formatMyContributionDate(query.fromDate!)}',
            ),
            tooltip: l10n.myContributionsClearFilterTooltip,
            onDeleted: () => _removeFrom(ref),
          ),
        if (query.toDate != null)
          InputChip(
            key: const Key('myContributionsActiveFilter_to'),
            label: Text(
              '${l10n.myContributionsToLabel}: '
              '${formatMyContributionDate(query.toDate!)}',
            ),
            tooltip: l10n.myContributionsClearFilterTooltip,
            onDeleted: () => _removeTo(ref),
          ),
        if (query.hasActiveFilters)
          TextButton(
            key: const Key('myContributionsClearAllFilters'),
            onPressed: () =>
                ref.read(myContributionsQueryProvider.notifier).clearFilters(),
            child: Text(l10n.myContributionsClearFiltersAction),
          ),
      ],
    );
  }

  /// Name from the backend's own filter options (never the loaded page).
  String? _typeNameFor(String id) {
    for (final option in contributionTypes) {
      if (option.id == id) return option.name;
    }
    return null;
  }
}
