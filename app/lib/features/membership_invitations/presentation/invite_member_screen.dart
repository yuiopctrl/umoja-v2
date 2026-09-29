import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/domain/group_member.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../../payments/presentation/widgets/member_search_picker.dart';
import '../controllers/membership_invitation_controller.dart';
import '../domain/membership_invitation.dart';

/// The five role codes the backend actually accepts today
/// (`public.roles`, seeded by migration) — never invented client-side,
/// never sent as anything but the exact code string. Kept as a plain
/// ordered list rather than fetched from a dedicated RPC because none
/// exists (Prompt 09G-B1-E2 §D) and this exact fixed vocabulary is
/// already the established convention for role display elsewhere in
/// this codebase (`memberRoleLabel`).
const _availableRoleCodes = [
  'MEMBER',
  'TREASURER',
  'SECRETARY',
  'CHAIRPERSON',
  'ADMIN',
];

enum _InviteStep { selectMember, selectRoles, review }

/// `/members/invite`: Members → Invite Member → select an existing
/// eligible member → select role(s) → review → create. Operates
/// exclusively on an EXISTING `group_memberships` row (never creates a
/// duplicate member record) via `rpc_create_membership_invitation`.
class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  _InviteStep _step = _InviteStep.selectMember;
  GroupMember? _selectedMember;
  final Set<String> _selectedRoleCodes = {};
  MembershipInvitation? _created;

  Future<void> _submit(String groupId) async {
    final member = _selectedMember;
    if (member == null || _selectedRoleCodes.isEmpty) return;

    final l10n = context.l10n;
    final invitation = await ref
        .read(membershipInvitationControllerProvider.notifier)
        .create(
          groupId: groupId,
          membershipId: member.membershipId,
          roleCodes: _selectedRoleCodes.toList(growable: false),
        );
    if (!mounted) return;

    if (invitation == null) {
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
      return;
    }

    setState(() => _created = invitation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final isAdminInviter =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasRole('ADMIN');

    final created = _created;
    if (created != null && _selectedMember != null) {
      return _InvitationCreatedScreen(
        invitation: created,
        member: _selectedMember!,
      );
    }

    if (groupId == null) return const SizedBox.shrink();

    final controllerState = ref.watch(membershipInvitationControllerProvider);

    return UmojaPage(
      title: l10n.inviteMemberTitle,
      backTo: AppRoutes.membersList,
      backLabel: l10n.membersTitle,
      scrollable: _step != _InviteStep.selectMember,
      body: switch (_step) {
        _InviteStep.selectMember => MemberSearchPicker(
          hintText: l10n.membersSearchHint,
          filter: (member) => member.isActive && !member.isLoginLinked,
          emptyTitle: l10n.inviteMemberNoEligibleTitle,
          emptyMessage: l10n.inviteMemberNoEligibleMessage,
          onSelected: (member) => setState(() {
            _selectedMember = member;
            _step = _InviteStep.selectRoles;
          }),
        ),
        _InviteStep.selectRoles => ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.inviteMemberSelectRolesHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: UmojaSpacing.md),
              for (final code in _availableRoleCodes)
                CheckboxListTile(
                  key: Key('inviteRoleOption_$code'),
                  title: Text(memberRoleLabel(l10n, code)),
                  value: _selectedRoleCodes.contains(code),
                  enabled: code != 'ADMIN' || isAdminInviter,
                  subtitle: code == 'ADMIN' && !isAdminInviter
                      ? Text(l10n.inviteMemberAdminRoleRequiresAdminHint)
                      : null,
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selectedRoleCodes.add(code);
                    } else {
                      _selectedRoleCodes.remove(code);
                    }
                  }),
                ),
              const SizedBox(height: UmojaSpacing.lg),
              UmojaPrimaryButton(
                key: const Key('inviteMemberContinueToReviewAction'),
                label: l10n.continueToReviewAction,
                onPressed: _selectedRoleCodes.isEmpty
                    ? null
                    : () => setState(() => _step = _InviteStep.review),
              ),
            ],
          ),
        ),
        _InviteStep.review => ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(UmojaSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.memberLabel, style: _labelStyle(context)),
                      Text(_selectedMember?.displayName ?? ''),
                      const SizedBox(height: UmojaSpacing.md),
                      Text(l10n.memberNumberLabel, style: _labelStyle(context)),
                      Text(_selectedMember?.memberNumber ?? '—'),
                      const SizedBox(height: UmojaSpacing.md),
                      Text(
                        l10n.inviteMemberSelectedRolesLabel,
                        style: _labelStyle(context),
                      ),
                      Text(
                        _selectedRoleCodes
                            .map((code) => memberRoleLabel(l10n, code))
                            .join(', '),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UmojaSpacing.md),
              Text(
                l10n.inviteMemberReviewExplanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: UmojaSpacing.lg),
              UmojaPrimaryButton(
                key: const Key('createInvitationAction'),
                label: l10n.createInvitationAction,
                isLoading: controllerState.isSubmitting,
                onPressed: controllerState.isSubmitting
                    ? null
                    : () => _submit(groupId),
              ),
            ],
          ),
        ),
      },
    );
  }
}

