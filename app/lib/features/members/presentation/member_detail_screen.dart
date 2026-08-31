import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/title_case.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_initials_avatar.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/member_role_controller.dart';
import '../controllers/member_status_controller.dart';
import '../domain/group_member.dart';
import '../providers/member_detail_provider.dart';
import 'widgets/member_role_label.dart';
import 'widgets/member_status_badge.dart';

const _assignableRoles = [
  'MEMBER',
  'TREASURER',
  'SECRETARY',
  'CHAIRPERSON',
  'ADMIN',
];

/// `/members/:membershipId`: member detail — identity, membership
/// status, roles, and contextual actions. A Charges/Madeni entry point
/// (Prompt 07 UAT-FIX-03) links out to the dedicated member-centric
/// charges view rather than embedding the full charge list here.
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.membershipId});

  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(membershipId));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canEdit = membership?.hasPermission('member.edit') ?? false;
    final canChangeStatus =
        membership?.hasPermission('member.change_status') ?? false;
    final canAssignRoles = membership?.hasPermission('role.assign') ?? false;
    final canViewCharges =
        (membership?.hasPermission('contribution.view') ?? false) &&
        (membership?.hasPermission('payment.view') ?? false);

    return UmojaPage(
      title: l10n.memberDetailTitle,
      maxWidth: 900,
      backTo: AppRoutes.membersList,
      backLabel: l10n.membersTitle,
      body: memberAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(memberDetailProvider(membershipId)),
        ),
        data: (member) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MemberHeader(member: member),
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
                    title: l10n.sectionIdentity,
                    child: _IdentitySection(member: member),
                  ),
                  const _SectionDivider(),
                  UmojaSection(
                    title: l10n.sectionMembership,
                    child: _MembershipSection(member: member),
                  ),
                  if (member.canViewRoles) ...[
                    const _SectionDivider(),
                    UmojaSection(
                      title: l10n.sectionRoles,
                      trailing: canAssignRoles
                          ? TextButton(
                              onPressed: () =>
                                  _openManageRolesSheet(context, ref, member),
                              child: Text(l10n.manageRolesAction),
                            )
                          : null,
                      child: _RolesSummary(member: member),
                    ),
                  ],
                  if (canViewCharges) ...[
                    const _SectionDivider(),
                    UmojaSection(
                      title: l10n.sectionCharges,
                      trailing: TextButton(
                        onPressed: () => context.push(
                          AppRoutes.memberChargesPath(member.membershipId),
                        ),
                        child: Text(l10n.viewChargesAction),
                      ),
                      child: const SizedBox.shrink(),
                    ),
                  ],
                  const _SectionDivider(),
                  UmojaSection(
                    title: l10n.sectionActions,
                    child: _ActionsSection(
                      member: member,
                      canEdit: canEdit,
                      canChangeStatus: canChangeStatus,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManageRolesSheet(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final groupId = member.groupId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ManageRolesSheet(
        membershipId: member.membershipId,
        groupId: groupId,
      ),
    );
  }
}

