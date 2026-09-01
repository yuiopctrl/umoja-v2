import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../providers/loan_account_detail_provider.dart';
import 'widgets/loan_labels.dart';

/// `/loans/accounts/:loanAccountId`: a single loan account and its
/// server-generated repayment schedule (Prompt 09A). Every mutation
/// available here (regenerate schedule, cancel) only ever applies
/// while the loan is still DRAFT — no approve/disburse/receive-payment
/// action exists anywhere on this screen, not even disabled.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final loanAsync = ref.watch(loanAccountDetailProvider(loanAccountId));
    final draftState = ref.watch(loanAccountDraftControllerProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canEdit = membership?.hasPermission('loan.edit') ?? false;
    final canGenerateSchedule =
        membership?.hasPermission('loan_schedule.generate') ?? false;

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
                          semantic: loan.isDraft
                              ? UmojaStatusSemantic.neutral
                              : UmojaStatusSemantic.success,
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
              if (draftState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  loanFailureMessage(l10n, draftState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (loan.isDraft && groupId != null) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                if (canGenerateSchedule)
                  UmojaSecondaryButton(
                    key: const Key('loanRegenerateScheduleAction'),
                    label: l10n.loanRegenerateScheduleAction,
                    isLoading: draftState.isSubmitting,
                    onPressed: () => _regenerate(context, ref, groupId),
                  ),
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
