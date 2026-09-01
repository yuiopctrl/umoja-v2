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
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_account.dart';
import '../providers/loan_accounts_provider.dart';
import 'widgets/loan_labels.dart';

const _defaultLimit = 20;

/// `/loans/accounts`: every loan account in the group (Prompt 09A) —
/// only DRAFT and CANCELLED are actually reachable statuses yet.
/// Entry point for the New Loan draft workflow; no
/// approve/disburse/repayment action exists anywhere here.
class LoanAccountsListScreen extends ConsumerStatefulWidget {
  const LoanAccountsListScreen({super.key});

  @override
  ConsumerState<LoanAccountsListScreen> createState() =>
      _LoanAccountsListScreenState();
}

class _LoanAccountsListScreenState
    extends ConsumerState<LoanAccountsListScreen> {
  int _limit = _defaultLimit;

  @override
  void initState() {
    super.initState();
    ref.invalidate(loanAccountsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      membershipId: null,
      loanProductId: null,
      status: null,
      limit: _limit,
      offset: 0,
    );
    final pageAsync = ref.watch(loanAccountsProvider(query));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canCreate = membership?.hasPermission('loan.create') ?? false;

    return UmojaPage(
      title: l10n.loanAccountsTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.loansHome,
      backLabel: l10n.loansTitle,
      headerTrailing: canCreate
          ? UmojaPrimaryButton(
              label: l10n.newLoanAction,
              onPressed: () => context.push(AppRoutes.newLoanAccount),
            )
          : null,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const Key('newLoanAccountFab'),
              onPressed: () => context.push(AppRoutes.newLoanAccount),
              child: const Icon(Icons.add),
            )
          : null,
      body: pageAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(loanAccountsProvider(query)),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return UmojaEmptyState(
              icon: Icons.request_quote_outlined,
              title: l10n.loanAccountsEmptyTitle,
              message: l10n.loanAccountsEmptyMessage,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(loanAccountsProvider(query));
              await ref.read(loanAccountsProvider(query).future);
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
                return _LoanAccountRow(loan: page.items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _LoanAccountRow extends StatelessWidget {
  const _LoanAccountRow({required this.loan});

  final LoanAccount loan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: loan.borrowerDisplayName,
      subtitle: Text(
        '${loan.loanNumber} · ${loan.loanProductName}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatAmount(loan.principalAmount),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.xs),
          UmojaStatusBadge(
            label: loanAccountStatusLabel(l10n, loan.status),
            semantic: loanAccountStatusSemantic(loan.status),
          ),
        ],
      ),
      onTap: () => context.push(AppRoutes.loanAccountDetailPath(loan.id)),
    );
  }
}
