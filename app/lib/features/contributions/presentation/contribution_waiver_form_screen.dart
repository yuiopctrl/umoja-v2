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
import '../controllers/contribution_waiver_controller.dart';
import '../providers/contribution_charge_detail_provider.dart';

/// `/contributions/charges/:chargeId/waive`: partial/full waiver
/// selection → amount → reason → effective date → confirm. Shows the
/// backend-authoritative current net obligation (maximum waiver) and
/// the resulting remaining obligation — never computed client-side; a
/// full waiver simply pre-fills the amount field with the current net
/// assessed rather than this screen deriving anything itself.
class ContributionWaiverFormScreen extends ConsumerStatefulWidget {
  const ContributionWaiverFormScreen({super.key, required this.chargeId});

  final String chargeId;

  @override
  ConsumerState<ContributionWaiverFormScreen> createState() =>
      _ContributionWaiverFormScreenState();
}

class _ContributionWaiverFormScreenState
    extends ConsumerState<ContributionWaiverFormScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isFull = false;
  DateTime _effectiveAt = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onTypeChanged(bool isFull, double netAssessed) {
    setState(() {
      _isFull = isFull;
      if (isFull) {
        _amountController.text = netAssessed.toString();
      }
    });
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

  Future<void> _submit(String groupId, String membershipId) async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionWaiverControllerProvider.notifier)
        .waive(
          groupId: groupId,
          chargeId: widget.chargeId,
          membershipId: membershipId,
          amount: amount,
          reason: _reasonController.text.trim(),
          effectiveAt: _effectiveAt,
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.waiverSuccessMessage)),
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
    final waiverState = ref.watch(contributionWaiverControllerProvider);

    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.waiveObligationTitle,
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
        data: (detail) {
          final enteredAmount =
              double.tryParse(_amountController.text.trim()) ?? 0;
          final remainingAfter = (detail.netAssessed - enteredAmount).clamp(
            0,
            detail.netAssessed,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.memberNameSnapshot),
              const SizedBox(height: UmojaSpacing.xs),
              Text(
                '${l10n.contributionCurrentNetAssessedLabel}: '
                '${formatAmount(detail.netAssessed)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${l10n.waiverMaximumLabel}: ${formatAmount(detail.netAssessed)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              Text(l10n.waiverTypeLabel),
              const SizedBox(height: UmojaSpacing.sm),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.waiverPartialOption),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.waiverFullOption),
                  ),
                ],
                selected: {_isFull},
                onSelectionChanged: (selection) =>
                    _onTypeChanged(selection.first, detail.netAssessed),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('waiverAmountField'),
                controller: _amountController,
                enabled: !_isFull,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.waiverAmountFieldLabel,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                '${l10n.waiverRemainingAfterLabel}: '
                '${formatAmount(remainingAfter.toDouble())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('waiverReasonField'),
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.waiverReasonFieldLabel,
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
              if (waiverState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  contributionFailureMessage(l10n, waiverState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                label: l10n.waiverSubmitAction,
                expand: true,
                isLoading: waiverState.isSubmitting,
                onPressed: groupId == null
                    ? null
                    : () => _submit(groupId, detail.membershipId),
              ),
            ],
          );
        },
      ),
    );
  }
}
