import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../financial_accounts/domain/financial_account.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../../payments/presentation/widgets/payment_labels.dart';
import '../controllers/loan_servicing_controller.dart';
import '../domain/loan_servicing.dart';

const _paymentMethods = ['CASH', 'BANK_TRANSFER', 'MOBILE_MONEY', 'OTHER'];

/// `/loans/accounts/:loanAccountId/prepay`: Partial Principal
/// Prepayment (Prompt 09E section 3/4). Input -> Server Preview
/// (REDUCE_TERM/REDUCE_INSTALLMENT) -> Review accounting impact ->
/// Confirm/Post. Blocked server-side while any overdue/currently-
/// payable penalty or interest remains outstanding.
class LoanPrepaymentScreen extends ConsumerStatefulWidget {
  const LoanPrepaymentScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<LoanPrepaymentScreen> createState() =>
      _LoanPrepaymentScreenState();
}

class _LoanPrepaymentScreenState extends ConsumerState<LoanPrepaymentScreen> {
  final _amountController = TextEditingController();
  String _treatment = 'REDUCE_TERM';
  String? _financialAccountId;
  String _paymentMethod = 'CASH';

  @override
  void initState() {
    super.initState();
    ref.invalidate(financialAccountsActiveForPickerProvider);
    _amountController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onInputChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    ref.read(loanPrepaymentControllerProvider.notifier).invalidatePreview();
  }

  Future<void> _preview(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) return;
    await ref
        .read(loanPrepaymentControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          amount: amount,
          treatment: _treatment,
        );
  }

  Future<void> _confirm(String groupId, LoanPrepaymentPreview preview) async {
    final accountId = _financialAccountId;
    if (accountId == null) return;
    final l10n = context.l10n;

    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanPrepaymentTitle,
      message: l10n.loanPrepaymentConfirmAction,
      confirmLabel: l10n.loanPrepaymentConfirmAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanPrepaymentControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          amount: preview.amount,
          treatment: preview.treatment,
          financialAccountId: accountId,
          paymentMethod: _paymentMethod,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loanPrepaymentSuccessMessage)),
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
    final state = ref.watch(loanPrepaymentControllerProvider);
    final preview = state.preview;

    return UmojaPage(
      title: l10n.loanPrepaymentTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('loanPrepaymentAmountField'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: l10n.loanPrepaymentAmountFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          DropdownButtonFormField<String>(
            key: const Key('loanPrepaymentTreatmentField'),
            isExpanded: true,
            initialValue: _treatment,
            decoration: InputDecoration(
              labelText: l10n.loanPrepaymentTreatmentFieldLabel,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _treatment = value);
                ref
                    .read(loanPrepaymentControllerProvider.notifier)
                    .invalidatePreview();
              }
            },
            items: [
              DropdownMenuItem(
                value: 'REDUCE_TERM',
                child: Text(l10n.loanPrepaymentReduceTermLabel),
              ),
              DropdownMenuItem(
                value: 'REDUCE_INSTALLMENT',
                child: Text(l10n.loanPrepaymentReduceInstallmentLabel),
              ),
            ],
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
              key: const Key('loanPrepaymentPreviewAction'),
              label: l10n.loanPrepaymentPreviewAction,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null ? null : () => _preview(groupId),
            )
          else ...[
            UmojaCard(
              key: const Key('loanPrepaymentPreviewCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.loanPrepaymentFuturePrincipalBeforeLabel,
                        ),
                      ),
                      Text(
                        formatAmount(preview.futurePrincipalOutstandingBefore),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.loanPrepaymentFuturePrincipalAfterLabel,
                        ),
                      ),
                      Text(
                        formatAmount(preview.futurePrincipalOutstandingAfter),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    l10n.loanPrepaymentNewScheduleTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final row in preview.newFutureInstallments)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UmojaSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(formatKiswahiliDate(row.dueDate)),
                          ),
                          Text(
                            formatAmount(row.principalDue + row.interestDue),
                          ),
                        ],
                      ),
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
                key: const Key('loanPrepaymentFinancialAccountField'),
                isExpanded: true,
                initialValue: _financialAccountId,
                decoration: InputDecoration(
                  labelText: l10n.loanPrepaymentFinancialAccountFieldLabel,
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
              key: const Key('loanPrepaymentPaymentMethodField'),
              isExpanded: true,
              initialValue: _paymentMethod,
              decoration: InputDecoration(
                labelText: l10n.loanPrepaymentPaymentMethodFieldLabel,
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
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaSecondaryButton(
              key: const Key('loanPrepaymentBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanPrepaymentControllerProvider.notifier)
                  .invalidatePreview(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaPrimaryButton(
              key: const Key('loanPrepaymentConfirmAction'),
              label: l10n.loanPrepaymentConfirmAction,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: groupId == null || _financialAccountId == null
                  ? null
                  : () => _confirm(groupId, preview),
            ),
          ],
        ],
      ),
    );
  }
}
