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
import '../../../core/widgets/umoja_section.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_period_lifecycle_controller.dart';
import '../controllers/contribution_period_penalty_controller.dart';
import '../domain/contribution_period.dart';
import '../domain/contribution_setup.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_setup_detail_provider.dart';
import 'widgets/contribution_period_status_badge.dart';
import 'widgets/contribution_setup_labels.dart';
import 'widgets/contribution_type_labels.dart';

/// `/contributions/periods/:periodId`: contribution period detail — key
/// dates, snapshot info (once OPEN/CLOSED), eligibility/assessment
/// summary, and lifecycle actions gated by status + permission. No
/// paid/unpaid/balance concept anywhere — there is no payments module
/// yet.
class ContributionPeriodDetailScreen extends ConsumerWidget {
  const ContributionPeriodDetailScreen({super.key, required this.periodId});

  final String periodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = ref.watch(contributionPeriodDetailProvider(periodId));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;

    return UmojaPage(
      title: l10n.contributionPeriodDetailTitle,
      maxWidth: 900,
      backTo: AppRoutes.contributionPeriodsList,
      backLabel: l10n.contributionPeriodsTitle,
      body: periodAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(contributionPeriodDetailProvider(periodId)),
        ),
        data: (period) => _PeriodDetailBody(
          period: period,
          groupId: membership?.group.groupId,
          canManage:
              membership?.hasPermission('contribution.period.manage') ?? false,
          canOpen:
              membership?.hasPermission('contribution.period.open') ?? false,
          canClose:
              membership?.hasPermission('contribution.period.close') ?? false,
          canManageAmounts:
              membership?.hasPermission('contribution.member_amount.manage') ??
              false,
          canExclude:
              membership?.hasPermission('contribution.member_exclude') ?? false,
          canEnroll:
              membership?.hasPermission('contribution.member_enroll') ?? false,
          canViewCharges:
              (membership?.hasPermission('contribution.view') ?? false) ||
              (membership?.hasPermission('contribution.self_view') ?? false),
          canAssessPenalties:
              membership?.hasPermission('contribution.penalty.assess') ?? false,
        ),
      ),
    );
  }
}

class _PeriodDetailBody extends ConsumerWidget {
  const _PeriodDetailBody({
    required this.period,
    required this.groupId,
    required this.canManage,
    required this.canOpen,
    required this.canClose,
    required this.canManageAmounts,
    required this.canExclude,
    required this.canEnroll,
    required this.canViewCharges,
    required this.canAssessPenalties,
  });

  final ContributionPeriod period;
  final String? groupId;
  final bool canManage;
  final bool canOpen;
  final bool canClose;
  final bool canManageAmounts;
  final bool canExclude;
  final bool canEnroll;
  final bool canViewCharges;
  final bool canAssessPenalties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Snapshot fields are only populated once OPEN/CLOSED — before that,
    // the live setup record is the source of truth for display.
    final setupAsync = period.isPreOpen
        ? ref.watch(contributionSetupDetailProvider(period.contributionSetupId))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                period.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            ContributionPeriodStatusBadge(status: period.status),
          ],
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaCard(
          padding: const EdgeInsets.symmetric(
            horizontal: UmojaSpacing.lg,
            vertical: UmojaSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaSection(
                title: l10n.sectionContributionPeriodDates,
                child: _DatesSection(period: period),
              ),
              const _SectionDivider(),
              UmojaSection(
                title: l10n.sectionContributionSnapshot,
                child: period.isPreOpen
                    ? (setupAsync == null
                          ? const SizedBox.shrink()
                          : setupAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (error, stackTrace) =>
                                  Text(l10n.refreshFailedMessage),
                              data: (setup) =>
                                  _PreOpenConfigSection(setup: setup),
                            ))
                    : _SnapshotSection(period: period),
              ),
              const _SectionDivider(),
              UmojaSection(
                title: l10n.sectionContributionSummary,
                child: _SummarySection(period: period),
              ),
              const _SectionDivider(),
              UmojaSection(
                title: l10n.sectionActions,
                child: _ActionsSection(
                  period: period,
                  groupId: groupId,
                  canManage: canManage,
                  canOpen: canOpen,
                  canClose: canClose,
                  canManageAmounts: canManageAmounts,
                  canExclude: canExclude,
                  canEnroll: canEnroll,
                  canViewCharges: canViewCharges,
                  canAssessPenalties: canAssessPenalties,
                  isCustomPerMember: period.isPreOpen
                      ? (setupAsync?.value?.isCustomPerMember ?? false)
                      : period.snapshotAmountMode == 'CUSTOM_PER_MEMBER',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
      child: Divider(height: 1),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 200, child: Text(label, style: textTheme.bodyMedium)),
          Expanded(child: Text(value, style: textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _DatesSection extends StatelessWidget {
  const _DatesSection({required this.period});

  final ContributionPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: l10n.contributionPeriodStartLabel,
          value: formatKiswahiliDate(period.periodStart),
        ),
        _InfoRow(
          label: l10n.contributionPeriodEndLabel,
          value: formatKiswahiliDate(period.periodEnd),
        ),
        _InfoRow(
          label: l10n.contributionObligationDateLabel,
          value: formatKiswahiliDate(period.obligationDate),
        ),
        _InfoRow(
          label: l10n.contributionEligibilityDateLabel,
          value: formatKiswahiliDate(period.eligibilityDate),
        ),
        _InfoRow(
          label: l10n.contributionDueDateLabel,
          value: formatKiswahiliDate(period.dueDate),
        ),
        if (period.scheduledOpenDate != null)
          _InfoRow(
            label: l10n.contributionScheduledOpenDateLabel,
            value: formatKiswahiliDate(period.scheduledOpenDate!),
          ),
      ],
    );
  }
}

