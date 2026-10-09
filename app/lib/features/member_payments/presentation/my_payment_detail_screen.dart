import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/shell/member_child_scaffold.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../data/my_payments_failure.dart';
import '../domain/my_payment.dart';
import '../providers/my_payment_detail_provider.dart';
import 'my_payments_screen.dart' show myPaymentsFailureMessage;
import 'widgets/my_payment_labels.dart';

/// `/me/payments/:paymentId`: one of the caller's OWN payments. Backed
/// by rpc_get_my_payment_detail — never derived from the list row
/// (Prompt 09G-B6-C §O). The backend's single payment amount/date is
/// the ONE header shown; allocations are breakdown only, never a second
/// payment; a payment-created wallet credit stays inside this same
/// payment's section; a reversed payment stays visible with its
/// reversal state. There is no running balance in B6.
class MyPaymentDetailScreen extends ConsumerWidget {
  const MyPaymentDetailScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detailAsync = ref.watch(myPaymentDetailProvider(paymentId));

    return MemberChildScaffold(
      title: l10n.myPaymentsDetailTitle,
      scrollable: false,
      body: detailAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: _messageFor(context, error),
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myPaymentDetailProvider(paymentId)),
        ),
        data: (detail) => _DetailContent(detail: detail),
      ),
    );
  }
}

