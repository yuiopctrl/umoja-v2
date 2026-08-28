import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_opening_balance_item.dart';
import '../providers/contribution_opening_balances_list_provider.dart';

const _defaultLimit = 10;

/// `/contributions/opening-balances`: dedicated report of every posted
/// OPENING_BALANCE charge (Prompt 06C) — deliberately separate from the
/// normal periods/charges screens, which always exclude these system
/// periods. The only entry point into the batch import flow.
class ContributionOpeningBalancesScreen extends ConsumerStatefulWidget {
  const ContributionOpeningBalancesScreen({super.key});

  @override
  ConsumerState<ContributionOpeningBalancesScreen> createState() =>
      _ContributionOpeningBalancesScreenState();
}

class _ContributionOpeningBalancesScreenState
    extends ConsumerState<ContributionOpeningBalancesScreen> {
  int _limit = _defaultLimit;

  @override
  Widget build(BuildContext context) {
    final query = (contributionTypeId: null, limit: _limit);
    final pageAsync = ref.watch(contributionOpeningBalancesListProvider(query));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final canManage =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission(
          'contribution.opening_balance.manage',
        );

    return UmojaPage(
      title: l10n.openingBalancesTitle,
      scrollable: false,
      maxWidth: 900,
      headerTrailing: canManage
          ? UmojaPrimaryButton(
              label: l10n.openingBalanceImportAction,
              onPressed: () =>
                  context.push(AppRoutes.contributionOpeningBalanceImport),
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton(
              key: const Key('openingBalanceImportFab'),
              onPressed: () =>
                  context.push(AppRoutes.contributionOpeningBalanceImport),
              child: const Icon(Icons.add),
            )
          : null,
      body: pageAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(contributionOpeningBalancesListProvider(query)),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return UmojaEmptyState(
              icon: Icons.history_edu_outlined,
              title: l10n.openingBalancesEmptyTitle,
              message: l10n.openingBalancesEmptyMessage,
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
                      onPressed: () => setState(() => _limit += _defaultLimit),
                      child: Text(l10n.loadMoreAction),
                    ),
                  ),
                );
              }
              return _OpeningBalanceRow(item: page.items[index]);
            },
          );
        },
      ),
    );
  }
}

class _OpeningBalanceRow extends StatelessWidget {
  const _OpeningBalanceRow({required this.item});

  final ContributionOpeningBalanceItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: item.memberNameSnapshot,
      subtitle: Text(
        '${item.memberNumberSnapshot} · ${item.contributionTypeName} · '
        '${l10n.contributionEffectiveDateFieldLabel}: '
        '${formatKiswahiliDate(item.effectiveAt)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Text(
        formatAmount(item.netAssessed),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
