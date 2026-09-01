import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
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
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_account_draft_controller.dart';
import '../controllers/loan_workflow_controller.dart';
import '../domain/loan_account.dart';
import '../providers/loan_account_detail_provider.dart';
import 'widgets/loan_labels.dart';

/// `/loans/accounts/:loanAccountId`: a single loan account, its
/// server-generated repayment schedule, and its full lifecycle
/// (Prompt 09A foundation, extended 09B with Submit/Approve/Reject/
/// Cancel/Disburse). Actions shown depend on both status and
/// permission — DRAFT allows Edit/Regenerate/Submit/Cancel; SUBMITTED
/// allows Approve/Reject/Cancel; APPROVED allows Disburse/Cancel;
/// DISBURSED/ACTIVE show funded disbursement detail with no further
/// mutation; REJECTED/CANCELLED are read-only history. No approve/
/// disburse/receive-payment action ever appears merely disabled for
/// an unauthorized user — it is hidden outright, matching the rest of
/// this module's convention; the backend remains the authorization
/// boundary regardless.
class LoanAccountDetailScreen extends ConsumerWidget {
  const LoanAccountDetailScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  Future<void> _regenerate(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    await ref
        .read(loanAccountDraftControllerProvider.notifier)
        .regenerateSchedule(groupId: groupId, loanAccountId: loanAccountId);
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanCancelDraftConfirmTitle,
      message: l10n.loanCancelDraftConfirmMessage,
      confirmLabel: l10n.loanCancelDraftAction,
      cancelLabel: l10n.cancelButton,
      danger: true,
    );
    if (!confirmed) return;

