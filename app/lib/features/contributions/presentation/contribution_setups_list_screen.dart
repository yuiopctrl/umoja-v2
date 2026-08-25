import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_setup.dart';
import '../providers/contribution_setups_list_provider.dart';
import '../providers/contribution_setups_query_provider.dart';
import 'widgets/contribution_setup_labels.dart';

const _fabScrollClearance = 96.0;

/// `/contributions/setups`: filterable, paginated contribution setup
/// list. Mirrors `MembersListScreen`'s pagination pattern; filters by
/// active/inactive only (type filter is reachable by arriving from a
/// specific type in a future enhancement — not required by this
/// foundation scope).
class ContributionSetupsListScreen extends ConsumerWidget {
  const ContributionSetupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final setupsAsync = ref.watch(contributionSetupsListProvider);
    final query = ref.watch(contributionSetupsQueryProvider);
    final l10n = context.l10n;

    final canManage =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('contribution.setup.manage');

    final activeFilters = <(String label, bool? value)>[
      (l10n.filterAll, null),
      (l10n.contributionFilterActiveOnly, true),
      (l10n.contributionFilterInactiveOnly, false),
    ];

    return UmojaPage(
      title: l10n.contributionSetupsTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.contributionsHome,
      backLabel: l10n.contributionsTitle,
      headerTrailing: canManage
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contributionSetupNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionSetupAction),
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.contributionSetupNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionSetupAction),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in activeFilters)
                ChoiceChip(
                  label: Text(filter.$1),
                  selected: query.isActive == filter.$2,
                  onSelected: (_) => ref
                      .read(contributionSetupsQueryProvider.notifier)
                      .setActiveFilter(filter.$2),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: setupsAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(contributionSetupsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return _SetupsEmptyState(
                    hasActiveFilters: query.isActive != null,
                    canManage: canManage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref
                        .read(contributionSetupsQueryProvider.notifier)
                        .resetPageSize();
                    ref.invalidate(contributionSetupsListProvider);
                    await ref.read(contributionSetupsListProvider.future);
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
                                    contributionSetupsQueryProvider.notifier,
                                  )
                                  .loadMore(),
                              child: Text(l10n.loadMoreAction),
                            ),
                          ),
                        );
                      }
                      final setup = page.items[index];
                      return _SetupRow(
                        setup: setup,
                        canManage: canManage,
                        onTap: canManage
                            ? () => context.push(
                                AppRoutes.contributionSetupEditPath(setup.id),
                              )
                            : null,
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

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.setup, required this.canManage, this.onTap});

  final ContributionSetup setup;
  final bool canManage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amountText = setup.isFixedAmount
        ? formatAmount(setup.fixedAmount ?? 0)
        : contributionAmountModeLabel(l10n, setup.amountMode);

    return UmojaListTile(
      title: setup.name,
      onTap: onTap,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${contributionScheduleModeLabel(l10n, setup.scheduleMode)} · $amountText',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!setup.isActive) ...[
            const SizedBox(height: 4),
            UmojaStatusBadge(
              label: l10n.contributionInactiveBadgeLabel,
              semantic: UmojaStatusSemantic.neutral,
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupsEmptyState extends StatelessWidget {
  const _SetupsEmptyState({
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
        title: l10n.contributionSetupsEmptyFilteredTitle,
        message: l10n.contributionSetupsEmptyFilteredMessage,
      );
    }
    return UmojaEmptyState(
      icon: Icons.tune_outlined,
      title: l10n.contributionSetupsEmptyTitle,
      message: l10n.contributionSetupsEmptyMessage,
      action: canManage
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contributionSetupNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionSetupAction),
            )
          : null,
    );
  }
}
