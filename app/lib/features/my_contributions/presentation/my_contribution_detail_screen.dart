import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../app/shell/member_child_scaffold.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../data/my_contributions_failure.dart';
import '../domain/my_contribution.dart';
import '../providers/my_contribution_detail_provider.dart';
import 'widgets/my_contribution_labels.dart';

/// `/me/contributions/:chargeId`: one of the caller's own charges, with
/// the backend's canonical position, component breakdown, and settlement
/// history (Prompt 09G-B4-C §P–§R). Nothing is derived from the list row
/// or recomputed here.
class MyContributionDetailScreen extends ConsumerWidget {
  const MyContributionDetailScreen({super.key, required this.chargeId});

  final String chargeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detailAsync = ref.watch(myContributionDetailProvider(chargeId));

    return MemberChildScaffold(
      title: l10n.myContributionsDetailTitle,
      scrollable: false,
      body: detailAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: _messageFor(context, error),
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myContributionDetailProvider(chargeId)),
        ),
        data: (detail) => _MyContributionDetailContent(detail: detail),
      ),
    );
  }
}

String _messageFor(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is MyContributionsFailure) {
    return myContributionsFailureMessage(l10n, error, isDetail: true);
  }
  return l10n.myContributionsDetailLoadFailedMessage;
}

class _MyContributionDetailContent extends StatelessWidget {
  const _MyContributionDetailContent({required this.detail});

  final MyContributionDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final periodContext = myContributionPeriodContext(
      l10n,
      purpose: detail.periodPurpose,
      periodLabel: detail.periodLabel,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      myContributionTypeLabel(
                        l10n,
                        detail.contributionTypeName,
                      ),
                      key: const Key('myContributionDetailTypeName'),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (periodContext != null)
                      Text(periodContext, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: UmojaSpacing.sm),
              UmojaStatusBadge(
                key: const Key('myContributionDetailStatus'),
                label: myContributionStatusLabel(l10n, detail.status),
                semantic: myContributionStatusSemantic(detail.status),
              ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            detail.dueDate == null
                ? '${l10n.myContributionsEffectiveDateLabel}: '
                      '${formatMyContributionDate(detail.effectiveAt)}'
                : '${l10n.myContributionsEffectiveDateLabel}: '
                      '${formatMyContributionDate(detail.effectiveAt)}'
                      '  •  '
                      '${l10n.myContributionsDueDateLabel}: '
                      '${formatMyContributionDate(detail.dueDate!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: UmojaSpacing.xl),
          Text(
            l10n.myContributionsPositionTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.sm),
          UmojaCard(
            key: const Key('myContributionDetailPosition'),
            child: Column(
              children: [
                _PositionRow(
                  label: l10n.myContributionsNetAssessedLabel,
                  value: formatAmount(detail.netAssessed),
                ),
                const Divider(height: UmojaSpacing.lg),
                _PositionRow(
                  label: l10n.myContributionsAllocatedLabel,
                  value: formatAmount(detail.allocatedAmount),
                ),
                const Divider(height: UmojaSpacing.lg),
                _PositionRow(
                  label: l10n.myContributionsOutstandingLabel,
                  value: formatAmount(detail.outstanding),
                  emphasized: true,
                ),
              ],
            ),
          ),
          if (detail.components.isNotEmpty) ...[
            const SizedBox(height: UmojaSpacing.xl),
            Text(
              l10n.myContributionsComponentsTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaCard(
              padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < detail.components.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ComponentTile(
                      key: Key(
                        'myContributionComponent_${detail.components[i].componentId}',
                      ),
                      component: detail.components[i],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: UmojaSpacing.xl),
          Text(
            l10n.myContributionsSettlementHistoryTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.sm),
          if (detail.settlementHistory.isEmpty)
            Text(
              l10n.myContributionsNoSettlementsMessage,
              key: const Key('myContributionSettlementsEmpty'),
              style: theme.textTheme.bodyMedium,
            )
          else
            UmojaCard(
              padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < detail.settlementHistory.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _SettlementTile(
                      key: Key(
                        'mySettlement_${detail.settlementHistory[i].allocationId}',
                      ),
                      settlement: detail.settlementHistory[i],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// One component. Signed backend values are shown as returned, so a
/// negative WAIVER or ADJUSTMENT reads as a negative correction. A null
/// per-component field is omitted, never shown as a fabricated zero.
class _ComponentTile extends StatelessWidget {
  const _ComponentTile({super.key, required this.component});

  final MyContributionComponent component;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  myContributionComponentLabel(l10n, component.componentType),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                formatAmount(component.assessedAmount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (component.netEffect != null)
            Text(
              '${l10n.myContributionsNetAssessedLabel}: '
              '${formatAmount(component.netEffect!)}',
              style: muted,
            ),
          if (component.allocated != null)
            Text(
              '${l10n.myContributionsAllocatedLabel}: '
              '${formatAmount(component.allocated!)}',
              style: muted,
            ),
          if (component.outstanding != null)
            Text(
              '${l10n.myContributionsOutstandingLabel}: '
              '${formatAmount(component.outstanding!)}',
              style: muted,
            ),
        ],
      ),
    );
  }
}

/// One settlement. A WALLET settlement is labeled as a wallet settlement,
/// never as a new payment. A reversed payment stays visible with its
/// Reversed badge and does not count toward the position above.
class _SettlementTile extends StatelessWidget {
  const _SettlementTile({super.key, required this.settlement});

  final MyContributionSettlement settlement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isWallet = settlement.source == MyContributionSettlementSource.wallet;
    final sourceLabel = isWallet
        ? l10n.myContributionsSettlementWalletLabel
        : l10n.myContributionsSettlementPaymentLabel;
    final receipt = settlement.receiptNumber;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sourceLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatAmount(settlement.amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(formatMyContributionDate(settlement.effectiveAt), style: muted),
          if (isWallet)
            Text(l10n.myContributionsWalletSettlementHint, style: muted)
          else if (receipt != null && receipt.isNotEmpty)
            Text(l10n.myContributionsReceiptLabel(receipt), style: muted),
          if (settlement.reversed) ...[
            const SizedBox(height: UmojaSpacing.xs),
            Row(
              children: [
                UmojaStatusBadge(
                  key: Key('mySettlementReversed_${settlement.allocationId}'),
                  label: l10n.myContributionsReversedLabel,
                  semantic: UmojaStatusSemantic.neutral,
                ),
                const SizedBox(width: UmojaSpacing.sm),
                Expanded(
                  child: Text(l10n.myContributionsReversedHint, style: muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
