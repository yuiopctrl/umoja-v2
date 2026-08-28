import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_adjustment_controller.dart';
import '../providers/contribution_charge_detail_provider.dart';

/// `/contributions/charges/:chargeId/adjust`: member charge → signed
/// amount (chosen via an explicit increase/reduce selector, never a
/// raw signed number typed by the user) → reason → effective date →
/// submit. The backend's own floor check
/// (`ADJUSTMENT_WOULD_MAKE_OBLIGATION_NEGATIVE`) is the authority on
/// whether a reducing adjustment is allowed — this screen shows the
/// current net assessed for context only, never pre-computes the
/// allowed range itself.
class ContributionAdjustmentFormScreen extends ConsumerStatefulWidget {
  const ContributionAdjustmentFormScreen({super.key, required this.chargeId});

  final String chargeId;

  @override
  ConsumerState<ContributionAdjustmentFormScreen> createState() =>
      _ContributionAdjustmentFormScreenState();
}

class _ContributionAdjustmentFormScreenState
    extends ConsumerState<ContributionAdjustmentFormScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isIncrease = true;
  DateTime _effectiveAt = DateTime.now();

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
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _effectiveAt = picked);
  }

  Future<void> _submit(
    String groupId,
    String periodId,
    String membershipId,
  ) async {
    FocusScope.of(context).unfocus();
    final magnitude = double.tryParse(_amountController.text.trim());
    if (magnitude == null || magnitude == 0) return;
    final signedAmount = _isIncrease ? magnitude.abs() : -magnitude.abs();

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionAdjustmentControllerProvider.notifier)
        .createAdjustment(
          groupId: groupId,
          chargeId: widget.chargeId,
          periodId: periodId,
          membershipId: membershipId,
          amount: signedAmount,
          reason: _reasonController.text.trim(),
          effectiveAt: _effectiveAt,
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adjustmentSuccessMessage)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final detailAsync = ref.watch(
      contributionChargeDetailProvider(widget.chargeId),
    );
    final adjustmentState = ref.watch(contributionAdjustmentControllerProvider);

    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.addAdjustmentTitle,
      maxWidth: 600,
      backTo: AppRoutes.contributionChargeDetailPath(widget.chargeId),
      backLabel: l10n.chargeDetailTitle,
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(contributionChargeDetailProvider(widget.chargeId)),
        ),
        data: (detail) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail.memberNameSnapshot),
            const SizedBox(height: UmojaSpacing.xs),
            Text(
              '${l10n.contributionCurrentNetAssessedLabel}: '
              '${formatAmount(detail.netAssessed)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: UmojaSpacing.xxl),
            Text(l10n.adjustmentDirectionLabel),
            const SizedBox(height: UmojaSpacing.sm),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(l10n.adjustmentIncreaseOption),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(l10n.adjustmentReduceOption),
                ),
              ],
              selected: {_isIncrease},
              onSelectionChanged: (selection) =>
                  setState(() => _isIncrease = selection.first),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('adjustmentAmountField'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.adjustmentAmountFieldLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('adjustmentReasonField'),
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.adjustmentReasonFieldLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.contributionEffectiveDateFieldLabel),
              subtitle: Text('${_effectiveAt.toLocal()}'.split(' ').first),
              trailing: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: _pickDate,
            ),
            if (adjustmentState.errorType != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                contributionFailureMessage(l10n, adjustmentState.errorType!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: UmojaSpacing.xxl),
            UmojaPrimaryButton(
              label: l10n.adjustmentSubmitAction,
              expand: true,
              isLoading: adjustmentState.isSubmitting,
              onPressed: groupId == null
                  ? null
                  : () =>
                        _submit(groupId, detail.periodId, detail.membershipId),
            ),
          ],
        ),
      ),
    );
  }
}
