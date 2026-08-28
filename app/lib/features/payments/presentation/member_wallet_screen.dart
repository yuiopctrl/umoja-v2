import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../controllers/wallet_allocation_controller.dart';
import '../controllers/wallet_allocation_preview_controller.dart';
import '../providers/member_wallet_provider.dart';
import 'widgets/payment_labels.dart';

const _defaultLimit = 10;

/// `/wallet/:membershipId`: current balance, ledger/history, and (if
/// permitted) an allocate action — never presented as group cash
/// (section 34).
class MemberWalletScreen extends ConsumerStatefulWidget {
  const MemberWalletScreen({super.key, required this.membershipId});

  final String membershipId;

  @override
  ConsumerState<MemberWalletScreen> createState() => _MemberWalletScreenState();
}

class _MemberWalletScreenState extends ConsumerState<MemberWalletScreen> {
  int _limit = _defaultLimit;

  @override
  void initState() {
    super.initState();
    ref.invalidate(
      memberWalletEntriesProvider((
        membershipId: widget.membershipId,
        limit: _limit,
      )),
    );
  }

  Future<void> _openAllocateSheet(String groupId) async {
    ref.read(walletAllocationPreviewControllerProvider.notifier).reset();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AllocateWalletSheet(
        groupId: groupId,
        membershipId: widget.membershipId,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = (membershipId: widget.membershipId, limit: _limit);
    final pageAsync = ref.watch(memberWalletEntriesProvider(query));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final groupId = membership?.group.groupId;
    final canAllocate = membership?.hasPermission('wallet.allocate') ?? false;

    return UmojaPage(
      title: l10n.memberWalletTitle,
      maxWidth: 700,
      body: pageAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(memberWalletEntriesProvider(query)),
        ),
        data: (page) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UmojaCard(
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.walletBalanceLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        formatAmount(page.walletBalance),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  if (canAllocate && page.walletBalance > 0) ...[
                    const SizedBox(height: UmojaSpacing.lg),
                    UmojaPrimaryButton(
                      key: const Key('walletAllocateAction'),
                      label: l10n.allocateWalletAction,
                      onPressed: groupId == null
                          ? null
                          : () => _openAllocateSheet(groupId),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaSection(
              title: l10n.walletHistoryTitle,
              child: Column(
                children: [
                  for (final entry in page.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UmojaSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  walletEntryTypeLabel(l10n, entry.entryType),
                                ),
                                Text(
                                  formatKiswahiliDate(entry.effectiveAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${entry.isCredit ? '+' : '-'}${formatAmount(entry.amount)}',
                          ),
                        ],
                      ),
                    ),
                  if (page.items.isEmpty) Text(l10n.walletHistoryEmptyMessage),
                  if (page.hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UmojaSpacing.md,
                      ),
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _limit += _defaultLimit),
                        child: Text(l10n.loadMoreAction),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocateWalletSheet extends ConsumerStatefulWidget {
  const _AllocateWalletSheet({
    required this.groupId,
    required this.membershipId,
  });

  final String groupId;
  final String membershipId;

  @override
  ConsumerState<_AllocateWalletSheet> createState() =>
      _AllocateWalletSheetState();
}

class _AllocateWalletSheetState extends ConsumerState<_AllocateWalletSheet> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await ref
        .read(walletAllocationPreviewControllerProvider.notifier)
        .preview(
          groupId: widget.groupId,
          membershipId: widget.membershipId,
          amount: amount,
        );
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(walletAllocationControllerProvider.notifier)
        .allocate(
          groupId: widget.groupId,
          membershipId: widget.membershipId,
          amount: amount,
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.allocateWalletSuccessMessage)),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previewState = ref.watch(walletAllocationPreviewControllerProvider);
    final allocateState = ref.watch(walletAllocationControllerProvider);
    final preview = previewState.preview;

    return Padding(
      padding: EdgeInsets.only(
        left: UmojaSpacing.lg,
        right: UmojaSpacing.lg,
        top: UmojaSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + UmojaSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.allocateWalletTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('walletAllocateAmountField'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.recordPaymentAmountLabel,
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.paymentPreviewWillSettleLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final line in preview.allocations)
              Padding(
                padding: const EdgeInsets.only(top: UmojaSpacing.xs),
                child: Text(
                  '${contributionComponentTypeLabel(l10n, line.componentType)} — ${formatAmount(line.amount)}',
                ),
              ),
            if (preview.allocations.isEmpty)
              Text(l10n.paymentPreviewNoOutstandingMessage),
          ],
          if (previewState.errorType != null ||
              allocateState.errorType != null) ...[
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              paymentFailureMessage(
                context.l10n,
                (previewState.errorType ?? allocateState.errorType)!,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: UmojaSpacing.xxl),
          if (preview == null)
            UmojaPrimaryButton(
              key: const Key('walletAllocatePreviewAction'),
              label: l10n.recordPaymentPreviewAction,
              expand: true,
              isLoading: previewState.isLoading,
              onPressed: _preview,
            )
          else
            UmojaPrimaryButton(
              key: const Key('walletAllocateConfirmAction'),
              label: l10n.recordPaymentConfirmAction,
              expand: true,
              isLoading: allocateState.isSubmitting,
              onPressed: _confirm,
            ),
        ],
      ),
    );
  }
}
