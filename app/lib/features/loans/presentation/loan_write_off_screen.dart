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
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_write_off_recovery_controller.dart';
import '../domain/loan_write_off_recovery.dart';

String loanWriteOffReasonLabel(BuildContext context, String code) {
  final l10n = context.l10n;
  return switch (code) {
    'PROLONGED_DEFAULT' => l10n.loanWriteOffReasonProlongedDefault,
    'BORROWER_DECEASED' => l10n.loanWriteOffReasonBorrowerDeceased,
    'BORROWER_UNTRACEABLE' => l10n.loanWriteOffReasonBorrowerUntraceable,
    'UNCOLLECTIBLE_COST' => l10n.loanWriteOffReasonUncollectibleCost,
    'GROUP_DECISION' => l10n.loanWriteOffReasonGroupDecision,
    _ => l10n.loanWriteOffReasonOther,
  };
}

/// `/loans/accounts/:loanAccountId/write-off`: Write Off Loan (Prompt
/// 09F-B section F). Reason -> note -> Server Preview -> Review ->
/// Confirm. Preview always shows Cash Impact: TZS 0, Payment Created:
/// No, Receipt Created: No — a write-off is never a payment and no
/// cash is received.
class LoanWriteOffScreen extends ConsumerStatefulWidget {
  const LoanWriteOffScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<LoanWriteOffScreen> createState() => _LoanWriteOffScreenState();
}

class _LoanWriteOffScreenState extends ConsumerState<LoanWriteOffScreen> {
  final _noteController = TextEditingController();
  String _reasonCode = loanWriteOffReasonCodes.first;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _preview(String groupId) async {
    await ref
        .read(loanWriteOffControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          reasonCode: _reasonCode,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
  }

  Future<void> _confirm(String groupId) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanWriteOffTitle,
      message: l10n.loanWriteOffWarningMessage,
      confirmLabel: l10n.loanWriteOffConfirmAction,
      cancelLabel: l10n.cancelButton,
      danger: true,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanWriteOffControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          reasonCode: _reasonCode,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loanWriteOffSuccessMessage)));
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
    final state = ref.watch(loanWriteOffControllerProvider);
    final preview = state.preview;

    return UmojaPage(
      title: l10n.loanWriteOffTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.loanWriteOffWarningMessage,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          DropdownButtonFormField<String>(
            key: const Key('loanWriteOffReasonField'),
            isExpanded: true,
            initialValue: _reasonCode,
            decoration: InputDecoration(
              labelText: l10n.loanObligationReasonFieldLabel,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _reasonCode = value);
                ref
                    .read(loanWriteOffControllerProvider.notifier)
                    .invalidatePreview();
              }
            },
            items: [
              for (final code in loanWriteOffReasonCodes)
                DropdownMenuItem(
                  value: code,
                  child: Text(loanWriteOffReasonLabel(context, code)),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanWriteOffNoteField'),
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.loanObligationNoteFieldLabel,
            ),
            onChanged: (_) => ref
                .read(loanWriteOffControllerProvider.notifier)
                .invalidatePreview(),
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
              key: const Key('loanWriteOffPreviewAction'),
              label: l10n.loanObligationPreviewAction,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null ? null : () => _preview(groupId),
            )
          else ...[
            UmojaCard(
              key: const Key('loanWriteOffPreviewCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(
                    label: l10n.loanWriteOffPrincipalLabel,
                    value: formatAmount(preview.principalAmount),
                  ),
                  _PreviewRow(
                    label: l10n.loanWriteOffInterestLabel,
                    value: formatAmount(preview.interestAmount),
                  ),
                  _PreviewRow(
                    label: l10n.loanWriteOffPenaltyLabel,
                    value: formatAmount(preview.penaltyAmount),
                  ),
                  const Divider(),
                  _PreviewRow(
                    label: l10n.loanWriteOffTotalLabel,
                    value: formatAmount(preview.totalAmount),
                  ),
                  const Divider(),
                  _PreviewRow(
                    label: l10n.loanObligationCashImpactLabel,
                    value: formatAmount(preview.cashImpact),
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationPaymentCreatedLabel,
                    value: l10n.loanObligationNoLabel,
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationReceiptCreatedLabel,
                    value: l10n.loanObligationNoLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaSecondaryButton(
              key: const Key('loanWriteOffBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanWriteOffControllerProvider.notifier)
                  .invalidatePreview(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaDangerButton(
              key: const Key('loanWriteOffConfirmAction'),
              label: l10n.loanWriteOffConfirmAction,
              filled: true,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: groupId == null ? null : () => _confirm(groupId),
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
