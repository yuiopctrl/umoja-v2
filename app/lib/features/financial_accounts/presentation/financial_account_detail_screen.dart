import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/financial_account_form_controller.dart';
import '../domain/financial_account.dart';
import '../domain/financial_account_entry.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_entries_provider.dart';
import 'widgets/financial_account_labels.dart';

const _defaultLimit = 10;

/// `/financial-accounts/:accountId`: account detail — server-derived
/// balance, active/inactive state, and its immutable entries
/// (cashbook lines). No paid/unpaid contribution concept anywhere
/// here — this is the Prompt 08A cashbook, not the obligation ledger.
class FinancialAccountDetailScreen extends ConsumerStatefulWidget {
  const FinancialAccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<FinancialAccountDetailScreen> createState() =>
      _FinancialAccountDetailScreenState();
}

class _FinancialAccountDetailScreenState
    extends ConsumerState<FinancialAccountDetailScreen> {
  int _limit = _defaultLimit;

  Future<void> _toggleActive(String groupId, FinancialAccount account) async {
    await ref
        .read(financialAccountFormControllerProvider.notifier)
        .update(
          groupId: groupId,
          accountId: account.id,
          isActive: !account.isActive,
        );
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(
      financialAccountDetailProvider(widget.accountId),
    );
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canManage =
        membership?.hasPermission('financial_account.manage') ?? false;

    return UmojaPage(
      title: l10n.financialAccountsTitle,
      maxWidth: 700,
      backTo: AppRoutes.financialAccountsList,
      backLabel: l10n.financialAccountsTitle,
      body: accountAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(financialAccountDetailProvider(widget.accountId)),
        ),
        data: (account) => _DetailBody(
          account: account,
          canManage: canManage,
          limit: _limit,
          onLoadMore: () => setState(() => _limit += _defaultLimit),
          onToggleActive: membership == null
              ? null
              : () => _toggleActive(membership.group.groupId, account),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.account,
    required this.canManage,
    required this.limit,
    required this.onLoadMore,
    required this.onToggleActive,
  });

  final FinancialAccount account;
  final bool canManage;
  final int limit;
  final VoidCallback onLoadMore;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entriesQuery = (accountId: account.id, limit: limit);
    final entriesAsync = ref.watch(
      financialAccountEntriesProvider(entriesQuery),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                account.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
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
        Text(
          financialAccountTypeLabel(l10n, account.accountType),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaCard(
          padding: const EdgeInsets.symmetric(
            horizontal: UmojaSpacing.lg,
            vertical: UmojaSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.financialAccountBalanceLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    formatAmount(account.balance),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              if (canManage) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
                  child: Divider(height: 1),
                ),
                Wrap(
                  spacing: UmojaSpacing.md,
                  runSpacing: UmojaSpacing.md,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.financialAccountEditPath(account.id),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.financialAccountEditAction),
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleActive,
                      icon: Icon(
                        account.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 18,
                      ),
                      label: Text(
                        account.isActive
                            ? l10n.financialAccountDeactivateAction
                            : l10n.financialAccountActivateAction,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaSection(
          title: l10n.financialAccountEntriesTitle,
          child: entriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
            data: (page) {
              if (page.items.isEmpty) {
                return Text(l10n.financialAccountEntriesEmptyMessage);
              }
              return Column(
                children: [
                  for (final entry in page.items) _EntryRow(entry: entry),
                  if (page.hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UmojaSpacing.md,
                      ),
                      child: OutlinedButton(
                        onPressed: onLoadMore,
                        child: Text(l10n.loadMoreAction),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final FinancialAccountEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amountText =
        '${entry.isCredit ? '+' : '-'}${formatAmount(entry.amount)}';
    final description = entry.description;
    return UmojaListTile(
      // Names WHERE the money went/came from for a transfer entry
      // (e.g. "Uhamisho kwenda Cash Box") — never the bare
      // TRANSFER_OUT/TRANSFER_IN enum or a generic "Transfer Out"/
      // "Transfer In" with no counterparty.
      title: financialAccountEntryDisplayLabel(l10n, entry),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatKiswahiliDate(entry.effectiveAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          // The transfer direction/counterparty above is never
          // replaced by a description/reference — both are shown
          // alongside it, on their own line, when present.
          if (description != null && description.isNotEmpty)
            Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: Text(
        amountText,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: entry.isCredit ? null : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
