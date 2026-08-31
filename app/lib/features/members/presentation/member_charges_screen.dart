import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../../payments/domain/member_contribution_charge.dart';
import '../../payments/presentation/widgets/payment_labels.dart';
import '../../payments/providers/member_contribution_charges_provider.dart';
import '../../payments/providers/member_contribution_statement_provider.dart';

const _defaultLimit = 10;
const _filters = ['OUTSTANDING', 'ALL', 'SETTLED', 'OVERDUE'];

String _filterLabel(AppLocalizations l10n, String filter) {
  return switch (filter) {
    'ALL' => l10n.filterAll,
    'OUTSTANDING' => l10n.filterOutstanding,
    'SETTLED' => l10n.filterSettled,
    'OVERDUE' => l10n.filterOverdue,
    _ => filter,
  };
}

/// `/members/:membershipId/charges`: the member-centric Charges/Madeni
/// view (Prompt 07 UAT-FIX-03) — every contribution charge for one
/// member across every period, so the treasurer never has to open each
/// contribution period individually to see one member's full charge
/// history. Reuses the existing Contribution Charge Detail screen for
/// per-charge drill-down and the existing Record Payment/Member Wallet
/// flows for its shortcuts — no duplicate implementation of any of
/// those here.
class MemberChargesScreen extends ConsumerStatefulWidget {
  const MemberChargesScreen({super.key, required this.membershipId});

  final String membershipId;

  @override
  ConsumerState<MemberChargesScreen> createState() =>
      _MemberChargesScreenState();
}

class _MemberChargesScreenState extends ConsumerState<MemberChargesScreen> {
  String _filter = 'OUTSTANDING';
  int _limit = _defaultLimit;

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _limit = _defaultLimit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canViewWallet = membership?.hasPermission('wallet.view') ?? false;
    final canRecordPayment =
        membership?.hasPermission('payment.create') ?? false;

    final statementAsync = ref.watch(
      memberContributionStatementProvider(widget.membershipId),
    );
    final chargesQuery = (
      membershipId: widget.membershipId,
      filter: _filter,
      limit: _limit,
    );
    final chargesAsync = ref.watch(
      memberContributionChargesProvider(chargesQuery),
    );

    return UmojaPage(
      title: l10n.memberChargesTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.memberDetailPath(widget.membershipId),
      backLabel: l10n.memberDetailTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statementAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (statement) => _SummaryCard(
              totalOutstanding: statement.totalOutstanding,
              totalAllocated: statement.totalAllocated,
              walletBalance: statement.walletBalance,
              canViewWallet: canViewWallet,
              onTapWallet: () =>
                  context.push(AppRoutes.walletDetailPath(widget.membershipId)),
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          if (canRecordPayment)
            UmojaPrimaryButton(
              key: const Key('memberChargesRecordPaymentAction'),
              label: l10n.recordPaymentAction,
              onPressed: () => context.push(
                AppRoutes.paymentRecordPath(widget.membershipId),
              ),
            ),
          const SizedBox(height: UmojaSpacing.lg),
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in _filters)
                ChoiceChip(
                  label: Text(_filterLabel(l10n, filter)),
                  selected: _filter == filter,
                  onSelected: (_) => _setFilter(filter),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: chargesAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(
                  memberContributionChargesProvider(chargesQuery),
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _filter == 'OUTSTANDING'
                        ? l10n.memberChargesEmptyOutstandingMessage
                        : l10n.memberChargesEmptyMessage,
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
                            onPressed: () =>
                                setState(() => _limit += _defaultLimit),
                            child: Text(l10n.loadMoreAction),
                          ),
                        ),
                      );
                    }
                    return _ChargeRow(charge: page.items[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalOutstanding,
    required this.totalAllocated,
    required this.walletBalance,
    required this.canViewWallet,
    required this.onTapWallet,
  });

  final double totalOutstanding;
  final double totalAllocated;
  final double walletBalance;
  final bool canViewWallet;
  final VoidCallback onTapWallet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaCard(
      padding: const EdgeInsets.all(UmojaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            key: const Key('memberChargesOutstandingRow'),
            label: l10n.paymentSummaryOutstandingLabel,
            value: formatAmount(totalOutstanding),
          ),
          const SizedBox(height: UmojaSpacing.sm),
          _SummaryRow(
            label: l10n.memberChargesTotalAllocatedLabel,
            value: formatAmount(totalAllocated),
          ),
          if (canViewWallet) ...[
            const SizedBox(height: UmojaSpacing.sm),
            InkWell(
              key: const Key('memberChargesWalletRow'),
              onTap: onTapWallet,
              child: _SummaryRow(
                label: l10n.memberWalletTitle,
                value: formatAmount(walletBalance),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.charge});

  final MemberCharge charge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () =>
          context.push(AppRoutes.contributionChargeDetailPath(charge.chargeId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    obligationContextLabel(
                      contributionTypeName: charge.contributionTypeName,
                      periodLabel: charge.periodLabel,
                      periodPurpose: charge.periodPurpose,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (charge.isOverdue)
                  UmojaStatusBadge(
                    label: l10n.filterOverdue,
                    semantic: UmojaStatusSemantic.danger,
                  ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.xs),
            Text(
              '${l10n.contributionDueDateLabel}: '
              '${formatKiswahiliDate(charge.dueDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            for (final component in charge.components)
              Padding(
                padding: const EdgeInsets.only(bottom: UmojaSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      contributionComponentTypeLabel(
                        l10n,
                        component.componentType,
                      ),
                    ),
                    Text(
                      formatAmount(component.amount),
                      style: TextStyle(
                        color: component.amount < 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: UmojaSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.chargeOutstandingLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  formatAmount(charge.outstanding),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