TextStyle? _labelStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelMedium;

class _InvitationCreatedScreen extends StatelessWidget {
  const _InvitationCreatedScreen({
    required this.invitation,
    required this.member,
  });

  final MembershipInvitation invitation;
  final GroupMember member;

  String _invitationLink() {
    // Web: Uri.base gives the real deployed origin. Non-web platforms
    // fall back to a relative path — there is no canonical app domain
    // configured yet for a native deep link; E3 will define the actual
    // acceptance screen this path resolves to.
    final path = AppRoutes.membershipInvitationAcceptPath(invitation.token);
    try {
      return Uri.base.resolve(path).toString();
    } catch (_) {
      return path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final link = _invitationLink();

    return UmojaPage(
      title: l10n.invitationCreatedTitle,
      backTo: AppRoutes.membersList,
      backLabel: l10n.membersTitle,
      body: ResponsiveCenter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.memberLabel, style: _labelStyle(context)),
                    Text(member.displayName),
                    const SizedBox(height: UmojaSpacing.md),
                    Text(l10n.memberNumberLabel, style: _labelStyle(context)),
                    Text(member.memberNumber ?? '—'),
                    const SizedBox(height: UmojaSpacing.md),
                    Text(
                      l10n.inviteMemberSelectedRolesLabel,
                      style: _labelStyle(context),
                    ),
                    Text(
                      invitation.roleCodes
                          .map((code) => memberRoleLabel(l10n, code))
                          .join(', '),
                    ),
                    const SizedBox(height: UmojaSpacing.md),
                    Text(l10n.statusLabel, style: _labelStyle(context)),
                    Text(l10n.membershipInvitationStatusPending),
                    const SizedBox(height: UmojaSpacing.md),
                    Text(l10n.expiresOnLabel, style: _labelStyle(context)),
                    Text(invitation.expiresAt.toLocal().toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            // Stacked full-width (not side-by-side): these two labels
            // are too long to share a Row on narrower widths without
            // overflowing the button's inner content — see
            // `_ButtonContent` (core/widgets/umoja_buttons.dart), which
            // doesn't wrap/ellipsize its label.
            UmojaSecondaryButton(
              key: const Key('copyInvitationLinkAction'),
              label: l10n.copyInvitationLinkAction,
              icon: Icons.copy,
              expand: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.invitationLinkCopiedMessage)),
                );
              },
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaPrimaryButton(
              key: const Key('shareInvitationAction'),
              label: l10n.shareInvitationAction,
              icon: Icons.share,
              expand: true,
              onPressed: () async {
                await SharePlus.instance.share(ShareParams(text: link));
              },
            ),
            const SizedBox(height: UmojaSpacing.lg),
            UmojaSecondaryButton(
              key: const Key('invitationCreatedDoneAction'),
              label: l10n.doneAction,
              onPressed: () => context.go(AppRoutes.membersList),
            ),
          ],
        ),
      ),
    );
  }
}
