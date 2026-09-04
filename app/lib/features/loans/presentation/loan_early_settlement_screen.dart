import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../financial_accounts/domain/financial_account.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../../payments/presentation/widgets/payment_labels.dart';
import '../controllers/loan_servicing_controller.dart';

const _paymentMethods = ['CASH', 'BANK_TRANSFER', 'MOBILE_MONEY', 'OTHER'];

/// `/loans/accounts/:loanAccountId/early-settlement`: full Early
/// Settlement (Prompt 09E section 2). Input -> Server Preview (Quote)
/// -> Review accounting impact -> Confirm/Post. The settlement amount
/// is ALWAYS server-computed (`rpc_preview_loan_early_settlement`/
/// `rpc_settle_loan_early`) — there is deliberately no amount field
/// anywhere on this screen for the operator to edit.
class LoanEarlySettlementScreen extends ConsumerStatefulWidget {
  const LoanEarlySettlementScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<LoanEarlySettlementScreen> createState() =>
      _LoanEarlySettlementScreenState();
}

class _LoanEarlySettlementScreenState
    extends ConsumerState<LoanEarlySettlementScreen> {
  String? _financialAccountId;
  String _paymentMethod = 'CASH';
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.invalidate(financialAccountsActiveForPickerProvider);
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _preview(String groupId) async {
    await ref
        .read(loanEarlySettlementControllerProvider.notifier)
        .preview(groupId: groupId, loanAccountId: widget.loanAccountId);
  }

  Future<void> _confirm(String groupId) async {
    final accountId = _financialAccountId;
    if (accountId == null) return;
    final l10n = context.l10n;

    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanEarlySettlementTitle,
      message: l10n.loanEarlySettlementSafetyMessage,
      confirmLabel: l10n.loanEarlySettlementConfirmAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanEarlySettlementControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          financialAccountId: accountId,
          paymentMethod: _paymentMethod,
          externalReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loanEarlySettlementSuccessMessage)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final accountsAsync = ref.watch(financialAccountsActiveForPickerProvider);
    final state = ref.watch(loanEarlySettlementControllerProvider);
    final quote = state.quote;

    return UmojaPage(
      title: l10n.loanEarlySettlementTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote == null) ...[
            Text(l10n.loanEarlySettlementSafetyMessage),
            const SizedBox(height: UmojaSpacing.lg),
            if (state.errorType != null) ...[
              Text(
                loanFailureMessage(l10n, state.errorType!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: UmojaSpacing.sm),
            ],
            UmojaPrimaryButton(
              key: const Key('loanEarlySettlementPreviewAction'),
              label: l10n.loanEarlySettlementQuoteTitle,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null ? null : () => _preview(groupId),
            ),
          ] else ...[
            UmojaCard(
              key: const Key('loanEarlySettlementQuoteCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.loanEarlySettlementQuoteTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: UmojaSpacing.sm),
                  if (quote.overduePenaltyOutstanding > 0)
                    _Row(
                      l10n.loanEarlySettlementOverduePenaltyLabel,
                      quote.overduePenaltyOutstanding,
                    ),
                  if (quote.overdueInterestOutstanding > 0)
                    _Row(
                      l10n.loanEarlySettlementOverdueInterestLabel,
                      quote.overdueInterestOutstanding,
                    ),
                  if (quote.overduePrincipalOutstanding > 0)
                    _Row(
                      l10n.loanEarlySettlementOverduePrincipalLabel,
                      quote.overduePrincipalOutstanding,
                    ),
                  if (quote.currentPayablePenalty > 0)
                    _Row(
                      l10n.loanEarlySettlementCurrentPenaltyLabel,
                      quote.currentPayablePenalty,
                    ),
                  if (quote.currentPayableInterest > 0)
                    _Row(
                      l10n.loanEarlySettlementCurrentInterestLabel,
                      quote.currentPayableInterest,
                    ),
                  if (quote.currentPayablePrincipal > 0)
                    _Row(
                      l10n.loanEarlySettlementCurrentPrincipalLabel,
                      quote.currentPayablePrincipal,
                    ),
                  _Row(
                    l10n.loanEarlySettlementFuturePrincipalLabel,
                    quote.futurePrincipalOutstanding,
                  ),
                  _Row(
                    l10n.loanEarlySettlementFutureUnearnedInterestLabel,
                    quote.futureUnearnedInterest,
                  ),
                  const Divider(),
                  _Row(
                    l10n.loanEarlySettlementTotalLabel,
                    quote.totalSettlementAmount,
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () =>
                    ref.invalidate(financialAccountsActiveForPickerProvider),
              ),
              data: (accounts) => DropdownButtonFormField<String>(
                key: const Key('loanEarlySettlementFinancialAccountField'),
                isExpanded: true,
                initialValue: _financialAccountId,
                decoration: InputDecoration(
                  labelText: l10n.loanEarlySettlementFinancialAccountFieldLabel,
                ),
                onChanged: (value) =>
                    setState(() => _financialAccountId = value),
                items: [
                  for (final FinancialAccount account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        '${account.name} — ${formatAmount(account.balance)}',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            DropdownButtonFormField<String>(
              key: const Key('loanEarlySettlementPaymentMethodField'),
              isExpanded: true,
              initialValue: _paymentMethod,
              decoration: InputDecoration(
                labelText: l10n.loanEarlySettlementPaymentMethodFieldLabel,
              ),
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
              items: [
                for (final method in _paymentMethods)
                  DropdownMenuItem(
                    value: method,
                    child: Text(paymentMethodLabel(l10n, method)),
                  ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('loanEarlySettlementReferenceField'),
              controller: _referenceController,
              decoration: const InputDecoration(labelText: 'Reference'),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('loanEarlySettlementNotesField'),
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            if (state.errorType != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                loanFailureMessage(l10n, state.errorType!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaSecondaryButton(
              key: const Key('loanEarlySettlementBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanEarlySettlementControllerProvider.notifier)
                  .invalidateQuote(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaPrimaryButton(
              key: const Key('loanEarlySettlementConfirmAction'),
              label: l10n.loanEarlySettlementConfirmAction,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: groupId == null || _financialAccountId == null
                  ? null
                  : () => _confirm(groupId),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.amount, {this.emphasize = false});

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: UmojaSpacing.sm),
          Text(formatAmount(amount), style: style),
        ],
      ),
    );
  }
}
