import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_account.dart';
import '../providers/financial_accounts_list_provider.dart';
import 'widgets/financial_account_labels.dart';

const _defaultLimit = 10;

/// `/financial-accounts`: every CASH/BANK/MOBILE_MONEY account in the
/// group, with its server-derived balance (Prompt 08A). Entry point
/// for creating a new account and for the internal transfer flow.
class FinancialAccountsListScreen extends ConsumerStatefulWidget {
  const FinancialAccountsListScreen({super.key});

  @override
  ConsumerState<FinancialAccountsListScreen> createState() =>
      _FinancialAccountsListScreenState();
}

class _FinancialAccountsListScreenState
    extends ConsumerState<FinancialAccountsListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _limit = _defaultLimit;

  @override
  void initState() {
    super.initState();
    // Force a refetch on every screen entry — a same-device account
    // creation/edit already invalidates these providers explicitly,
    // but that cannot reach a change made on another device/session
    // (e.g. Desktop creating an account while this screen sits
    // further back in Mobile's navigation stack, not yet disposed by
    // `.autoDispose`). See UAT-FIX-01.
    ref.invalidate(financialAccountsListProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _search = value;
        _limit = _defaultLimit;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _search, limit: _limit);
    final pageAsync = ref.watch(financialAccountsListProvider(query));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canManage =
        membership?.hasPermission('financial_account.manage') ?? false;
    final canTransfer =
        membership?.hasPermission('financial_account.transfer.create') ?? false;

    return UmojaPage(
      title: l10n.financialAccountsTitle,
      scrollable: false,
      maxWidth: 900,
      // "Transfer Funds" lives in the body below, not here — this
      // header only ever renders on desktop/tablet (see UmojaPage), so
      // a mobile user never saw it at all (UAT-FIX-03). Putting it in
      // the body instead makes it width-independent, with exactly one
      // instance on every platform rather than a duplicate on desktop.
      headerTrailing: canManage
          ? UmojaPrimaryButton(
              label: l10n.financialAccountNewAction,
              onPressed: () => context.push(AppRoutes.financialAccountNew),
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton(
              key: const Key('financialAccountNewFab'),
              onPressed: () => context.push(AppRoutes.financialAccountNew),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A single, width-independent action — visible identically
          // on mobile and desktop, so an authorized user always has
          // an obvious way to start a transfer regardless of platform
          // (UAT-FIX-03: previously only reachable via `headerTrailing`,
          // which never renders on mobile at all).
          if (canTransfer) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('financialAccountTransferFundsAction'),
                onPressed: () =>
                    context.push(AppRoutes.financialAccountTransfer),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(l10n.financialAccountTransferAction),
              ),
            ),
            const SizedBox(height: UmojaSpacing.md),
          ],
          UmojaSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: l10n.financialAccountsSearchHint,
          ),
          const SizedBox(height: UmojaSpacing.md),
          Expanded(
            child: pageAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () =>
                    ref.invalidate(financialAccountsListProvider(query)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: l10n.financialAccountsEmptyTitle,
                    message: l10n.financialAccountsEmptyMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(financialAccountsListProvider(query));
                    await ref.read(financialAccountsListProvider(query).future);
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
                      return _AccountRow(account: page.items[index]);
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final FinancialAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: account.name,
      subtitle: Text(
        financialAccountTypeLabel(l10n, account.accountType),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatAmount(account.balance),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.xs),
          UmojaStatusBadge(
            label: account.isActive
                ? l10n.financialAccountActiveBadge
                : l10n.financialAccountInactiveBadge,
            semantic: account.isActive
                ? UmojaStatusSemantic.success
                : UmojaStatusSemantic.neutral,
          ),
        ],
      ),
      onTap: () =>
          context.push(AppRoutes.financialAccountDetailPath(account.id)),
    );
  }
}