String _messageFor(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is MyPaymentsFailure) {
    return myPaymentsFailureMessage(l10n, error, isDetail: true);
  }
  return l10n.myPaymentsDetailLoadFailedMessage;
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.detail});

  final MyPaymentDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final payment = detail.payment;
    final isReversed = payment.status == MyPaymentStatus.reversed;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Payment Details — ONE header, the backend's canonical
          // amount/date, never a derived sum of the allocations below.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatAmount(payment.amount),
                      key: const Key('myPaymentDetailAmount'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatMyPaymentDate(payment.effectiveAt),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UmojaSpacing.sm),
              UmojaStatusBadge(
                key: const Key('myPaymentDetailStatus'),
                label: myPaymentStatusLabel(l10n, payment.status),
                semantic: myPaymentStatusSemantic(payment.status),
              ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          UmojaCard(
            key: const Key('myPaymentDetailCard'),
            child: Column(
              children: [
                _DetailRow(
                  label: l10n.myPaymentsMethodLabel,
                  value: myPaymentMethodLabel(l10n, payment.paymentMethod),
                ),
                if (payment.receiptNumber != null) ...[
                  const Divider(height: UmojaSpacing.lg),
                  _DetailRow(
                    label: l10n.myPaymentsReceiptNumberLabel,
                    value: payment.receiptNumber!,
                  ),
                ],
                if (payment.externalReference != null &&
                    payment.externalReference!.isNotEmpty) ...[
                  const Divider(height: UmojaSpacing.lg),
                  _DetailRow(
                    label: l10n.myPaymentsExternalReferenceLabel,
                    value: payment.externalReference!,
                  ),
                ],
              ],
            ),
          ),

          // 2. Reversal — only when REVERSED. Never reversed_by, never
          // a second negative payment.
          if (isReversed) ...[
            const SizedBox(height: UmojaSpacing.xl),
            UmojaCard(
              key: const Key('myPaymentDetailReversalCard'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.myPaymentsReversedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (payment.reversalReason != null &&
                      payment.reversalReason!.isNotEmpty) ...[
                    const SizedBox(height: UmojaSpacing.xs),
                    Text(
                      payment.reversalReason!,
                      key: const Key('myPaymentDetailReversalReason'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // 3. Breakdown — allocations, grouped by domain for
          // readability. Never a second payment amount.
          if (detail.allocations.isNotEmpty) ...[
            const SizedBox(height: UmojaSpacing.xl),
            Text(
              l10n.myPaymentsBreakdownTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            _AllocationsCard(allocations: detail.allocations),
          ],

          // 4. Wallet credit — THIS payment's own credit, never implied
          // as extra cash received.
          if (detail.walletCredit != null) ...[
            const SizedBox(height: UmojaSpacing.xl),
            Text(
              l10n.myPaymentsWalletCreditTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            _WalletCreditCard(walletCredit: detail.walletCredit!),
          ],

          // 5. View Receipt.
          const SizedBox(height: UmojaSpacing.xl),
          if (payment.receiptNumber != null)
            OutlinedButton.icon(
              key: const Key('myPaymentViewReceiptAction'),
              onPressed: () => context.push(
                AppRoutes.myPaymentReceiptPath(payment.paymentId),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n.myPaymentsViewReceiptAction),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: UmojaSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

/// Allocations grouped by domain (Contributions / Loans) — Prompt
/// 09G-B6-C §S: the header above remains the single payment amount; a
/// cross-domain payment is still exactly one payment with two groups of
/// breakdown lines, never two payments.
class _AllocationsCard extends StatelessWidget {
  const _AllocationsCard({required this.allocations});

  final List<MyPaymentAllocation> allocations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final contributionLines = allocations
        .where(
          (a) =>
              a.targetType ==
              MyPaymentAllocationTargetType.contributionComponent,
        )
        .toList(growable: false);
    final loanLines = allocations
        .where((a) => a.targetType.isLoanTarget)
        .toList(growable: false);
    final otherLines = allocations
        .where(
          (a) =>
              a.targetType !=
                  MyPaymentAllocationTargetType.contributionComponent &&
              !a.targetType.isLoanTarget,
        )
        .toList(growable: false);
    final showGroupLabels =
        contributionLines.isNotEmpty && loanLines.isNotEmpty;

    return UmojaCard(
      key: const Key('myPaymentAllocationsCard'),
      padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGroupLabels && contributionLines.isNotEmpty)
            _GroupLabel(l10n.myPaymentsContributionsGroupLabel),
          for (final allocation in contributionLines)
            _AllocationTile(allocation: allocation),
          if (showGroupLabels && loanLines.isNotEmpty)
            _GroupLabel(l10n.myPaymentsLoansGroupLabel),
          for (final allocation in loanLines)
            _AllocationTile(allocation: allocation),
          for (final allocation in otherLines)
            _AllocationTile(allocation: allocation),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AllocationTile extends StatelessWidget {
  const _AllocationTile({required this.allocation});

  final MyPaymentAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isContribution =
        allocation.targetType ==
        MyPaymentAllocationTargetType.contributionComponent;

    return Padding(
      key: Key('myPaymentAllocation_${allocation.allocationId}'),
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isContribution
                      ? myPaymentComponentLabel(l10n, allocation.componentType)
                      : myPaymentAllocationTargetLabel(
                          l10n,
                          allocation.targetType,
                        ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                formatAmount(allocation.amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isContribution && allocation.contributionTypeName != null)
            Text(allocation.contributionTypeName!, style: muted),
          if (isContribution && allocation.periodLabel != null)
            Text(allocation.periodLabel!, style: muted),
          if (!isContribution && allocation.loanNumber != null)
            Text(
              '${l10n.myPaymentsLoanNumberLabel} ${allocation.loanNumber}',
              style: muted,
            ),
          if (!isContribution && allocation.installmentNumber != null)
            Text(
              l10n.myPaymentsInstallmentLabel(allocation.installmentNumber!),
              style: muted,
            ),
        ],
      ),
    );
  }
}

/// Prompt 09G-B6-C §T: shown as context of the SAME payment, never as a
/// separate cash event, and never used to compute a wallet balance here.
class _WalletCreditCard extends StatelessWidget {
  const _WalletCreditCard({required this.walletCredit});

  final MyPaymentWalletCredit walletCredit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return UmojaCard(
      key: const Key('myPaymentWalletCreditCard'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatAmount(walletCredit.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (walletCredit.isReversed)
            UmojaStatusBadge(
              key: const Key('myPaymentWalletCreditReversed'),
              label: l10n.myPaymentsReversedTitle,
              semantic: UmojaStatusSemantic.neutral,
            ),
        ],
      ),
    );
  }
}
