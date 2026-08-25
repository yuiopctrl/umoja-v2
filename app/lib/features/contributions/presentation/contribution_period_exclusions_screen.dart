import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_period_exclusion_controller.dart';
import '../providers/contribution_period_open_preview_provider.dart';
import 'widgets/contribution_exclusion_reason_label.dart';

/// `/contributions/periods/:periodId/exclusions`: pre-open eligibility
/// management — DRAFT/SCHEDULED periods only. This is never described
/// as a "waiver": no charge exists yet for an excluded member, so
/// nothing is being forgiven, only kept from ever being posted in the
/// first place.
class ContributionPeriodExclusionsScreen extends ConsumerWidget {
  const ContributionPeriodExclusionsScreen({super.key, required this.periodId});

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
      title: l10n.exclusionsScreenTitle,
      maxWidth: 700,
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
        data: (preview) {
          final exclusionState = ref.watch(
            contributionPeriodExclusionControllerProvider,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exclusionState.errorType != null) ...[
                Text(
                  contributionFailureMessage(l10n, exclusionState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: UmojaSpacing.md),
              ],
              UmojaSection(
                title: l10n.sectionEligibleMembers,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final member in preview.eligibleMembers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        // Column (not Row) — "Ondoa kwenye Kipindi Hiki"
                        // is long enough in Kiswahili that a Row with a
                        // long member name overflows on narrow screens.
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(member.displayName),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed:
                                    exclusionState.isSubmitting ||
                                        groupId == null
                                    ? null
                                    : () => _excludeMember(
                                        context,
                                        ref,
                                        groupId,
                                        member.membershipId,
                                      ),
                                child: Text(l10n.excludeMemberAction),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (preview.eligibleMembers.isEmpty)
                      Text(
                        l10n.chargesEmptyMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        // Column (not Row) — same overflow reasoning as
                        // the eligible-members list above.
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(member.displayName),
                            Text(
                              contributionExclusionReasonLabel(
                                l10n,
                                member.reason,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            // Only an explicit exclusion has a row to
                            // remove — automatic ineligibility
                            // (SUSPENDED/EXITED/...) has none.
                            if (!member.isAutomaticIneligibility)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed:
                                      exclusionState.isSubmitting ||
                                          groupId == null
                                      ? null
                                      : () => _removeExclusion(
                                          context,
                                          ref,
                                          groupId,
                                          member.membershipId,
                                        ),
                                  child: Text(l10n.removeExclusionAction),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (preview.excludedMembers.isEmpty)
                      Text('—', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _excludeMember(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String membershipId,
  ) async {
    final l10n = context.l10n;
    final reason = await _promptReason(context);
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionPeriodExclusionControllerProvider.notifier)
        .exclude(
          groupId: groupId,
          periodId: periodId,
          membershipId: membershipId,
          reason: reason.isEmpty ? null : reason,
        );
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.memberExcludedMessage)),
      );
    }
  }

  Future<void> _removeExclusion(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String membershipId,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionPeriodExclusionControllerProvider.notifier)
        .removeExclusion(
          groupId: groupId,
          periodId: periodId,
          membershipId: membershipId,
        );
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.memberExclusionRemovedMessage)),
      );
    }
  }

  Future<String?> _promptReason(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: UmojaSpacing.xxl,
            right: UmojaSpacing.xxl,
            top: UmojaSpacing.sm,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom +
                UmojaSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.exclusionSheetTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: UmojaSpacing.md),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: l10n.exclusionReasonLabel,
                ),
                autofocus: true,
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(l10n.cancelButton),
                    ),
                  ),
                  const SizedBox(width: UmojaSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext)
                              .pop(controller.text.trim()),
                      child: Text(l10n.excludeMemberAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
