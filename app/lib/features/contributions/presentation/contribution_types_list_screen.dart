import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_type.dart';
import '../providers/contribution_types_list_provider.dart';
import '../providers/contribution_types_query_provider.dart';
import 'widgets/contribution_type_labels.dart';

const _fabScrollClearance = 96.0;

/// `/contributions/types`: searchable, filterable, paginated
/// contribution type list for the currently selected group. Mirrors
/// `MembersListScreen`'s structure/pagination exactly.
class ContributionTypesListScreen extends ConsumerStatefulWidget {
  const ContributionTypesListScreen({super.key});

  @override
  ConsumerState<ContributionTypesListScreen> createState() =>
      _ContributionTypesListScreenState();
}

class _ContributionTypesListScreenState
    extends ConsumerState<ContributionTypesListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(contributionTypesQueryProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final typesAsync = ref.watch(contributionTypesListProvider);
    final query = ref.watch(contributionTypesQueryProvider);
    final l10n = context.l10n;

    final canManage =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('contribution.type.manage');

    final activeFilters = <(String label, bool? value)>[
      (l10n.filterAll, null),
      (l10n.contributionFilterActiveOnly, true),
      (l10n.contributionFilterInactiveOnly, false),
    ];

    return UmojaPage(
      title: l10n.contributionTypesTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.contributionsHome,
      backLabel: l10n.contributionsTitle,
      headerTrailing: canManage
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contributionTypeNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionTypeAction),
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.contributionTypeNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionTypeAction),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: l10n.contributionTypesSearchHint,
          ),
          const SizedBox(height: UmojaSpacing.md),
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in activeFilters)
                ChoiceChip(
                  label: Text(filter.$1),
                  selected: query.isActive == filter.$2,
                  onSelected: (_) => ref
                      .read(contributionTypesQueryProvider.notifier)
                      .setActiveFilter(filter.$2),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: typesAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(contributionTypesListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return _TypesEmptyState(
                    hasActiveFilters:
                        query.search.isNotEmpty || query.isActive != null,
                    canManage: canManage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref
                        .read(contributionTypesQueryProvider.notifier)
                        .resetPageSize();
                    ref.invalidate(contributionTypesListProvider);
                    await ref.read(contributionTypesListProvider.future);
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
                                  .read(contributionTypesQueryProvider.notifier)
                                  .loadMore(),
                              child: Text(l10n.loadMoreAction),
                            ),
                          ),
                        );
                      }
                      final type = page.items[index];
                      return _TypeRow(
                        type: type,
                        canManage: canManage,
                        onTap: canManage
                            ? () => context.push(
                                AppRoutes.contributionTypeEditPath(type.id),
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

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.canManage, this.onTap});

  final ContributionType type;
  final bool canManage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: type.name,
      onTap: onTap,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${contributionCategoryLabel(l10n, type.category)} · '
            '${contributionAccountingTreatmentLabel(l10n, type.accountingTreatment)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!type.isActive) ...[
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

class _TypesEmptyState extends StatelessWidget {
  const _TypesEmptyState({
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
        title: l10n.contributionTypesEmptyFilteredTitle,
        message: l10n.contributionTypesEmptyFilteredMessage,
      );
    }
    return UmojaEmptyState(
      icon: Icons.category_outlined,
      title: l10n.contributionTypesEmptyTitle,
      message: l10n.contributionTypesEmptyMessage,
      action: canManage
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.contributionTypeNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.addContributionTypeAction),
            )
          : null,
    );
  }
}
