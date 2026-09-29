import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../controllers/personal_membership_invitation_controller.dart';
import '../domain/my_membership_invitation.dart';
import '../providers/my_membership_invitations_provider.dart';
import 'widgets/membership_invitation_labels.dart';

/// `/invitations` (Prompt 09G-B1-F2 §J): the authenticated caller's OWN
/// GLOBAL invitation inbox — `rpc_list_my_membership_invitations`
/// only, never `p_phone`/group_id/membership_id/user_id. Distinct from
/// the officer-facing, group-scoped `/members/invitations`
/// (`MembershipInvitationsListScreen`, invitations the SIGNED-IN
/// OFFICER created for their selected group) — this screen shows
/// invitations addressed TO the signed-in person, regardless of which
/// group (if any) is currently selected.
class PersonalInvitationsScreen extends ConsumerWidget {
  const PersonalInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pageAsync = ref.watch(myMembershipInvitationsProvider);

    return UmojaPage(
      title: l10n.myInvitationsTitle,
      scrollable: false,
      body: pageAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myMembershipInvitationsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return ResponsiveCenter(
              child: UmojaEmptyState(
                icon: Icons.mail_outline,
                title: l10n.myInvitationsEmptyTitle,
                message: l10n.myInvitationsEmptyMessage,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myMembershipInvitationsProvider);
              await ref.read(myMembershipInvitationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              itemCount: page.items.length,
              separatorBuilder: (context, _) =>
                  const SizedBox(height: UmojaSpacing.md),
              itemBuilder: (context, index) =>
                  _MyInvitationCard(item: page.items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _MyInvitationCard extends ConsumerWidget {
  const _MyInvitationCard({required this.item});

  final MyMembershipInvitation item;

  Future<void> _confirmAccept(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.acceptInvitationConfirmTitle),
        content: Text(
          l10n.acceptInvitationConfirmMessage(item.groupName ?? ''),
        ),
        actions: [
          TextButton(
            key: const Key('myInvitationAcceptDismissAction'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('myInvitationAcceptConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.acceptInvitationAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(personalMembershipInvitationControllerProvider.notifier)
        .accept(invitationId: item.invitationId);
    if (!context.mounted) return;
    if (!success) {
      final errorType = ref
          .read(personalMembershipInvitationControllerProvider)
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

  Future<void> _confirmDecline(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.declineInvitationConfirmTitle),
        content: Text(l10n.declineInvitationConfirmMessage),
        actions: [
          TextButton(
            key: const Key('myInvitationDeclineDismissAction'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('myInvitationDeclineConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.declineInvitationAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(personalMembershipInvitationControllerProvider.notifier)
        .decline(invitationId: item.invitationId);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invitationDeclinedMessage)));
    } else {
      final errorType = ref
          .read(personalMembershipInvitationControllerProvider)
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
    final controllerState = ref.watch(
      personalMembershipInvitationControllerProvider,
    );

    return Card(
      key: Key('myInvitationCard_${item.invitationId}'),
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
                    item.groupName ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                UmojaStatusBadge(
                  label: membershipInvitationStatusLabel(l10n, item.status),
                  semantic: membershipInvitationStatusSemantic(item.status),
                ),
              ],
            ),
            if (item.membershipDisplayName != null)
              Text(
                item.membershipDisplayName!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (item.membershipMemberNumber != null)
              Text(
                item.membershipMemberNumber!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              '${l10n.roleLabel}: '
              '${item.roleNames.isEmpty ? '—' : item.roleNames.map((name) => name).join(', ')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              '${l10n.invitedOnLabel}: ${item.invitedAt.toLocal().toString().split(' ').first}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.canAccept) ...[
              const SizedBox(height: UmojaSpacing.md),
              UmojaPrimaryButton(
                key: Key('myInvitationAcceptAction_${item.invitationId}'),
                expand: true,
                label: l10n.acceptInvitationAction,
                isLoading: controllerState.isAccepting,
                onPressed: controllerState.isAccepting
                    ? null
                    : () => _confirmAccept(context, ref),
              ),
              const SizedBox(height: UmojaSpacing.sm),
              UmojaSecondaryButton(
                key: Key('myInvitationDeclineAction_${item.invitationId}'),
                expand: true,
                label: l10n.declineInvitationAction,
                isLoading: controllerState.isDeclining,
                onPressed: controllerState.isDeclining
                    ? null
                    : () => _confirmDecline(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
