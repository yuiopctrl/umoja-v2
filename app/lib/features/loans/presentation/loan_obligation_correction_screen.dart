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

String correctionReasonLabel(BuildContext context, String code) {
  final l10n = context.l10n;
  return switch (code) {
    'ASSESSMENT_ERROR' => l10n.loanObligationReasonAssessmentError,
    'DATA_ENTRY_ERROR' => l10n.loanObligationReasonDataEntryError,
    'MIGRATION_ERROR' => l10n.loanObligationReasonMigrationError,
    _ => l10n.loanObligationReasonOther,
  };
}

/// `/loans/accounts/:loanAccountId/correct/:targetType/:targetId`:
/// Correct Obligation (Prompt 09F-A section 11/12/13, ADMIN-only —
/// section 3). Select eligible target (chosen on the previous screen)
/// -> correction direction -> amount -> reason -> note -> Server Preview
/// -> Review (source obligation, prior corrections, current/new
/// effective amount) -> Confirm. CORRECTION_INCREASE is never offered
/// for interest ([canIncrease] is always false for LOAN_INTEREST,
/// enforced by the caller).
class LoanObligationCorrectionScreen extends ConsumerStatefulWidget {
  const LoanObligationCorrectionScreen({
    super.key,
    required this.loanAccountId,
    required this.targetType,
    required this.targetId,
    required this.canIncrease,
  });

  final String loanAccountId;

  /// 'LOAN_PENALTY' or 'LOAN_INTEREST'.
  final String targetType;
  final String targetId;

  /// Whether CORRECTION_INCREASE should be offered at all — false for
  /// every LOAN_INTEREST target (section 13) and for any caller lacking
  /// `loan.correct_increase`. UX only; the server is always the final
  /// authority (section 3/16).
  final bool canIncrease;

  @override
  ConsumerState<LoanObligationCorrectionScreen> createState() =>
      _LoanObligationCorrectionScreenState();
}

class _LoanObligationCorrectionScreenState
    extends ConsumerState<LoanObligationCorrectionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _reasonCode = correctionReasonCodes.first;
  late String _adjustmentType;

  @override
  void initState() {
    super.initState();
    _adjustmentType = 'CORRECTION_DECREASE';
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
        .read(loanObligationCorrectionControllerProvider.notifier)
        .invalidatePreview();
  }

  Future<void> _preview(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) return;
    await ref
        .read(loanObligationCorrectionControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          targetType: widget.targetType,
          targetId: widget.targetId,
          adjustmentType: _adjustmentType,
          amount: amount,
          reasonCode: _reasonCode,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
  }

  Future<void> _confirm(
    String groupId,
    LoanObligationCorrectionPreview preview,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanObligationCorrectTitle,
      message: l10n.loanObligationConfirmCorrectionAction,
      confirmLabel: l10n.loanObligationConfirmCorrectionAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanObligationCorrectionControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          targetType: widget.targetType,
          targetId: widget.targetId,
          adjustmentType: preview.adjustmentType,
          amount: preview.proposedCorrection.abs(),
          reasonCode: _reasonCode,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loanObligationCorrectionSuccessMessage)),
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
    final state = ref.watch(loanObligationCorrectionControllerProvider);
    final preview = state.preview;

    return UmojaPage(
      title: l10n.loanObligationCorrectTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoanObligationTargetContext(
            loanAccountId: widget.loanAccountId,
            targetType: widget.targetType,
            targetId: widget.targetId,
          ),
          DropdownButtonFormField<String>(
            key: const Key('loanObligationCorrectionTypeField'),
            isExpanded: true,
            initialValue: _adjustmentType,
            decoration: InputDecoration(
              labelText: l10n.loanObligationCorrectionTypeFieldLabel,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _adjustmentType = value);
                ref
                    .read(loanObligationCorrectionControllerProvider.notifier)
                    .invalidatePreview();
              }
            },
            items: [
              DropdownMenuItem(
                value: 'CORRECTION_DECREASE',
                child: Text(l10n.loanObligationCorrectionDecreaseLabel),
              ),
              // Never offered for LOAN_INTEREST (section 13) — the server
              // also rejects this structurally regardless of what the UI
              // shows.
              if (widget.canIncrease && widget.targetType != 'LOAN_INTEREST')
                DropdownMenuItem(
                  value: 'CORRECTION_INCREASE',
                  child: Text(l10n.loanObligationCorrectionIncreaseLabel),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanObligationCorrectionAmountField'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: l10n.loanObligationAmountFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          DropdownButtonFormField<String>(
            key: const Key('loanObligationCorrectionReasonField'),
            isExpanded: true,
            initialValue: _reasonCode,
            decoration: InputDecoration(
              labelText: l10n.loanObligationReasonFieldLabel,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _reasonCode = value);
                ref
                    .read(loanObligationCorrectionControllerProvider.notifier)
                    .invalidatePreview();
              }
            },
            items: [
              for (final code in correctionReasonCodes)
                DropdownMenuItem(
                  value: code,
                  child: Text(correctionReasonLabel(context, code)),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanObligationCorrectionNoteField'),
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.loanObligationNoteFieldLabel,
            ),
            onChanged: (_) => ref
                .read(loanObligationCorrectionControllerProvider.notifier)
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
              key: const Key('loanObligationCorrectionPreviewAction'),
              label: l10n.loanObligationPreviewAction,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null ? null : () => _preview(groupId),
            )
          else ...[
            UmojaCard(
              key: const Key('loanObligationCorrectionPreviewCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(
                    label: l10n.loanObligationSourceOriginalAmountLabel,
                    value: formatAmount(preview.sourceOriginalAmount),
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationPriorNetCorrectionsLabel,
                    value: formatAmount(preview.priorNetCorrections),
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationCurrentEffectiveAmountLabel,
                    value: formatAmount(preview.currentEffectiveAmount),
                  ),
                  const Divider(),
                  _PreviewRow(
                    label: l10n.loanObligationProposedCorrectionLabel,
                    value: formatAmount(preview.proposedCorrection),
                  ),
                  _PreviewRow(
                    label: l10n.loanObligationNewEffectiveAmountLabel,
                    value: formatAmount(preview.newEffectiveAmount),
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
              key: const Key('loanObligationCorrectionBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanObligationCorrectionControllerProvider.notifier)
                  .invalidatePreview(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaPrimaryButton(
              key: const Key('loanObligationCorrectionConfirmAction'),
              label: l10n.loanObligationConfirmCorrectionAction,
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
