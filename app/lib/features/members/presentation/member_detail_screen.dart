import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/member_role_controller.dart';
import '../controllers/member_status_controller.dart';
import '../domain/group_member.dart';
import '../providers/member_detail_provider.dart';
import 'widgets/member_status_badge.dart';

const _assignableRoles = [
  'MEMBER',
  'TREASURER',
  'SECRETARY',
  'CHAIRPERSON',
  'ADMIN',
];

/// `/members/:membershipId`: member detail — identity, membership
/// status, roles, and contextual actions. No financial placeholder
/// sections — those modules do not exist yet.
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.membershipId});

  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(membershipId));
    final selectedGroup = ref.watch(selectedGroupProvider);

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canEdit = membership?.hasPermission('member.edit') ?? false;
    final canChangeStatus =
        membership?.hasPermission('member.change_status') ?? false;
    final canAssignRoles = membership?.hasPermission('role.assign') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: SafeArea(
        child: memberAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ResponsiveCenter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this member.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(memberDetailProvider(membershipId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (member) => SingleChildScrollView(
            child: ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IdentitySection(member: member),
                  const SizedBox(height: 24),
                  _MembershipSection(member: member),
                  const SizedBox(height: 24),
                  _RolesSection(
                    member: member,
                    canAssignRoles: canAssignRoles,
                    groupId: member.groupId,
                  ),
                  const SizedBox(height: 24),
                  _ActionsSection(
                    member: member,
                    canEdit: canEdit,
                    canChangeStatus: canChangeStatus,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Identity'),
        const SizedBox(height: 8),
        Text(
          member.displayName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (member.memberNumber != null)
          Text('Member No: ${member.memberNumber}'),
        if (member.phone != null) Text(member.phone!),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              member.isLoginLinked ? Icons.link : Icons.link_off,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              member.isLoginLinked
                  ? 'Account access: Linked'
                  : 'Account access: Not linked',
              style: Theme.of(context).textTheme.bodySmall,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Membership'),
        const SizedBox(height: 8),
        Row(
          children: [
            MemberStatusBadge(status: member.status),
            if (member.joinedAt != null) ...[
              const SizedBox(width: 12),
              Text('Joined: ${_formatDate(member.joinedAt!)}'),
            ],
          ],
        ),
        if (member.isExited && member.exitedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Exited: ${_formatDate(member.exitedAt!)}'),
          ),
      ],
    );
  }
}

class _RolesSection extends ConsumerWidget {
  const _RolesSection({
    required this.member,
    required this.canAssignRoles,
    required this.groupId,
  });

  final GroupMember member;
  final bool canAssignRoles;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!member.canViewRoles) {
      // No role.view — this section is not shown at all.
      return const SizedBox.shrink();
    }

    final roleState = ref.watch(memberRoleControllerProvider);
    final roles = member.roleCodes!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Roles'),
        const SizedBox(height: 8),
        if (roles.isEmpty)
          const Text('No roles assigned.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in roles)
                Chip(
                  label: Text(role),
                  onDeleted: canAssignRoles && !roleState.isSubmitting
                      ? () => _confirmRemoveRole(context, ref, role)
                      : null,
                ),
            ],
          ),
        if (canAssignRoles) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final role in _assignableRoles)
                if (!roles.contains(role))
                  OutlinedButton(
                    onPressed: roleState.isSubmitting
                        ? null
                        : () => ref
                              .read(memberRoleControllerProvider.notifier)
                              .assignRole(
                                groupId: groupId,
                                membershipId: member.membershipId,
                                roleCode: role,
                              ),
                    child: Text('+ $role'),
                  ),
            ],
          ),
        ],
        if (roleState.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            roleState.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRemoveRole(
    BuildContext context,
    WidgetRef ref,
    String role,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove role'),
        content: Text('Remove the $role role from ${member.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(memberRoleControllerProvider.notifier)
          .removeRole(
            groupId: groupId,
            membershipId: member.membershipId,
            roleCode: role,
          );
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (canEdit)
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.memberEditPath(member.membershipId)),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            if (canChangeStatus && member.isActive) ...[
              OutlinedButton(
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        'SUSPENDED',
                        'Suspend this member?',
                      ),
                child: const Text('Suspend'),
              ),
              OutlinedButton(
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        'EXITED',
                        'Mark this member as exited? This cannot be undone from here.',
                      ),
                child: const Text('Mark as Exited'),
              ),
            ],
            if (canChangeStatus && member.isSuspended) ...[
              FilledButton(
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        'ACTIVE',
                        'Reactivate this member?',
                      ),
                child: const Text('Reactivate'),
              ),
              OutlinedButton(
                onPressed: statusState.isSubmitting
                    ? null
                    : () => _confirmStatusChange(
                        context,
                        ref,
                        'EXITED',
                        'Mark this member as exited? This cannot be undone from here.',
                      ),
                child: const Text('Mark as Exited'),
              ),
            ],
            // EXITED: no normal reactivation action, per the terminal
            // generic-status-RPC rule — see docs/product/members.md.
          ],
        ),
        if (statusState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            statusState.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref,
    String newStatus,
    String message,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm action'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(memberStatusControllerProvider.notifier)
          .changeStatus(
            groupId: member.groupId,
            membershipId: member.membershipId,
            status: newStatus,
          );
    }
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
