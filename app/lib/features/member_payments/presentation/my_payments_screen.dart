import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/shell/member_child_scaffold.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../l10n/app_localizations.dart';
import '../data/my_payments_failure.dart';
import '../domain/my_payment.dart';
import '../providers/my_payments_provider.dart';
import '../providers/my_payments_query_provider.dart';
import 'widgets/my_payment_labels.dart';
import 'widgets/my_payment_row.dart';
import 'widgets/my_payments_filter_sheet.dart';

/// `/me/payments`: the caller's OWN external payment history for the
/// currently selected group (Prompt 09G-B6-C). Backed only by
/// rpc_get_my_payments. A wallet application never appears here — only
/// real external payment rows. Officer Payment History lives separately
/// at `/payments`.
class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pageAsync = ref.watch(myPaymentsProvider);

    return MemberChildScaffold(
      title: l10n.myPaymentsTitle,
      scrollable: false,
      body: pageAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: _messageFor(context, error),
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myPaymentsProvider),
        ),
        data: (page) => _MyPaymentsContent(page: page),
      ),
    );
  }
}

String _messageFor(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is MyPaymentsFailure) {
    return myPaymentsFailureMessage(l10n, error, isDetail: false);
  }
  return l10n.myPaymentsLoadFailedMessage;
}

/// Safe, localized message for a My Payments failure. Raw PostgREST
/// text, SQLSTATEs, and RPC names are never shown. A not-found result on
/// a payment-scoped read is the same text whether the payment is
/// missing, foreign, or in another group.
String myPaymentsFailureMessage(
  AppLocalizations l10n,
  MyPaymentsFailure error, {
  required bool isDetail,
}) {
  return switch (error.type) {
    MyPaymentsFailureType.notAuthorized => l10n.myPaymentsNotAuthorizedMessage,
    MyPaymentsFailureType.notFound => l10n.myPaymentsNotFoundMessage,
    MyPaymentsFailureType.network => l10n.myPaymentsNetworkMessage,
    MyPaymentsFailureType.invalidDateRange => l10n.myPaymentsFromAfterToError,
    MyPaymentsFailureType.invalidRequest || MyPaymentsFailureType.unexpected =>
      isDetail
          ? l10n.myPaymentsDetailLoadFailedMessage
          : l10n.myPaymentsLoadFailedMessage,
  };
}

class _MyPaymentsContent extends ConsumerStatefulWidget {
  const _MyPaymentsContent({required this.page});

  final MyPaymentsPage page;

  @override
  ConsumerState<_MyPaymentsContent> createState() => _MyPaymentsContentState();
}

class _MyPaymentsContentState extends ConsumerState<_MyPaymentsContent> {
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    ref.read(myPaymentsQueryProvider.notifier).loadMore();
    try {
      await ref.read(myPaymentsProvider.future);
    } catch (_) {
      // Surfaced through the provider's AsyncError on the next watch;
      // the already-loaded rows stay visible underneath.
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _refresh() async {
    ref.read(myPaymentsQueryProvider.notifier).resetPageSize();
    ref.invalidate(myPaymentsProvider);
    await ref.read(myPaymentsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = widget.page;
    final query = ref.watch(myPaymentsQueryProvider);
    final nextPageAsync = ref.watch(myPaymentsProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterBar(query: query),
            const SizedBox(height: UmojaSpacing.lg),
            if (page.items.isEmpty)
              UmojaEmptyState(
                key: Key(
                  query.hasActiveFilters
                      ? 'myPaymentsEmptyFiltered'
                      : 'myPaymentsEmpty',
                ),
                icon: Icons.payments_outlined,
                title: query.hasActiveFilters
                    ? l10n.myPaymentsEmptyFilteredTitle
                    : l10n.myPaymentsEmptyTitle,
                message: query.hasActiveFilters
                    ? null
                    : l10n.myPaymentsEmptyMessage,
              )
            else ...[
              _buildList(context, page.items),
              if (nextPageAsync.hasError && !_loadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UmojaSpacing.sm,
                  ),
                  child: Text(
                    l10n.myPaymentsLoadMoreFailedMessage,
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
                      key: const Key('myPaymentsLoadMoreAction'),
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

  Widget _buildList(BuildContext context, List<MyPayment> items) {
    return Column(
      key: const Key('myPaymentsList'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          MyPaymentRow(
            item: items[i],
            onTap: () =>
                context.push(AppRoutes.myPaymentDetailPath(items[i].paymentId)),
          ),
        ],
      ],
    );
  }
}

/// Compact filter entry point plus removable chips for each active
/// filter. Removing a chip clears only that filter; "Clear Filters"
/// clears all of them. Every change refetches from the backend and
/// resets pagination to the first page (handled by the query notifier).
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.query});

  final MyPaymentsQuery query;

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final result = await showMyPaymentsFilterSheet(
      context,
      current: MyPaymentsFilters(
        status: query.status,
        fromDate: query.fromDate,
        toDate: query.toDate,
      ),
    );
    if (result == null) return;
    ref
        .read(myPaymentsQueryProvider.notifier)
        .applyFilters(
          status: result.status,
          fromDate: result.fromDate,
          toDate: result.toDate,
        );
  }

  void _removeStatus(WidgetRef ref) {
    ref
        .read(myPaymentsQueryProvider.notifier)
        .applyFilters(fromDate: query.fromDate, toDate: query.toDate);
  }

  void _removeFrom(WidgetRef ref) {
    ref
        .read(myPaymentsQueryProvider.notifier)
        .applyFilters(status: query.status, toDate: query.toDate);
  }

  void _removeTo(WidgetRef ref) {
    ref
        .read(myPaymentsQueryProvider.notifier)
        .applyFilters(status: query.status, fromDate: query.fromDate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Wrap(
      spacing: UmojaSpacing.sm,
      runSpacing: UmojaSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('myPaymentsFiltersAction'),
          onPressed: () => _openSheet(context, ref),
          icon: const Icon(Icons.tune, size: 18),
          label: Text(l10n.myPaymentsFiltersAction),
        ),
        if (query.status != null)
          InputChip(
            key: const Key('myPaymentsActiveFilter_status'),
            label: Text(myPaymentStatusLabel(l10n, query.status!)),
            tooltip: l10n.myPaymentsClearFilterTooltip,
            onDeleted: () => _removeStatus(ref),
          ),
        if (query.fromDate != null)
          InputChip(
            key: const Key('myPaymentsActiveFilter_from'),
            label: Text(
              '${l10n.myPaymentsFromLabel}: '
              '${formatMyPaymentDate(query.fromDate!)}',
            ),
            tooltip: l10n.myPaymentsClearFilterTooltip,
            onDeleted: () => _removeFrom(ref),
          ),
        if (query.toDate != null)
          InputChip(
            key: const Key('myPaymentsActiveFilter_to'),
            label: Text(
              '${l10n.myPaymentsToLabel}: '
              '${formatMyPaymentDate(query.toDate!)}',
            ),
            tooltip: l10n.myPaymentsClearFilterTooltip,
            onDeleted: () => _removeTo(ref),
          ),
        if (query.hasActiveFilters)
          TextButton(
            key: const Key('myPaymentsClearAllFilters'),
            onPressed: () =>
                ref.read(myPaymentsQueryProvider.notifier).clearFilters(),
            child: Text(l10n.myPaymentsClearFiltersAction),
          ),
      ],
    );
  }
}
