import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/financial_adjustment_controller.dart';
import '../providers/financial_account_detail_provider.dart';

/// `/financial-accounts/:accountId/adjustment`: Marekebisho ya Fedha —
/// a controlled, explicit correction for a verified real-world
/// discrepancy (Prompt 08B, section 18). Never presented or counted as
/// ordinary income/expense; requires a reason.
class FinancialAdjustmentScreen extends ConsumerStatefulWidget {
  const FinancialAdjustmentScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<FinancialAdjustmentScreen> createState() =>
      _FinancialAdjustmentScreenState();
}

class _FinancialAdjustmentScreenState
    extends ConsumerState<FinancialAdjustmentScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String _direction = 'DECREASE';
  DateTime _effectiveAt = DateTime.now();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    // Deferred to a post-frame callback: at the moment this screen is
    // pushed, the Account Detail screen underneath is still watching
    // this same `financialAccountDetailProvider(accountId)` mid-
    // transition — invalidating it synchronously here would call
    // setState on that still-building widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(financialAccountDetailProvider(widget.accountId));
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _effectiveAt = picked);
  }

  Future<void> _confirm(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    final reason = _reasonController.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) return;

    final success = await ref
        .read(financialAdjustmentControllerProvider.notifier)
        .record(
          groupId: groupId,
          financialAccountId: widget.accountId,
          direction: _direction,
          amount: amount,
          reason: reason,
          effectiveAt: _effectiveAt,
        );
    if (success && mounted) setState(() => _confirmed = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final accountAsync = ref.watch(
      financialAccountDetailProvider(widget.accountId),
    );
    final adjState = ref.watch(financialAdjustmentControllerProvider);

    return UmojaPage(
      title: l10n.financialAdjustmentTitle,
      maxWidth: 700,
      backTo: AppRoutes.financialAccountDetailPath(widget.accountId),
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
        data: (account) {
          if (_confirmed) {
            final result = adjState.lastResult;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 64,
                ),
                const SizedBox(height: UmojaSpacing.lg),
                Text(
                  l10n.financialAdjustmentSuccessMessage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (result != null) ...[
                  const SizedBox(height: UmojaSpacing.sm),
                  Text(
                    '${l10n.financialAccountBalanceLabel}: '
                    '${formatAmount(result.financialAccountBalance)}',
                  ),
                ],
                const SizedBox(height: UmojaSpacing.xxl),
                UmojaSecondaryButton(
                  label: l10n.doneAction,
                  onPressed: () => context.go(
                    AppRoutes.financialAccountDetailPath(widget.accountId),
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Row(
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
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'DECREASE',
                    label: Text(l10n.adjustmentDecreaseOption),
                  ),
                  ButtonSegment(
                    value: 'INCREASE',
                    label: Text(l10n.adjustmentIncreaseOption),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) =>
                    setState(() => _direction = selection.first),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('financialAdjustmentAmountField'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(labelText: l10n.amountFieldLabel),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('financialAdjustmentReasonField'),
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.financialAdjustmentReasonFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(
                  '${l10n.effectiveDateFieldLabel}: '
                  '${formatKiswahiliDate(_effectiveAt)}',
                ),
              ),
              if (adjState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  financialAccountFailureMessage(l10n, adjState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                key: const Key('financialAdjustmentConfirmAction'),
                label: l10n.financialAdjustmentConfirmAction,
                expand: true,
                isLoading: adjState.isSubmitting,
                onPressed: groupId == null ? null : () => _confirm(groupId),
              ),
            ],
          );
        },
      ),
    );
  }
}
