import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_period.dart';
import '../providers/contribution_periods_list_provider.dart';
import '../providers/contribution_periods_query_provider.dart';
import 'widgets/contribution_period_status_badge.dart';

const _fabScrollClearance = 96.0;
const _statuses = ['DRAFT', 'SCHEDULED', 'OPEN', 'CLOSED', 'CANCELLED'];

/// `/contributions/periods`: filterable, paginated contribution period
/// list, grouped visually by status via [ContributionPeriodStatusBadge].
/// Mirrors `MembersListScreen`'s pagination pattern.
class ContributionPeriodsListScreen extends ConsumerWidget {
  const ContributionPeriodsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final periodsAsync = ref.watch(contributionPeriodsListProvider);
    final query = ref.watch(contributionPeriodsQueryProvider);
    final l10n = context.l10n;

    final canManage =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('contribution.period.manage');

    final statusFilters = <(String label, String? value)>[
      (l10n.filterAll, null),
      for (final status in _statuses)
        (contributionPeriodStatusLabel(l10n, status), status),
    ];

    return UmojaPage(
      title: l10n.contributionPeriodsTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.contributionsHome,
      backLabel: l10n.contributionsTitle,
      headerTrailing: canManage
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contributionPeriodNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionPeriodAction),
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.contributionPeriodNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionPeriodAction),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in statusFilters)
                ChoiceChip(
                  label: Text(filter.$1),
                  selected: query.status == filter.$2,
                  onSelected: (_) => ref
                      .read(contributionPeriodsQueryProvider.notifier)
                      .setStatusFilter(filter.$2),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: periodsAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(contributionPeriodsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return _PeriodsEmptyState(
                    hasActiveFilters: query.status != null,
                    canManage: canManage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref
                        .read(contributionPeriodsQueryProvider.notifier)
                        .resetPageSize();
                    ref.invalidate(contributionPeriodsListProvider);
                    await ref.read(contributionPeriodsListProvider.future);
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.only(
                      bottom: canManage ? _fabScrollClearance : 0,
                    ),
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
                              onPressed: () => ref
                                  .read(
                                    contributionPeriodsQueryProvider.notifier,
                                  )
                                  .loadMore(),
                              child: Text(l10n.loadMoreAction),
                            ),
                          ),
                        );
                      }
                      final period = page.items[index];
                      return _PeriodRow(
                        period: period,
                        onTap: () => context.push(
                          AppRoutes.contributionPeriodDetailPath(period.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.onTap});

  final ContributionPeriod period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: period.label,
      onTap: onTap,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l10n.contributionDueDateLabel}: ${formatKiswahiliDate(period.dueDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          ContributionPeriodStatusBadge(status: period.status),
        ],
      ),
    );
  }
}

class _PeriodsEmptyState extends StatelessWidget {
  const _PeriodsEmptyState({
    required this.hasActiveFilters,
    required this.canManage,
  });

  final bool hasActiveFilters;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (hasActiveFilters) {
      return UmojaEmptyState(
        icon: Icons.search_off,
        title: l10n.contributionPeriodsEmptyFilteredTitle,
        message: l10n.contributionPeriodsEmptyFilteredMessage,
      );
    }
    return UmojaEmptyState(
      icon: Icons.event_note_outlined,
      title: l10n.contributionPeriodsEmptyTitle,
      message: l10n.contributionPeriodsEmptyMessage,
      action: canManage
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contributionPeriodNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionPeriodAction),
            )
          : null,
    );
  }
}
