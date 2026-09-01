import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_workflow_controller.dart';
import '../providers/loan_account_detail_provider.dart';

/// `/loans/accounts/:loanAccountId/reject`: reject a SUBMITTED loan
/// (Prompt 09B). A rejection reason is mandatory — the loan stays
/// historically readable, its schedule stays a historical/planned
/// record, and it can never be disbursed afterward.
class RejectLoanScreen extends ConsumerStatefulWidget {
  const RejectLoanScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  ConsumerState<RejectLoanScreen> createState() => _RejectLoanScreenState();
}

class _RejectLoanScreenState extends ConsumerState<RejectLoanScreen> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm(String groupId) async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    final success = await ref
        .read(loanWorkflowControllerProvider.notifier)
        .reject(
          groupId: groupId,
          loanAccountId: widget.loanAccountId,
          reason: reason,
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
    final workflowState = ref.watch(loanWorkflowControllerProvider);

    return UmojaPage(
      title: l10n.loanRejectTitle,
      maxWidth: 600,
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
        data: (loan) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UmojaCard(
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.borrowerDisplayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(loan.loanNumber),
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('rejectLoanReasonField'),
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.loanRejectionReasonLabel,
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
            UmojaDangerButton(
              key: const Key('rejectLoanConfirmAction'),
              label: l10n.loanRejectConfirmAction,
              expand: true,
              isLoading: workflowState.isSubmitting,
              onPressed: groupId == null ? null : () => _confirm(groupId),
            ),
          ],
        ),
      ),
    );
  }
}