    await ref
        .read(loanAccountDraftControllerProvider.notifier)
        .cancelDraft(groupId: groupId, loanAccountId: loanAccountId);
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    LoanAccount loan,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanSubmitConfirmTitle,
      message: l10n.loanSubmitConfirmMessage(
        loan.borrowerDisplayName,
        loan.loanNumber,
        loan.loanProductName,
        formatAmount(loan.principalAmount),
        loanInterestMethodLabel(l10n, loan.interestMethod),
        loan.interestRate.toString(),
        loan.term.toString(),
        formatAmount(loan.totalInterest),
        formatAmount(loan.totalRepayable),
        formatKiswahiliDate(loan.firstRepaymentDate),
      ),
      confirmLabel: l10n.loanSubmitAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    await ref
        .read(loanWorkflowControllerProvider.notifier)
        .submit(groupId: groupId, loanAccountId: loanAccountId);
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.loanApproveConfirmTitle,
      message: l10n.loanApproveConfirmMessage,
      confirmLabel: l10n.loanApproveAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    await ref
        .read(loanWorkflowControllerProvider.notifier)
        .approve(groupId: groupId, loanAccountId: loanAccountId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final loanAsync = ref.watch(loanAccountDetailProvider(loanAccountId));
    final draftState = ref.watch(loanAccountDraftControllerProvider);
    final workflowState = ref.watch(loanWorkflowControllerProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canEdit = membership?.hasPermission('loan.edit') ?? false;
    final canGenerateSchedule =
        membership?.hasPermission('loan_schedule.generate') ?? false;
    final canSubmit = membership?.hasPermission('loan.submit') ?? false;
    final canApprove = membership?.hasPermission('loan.approve') ?? false;
    final canReject = membership?.hasPermission('loan.reject') ?? false;
    final canCancel = membership?.hasPermission('loan.cancel') ?? false;
    final canDisburse = membership?.hasPermission('loan.disburse') ?? false;

    return UmojaPage(
      title: l10n.loanAccountDetailTitle,
      maxWidth: 700,
      body: loanAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(loanAccountDetailProvider(loanAccountId)),
        ),
        data: (loan) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            loan.borrowerDisplayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        UmojaStatusBadge(
                          label: loanAccountStatusLabel(l10n, loan.status),
                          semantic: loanAccountStatusSemantic(loan.status),
                        ),
                      ],
                    ),
                    Text(loan.loanNumber),
                    const SizedBox(height: UmojaSpacing.md),
                    _DetailRow(
                      label: l10n.loanProductsTitle,
                      value: loan.loanProductName,
                    ),
                    _DetailRow(
                      label: l10n.loanAccountPrincipalFieldLabel,
                      value: formatAmount(loan.principalAmount),
                    ),
                    _DetailRow(
                      label: l10n.loanProductInterestRateFieldLabel,
                      value:
                          '${loan.interestRate} '
                          '(${loanInterestRateBasisLabel(l10n, loan.interestRateBasis)}, '
                          '${loanInterestMethodLabel(l10n, loan.interestMethod)})',
                    ),
                    _DetailRow(
                      label: l10n.loanAccountTermFieldLabel,
                      value: loan.term.toString(),
                    ),
                    _DetailRow(
                      label: l10n.loanAccountFirstRepaymentDateFieldLabel,
                      value: formatKiswahiliDate(loan.firstRepaymentDate),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              Text(
                l10n.loanScheduleTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: UmojaSpacing.sm),
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  children: [
                    for (final installment in loan.installments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.loanInstallmentNumberLabel(
                                  installment.installmentNumber,
                                ),
                              ),
                            ),
                            Text(formatKiswahiliDate(installment.dueDate)),
                            const SizedBox(width: UmojaSpacing.md),
                            Text(formatAmount(installment.totalDue)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (loan.disbursement != null) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                Text(
                  l10n.loanDisbursementDetailTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: UmojaSpacing.sm),
                UmojaCard(
                  padding: const EdgeInsets.all(UmojaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        label: l10n.loanDisburseFinancialAccountLabel,
                        value: loan.disbursement!.financialAccountName,
                      ),
                      _DetailRow(
                        label: l10n.loanDisburseAmountLabel,
                        value: formatAmount(loan.disbursement!.amount),
                      ),
                      _DetailRow(
                        label: l10n.loanDisburseEffectiveDateLabel,
                        value: formatKiswahiliDate(
                          loan.disbursement!.effectiveAt,
                        ),
                      ),
                      if (loan.disbursement!.reference != null)
                        _DetailRow(
                          label: l10n.loanDisburseReferenceFieldLabel,
                          value: loan.disbursement!.reference!,
                        ),
                    ],
                  ),
                ),
              ],
              if (loan.isRejected || loan.isCancelled) ...[
                const SizedBox(height: UmojaSpacing.lg),
                Builder(
                  builder: (context) {
                    final event = loan.events
                        .where(
                          (e) =>
                              e.eventType ==
                              (loan.isRejected ? 'REJECTED' : 'CANCELLED'),
                        )
                        .lastOrNull;
                    if (event?.reason == null) return const SizedBox.shrink();
                    return Text(
                      '${l10n.loanReasonLabel}: ${event!.reason}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                ),
              ],
              if (draftState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  loanFailureMessage(l10n, draftState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (workflowState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  loanFailureMessage(l10n, workflowState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (groupId != null) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                if (loan.isDraft) ...[
                  if (canEdit)
                    UmojaPrimaryButton(
                      key: const Key('loanEditTermsAction'),
                      label: l10n.loanEditTermsAction,
                      expand: true,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountEditPath(loanAccountId),
                      ),
                    ),
                  if (canGenerateSchedule) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    UmojaSecondaryButton(
                      key: const Key('loanRegenerateScheduleAction'),
                      label: l10n.loanRegenerateScheduleAction,
                      isLoading: draftState.isSubmitting,
                      onPressed: () => _regenerate(context, ref, groupId),
                    ),
                  ],
                  if (canSubmit) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    UmojaSecondaryButton(
                      key: const Key('loanSubmitAction'),
                      label: l10n.loanSubmitAction,
                      isLoading: workflowState.isSubmitting,
                      onPressed: () => _submit(context, ref, groupId, loan),
                    ),
                  ],
                  if (canEdit) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    UmojaDangerButton(
                      key: const Key('loanCancelDraftAction'),
                      label: l10n.loanCancelDraftAction,
                      isLoading: draftState.isSubmitting,
                      onPressed: () => _cancel(context, ref, groupId),
                    ),
                  ],
                ],
                if (loan.isSubmitted) ...[
                  if (canApprove)
                    UmojaPrimaryButton(
                      key: const Key('loanApproveAction'),
                      label: l10n.loanApproveAction,
                      expand: true,
                      isLoading: workflowState.isSubmitting,
                      onPressed: () => _approve(context, ref, groupId),
                    ),
                  if (canReject) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    UmojaDangerButton(
                      key: const Key('loanRejectAction'),
                      label: l10n.loanRejectAction,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountRejectPath(loanAccountId),
                      ),
                    ),
                  ],
                  if (canCancel) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    UmojaSecondaryButton(
                      key: const Key('loanCancelAction'),
                      label: l10n.loanCancelAction,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountCancelPath(loanAccountId),
                      ),
                    ),
                  ],
                ],
                if (loan.isApproved) ...[
                  if (canDisburse)
                    UmojaPrimaryButton(
                      key: const Key('loanDisburseAction'),
                      label: l10n.loanDisburseAction,
                      expand: true,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountDisbursePath(loanAccountId),
                      ),
                    ),
                  if (canCancel) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    UmojaSecondaryButton(
                      key: const Key('loanCancelAction'),
                      label: l10n.loanCancelAction,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountCancelPath(loanAccountId),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: UmojaSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
