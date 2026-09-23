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
import '../controllers/loan_obligation_adjustment_controller.dart';
import '../domain/loan_obligation_adjustment.dart';
import 'widgets/loan_obligation_target_context.dart';

String waiverReasonLabel(BuildContext context, String code) {
  final l10n = context.l10n;
  return switch (code) {
    'HARDSHIP' => l10n.loanObligationReasonHardship,
    'COMMITTEE_DECISION' => l10n.loanObligationReasonCommitteeDecision,
    'GOODWILL' => l10n.loanObligationReasonGoodwill,
    'SETTLEMENT_CONCESSION' => l10n.loanObligationReasonSettlementConcession,
    _ => l10n.loanObligationReasonOther,
  };
}

/// `/loans/accounts/:loanAccountId/waive/:targetType/:targetId`: Waive
/// Obligation (Prompt 09F-A section 9/10/25). Select eligible target
/// (chosen on the previous screen) -> amount -> reason -> note -> Server
/// Preview -> Review -> Confirm. Preview always shows Cash Impact: TZS
/// 0, Payment Created: No, Receipt Created: No — never a client-side
/// authoritative figure.
class LoanObligationWaiverScreen extends ConsumerStatefulWidget {
  const LoanObligationWaiverScreen({
    super.key,
    required this.loanAccountId,
    required this.targetType,
    required this.targetId,
  });

  final String loanAccountId;

  /// 'LOAN_PENALTY' or 'LOAN_INTEREST'.
  final String targetType;
  final String targetId;

  @override
  ConsumerState<LoanObligationWaiverScreen> createState() =>
      _LoanObligationWaiverScreenState();
}

class _LoanObligationWaiverScreenState
    extends ConsumerState<LoanObligationWaiverScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _reasonCode = waiverReasonCodes.first;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onInputChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    ref
        .read(loanObligationWaiverControllerProvider.notifier)
        .invalidatePreview();
  }

  Future<void> _preview(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) return;
    await ref
        .read(loanObligationWaiverControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          targetType: widget.targetType,
          targetId: widget.targetId,
          amount: amount,
          reasonCode: _reasonCode,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
  }

  Future<void> _confirm(
    String groupId,
    LoanObligationWaiverPreview preview,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanObligationWaiveTitle,
      message: l10n.loanObligationConfirmWaiverAction,
      confirmLabel: l10n.loanObligationConfirmWaiverAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanObligationWaiverControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          targetType: widget.targetType,
          targetId: widget.targetId,
          amount: preview.waiverAmount,
          reasonCode: _reasonCode,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loanObligationWaiverSuccessMessage)),
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
    final state = ref.watch(loanObligationWaiverControllerProvider);
    final preview = state.preview;

    return UmojaPage(
      title: l10n.loanObligationWaiveTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoanObligationTargetContext(
            loanAccountId: widget.loanAccountId,
            targetType: widget.targetType,
            targetId: widget.targetId,
          ),
          TextField(
            key: const Key('loanObligationWaiverAmountField'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: l10n.loanObligationAmountFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          DropdownButtonFormField<String>(
            key: const Key('loanObligationWaiverReasonField'),
            isExpanded: true,
            initialValue: _reasonCode,
            decoration: InputDecoration(
              labelText: l10n.loanObligationReasonFieldLabel,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _reasonCode = value);
                ref
                    .read(loanObligationWaiverControllerProvider.notifier)
                    .invalidatePreview();
              }
            },
            items: [
              for (final code in waiverReasonCodes)
                DropdownMenuItem(
                  value: code,
                  child: Text(waiverReasonLabel(context, code)),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanObligationWaiverNoteField'),
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.loanObligationNoteFieldLabel,
            ),
            onChanged: (_) => ref
                .read(loanObligationWaiverControllerProvider.notifier)
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
              key: const Key('loanObligationWaiverPreviewAction'),
              label: l10n.loanObligationPreviewAction,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null ? null : () => _preview(groupId),
            )
          else ...[
            UmojaCard(
              key: const Key('loanObligationWaiverPreviewCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(
                    label: l10n.loanObligationCurrentOutstandingLabel,
                    value: formatAmount(preview.currentOutstanding),
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationWaiverAmountLabel,
                    value: formatAmount(preview.waiverAmount),
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationRemainingOutstandingLabel,
                    value: formatAmount(preview.remainingOutstanding),
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
              key: const Key('loanObligationWaiverBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanObligationWaiverControllerProvider.notifier)
                  .invalidatePreview(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaPrimaryButton(
              key: const Key('loanObligationWaiverConfirmAction'),
              label: l10n.loanObligationConfirmWaiverAction,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: groupId == null
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