/// Consistent hairline rhythm between sections within the detail card —
/// deliberately not a separate `Card` per section (prompt 05A §17: "do
/// not make every data row a separate Card").
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

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final name = toTitleCase(member.displayName);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UmojaInitialsAvatar(name: name, size: 56),
        const SizedBox(width: UmojaSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  MemberStatusBadge(status: member.status),
                  if (member.phone != null) ...[
                    const SizedBox(width: UmojaSpacing.sm),
                    Flexible(
                      child: Text(
                        member.phone!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: l10n.memberNumberLabel,
          value: member.memberNumber ?? '—',
        ),
        _InfoRow(label: l10n.phoneLabel, value: member.phone ?? '—'),
        const SizedBox(height: UmojaSpacing.sm),
        Row(
          children: [
            Icon(
              member.isLoginLinked ? Icons.link : Icons.link_off,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                member.isLoginLinked
                    ? l10n.accountLinkedLabel
                    : l10n.accountNotLinkedLabel,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MembershipSection extends StatelessWidget {
  const _MembershipSection({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: l10n.joinedLabel,
          value: member.joinedAt == null
              ? '—'
              : formatKiswahiliDate(member.joinedAt!),
        ),
        if (member.isExited && member.exitedAt != null)
          _InfoRow(
            label: l10n.exitedLabel,
            value: formatKiswahiliDate(member.exitedAt!),
          ),
      ],
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
          SizedBox(width: 168, child: Text(label, style: textTheme.bodyMedium)),
          Expanded(child: Text(value, style: textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _RolesSummary extends StatelessWidget {
  const _RolesSummary({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roles = member.roleCodes ?? const <String>[];
    if (roles.isEmpty) {
      return Text(
        l10n.noRolesAssigned,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Wrap(
      spacing: UmojaSpacing.sm,
      runSpacing: UmojaSpacing.sm,
      children: [
        for (final role in roles)
          Chip(label: Text(memberRoleLabel(l10n, role))),
      ],
    );
  }
}

class _ManageRolesSheet extends ConsumerWidget {
  const _ManageRolesSheet({required this.membershipId, required this.groupId});

  final String membershipId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(membershipId));
    final roleState = ref.watch(memberRoleControllerProvider);
    final roles = memberAsync.value?.roleCodes ?? const <String>[];
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UmojaSpacing.xxl,
          UmojaSpacing.sm,
          UmojaSpacing.xxl,
          UmojaSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sectionRoles,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.rolesSheetSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            for (final role in _assignableRoles)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(memberRoleLabel(l10n, role)),
                value: roles.contains(role),
                onChanged: roleState.isSubmitting
                    ? null
                    : (checked) {
                        final controller = ref.read(
                          memberRoleControllerProvider.notifier,
                        );
                        if (checked == true) {
                          controller.assignRole(
                            groupId: groupId,
                            membershipId: membershipId,
                            roleCode: role,
                          );
                        } else {
                          controller.removeRole(
                            groupId: groupId,
                            membershipId: membershipId,
                            roleCode: role,
                          );
                        }
                      },
              ),
            if (roleState.errorType != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                memberFailureMessage(l10n, roleState.errorType!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: UmojaSpacing.md),
            UmojaSecondaryButton(
              label: l10n.closeButton,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({
    required this.member,
    required this.canEdit,
    required this.canChangeStatus,
  });

  final GroupMember member;
  final bool canEdit;
  final bool canChangeStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusState = ref.watch(memberStatusControllerProvider);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: UmojaSpacing.md,
          runSpacing: UmojaSpacing.md,
          children: [
            if (canEdit)
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.memberEditPath(member.membershipId)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.editAction),
              ),
            if (canChangeStatus && member.isActive) ...[
              OutlinedButton(
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        newStatus: 'SUSPENDED',
                        title: l10n.suspendConfirmTitle,
                        message: l10n.suspendConfirmMessage,
                        confirmLabel: l10n.suspendButton,
                        successMessage: l10n.statusChangeSuccessSuspended,
                      ),
                child: Text(l10n.suspendButton),
              ),
              UmojaDangerButton(
                label: l10n.markExitedButton,
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        newStatus: 'EXITED',
                        title: l10n.exitConfirmTitle,
                        message: l10n.exitConfirmMessage,
                        confirmLabel: l10n.markExitedButton,
                        successMessage: l10n.statusChangeSuccessExited,
                        danger: true,
                      ),
              ),
            ],
            if (canChangeStatus && member.isSuspended) ...[
              UmojaPrimaryButton(
                label: l10n.reactivateButton,
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        newStatus: 'ACTIVE',
                        title: l10n.reactivateConfirmTitle,
                        message: l10n.reactivateConfirmMessage,
                        confirmLabel: l10n.reactivateButton,
                        successMessage: l10n.statusChangeSuccessActive,
                      ),
              ),
              UmojaDangerButton(
                label: l10n.markExitedButton,
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        newStatus: 'EXITED',
                        title: l10n.exitConfirmTitle,
                        message: l10n.exitConfirmMessage,
                        confirmLabel: l10n.markExitedButton,
                        successMessage: l10n.statusChangeSuccessExited,
                        danger: true,
                      ),
              ),
            ],
            if (canChangeStatus && member.isExited)
              UmojaPrimaryButton(
                label: l10n.rejoinButton,
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmRejoin(context, ref),
              ),
          ],
        ),
        if (statusState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.md),
          Text(
            memberFailureMessage(l10n, statusState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref, {
    required String newStatus,
    required String title,
    required String message,
    required String confirmLabel,
    required String successMessage,
    bool danger = false,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: l10n.cancelButton,
      danger: danger,
    );
    if (!confirmed) return;

    final success = await ref
        .read(memberStatusControllerProvider.notifier)
        .changeStatus(
          groupId: member.groupId,
          membershipId: member.membershipId,
          status: newStatus,
        );
    if (success) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }

  Future<void> _confirmRejoin(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.rejoinConfirmTitle,
      message: l10n.rejoinConfirmMessage,
      confirmLabel: l10n.rejoinButton,
      cancelLabel: l10n.cancelButton,
    );
    if (!confirmed) return;

    final success = await ref
        .read(memberStatusControllerProvider.notifier)
        .rejoin(groupId: member.groupId, membershipId: member.membershipId);
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rejoinSuccessMessage)),
      );
    }
  }
}
