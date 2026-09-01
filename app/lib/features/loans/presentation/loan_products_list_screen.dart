import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_product.dart';
import '../providers/loan_products_provider.dart';
import 'widgets/loan_labels.dart';

const _defaultLimit = 20;

/// `/loans/products`: every loan product (reusable lending policy) in
/// the group — Prompt 09A. Entry point for creating/editing a product.
/// Editing here never affects loan accounts already created from a
/// product — see docs/product/loans.md's snapshot rule.
class LoanProductsListScreen extends ConsumerStatefulWidget {
  const LoanProductsListScreen({super.key});

  @override
  ConsumerState<LoanProductsListScreen> createState() =>
      _LoanProductsListScreenState();
}

class _LoanProductsListScreenState
    extends ConsumerState<LoanProductsListScreen> {
  bool? _isActiveFilter;
  int _limit = _defaultLimit;

  @override
  void initState() {
    super.initState();
    // Re-entering this screen always refetches, matching the
    // `financialAccountsListProvider` re-entry precedent (UAT-FIX-01).
    ref.invalidate(loanProductsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final query = (isActive: _isActiveFilter, limit: _limit, offset: 0);
    final pageAsync = ref.watch(loanProductsProvider(query));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canManage = membership?.hasPermission('loan_product.manage') ?? false;

    return UmojaPage(
      title: l10n.loanProductsTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.loansHome,
      backLabel: l10n.loansTitle,
      headerTrailing: canManage
          ? UmojaPrimaryButton(
              label: l10n.loanProductNewAction,
              onPressed: () => context.push(AppRoutes.loanProductNew),
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton(
              key: const Key('loanProductNewFab'),
              onPressed: () => context.push(AppRoutes.loanProductNew),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool?>(
            key: const Key('loanProductsActiveFilter'),
            segments: [
              ButtonSegment(value: null, label: Text(l10n.filterAll)),
              ButtonSegment(
                value: true,
                label: Text(l10n.loanProductActiveBadge),
              ),
              ButtonSegment(
                value: false,
                label: Text(l10n.loanProductInactiveBadge),
              ),
            ],
            selected: {_isActiveFilter},
            onSelectionChanged: (selection) =>
                setState(() => _isActiveFilter = selection.first),
          ),
          const SizedBox(height: UmojaSpacing.md),
          Expanded(
            child: pageAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(loanProductsProvider(query)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.local_atm_outlined,
                    title: l10n.loanProductsEmptyTitle,
                    message: l10n.loanProductsEmptyMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(loanProductsProvider(query));
                    await ref.read(loanProductsProvider(query).future);
                  },
                  child: ListView.separated(
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
                      return _LoanProductRow(product: page.items[index]);
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

class _LoanProductRow extends StatelessWidget {
  const _LoanProductRow({required this.product});

  final LoanProduct product;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: product.name,
      subtitle: Text(
        '${product.code} · ${loanInterestMethodLabel(l10n, product.interestMethod)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: UmojaStatusBadge(
        label: product.isActive
            ? l10n.loanProductActiveBadge
            : l10n.loanProductInactiveBadge,
        semantic: product.isActive
            ? UmojaStatusSemantic.success
            : UmojaStatusSemantic.neutral,
      ),
      onTap: () => context.push(AppRoutes.loanProductEditPath(product.id)),
    );
  }
}
