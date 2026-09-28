import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/membership_claim_controller.dart';
import '../domain/membership_claim_queue_item.dart';
import '../providers/membership_claim_detail_provider.dart';
import 'widgets/membership_claim_labels.dart';

/// `/members/requests/:claimId`: the officer-facing claim review
/// screen (Prompt 09G-B1-D3). Only [claimId] travels through the
/// route — every other field is fetched fresh from the server via
/// [membershipClaimDetailProvider], never passed through route
/// arguments. Approve/Reject only ever call
/// `rpc_approve_membership_claim`/`rpc_reject_membership_claim`
/// (through [MembershipClaimController]) — this screen never sets
/// `group_memberships.user_id` or a claim's status itself.
class MembershipClaimReviewScreen extends ConsumerWidget {
  const MembershipClaimReviewScreen({super.key, required this.claimId});

  final String claimId;

  Future<void> _confirmApprove(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    MembershipClaimQueueItem item,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text(l10n.approveMembershipClaimConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.approveMembershipClaimTarget(
                item.claimantFullName ?? l10n.membershipRequestsUnknownClaimant,
                item.membershipDisplayName ?? '—',
              ),
            ),
            const SizedBox(height: UmojaSpacing.md),
            Text(l10n.approveMembershipClaimWarning),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('approveMembershipClaimDismissAction'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('approveMembershipClaimConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.approveMembershipClaimAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(membershipClaimControllerProvider.notifier)
        .approve(groupId: groupId, claimId: claimId);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.approveMembershipClaimSuccessMessage)),
      );
    } else {
      _showError(context, ref);
    }
  }

  Future<void> _confirmReject(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    final l10n = context.l10n;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rejectMembershipClaimConfirmTitle),
        content: TextField(
          key: const Key('rejectMembershipClaimReasonField'),
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.rejectMembershipClaimReasonFieldLabel,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('rejectMembershipClaimDismissAction'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('rejectMembershipClaimConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.rejectMembershipClaimAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final reason = reasonController.text.trim();
    final success = await ref
        .read(membershipClaimControllerProvider.notifier)
        .reject(groupId: groupId, claimId: claimId, rejectionReason: reason);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rejectMembershipClaimSuccessMessage)),
      );
    } else {
      _showError(context, ref);
    }
  }

  void _showError(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final errorType = ref.read(membershipClaimControllerProvider).errorType;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorType == null
              ? l10n.memberErrorUnexpected
              : membershipClaimFailureMessage(l10n, errorType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final groupId = membership?.group.groupId;
    final canReview =
        membership?.hasPermission('member.claim.approve') ?? false;

    if (groupId == null) {
      return UmojaPage(
        title: l10n.reviewMembershipRequestTitle,
        backTo: AppRoutes.membershipRequestsList,
        backLabel: l10n.membershipRequestsTitle,
        body: const SizedBox.shrink(),
      );
    }

    final query = (groupId: groupId, claimId: claimId);
    final itemAsync = ref.watch(membershipClaimDetailProvider(query));
    final controllerState = ref.watch(membershipClaimControllerProvider);

    return UmojaPage(
      title: l10n.reviewMembershipRequestTitle,
      maxWidth: 700,
      backTo: AppRoutes.membershipRequestsList,
      backLabel: l10n.membershipRequestsTitle,
      body: itemAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.membershipRequestInaccessibleMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(membershipClaimDetailProvider(query)),
        ),
        data: (item) {
          final canAct = canReview && item.isPending;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaSection(
                title: l10n.claimSectionTitle,
                child: UmojaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.statusLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: UmojaSpacing.sm),
                          UmojaStatusBadge(
                            label: membershipClaimStatusLabel(
                              l10n,
                              item.status,
                            ),
                            semantic: membershipClaimStatusSemantic(
                              item.status,
                            ),
                          ),
                        ],
                      ),
                      if (item.requestedAt != null) ...[
                        const SizedBox(height: UmojaSpacing.sm),
                        _ReviewRow(
                          label: l10n.submittedOnLabel,
                          value: formatKiswahiliDate(item.requestedAt!),
                        ),
                      ],
                      if (item.resolvedAt != null) ...[
                        const SizedBox(height: UmojaSpacing.sm),
                        _ReviewRow(
                          label: l10n.resolvedOnLabel,
                          value: formatKiswahiliDate(item.resolvedAt!),
                        ),
                      ],
                      if (item.rejectionReason != null) ...[
                        const SizedBox(height: UmojaSpacing.sm),
                        Text(
                          l10n.rejectionReasonLabel,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(item.rejectionReason!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaSection(
                title: l10n.memberRecordSectionTitle,
                child: UmojaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewRow(
                        label: l10n.memberLabel,
                        value: item.membershipDisplayName ?? '—',
                      ),
                      const SizedBox(height: UmojaSpacing.sm),
                      _ReviewRow(
                        label: l10n.memberNumberLabel,
                        value: item.membershipMemberNumber ?? '—',
                      ),
                      if (item.membershipPhone != null) ...[
                        const SizedBox(height: UmojaSpacing.sm),
                        _ReviewRow(
                          label: l10n.phoneLabel,
                          value: item.membershipPhone!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaSection(
                title: l10n.claimantAccountSectionTitle,
                child: UmojaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewRow(
                        label: l10n.claimantLabel,
                        value:
                            item.claimantFullName ??
                            l10n.membershipRequestsUnknownClaimant,
                      ),
                      if (item.claimantPhone != null) ...[
                        const SizedBox(height: UmojaSpacing.sm),
                        _ReviewRow(
                          label: l10n.phoneLabel,
                          value: item.claimantPhone!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (canAct) ...[
                const SizedBox(height: UmojaSpacing.xxl),
                UmojaSection(
                  title: l10n.actionsSectionTitle,
                  child: Row(
                    children: [
                      Expanded(
                        child: UmojaDangerButton(
                          key: const Key('rejectMembershipClaimAction'),
                          label: l10n.rejectMembershipClaimAction,
                          isLoading: controllerState.isRejecting,
                          onPressed: controllerState.isRejecting
                              ? null
                              : () => _confirmReject(context, ref, groupId),
                        ),
                      ),
                      const SizedBox(width: UmojaSpacing.md),
                      Expanded(
                        child: UmojaPrimaryButton(
                          key: const Key('approveMembershipClaimAction'),
                          label: l10n.approveMembershipClaimAction,
                          isLoading: controllerState.isApproving,
                          onPressed: controllerState.isApproving
                              ? null
                              : () => _confirmApprove(
                                  context,
                                  ref,
                                  groupId,
                                  item,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: UmojaSpacing.md),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}