/// Shown for DRAFT/SCHEDULED periods — reads the *live* setup record
/// (snapshot fields are still null pre-open).
class _PreOpenConfigSection extends StatelessWidget {
  const _PreOpenConfigSection({required this.setup});

  final ContributionSetup setup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: l10n.contributionSetupTypeLabel, value: setup.name),
        _InfoRow(
          label: l10n.contributionAmountModeLabel,
          value: contributionAmountModeLabel(l10n, setup.amountMode),
        ),
        if (setup.isFixedAmount)
          _InfoRow(
            label: l10n.contributionFixedAmountLabel,
            value: formatAmount(setup.fixedAmount ?? 0),
          ),
      ],
    );
  }
}

/// Shown for OPEN/CLOSED periods — the frozen snapshot is the
/// historical source of truth, never the (possibly since-edited) live
/// type/setup record.
class _SnapshotSection extends StatelessWidget {
  const _SnapshotSection({required this.period});

  final ContributionPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (period.snapshotTypeName != null)
          _InfoRow(
            label: l10n.contributionSetupTypeLabel,
            value: period.snapshotTypeName!,
          ),
        if (period.snapshotCategory != null)
          _InfoRow(
            label: l10n.contributionCategoryLabel,
            value: contributionCategoryLabel(l10n, period.snapshotCategory!),
          ),
        if (period.snapshotAccountingTreatment != null)
          _InfoRow(
            label: l10n.contributionAccountingTreatmentLabel,
            value: contributionAccountingTreatmentLabel(
              l10n,
              period.snapshotAccountingTreatment!,
            ),
          ),
        if (period.snapshotAmountMode != null)
          _InfoRow(
            label: l10n.contributionAmountModeLabel,
            value: contributionAmountModeLabel(
              l10n,
              period.snapshotAmountMode!,
            ),
          ),
        if (period.snapshotFixedAmount != null)
          _InfoRow(
            label: l10n.contributionFixedAmountLabel,
            value: formatAmount(period.snapshotFixedAmount!),
          ),
        if (period.snapshotPenaltyMode != null)
          _InfoRow(
            label: l10n.contributionPenaltyModeLabel,
            value: contributionPenaltyModeLabel(
              l10n,
              period.snapshotPenaltyMode!,
            ),
          ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.period});

  final ContributionPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: l10n.contributionExcludedCountLabel,
          value: '${period.excludedCount ?? 0}',
        ),
        _InfoRow(
          label: l10n.contributionCustomAmountCountLabel,
          value: '${period.customAmountCount ?? 0}',
        ),
        _InfoRow(
          label: l10n.contributionTotalMembersChargedLabel,
          value: '${period.totalMembersCharged ?? 0}',
        ),
        _InfoRow(
          label: l10n.contributionTotalBaseAssessedLabel,
          value: formatAmount(period.totalBaseAssessed ?? 0),
        ),
        if (!period.isPreOpen) ...[
          if (period.hasPenaltyPolicy) ...[
            _InfoRow(
              label: l10n.contributionTotalPenaltyAssessedLabel,
              value: formatAmount(period.totalPenaltyAssessed ?? 0),
            ),
            _InfoRow(
              label: l10n.contributionPenaltyChargeCountLabel,
              value: '${period.penaltyChargeCount ?? 0}',
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: UmojaSpacing.sm),
              child: Text(
                l10n.contributionNoPenaltyPolicyMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({
    required this.period,
    required this.groupId,
    required this.canManage,
    required this.canOpen,
    required this.canClose,
    required this.canManageAmounts,
    required this.canExclude,
    required this.canEnroll,
    required this.canViewCharges,
    required this.canAssessPenalties,
    required this.isCustomPerMember,
  });

  final ContributionPeriod period;
  final String? groupId;
  final bool canManage;
  final bool canOpen;
  final bool canClose;
  final bool canManageAmounts;
  final bool canExclude;
  final bool canEnroll;
  final bool canViewCharges;
  final bool canAssessPenalties;
  final bool isCustomPerMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lifecycleState = ref.watch(
      contributionPeriodLifecycleControllerProvider,
    );
    final penaltyState = ref.watch(contributionPeriodPenaltyControllerProvider);

    final buttons = <Widget>[];

    if (period.isPreOpen) {
      if (canManage) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.contributionPeriodEditPath(period.id)),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.editAction),
          ),
        );
      }
      if (canExclude) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRoutes.contributionPeriodExclusionsPath(period.id),
            ),
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: Text(l10n.editExclusionsAction),
          ),
        );
      }
      if (canManageAmounts && isCustomPerMember) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRoutes.contributionPeriodAmountsPath(period.id),
            ),
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: Text(l10n.configureCustomAmountsAction),
          ),
        );
      }
      if (canOpen) {
        buttons.add(
          UmojaPrimaryButton(
            label: l10n.previewAndOpenAction,
            onPressed: () => context.push(
              AppRoutes.contributionPeriodOpenPreviewPath(period.id),
            ),
          ),
        );
      }
      if (canManage) {
        buttons.add(
          UmojaDangerButton(
            label: l10n.cancelPeriodAction,
            isLoading: lifecycleState.isSubmitting,
            onPressed: lifecycleState.isSubmitting
                ? null
                : () => _confirmCancel(context, ref),
          ),
        );
      }
    } else if (period.isOpen) {
      if (canViewCharges) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRoutes.contributionPeriodChargesPath(period.id),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(l10n.viewChargesAction),
          ),
        );
      }
      if (canEnroll) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.contributionPeriodEnrollPath(period.id)),
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: Text(l10n.enrollMemberAction),
          ),
        );
      }
      // Prompt 06B: only shown once this period actually has a penalty
      // policy configured — a period without one gets no pointless
      // action (see docs/product/contributions.md's penalty section).
      if (canAssessPenalties && period.hasPenaltyPolicy) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: penaltyState.isSubmitting
                ? null
                : () => _confirmAssessPenalties(context, ref),
            icon: const Icon(Icons.gavel_outlined, size: 18),
            label: Text(l10n.assessPenaltiesAction),
          ),
        );
      }
      if (canClose) {
        buttons.add(
          UmojaPrimaryButton(
            label: l10n.closePeriodAction,
            isLoading: lifecycleState.isSubmitting,
            onPressed: lifecycleState.isSubmitting
                ? null
                : () => _confirmClose(context, ref),
          ),
        );
      }
    } else if (period.isClosed) {
      if (canViewCharges) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRoutes.contributionPeriodChargesPath(period.id),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(l10n.viewChargesAction),
          ),
        );
      }
    }
    // CANCELLED: read-only — no buttons at all.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buttons.isNotEmpty)
          Wrap(
            spacing: UmojaSpacing.md,
            runSpacing: UmojaSpacing.md,
            children: buttons,
          ),
        if (lifecycleState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.md),
          Text(
            contributionFailureMessage(l10n, lifecycleState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (penaltyState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.md),
          Text(
            contributionFailureMessage(l10n, penaltyState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmAssessPenalties(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final groupId = this.groupId;
    if (groupId == null) return;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.assessPenaltiesConfirmTitle,
      message: l10n.assessPenaltiesConfirmMessage,
      confirmLabel: l10n.assessPenaltiesAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(contributionPeriodPenaltyControllerProvider.notifier)
        .assess(
          groupId: groupId,
          periodId: period.id,
          // The RPC requires an explicit assessment date — its own
          // `default current_date` never applies once PostgREST sends
          // an explicit JSON `null` for an omitted-here argument, so
          // this must always supply today's local date itself rather
          // than leaving it to the backend default.
          assessmentDate: DateTime.now(),
        );
    if (!success || !context.mounted) return;

    final result = ref
        .read(contributionPeriodPenaltyControllerProvider)
        .lastResult;
    if (result == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.assessPenaltiesResultTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.assessPenaltiesResultCreatedCount(
                result.penaltiesCreatedCount,
              ),
            ),
            Text(
              l10n.assessPenaltiesResultAlreadyCurrentCount(
                result.alreadyCurrentChargeCount,
              ),
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              '${l10n.assessPenaltiesResultTotalThisRun}: '
              '${formatAmount(result.totalPenaltyAssessedThisRun)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final groupId = this.groupId;
    if (groupId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.cancelPeriodConfirmTitle,
      message: l10n.cancelPeriodConfirmMessage,
      confirmLabel: l10n.cancelPeriodAction,
      cancelLabel: l10n.cancelButton,
      danger: true,
    );
    if (!confirmed) return;

    final success = await ref
        .read(contributionPeriodLifecycleControllerProvider.notifier)
        .cancel(groupId: groupId, periodId: period.id);
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.periodCancelledMessage)),
      );
    }
  }

  Future<void> _confirmClose(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final groupId = this.groupId;
    if (groupId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.closePeriodConfirmTitle,
      message: l10n.closePeriodConfirmMessage,
      confirmLabel: l10n.closePeriodAction,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(contributionPeriodLifecycleControllerProvider.notifier)
        .close(groupId: groupId, periodId: period.id);
    if (success) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.periodClosedMessage)));
    }
  }
}
