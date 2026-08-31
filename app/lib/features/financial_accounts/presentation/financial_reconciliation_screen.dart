import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/financial_reconciliation_controller.dart';
import '../domain/financial_reconciliation.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_reconciliations_provider.dart';

const _defaultLimit = 10;

/// `/financial-accounts/:accountId/reconcile` (Prompt 08B, sections
/// 15-19/34): compare the authoritative derived balance against a
/// bank/mobile statement or physical cash count. Never implies that
/// saving a non-zero difference auto-corrects the cashbook — a real
/// correction is a separate, explicit Financial Adjustment. Also shows
/// this account's reconciliation history below the form.
class FinancialReconciliationScreen extends ConsumerStatefulWidget {
  const FinancialReconciliationScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<FinancialReconciliationScreen> createState() =>
      _FinancialReconciliationScreenState();
}

class _FinancialReconciliationScreenState
    extends ConsumerState<FinancialReconciliationScreen> {
  final _statedBalanceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _reconciliationAt = DateTime.now();
  int _historyLimit = _defaultLimit;

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
    _statedBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reconciliationAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _reconciliationAt = picked);
  }

  Future<void> _save(String groupId) async {
    final statedBalance = parseAmountInput(_statedBalanceController.text);
    if (statedBalance == null) return;

    final success = await ref
        .read(financialReconciliationControllerProvider.notifier)
        .create(
          groupId: groupId,
          financialAccountId: widget.accountId,
          statedBalance: statedBalance,
          reconciliationAt: _reconciliationAt,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (success && mounted) {
      _statedBalanceController.clear();
      _notesController.clear();
      ref.invalidate(financialAccountReconciliationsProvider);
    }
  }

  Future<void> _cancelReconciliation(
    String groupId,
    String reconciliationId,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.cancelReconciliationConfirmTitle,
      message: l10n.cancelReconciliationConfirmMessage,
      confirmLabel: l10n.cancelReconciliationConfirmAction,
      cancelLabel: l10n.cancelButton,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(financialReconciliationControllerProvider.notifier)
        .cancel(
          groupId: groupId,
          reconciliationId: reconciliationId,
          cancellationReason: l10n.cancelReconciliationDefaultReason,
        );
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
    final reconState = ref.watch(financialReconciliationControllerProvider);
    final historyQuery = (accountId: widget.accountId, limit: _historyLimit);
    final historyAsync = ref.watch(
      financialAccountReconciliationsProvider(historyQuery),
    );

    return UmojaPage(
      title: l10n.reconciliationTitle,
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
        data: (account) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KeyValueRow(
                      label: l10n.systemBalanceLabel,
                      value: formatAmount(account.balance),
                    ),
                    const SizedBox(height: UmojaSpacing.lg),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(
                        '${l10n.reconciliationDateLabel}: '
                        '${formatKiswahiliDate(_reconciliationAt)}',
                      ),
                    ),
                    const SizedBox(height: UmojaSpacing.lg),
                    TextField(
                      key: const Key('reconciliationStatedBalanceField'),
                      controller: _statedBalanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [ThousandsInputFormatter()],
                      decoration: InputDecoration(
                        labelText: l10n.statementBalanceLabel,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: UmojaSpacing.sm),
                    Builder(
                      builder: (context) {
                        final stated = parseAmountInput(
                          _statedBalanceController.text,
                        );
                        if (stated == null) return const SizedBox.shrink();
                        final difference = stated - account.balance;
                        return Text(
                          difference == 0
                              ? l10n.reconciliationBalancedMessage
                              : '${l10n.differenceLabel}: '
                                    '${formatAmount(difference)}',
                          style: TextStyle(
                            color: difference == 0
                                ? null
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: UmojaSpacing.lg),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.reconciliationNotesLabel,
                      ),
                    ),
                    if (reconState.errorType != null) ...[
                      const SizedBox(height: UmojaSpacing.sm),
                      Text(
                        financialAccountFailureMessage(
                          l10n,
                          reconState.errorType!,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: UmojaSpacing.lg),
                    UmojaPrimaryButton(
                      key: const Key('reconciliationSaveAction'),
                      label: l10n.reconciliationSaveAction,
                      expand: true,
                      isLoading: reconState.isSubmitting,
                      onPressed: groupId == null ? null : () => _save(groupId),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              Text(
                l10n.reconciliationHistoryTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: UmojaSpacing.sm),
              historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
                data: (page) {
                  if (page.items.isEmpty) {
                    return Text(l10n.reconciliationHistoryEmptyMessage);
                  }
                  return Column(
                    children: [
                      for (final record in page.items)
                        _ReconciliationRow(
                          record: record,
                          onCancel: groupId == null || record.isCancelled
                              ? null
                              : () => _cancelReconciliation(groupId, record.id),
                        ),
                      if (page.hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: UmojaSpacing.md,
                          ),
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _historyLimit += _defaultLimit),
                            child: Text(l10n.loadMoreAction),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ReconciliationRow extends StatelessWidget {
  const _ReconciliationRow({required this.record, required this.onCancel});

  final FinancialReconciliation record;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatKiswahiliDate(record.reconciliationAt)),
                Text(
                  '${l10n.systemBalanceLabel}: ${formatAmount(record.systemBalance)} · '
                  '${l10n.statementBalanceLabel}: ${formatAmount(record.statedBalance)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  record.isBalanced
                      ? l10n.reconciliationBalancedMessage
                      : '${l10n.differenceLabel}: ${formatAmount(record.difference)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: record.isBalanced
                        ? null
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                if (record.isCancelled)
                  Text(
                    l10n.reconciliationCancelledLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(onPressed: onCancel, child: Text(l10n.cancelButton)),
        ],
      ),
    );
  }
}
