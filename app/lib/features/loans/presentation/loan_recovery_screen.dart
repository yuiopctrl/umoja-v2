import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../financial_accounts/domain/financial_account.dart';
import '../../financial_accounts/presentation/widgets/financial_account_labels.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../../payments/presentation/widgets/payment_labels.dart';
import '../controllers/loan_write_off_recovery_controller.dart';
import '../domain/loan_write_off_recovery.dart';
import 'widgets/loan_labels.dart';

const _recoveryPaymentMethods = [
  'CASH',
  'BANK_TRANSFER',
  'MOBILE_MONEY',
  'OTHER',
];

/// `/loans/accounts/:loanAccountId/record-recovery`: Record Recovery
/// (Prompt 09F-B section G) against a WRITTEN_OFF loan's remaining
/// recoverable balance. Amount -> financial account/payment method ->
/// Server Preview -> Review (showing the server's own PENALTY ->
/// INTEREST -> PRINCIPAL allocation) -> Confirm. Unlike a write-off, a
/// recovery IS a real cash event and reuses the existing Payment
/// Engine.
class LoanRecoveryScreen extends ConsumerStatefulWidget {
  const LoanRecoveryScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<LoanRecoveryScreen> createState() => _LoanRecoveryScreenState();
}

class _LoanRecoveryScreenState extends ConsumerState<LoanRecoveryScreen> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _financialAccountId;
  String _paymentMethod = 'CASH';

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onInputChanged);
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    ref.read(loanRecoveryControllerProvider.notifier).invalidatePreview();
  }

  Future<void> _preview(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) return;
    await ref
        .read(loanRecoveryControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          amount: amount,
        );
  }

  Future<void> _confirm(String groupId, LoanRecoveryPreview preview) async {
    final accountId = _financialAccountId;
    if (accountId == null) return;
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanRecoveryTitle,
      message: l10n.loanRecoveryConfirmAction,
      confirmLabel: l10n.loanRecoveryConfirmAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanRecoveryControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          amount: preview.recoveryAmount,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loanRecoverySuccessMessage)));
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
    final state = ref.watch(loanRecoveryControllerProvider);
    final preview = state.preview;
    final accountsAsync = ref.watch(financialAccountsActiveForPickerProvider);

    return UmojaPage(
      title: l10n.loanRecoveryTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('loanRecoveryAmountField'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: l10n.loanRecoveryAmountFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          DropdownButtonFormField<String>(
            key: const Key('loanRecoveryPaymentMethodField'),
            isExpanded: true,
            initialValue: _paymentMethod,
            decoration: InputDecoration(
              labelText: l10n.loanRecoveryPaymentMethodFieldLabel,
            ),
            onChanged: (value) {
              if (value != null) setState(() => _paymentMethod = value);
            },
            items: [
              for (final method in _recoveryPaymentMethods)
                DropdownMenuItem(
                  value: method,
                  child: Text(paymentMethodLabel(l10n, method)),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          accountsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
            data: (accounts) => DropdownButtonFormField<String>(
              key: const Key('loanRecoveryAccountField'),
              isExpanded: true,
              initialValue: _financialAccountId,
              decoration: InputDecoration(
                labelText: l10n.loanRecoveryFinancialAccountFieldLabel,
              ),
              onChanged: (value) => setState(() => _financialAccountId = value),
              items: [
                for (final FinancialAccount account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.name} (${financialAccountTypeLabel(l10n, account.accountType)})',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanRecoveryReferenceField'),
            controller: _referenceController,
            decoration: InputDecoration(
              labelText: l10n.loanRecoveryExternalReferenceFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanRecoveryNotesField'),
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.loanRecoveryNotesFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          if (state.errorType != null) ...[
            Text(
              loanFailureMessage(l10n, state.errorType!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: UmojaSpacing.sm),
          ],
          if (preview == null)
            UmojaPrimaryButton(
              key: const Key('loanRecoveryPreviewAction'),
              label: l10n.loanObligationPreviewAction,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null ? null : () => _preview(groupId),
            )
          else ...[
            UmojaCard(
              key: const Key('loanRecoveryPreviewCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(
                    label: l10n.loanRecoveryOriginalWrittenOffLabel,
                    value: formatAmount(preview.writeOffTotalAmount),
                  ),
                  _PreviewRow(
                    label: l10n.loanRecoveryPreviouslyRecoveredLabel,
                    value: formatAmount(
                      preview.writeOffTotalAmount -
                          preview.remainingBefore.total,
                    ),
                  ),
                  _PreviewRow(
                    label: l10n.loanRecoveryRemainingBeforeLabel,
                    value: formatAmount(preview.remainingBefore.total),
                  ),
                  _PreviewRow(
                    label: l10n.loanRecoveryThisRecoveryLabel,
                    value: formatAmount(preview.recoveryAmount),
                  ),
                  const Divider(),
                  Text(
                    l10n.loanRecoveryAllocationTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  _PreviewRow(
                    label: loanComponentTypeLabel(l10n, 'PENALTY'),
                    value: formatAmount(preview.allocation.penalty),
                  ),
                  _PreviewRow(
                    label: loanComponentTypeLabel(l10n, 'INTEREST'),
                    value: formatAmount(preview.allocation.interest),
                  ),
                  _PreviewRow(
                    label: loanComponentTypeLabel(l10n, 'PRINCIPAL'),
                    value: formatAmount(preview.allocation.principal),
                  ),
                  const Divider(),
                  _PreviewRow(
                    label: l10n.loanRecoveryRemainingAfterLabel,
                    value: formatAmount(preview.remainingAfter.total),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaSecondaryButton(
              key: const Key('loanRecoveryBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanRecoveryControllerProvider.notifier)
                  .invalidatePreview(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaPrimaryButton(
              key: const Key('loanRecoveryConfirmAction'),
              label: l10n.loanRecoveryConfirmAction,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: (groupId == null || _financialAccountId == null)
                  ? null
                  : () => _confirm(groupId, preview),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
