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
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_account_draft_controller.dart';
import '../controllers/loan_obligation_adjustment_controller.dart';
import '../controllers/loan_workflow_controller.dart';
import '../domain/loan_account.dart';
import '../domain/loan_installment.dart';
import '../domain/loan_obligation_adjustment.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_obligation_adjustments_provider.dart';
import '../providers/loan_penalty_charges_provider.dart';
import 'widgets/loan_labels.dart';

/// `/loans/accounts/:loanAccountId`: a single loan account, its
/// server-generated repayment schedule, and its full lifecycle
/// (Prompt 09A foundation, extended 09B with Submit/Approve/Reject/
/// Cancel/Disburse, and 09C with derived repayment summary/installment
/// status). Actions shown depend on both status and permission — DRAFT
/// allows Edit/Regenerate/Submit/Cancel; SUBMITTED allows
/// Approve/Reject/Cancel; APPROVED allows Disburse/Cancel; ACTIVE shows
/// the repayment summary and per-installment status (a convenience
/// "Receive Payment" shortcut into the existing Record Payment flow was
/// considered here but deferred — see docs/product/loans.md); CLOSED
/// and DISBURSED show funded/settled detail with no further mutation;
/// REJECTED/CANCELLED are read-only history. No approve/disburse action
/// ever appears merely disabled for an unauthorized user — it is hidden
/// outright, matching the rest of this module's convention; the backend
/// remains the authorization boundary regardless.
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
    final canSettleEarly =
        membership?.hasPermission('loan.settle_early') ?? false;
    final canPrepayPrincipal =
        membership?.hasPermission('loan.prepay_principal') ?? false;
    final canRestructure =
        membership?.hasPermission('loan.restructure') ?? false;
    final canWaive = membership?.hasPermission('loan.waive') ?? false;
    final canCorrect = membership?.hasPermission('loan.correct') ?? false;
    final canCorrectIncrease =
        membership?.hasPermission('loan.correct_increase') ?? false;

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
                    if (loan.isMigrated) ...[
                      const SizedBox(height: UmojaSpacing.xs),
                      UmojaStatusBadge(
                        key: const Key('loanMigratedBadge'),
                        label: l10n.migratedBadgeLabel,
                        semantic: UmojaStatusSemantic.info,
                      ),
                    ],
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
              const SizedBox(height: UmojaSpacing.lg),
              // Frozen penalty snapshot (Prompt 09D, section 39) — the
              // loan's OWN terms, never the current (possibly since-
              // edited) loan product policy.
              UmojaCard(
                key: const Key('loanPenaltySnapshotCard'),
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.loanPenaltySnapshotTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: UmojaSpacing.xs),
                    if (loan.penaltyEnabled)
                      Text(
                        loanPenaltyPolicyDescription(
                          l10n,
                          penaltyType: loan.penaltyType!,
                          penaltyFrequency: loan.penaltyFrequency!,
                          graceDays: loan.penaltyGraceDays ?? 0,
                          fixedAmount: loan.penaltyFixedAmount,
                          rate: loan.penaltyRate,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Text(
                        l10n.loanPenaltyPolicyDisabledLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              if (loan.isMigrated && loan.openingPosition != null) ...[
                const SizedBox(height: UmojaSpacing.lg),
                UmojaCard(
                  key: const Key('loanOpeningPositionCard'),
                  padding: const EdgeInsets.all(UmojaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sectionMigratedLoanOpeningPosition,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: UmojaSpacing.xs),
                      _DetailRow(
                        label: l10n.originalDisbursementDateLabel,
                        value: formatKiswahiliDate(
                          loan.openingPosition!.originalDisbursementDate,
                        ),
                      ),
                      _DetailRow(
                        label: l10n.openingAsOfDateLabel,
                        value: formatKiswahiliDate(
                          loan.openingPosition!.openingAsOfDate,
                        ),
                      ),
                      _DetailRow(
                        label: l10n.originalPrincipalLabel,
                        value: formatAmount(
                          loan.openingPosition!.originalPrincipal,
                        ),
                      ),
                      _DetailRow(
                        label: l10n.openingPrincipalOutstandingFieldLabel,
                        value: formatAmount(
                          loan.openingPosition!.openingPrincipalOutstanding,
                        ),
                      ),
                      _DetailRow(
                        label: l10n.openingPrincipalArrearsFieldLabel,
                        value: formatAmount(
                          loan.openingPosition!.openingPrincipalArrears,
                        ),
                      ),
                      _DetailRow(
                        label: l10n.openingInterestArrearsFieldLabel,
                        value: formatAmount(
                          loan.openingPosition!.openingInterestArrears,
                        ),
                      ),
                      _DetailRow(
                        label: l10n.openingPenaltyArrearsFieldLabel,
                        value: formatAmount(
                          loan.openingPosition!.openingPenaltyArrears,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_historicalArrearsInstallments(loan).isNotEmpty) ...[
                  const SizedBox(height: UmojaSpacing.lg),
                  UmojaCard(
                    key: const Key('loanHistoricalArrearsCard'),
                    padding: const EdgeInsets.all(UmojaSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sectionMigratedLoanHistoricalArrears,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: UmojaSpacing.xs),
                        for (final (i, installment)
                            in _historicalArrearsInstallments(loan).indexed)
                          Padding(
                            key: Key('loanHistoricalArrearsRow_$i'),
                            padding: const EdgeInsets.only(
                              bottom: UmojaSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatKiswahiliDate(installment.dueDate),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                _DetailRow(
                                  label: l10n.arrearsRowPrincipalLabel,
                                  value: formatAmount(
                                    installment.principalOutstanding ??
                                        installment.principalDue,
                                  ),
                                ),
                                _DetailRow(
                                  label: l10n.arrearsRowInterestLabel,
                                  value: formatAmount(
                                    installment.interestOutstanding ??
                                        installment.interestDue,
                                  ),
                                ),
                                if ((installment.penaltyOutstanding ?? 0) > 0)
                                  _DetailRow(
                                    label: l10n.arrearsRowPenaltyLabel,
                                    value: formatAmount(
                                      installment.penaltyOutstanding!,
                                    ),
                                  ),
                                _DetailRow(
                                  label: l10n.arrearsRowTotalLabel,
                                  value: formatAmount(
                                    installment.totalOutstanding ??
                                        installment.totalDue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
              if (loan.isActive || loan.isClosed) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                Text(
                  l10n.loanScheduleTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: UmojaSpacing.sm),
                UmojaCard(
                  key: const Key('loanRepaymentSummaryCard'),
                  padding: const EdgeInsets.all(UmojaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        label: l10n.loanSummaryPrincipalRepaidLabel,
                        value: formatAmount(loan.principalRepaid),
                      ),
                      _DetailRow(
                        label: l10n.loanSummaryPrincipalOutstandingLabel,
                        value: formatAmount(loan.principalOutstanding ?? 0),
                      ),
                      _DetailRow(
                        label: l10n.loanSummaryInterestRecognizedLabel,
                        value: formatAmount(loan.interestRecognized),
                      ),
                      _DetailRow(
                        label: l10n.loanSummaryInterestOutstandingLabel,
                        value: formatAmount(loan.interestOutstanding ?? 0),
                      ),
                      if (loan.penaltyOutstanding != null &&
                          loan.penaltyOutstanding! > 0) ...[
                        _DetailRow(
                          label: l10n.loanSummaryPenaltyPaidLabel,
                          value: formatAmount(loan.penaltyPaid),
                        ),
                        _DetailRow(
                          key: const Key('loanSummaryPenaltyOutstandingRow'),
                          label: l10n.loanSummaryPenaltyOutstandingLabel,
                          value: formatAmount(loan.penaltyOutstanding!),
                        ),
                      ],
                      _DetailRow(
                        label: l10n.loanSummaryTotalOutstandingLabel,
                        value: formatAmount(loan.totalOutstanding ?? 0),
                      ),
                      if (loan.nextDueDate != null)
                        _DetailRow(
                          label: l10n.loanSummaryNextDueDateLabel,
                          value: formatKiswahiliDate(loan.nextDueDate!),
                        ),
                      if (loan.overdueAmount > 0)
                        _DetailRow(
                          label: l10n.loanSummaryOverdueAmountLabel,
                          value: formatAmount(loan.overdueAmount),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
              ] else ...[
                const SizedBox(height: UmojaSpacing.xxl),
                Text(
                  l10n.loanScheduleTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: UmojaSpacing.sm),
              ],
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.loanInstallmentNumberLabel(
                                      installment.installmentNumber,
                                    ),
                                  ),
                                  Text(
                                    formatKiswahiliDate(installment.dueDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  if ((installment.penaltyOutstanding ?? 0) > 0)
                                    Text(
                                      '${l10n.loanComponentPenalty}: '
                                      '${formatAmount(installment.penaltyOutstanding!)}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  if (installment.id != null &&
                                      (installment.interestOutstanding ?? 0) >
                                          0 &&
                                      _isInterestAdjustmentEligibleByDate(
                                        installment,
                                      ) &&
                                      (canWaive || canCorrect))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: UmojaSpacing.xs,
                                      ),
                                      child: Wrap(
                                        spacing: UmojaSpacing.sm,
                                        children: [
                                          if (canWaive)
                                            TextButton(
                                              key: Key(
                                                'loanWaiveInterestAction_${installment.id}',
                                              ),
                                              onPressed: () => context.push(
                                                AppRoutes.loanObligationWaivePath(
                                                  loanAccountId,
                                                  'LOAN_INTEREST',
                                                  installment.id!,
                                                ),
                                              ),
                                              child: Text(
                                                l10n.loanWaiveObligationAction,
                                              ),
                                            ),
                                          if (canCorrect)
                                            TextButton(
                                              key: Key(
                                                'loanCorrectInterestAction_${installment.id}',
                                              ),
                                              onPressed: () => context.push(
                                                AppRoutes.loanObligationCorrectPath(
                                                  loanAccountId,
                                                  'LOAN_INTEREST',
                                                  installment.id!,
                                                ),
                                              ),
                                              child: Text(
                                                l10n.loanCorrectObligationAction,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (installment.status != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: UmojaSpacing.sm,
                                ),
                                child: UmojaStatusBadge(
                                  label: loanInstallmentStatusLabel(
                                    l10n,
                                    installment.status!,
                                  ),
                                  semantic: loanInstallmentStatusSemantic(
                                    installment.status!,
                                  ),
                                ),
                              ),
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
              if (loan.penaltyEnabled) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                Text(
                  l10n.loanPenaltyHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: UmojaSpacing.sm),
                Consumer(
                  key: const Key('loanPenaltyHistorySection'),
                  builder: (context, ref, _) {
                    final chargesAsync = ref.watch(
                      loanPenaltyChargesProvider(loanAccountId),
                    );
                    return chargesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: UmojaSpacing.lg,
                        ),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => UmojaErrorState(
                        message: l10n.refreshFailedMessage,
                        retryLabel: l10n.retryButton,
                        onRetry: () => ref.invalidate(
                          loanPenaltyChargesProvider(loanAccountId),
                        ),
                      ),
                      data: (charges) {
                        if (charges.isEmpty) {
                          return Text(l10n.loanPenaltyHistoryEmptyMessage);
                        }
                        return UmojaCard(
                          padding: const EdgeInsets.all(UmojaSpacing.lg),
                          child: Column(
                            children: [
                              for (final charge in charges)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: UmojaSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              charge.isOpening
                                                  ? l10n.loanPenaltyOriginOpeningLabel
                                                  : l10n.loanPenaltyOccurrenceLabel(
                                                      charge.sequenceNumber,
                                                    ),
                                            ),
                                            Text(
                                              formatKiswahiliDate(
                                                charge.assessmentDate,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            if (charge.outstandingAmount > 0 &&
                                                (canWaive || canCorrect))
                                              Wrap(
                                                spacing: UmojaSpacing.sm,
                                                children: [
                                                  if (canWaive)
                                                    TextButton(
                                                      key: Key(
                                                        'loanWaivePenaltyAction_${charge.id}',
                                                      ),
                                                      onPressed: () => context.push(
                                                        AppRoutes.loanObligationWaivePath(
                                                          loanAccountId,
                                                          'LOAN_PENALTY',
                                                          charge.id,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        l10n.loanWaiveObligationAction,
                                                      ),
                                                    ),
                                                  if (canCorrect)
                                                    TextButton(
                                                      key: Key(
                                                        'loanCorrectPenaltyAction_${charge.id}',
                                                      ),
                                                      onPressed: () => context.push(
                                                        AppRoutes.loanObligationCorrectPath(
                                                          loanAccountId,
                                                          'LOAN_PENALTY',
                                                          charge.id,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        l10n.loanCorrectObligationAction,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(formatAmount(charge.penaltyAmount)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              if (loan.isActive || loan.isClosed) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                Text(
                  l10n.loanObligationHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: UmojaSpacing.sm),
                _LoanObligationAdjustmentHistorySection(
                  key: const Key('loanObligationHistorySection'),
                  loanAccountId: loanAccountId,
                  groupId: groupId,
                  canReverseWaiver: canWaive,
                  canReverseCorrection: canCorrect,
                  canReverseCorrectionIncrease: canCorrectIncrease,
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
                if (loan.isActive) ...[
                  if (canSettleEarly) ...[
                    UmojaPrimaryButton(
                      key: const Key('loanEarlySettlementAction'),
                      label: l10n.loanEarlySettlementAction,
                      expand: true,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountEarlySettlementPath(loanAccountId),
                      ),
                    ),
                    const SizedBox(height: UmojaSpacing.md),
                  ],
                  if (canPrepayPrincipal) ...[
                    UmojaSecondaryButton(
                      key: const Key('loanPrepayPrincipalAction'),
                      label: l10n.loanPrepayPrincipalAction,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountPrepayPath(loanAccountId),
                      ),
                    ),
                    const SizedBox(height: UmojaSpacing.md),
                  ],
                  if (canRestructure)
                    UmojaSecondaryButton(
                      key: const Key('loanRestructureAction'),
                      label: l10n.loanRestructureAction,
                      onPressed: () => context.push(
                        AppRoutes.loanAccountRestructurePath(loanAccountId),
                      ),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A migrated loan's historical overdue installments — each preserved
/// as its own `loan_installments` row with due_date <= the opening
/// as-of date (Prompt 09D-UAT-BLOCKER-02, section 23). Never one
/// synthetic combined row, and never shown for a NEW loan (which has no
/// opening position at all).
List<LoanInstallment> _historicalArrearsInstallments(LoanAccount loan) {
  final openingAsOfDate = loan.openingPosition?.openingAsOfDate;
  if (openingAsOfDate == null) return const [];
  return loan.installments
      .where((installment) => !installment.dueDate.isAfter(openingAsOfDate))
      .toList(growable: false);
}

/// Prompt 09F-A-12: whether an installment's interest is far enough
/// along to even offer Waive/Correct — mirrors the server's own
/// `due_date <= effective_date` gate (`rpc_preview/post_loan_obligation_
/// waiver`/`..._correction`, which unconditionally reject
/// LOAN_FUTURE_INTEREST_NOT_WAIVABLE/_NOT_CORRECTABLE otherwise). This
/// is a UX-only convenience so the action is never offered somewhere
/// the server is guaranteed to reject it (09F-A-11 Blocker-03) — it is
/// never itself the accounting authority, which remains entirely
/// server-side regardless of what this returns.
///
/// The loan read model has no top-level "as of"/server-generated-at
/// date to compare against (only a per-installment `status` string,
/// which collapses due-date ordering together with payment state —
/// e.g. `PARTIALLY_PAID` can occur for an on-time-or-future installment
/// just as easily as an overdue one, so it can't disambiguate
/// "future" on its own). In the absence of a server-supplied reference
/// date, this deliberately falls back to the device's local clock
/// ([DateTime.now]) purely to decide whether to show the button —
/// documented limitation: a device with a badly wrong clock could show
/// (or hide) the action inconsistently with the server's own
/// evaluation, but can never make the server accept an actually-future
/// waiver/correction, since the server re-evaluates its own
/// `current_date` independently on every preview and post.
bool _isInterestAdjustmentEligibleByDate(LoanInstallment installment) {
  final today = DateTime.now();
  final referenceDate = DateTime(today.year, today.month, today.day);
  return !installment.dueDate.isAfter(referenceDate);
}

/// Prompt 09F-A section 26: "Adjustments & Waivers" — the authoritative,
/// immutable history for one loan. No edit/delete is ever offered;
/// [_LoanObligationAdjustmentHistorySection.canReverseWaiver]/etc. only
/// gate whether the Reverse action is even shown — the server still
/// makes the final decision (permission + dependency-guard) on every
/// reversal attempt.
class _LoanObligationAdjustmentHistorySection extends ConsumerWidget {
  const _LoanObligationAdjustmentHistorySection({
    super.key,
    required this.loanAccountId,
    required this.groupId,
    required this.canReverseWaiver,
    required this.canReverseCorrection,
    required this.canReverseCorrectionIncrease,
  });

  final String loanAccountId;
  final String? groupId;
  final bool canReverseWaiver;
  final bool canReverseCorrection;
  final bool canReverseCorrectionIncrease;

  bool _canReverse(LoanObligationAdjustment adjustment) {
    switch (adjustment.adjustmentType) {
      case 'WAIVER':
        return canReverseWaiver;
      case 'CORRECTION_INCREASE':
        return canReverseCorrection && canReverseCorrectionIncrease;
      case 'CORRECTION_DECREASE':
        return canReverseCorrection;
      default:
        return false;
    }
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    LoanObligationAdjustment adjustment,
  ) async {
    final l10n = context.l10n;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.loanObligationReverseConfirmTitle),
        content: TextField(
          key: const Key('loanObligationReverseReasonField'),
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.loanObligationReverseReasonFieldLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('loanObligationReverseConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.loanObligationReverseAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(loanObligationAdjustmentReversalControllerProvider.notifier)
        .reverse(
          groupId: groupId,
          loanAccountId: loanAccountId,
          adjustmentId: adjustment.id,
          reversalReason: reasonController.text.trim(),
        );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loanObligationReverseSuccessMessage)),
      );
    } else if (context.mounted) {
      final errorType = ref
          .read(loanObligationAdjustmentReversalControllerProvider)
          .errorType;
      if (errorType != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loanFailureMessage(l10n, errorType))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pageAsync = ref.watch(
      loanObligationAdjustmentsProvider(loanAccountId),
    );
    final reversalState = ref.watch(
      loanObligationAdjustmentReversalControllerProvider,
    );

    return pageAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => UmojaErrorState(
        message: l10n.refreshFailedMessage,
        retryLabel: l10n.retryButton,
        onRetry: () =>
            ref.invalidate(loanObligationAdjustmentsProvider(loanAccountId)),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return UmojaEmptyState(
            icon: Icons.receipt_long_outlined,
            title: l10n.loanObligationHistoryTitle,
            message: l10n.loanObligationHistoryEmptyMessage,
          );
        }
        return UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            children: [
              for (final adjustment in page.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${adjustment.adjustmentType} · '
                              '${adjustment.targetType}',
                            ),
                            Text(
                              formatKiswahiliDate(adjustment.effectiveDate),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (adjustment.reasonCode.isNotEmpty)
                              Text(
                                adjustment.reasonCode,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (adjustment.isReversed)
                              Text(
                                l10n.loanObligationHistoryReversedLabel,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              )
                            else if (groupId != null &&
                                adjustment.isReversalCandidate &&
                                _canReverse(adjustment))
                              TextButton(
                                key: Key(
                                  'loanObligationReverseAction_${adjustment.id}',
                                ),
                                onPressed: reversalState.isSubmitting
                                    ? null
                                    : () => _reverse(
                                        context,
                                        ref,
                                        groupId!,
                                        adjustment,
                                      ),
                                child: Text(l10n.loanObligationReverseAction),
                              ),
                          ],
                        ),
                      ),
                      Text(formatAmount(adjustment.amount)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({super.key, required this.label, required this.value});

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
