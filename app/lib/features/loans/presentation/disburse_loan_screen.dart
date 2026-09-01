import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../financial_accounts/domain/financial_account.dart';
import '../../financial_accounts/presentation/widgets/financial_account_labels.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../controllers/loan_workflow_controller.dart';
import '../providers/loan_account_detail_provider.dart';

/// `/loans/accounts/:loanAccountId/disburse`: disburse an APPROVED
/// loan (Prompt 09B, "Toa Mkopo"). The amount is always the loan's own
/// frozen principal — never an arbitrary operator-entered figure —
/// and there is deliberately no expense-category selector anywhere on
/// this screen: a loan disbursement is a cash outflow, never an
/// expense (see docs/accounting/invariants.md). The financial account
/// picker only ever offers *active* accounts (reusing the same
/// `financialAccountsActiveForPickerProvider` the Payment/Transfer
/// flows already use) and shows each one's live server-derived
/// balance — the server remains the sole authority on sufficiency;
/// this screen only ever previews it.
class DisburseLoanScreen extends ConsumerStatefulWidget {
  const DisburseLoanScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<DisburseLoanScreen> createState() => _DisburseLoanScreenState();
}

class _DisburseLoanScreenState extends ConsumerState<DisburseLoanScreen> {
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _financialAccountId;
  DateTime _effectiveAt = DateTime.now();

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

  Future<void> _pickEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(_effectiveAt.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _effectiveAt = picked);
  }

  Future<void> _confirmAndDisburse(
    String groupId,
    String borrowerDisplayName,
    double principalAmount,
    String financialAccountName,
  ) async {
    final l10n = context.l10n;
    final accountId = _financialAccountId;
    if (accountId == null) return;

    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanDisburseConfirmTitle,
      message: l10n.loanDisburseConfirmMessage(
        formatAmount(principalAmount),
        financialAccountName,
        borrowerDisplayName,
      ),
      confirmLabel: l10n.loanDisburseAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanWorkflowControllerProvider.notifier)
        .disburse(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          financialAccountId: accountId,
          effectiveAt: _effectiveAt,
          reference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final loanAsync = ref.watch(
      loanAccountDetailProvider(widget.loanAccountId),
    );
    final accountsAsync = ref.watch(financialAccountsActiveForPickerProvider);
    final workflowState = ref.watch(loanWorkflowControllerProvider);

    return UmojaPage(
      title: l10n.loanDisburseTitle,
      maxWidth: 640,
      body: loanAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(loanAccountDetailProvider(widget.loanAccountId)),
        ),
        data: (loan) {
          final selectedAccount = accountsAsync.value
              ?.where((a) => a.id == _financialAccountId)
              .firstOrNull;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.loanNumber),
                    Text(
                      loan.borrowerDisplayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: UmojaSpacing.sm),
                    // Read-only — 09B never allows an arbitrary
                    // operator-entered disbursement amount.
                    Text(
                      '${l10n.loanDisburseAmountLabel}: '
                      '${formatAmount(loan.principalAmount)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              accountsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
                data: (accounts) => DropdownButtonFormField<String>(
                  key: const Key('disburseLoanAccountField'),
                  isExpanded: true,
                  initialValue: _financialAccountId,
                  decoration: InputDecoration(
                    labelText: l10n.loanDisburseFinancialAccountLabel,
                  ),
                  onChanged: (value) =>
                      setState(() => _financialAccountId = value),
                  items: [
                    for (final FinancialAccount account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} '
                          '(${financialAccountTypeLabel(l10n, account.accountType)}) '
                          '— ${formatAmount(account.balance)}',
                        ),
                      ),
                  ],
                ),
              ),
              if (selectedAccount != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  '${l10n.loanDisburseAvailableBalanceLabel}: '
                  '${formatAmount(selectedAccount.balance)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: UmojaSpacing.lg),
              OutlinedButton(
                key: const Key('disburseLoanEffectiveDateField'),
                onPressed: _pickEffectiveDate,
                child: Text(
                  '${l10n.loanDisburseEffectiveDateLabel}: '
                  '${formatKiswahiliDate(_effectiveAt)}',
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('disburseLoanReferenceField'),
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: l10n.loanDisburseReferenceFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('disburseLoanNotesField'),
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.loanDisburseNotesFieldLabel,
                ),
              ),
              if (workflowState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  loanFailureMessage(l10n, workflowState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                key: const Key('disburseLoanConfirmAction'),
                label: l10n.loanDisburseAction,
                expand: true,
                isLoading: workflowState.isSubmitting,
                onPressed: groupId == null || selectedAccount == null
                    ? null
                    : () => _confirmAndDisburse(
                        groupId,
                        loan.borrowerDisplayName,
                        loan.principalAmount,
                        selectedAccount.name,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
