import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_period_lifecycle_controller.dart';
import '../domain/contribution_period_open_preview.dart';
import '../providers/contribution_period_open_preview_provider.dart';
import 'widgets/contribution_exclusion_reason_label.dart';

/// `/contributions/periods/:periodId/open-preview`: server-authoritative
/// preview of `rpc_open_contribution_period()` — eligible/excluded
/// counts and lists, total assessment, and a missing-custom-amount
/// blocker. Confirming here calls
/// `ContributionPeriodLifecycleController.open`, itself calling
/// `rpc_open_contribution_period`, only after explicit confirmation via
/// [showUmojaConfirmationSheet].
class ContributionPeriodOpenPreviewScreen extends ConsumerWidget {
  const ContributionPeriodOpenPreviewScreen({
    super.key,
    required this.periodId,
  });

  final String periodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(
      contributionPeriodOpenPreviewProvider(periodId),
    );
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.openPreviewTitle,
      maxWidth: 800,
      backTo: AppRoutes.contributionPeriodDetailPath(periodId),
      backLabel: l10n.contributionPeriodDetailTitle,
      body: previewAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(contributionPeriodOpenPreviewProvider(periodId)),
        ),
        data: (preview) => _PreviewBody(
          periodId: periodId,
          groupId: groupId,
          preview: preview,
        ),
      ),
    );
  }
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({
    required this.periodId,
    required this.groupId,
    required this.preview,
  });

  final String periodId;
  final String? groupId;
  final ContributionPeriodOpenPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lifecycleState = ref.watch(
      contributionPeriodLifecycleControllerProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.openPreviewEligibleCount(preview.eligibleCount),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.xs),
        Text(l10n.openPreviewExcludedCount(preview.excludedCount)),
        if (preview.missingCustomAmountCount > 0) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            l10n.openPreviewMissingAmountCount(
              preview.missingCustomAmountCount,
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.md),
        Text(
          '${l10n.openPreviewExpectedTotal}: '
          '${formatAmount(preview.expectedTotalAssessment)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        if (preview.missingCustomAmountCount > 0) ...[
          UmojaSection(
            title: l10n.sectionMissingAmountMembers,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.openPreviewMissingAmountWarning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: UmojaSpacing.sm),
                for (final member in preview.missingCustomAmountMembers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(member.displayName),
                  ),
              ],
            ),
          ),
          const SizedBox(height: UmojaSpacing.xxl),
        ],
        UmojaSection(
          title: l10n.sectionEligibleMembers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final member in preview.eligibleMembers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(member.displayName)),
                      if (member.amount != null)
                        Text(formatAmount(member.amount!)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaSection(
          title: l10n.sectionExcludedMembers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final member in preview.excludedMembers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(member.displayName)),
                      Text(
                        contributionExclusionReasonLabel(l10n, member.reason),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        if (lifecycleState.errorType != null) ...[
          Text(
            contributionFailureMessage(l10n, lifecycleState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: UmojaSpacing.md),
        ],
        UmojaPrimaryButton(
          label: l10n.openPreviewConfirmButton,
          expand: true,
          isLoading: lifecycleState.isSubmitting,
          // Blocked while any eligible member is missing a configured
          // amount — mirrors the backend's own `can_open` /
          // MISSING_CUSTOM_AMOUNTS guard, so the user sees this before
          // ever calling rpc_open_contribution_period.
          onPressed: (!preview.canOpen || groupId == null)
              ? null
              : () => _confirmAndOpen(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmAndOpen(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final groupId = this.groupId;
    if (groupId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.openPreviewConfirmTitle,
      message: l10n.openPreviewConfirmMessage,
      confirmLabel: l10n.openPreviewConfirmButton,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(contributionPeriodLifecycleControllerProvider.notifier)
        .open(groupId: groupId, periodId: periodId);
    if (success && context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.periodOpenedMessage)));
      context.go(AppRoutes.contributionPeriodDetailPath(periodId));
    }
  }
}
