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
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_penalty_assessment_controller.dart';
import '../domain/loan_account.dart';
import '../domain/loan_penalty_charge.dart';
import '../providers/loan_accounts_provider.dart';

/// `/loans/penalties`: Adhabu za Mikopo (Prompt 09D) — total
/// outstanding penalties, ACTIVE loans currently carrying an
/// outstanding penalty, and (permission-gated) Run Assessment.
/// Deliberately separate from Record Payment (section 36): payment
/// consumes already-created obligations; assessment CREATES them.
class LoanPenaltiesScreen extends ConsumerStatefulWidget {
  const LoanPenaltiesScreen({super.key});

  @override
  ConsumerState<LoanPenaltiesScreen> createState() =>
      _LoanPenaltiesScreenState();
}

class _LoanPenaltiesScreenState extends ConsumerState<LoanPenaltiesScreen> {
  DateTime _assessmentDate = DateTime.now();

  static const _activeLoansQuery = (
    membershipId: null,
    loanProductId: null,
    status: 'ACTIVE',
    limit: 100,
    offset: 0,
  );

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _assessmentDate = picked);
  }

  Future<void> _runAssessment(String groupId) async {
    final controller = ref.read(
      loanPenaltyAssessmentControllerProvider.notifier,
    );
    final success = await controller.assess(
      groupId: groupId,
      assessmentDate: _assessmentDate,
    );
    if (success) {
      ref.invalidate(loanAccountsProvider(_activeLoansQuery));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final canAssess = membership?.hasPermission('loan_penalty.assess') ?? false;

    final pageAsync = ref.watch(loanAccountsProvider(_activeLoansQuery));
    final assessmentState = ref.watch(loanPenaltyAssessmentControllerProvider);

    return UmojaPage(
      title: l10n.loanPenaltiesScreenTitle,
      maxWidth: 900,
      backTo: AppRoutes.loansHome,
      backLabel: l10n.loansTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canAssess) ...[
            UmojaCard(
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(l10n.loanPenaltyAssessmentDateFieldLabel),
                      ),
                      TextButton(
                        key: const Key('loanPenaltyAssessmentDatePicker'),
                        onPressed: () => _pickDate(context),
                        child: Text(formatKiswahiliDate(_assessmentDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: UmojaSpacing.sm),
                  UmojaPrimaryButton(
                    key: const Key('loanPenaltyAssessAction'),
                    label: l10n.loanPenaltyAssessActionLabel,
                    expand: true,
                    isLoading: assessmentState.isSubmitting,
                    onPressed: groupId == null
                        ? null
                        : () => _runAssessment(groupId),
                  ),
                  if (assessmentState.errorType != null) ...[
                    const SizedBox(height: UmojaSpacing.sm),
                    Text(
                      loanFailureMessage(l10n, assessmentState.errorType!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (assessmentState.lastResult != null) ...[
                    const SizedBox(height: UmojaSpacing.md),
                    _AssessmentResultSummary(
                      key: const Key('loanPenaltyAssessmentResult'),
                      result: assessmentState.lastResult!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          Text(
            l10n.loanPenaltiesOutstandingTotalLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: UmojaSpacing.xs),
          pageAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: UmojaSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => UmojaErrorState(
              message: l10n.refreshFailedMessage,
              retryLabel: l10n.retryButton,
              onRetry: () =>
                  ref.invalidate(loanAccountsProvider(_activeLoansQuery)),
            ),
            data: (page) {
              final withPenalty = page.items
                  .where((loan) => (loan.penaltyOutstanding ?? 0) > 0)
                  .toList(growable: false);
              final total = withPenalty.fold<double>(
                0,
                (sum, loan) => sum + (loan.penaltyOutstanding ?? 0),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatAmount(total),
                    key: const Key('loanPenaltiesOutstandingTotal'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: UmojaSpacing.md),
                  if (withPenalty.isEmpty)
                    UmojaEmptyState(
                      icon: Icons.check_circle_outline,
                      title: l10n.loanPenaltiesOutstandingTotalLabel,
                      message: l10n.loanPenaltyHistoryEmptyMessage,
                    )
                  else
                    for (final loan in withPenalty) _LoanPenaltyRow(loan: loan),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AssessmentResultSummary extends StatelessWidget {
  const _AssessmentResultSummary({super.key, required this.result});

  final LoanPenaltyAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultRow(
          label: l10n.loanPenaltyAssessmentResultEligibleLabel,
          value: result.eligibleInstallmentCount.toString(),
        ),
        _ResultRow(
          label: l10n.loanPenaltyAssessmentResultAssessedLabel,
          value: result.assessedCount.toString(),
        ),
        _ResultRow(
          label: l10n.loanPenaltyAssessmentResultSkippedLabel,
          value: result.skippedCount.toString(),
        ),
        _ResultRow(
          label: l10n.loanPenaltyAssessmentResultTotalLabel,
          value: formatAmount(result.totalPenaltyAmount),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _LoanPenaltyRow extends StatelessWidget {
  const _LoanPenaltyRow({required this.loan});

  final LoanAccount loan;

  @override
  Widget build(BuildContext context) {
    return UmojaListTile(
      title: loan.borrowerDisplayName,
      subtitle: Text('${loan.loanNumber} · ${loan.loanProductName}'),
      trailing: Text(
        formatAmount(loan.penaltyOutstanding ?? 0),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: () => context.push(AppRoutes.loanAccountDetailPath(loan.id)),
    );
  }
}
