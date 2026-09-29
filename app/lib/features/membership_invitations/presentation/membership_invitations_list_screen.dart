import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../controllers/membership_invitation_controller.dart';
import '../domain/membership_invitation_queue_item.dart';
import '../domain/membership_invitation_status.dart';
import '../providers/membership_invitations_queue_provider.dart';
import 'widgets/membership_invitation_labels.dart';

/// `/members/invitations`: officer-facing invitation queue/history
/// (Prompt 09G-B1-E2), reached from Members for anyone holding
/// `member.invite`. Always re-read from
/// `rpc_list_membership_invitations` — never fabricates an EXPIRED
/// status the backend didn't already compute, and never deletes
/// history.
class MembershipInvitationsListScreen extends ConsumerStatefulWidget {
  const MembershipInvitationsListScreen({super.key});

  @override
  ConsumerState<MembershipInvitationsListScreen> createState() =>
      _MembershipInvitationsListScreenState();
}

class _MembershipInvitationsListScreenState
    extends ConsumerState<MembershipInvitationsListScreen> {
  MembershipInvitationStatus? _statusFilter =
      MembershipInvitationStatus.pending;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    if (groupId == null) return const SizedBox.shrink();

    final query = (
      groupId: groupId,
      status: _statusFilter,
      limit: 20,
      offset: 0,
    );
    final pageAsync = ref.watch(membershipInvitationsQueueProvider(query));

    final filters = <(String label, MembershipInvitationStatus?)>[
      (l10n.filterAll, null),
      (
        l10n.membershipInvitationStatusPending,
        MembershipInvitationStatus.pending,
      ),
      (
        l10n.membershipInvitationStatusAccepted,
        MembershipInvitationStatus.accepted,
      ),
      (
        l10n.membershipInvitationStatusCancelled,
        MembershipInvitationStatus.cancelled,
      ),
      (
        l10n.membershipInvitationStatusExpired,
        MembershipInvitationStatus.expired,
      ),
    ];

    return UmojaPage(
      title: l10n.membershipInvitationsTitle,
      backTo: AppRoutes.membersList,
      backLabel: l10n.membersTitle,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in filters)
                ChoiceChip(
                  label: Text(filter.$1),
                  selected: _statusFilter == filter.$2,
                  onSelected: (_) => setState(() => _statusFilter = filter.$2),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.md),
          Expanded(
            child: pageAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () =>
                    ref.invalidate(membershipInvitationsQueueProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return ResponsiveCenter(
                    child: UmojaEmptyState(
                      icon: Icons.mail_outline,
                      title: l10n.membershipInvitationsEmptyTitle,
                      message: l10n.membershipInvitationsEmptyMessage,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(membershipInvitationsQueueProvider(query));
                    await ref.read(
                      membershipInvitationsQueueProvider(query).future,
                    );
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(UmojaSpacing.lg),
                    itemCount: page.items.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: UmojaSpacing.md),
                    itemBuilder: (context, index) =>
                        _InvitationCard(item: page.items[index], query: query),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends ConsumerWidget {
  const _InvitationCard({required this.item, required this.query});

  final MembershipInvitationQueueItem item;
  final MembershipInvitationsQueueQuery query;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cancelInvitationConfirmTitle),
        content: Text(l10n.cancelInvitationConfirmMessage),
        actions: [
          TextButton(
            key: const Key('cancelInvitationDismissAction'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('cancelInvitationConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cancelInvitationAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(membershipInvitationControllerProvider.notifier)
        .cancel(groupId: query.groupId, invitationId: item.invitationId);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(membershipInvitationsQueueProvider(query));
    } else {
      final errorType = ref
          .read(membershipInvitationControllerProvider)
          .errorType;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorType == null
                ? l10n.memberErrorUnexpected
                : membershipInvitationFailureMessage(l10n, errorType),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controllerState = ref.watch(membershipInvitationControllerProvider);
    final effectiveStatus = item.effectiveStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UmojaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.membershipDisplayName ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                UmojaStatusBadge(
                  label: membershipInvitationStatusLabel(l10n, effectiveStatus),
                  semantic: membershipInvitationStatusSemantic(effectiveStatus),
                ),
              ],
            ),
            if (item.membershipMemberNumber != null)
              Text(
                item.membershipMemberNumber!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              item.roleCodes
                  .map((code) => memberRoleLabel(l10n, code))
                  .join(', '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              '${l10n.createdOnLabel}: ${formatKiswahiliDate(item.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.acceptedAt != null)
              Text(
                '${l10n.membershipInvitationStatusAccepted}: '
                '${formatKiswahiliDate(item.acceptedAt!)}'
                '${item.acceptedByFullName != null ? ' · ${item.acceptedByFullName}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (item.cancelledAt != null)
              Text(
                '${l10n.membershipInvitationStatusCancelled}: '
                '${formatKiswahiliDate(item.cancelledAt!)}'
                '${item.cancelledByFullName != null ? ' · ${item.cancelledByFullName}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (item.canCancel) ...[
              const SizedBox(height: UmojaSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: UmojaSecondaryButton(
                  key: Key('cancelInvitationAction_${item.invitationId}'),
                  label: l10n.cancelInvitationAction,
                  isLoading: controllerState.isCancelling,
                  onPressed: controllerState.isCancelling
                      ? null
                      : () => _confirmCancel(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
