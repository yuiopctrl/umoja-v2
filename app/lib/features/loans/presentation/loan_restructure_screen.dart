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
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_servicing_controller.dart';
import '../domain/loan_servicing.dart';

/// `/loans/accounts/:loanAccountId/restructure`: Restructure/Reschedule
/// Foundation (Prompt 09E section 6). Reason -> Effective Date ->
/// Proposed Future Schedule -> Preview -> Review -> Confirm. Blocked
/// server-side while any overdue balance (penalty, interest, OR
/// principal) remains outstanding — never debt forgiveness or
/// arbitrary balance editing, only a future-schedule replacement.
class LoanRestructureScreen extends ConsumerStatefulWidget {
  const LoanRestructureScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<LoanRestructureScreen> createState() =>
      _LoanRestructureScreenState();
}

class _LoanRestructureScreenState extends ConsumerState<LoanRestructureScreen> {
  final _reasonController = TextEditingController();
  final _newTermController = TextEditingController();
  final _newInterestRateController = TextEditingController();
  DateTime _newFirstInstallmentDate = DateTime.now().add(
    const Duration(days: 31),
  );

  @override
  void dispose() {
    _reasonController.dispose();
    _newTermController.dispose();
    _newInterestRateController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    ref.read(loanRestructureControllerProvider.notifier).invalidatePreview();
  }

  Future<void> _pickFirstInstallmentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newFirstInstallmentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) {
      setState(() => _newFirstInstallmentDate = picked);
      _onInputChanged();
    }
  }

  int? get _newTerm => int.tryParse(_newTermController.text.trim());
  double? get _newInterestRate {
    final text = _newInterestRateController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _preview(String groupId) async {
    final term = _newTerm;
    if (term == null) return;
    await ref
        .read(loanRestructureControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          newTerm: term,
          newFirstInstallmentDate: _newFirstInstallmentDate,
          newInterestRate: _newInterestRate,
        );
  }

  Future<void> _confirm(String groupId, LoanRestructurePreview preview) async {
    final l10n = context.l10n;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanRestructureTitle,
      message: l10n.loanRestructureSafetyMessage,
      confirmLabel: l10n.loanRestructureConfirmAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(loanRestructureControllerProvider.notifier)
        .confirm(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          reason: reason,
          newTerm: preview.newTerm,
          newFirstInstallmentDate: preview.newFirstInstallmentDate,
          newInterestRate: preview.newInterestRate,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loanRestructureSuccessMessage)),
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
    final state = ref.watch(loanRestructureControllerProvider);
    final preview = state.preview;

    return UmojaPage(
      title: l10n.loanRestructureTitle,
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.loanRestructureSafetyMessage),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanRestructureReasonField'),
            controller: _reasonController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.loanRestructureReasonFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanRestructureNewTermField'),
            controller: _newTermController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _onInputChanged();
            },
            decoration: InputDecoration(
              labelText: l10n.loanRestructureNewTermFieldLabel,
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          OutlinedButton(
            key: const Key('loanRestructureNewFirstInstallmentDateField'),
            onPressed: _pickFirstInstallmentDate,
            child: Text(
              '${l10n.loanRestructureNewFirstInstallmentDateFieldLabel}: '
              '${formatKiswahiliDate(_newFirstInstallmentDate)}',
            ),
          ),
          const SizedBox(height: UmojaSpacing.lg),
          TextField(
            key: const Key('loanRestructureNewInterestRateField'),
            controller: _newInterestRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _onInputChanged(),
            decoration: InputDecoration(
              labelText: l10n.loanRestructureNewInterestRateFieldLabel,
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
              key: const Key('loanRestructurePreviewAction'),
              label: l10n.loanRestructurePreviewAction,
              expand: true,
              isLoading: state.isPreviewing,
              onPressed: groupId == null || _newTerm == null
                  ? null
                  : () => _preview(groupId),
            )
          else ...[
            UmojaCard(
              key: const Key('loanRestructurePreviewCard'),
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.loanRestructureNewScheduleTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final row in preview.newInstallments)
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
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaSecondaryButton(
              key: const Key('loanRestructureBackAction'),
              label: l10n.editScheduleInputsAction,
              onPressed: () => ref
                  .read(loanRestructureControllerProvider.notifier)
                  .invalidatePreview(),
            ),
            const SizedBox(height: UmojaSpacing.md),
            UmojaPrimaryButton(
              key: const Key('loanRestructureConfirmAction'),
              label: l10n.loanRestructureConfirmAction,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed:
                  groupId == null || _reasonController.text.trim().isEmpty
                  ? null
                  : () => _confirm(groupId, preview),
            ),
          ],
        ],
      ),
    );
  }
}
