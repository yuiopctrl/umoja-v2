import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/tanzania_phone_number.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/domain/group_member.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../../payments/presentation/widgets/member_search_picker.dart';
import '../controllers/membership_invitation_controller.dart';
import '../domain/membership_phone_invitation.dart';

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

enum _InviteStep { selectMember, enterPhone, selectRoles, review }

/// `/members/invite`: Members → Invite Member → select an existing
/// eligible member → confirm/enter phone → select role(s) → review →
/// Send Invitation. Prompt 09G-B1-F2: PHONE invitations are now the
/// PRIMARY creation path — `rpc_create_membership_phone_invitation`,
/// never the legacy bearer-token RPC. Operates exclusively on an
/// EXISTING `group_memberships` row (never creates a duplicate member
/// record). The phone value is targeting input only — the BACKEND
/// remains authoritative for normalization; client-side validation
/// (`TanzaniaPhoneNumber.tryParse`) only catches an obviously malformed
/// number early, it never transforms what is actually sent.
class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  _InviteStep _step = _InviteStep.selectMember;
  GroupMember? _selectedMember;
  final _phoneController = TextEditingController();
  final Set<String> _selectedRoleCodes = {};
  MembershipPhoneInvitation? _created;
  bool _showPhoneError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _selectMember(GroupMember member) {
    setState(() {
      _selectedMember = member;
      _phoneController.text = member.phone ?? '';
      _step = _InviteStep.enterPhone;
    });
  }

  void _continueFromPhoneStep() {
    final parsed = TanzaniaPhoneNumber.tryParse(_phoneController.text);
    if (parsed == null) {
      setState(() => _showPhoneError = true);
      return;
    }
    setState(() {
      _showPhoneError = false;
      _step = _InviteStep.selectRoles;
    });
  }

  Future<void> _submit(String groupId) async {
    final member = _selectedMember;
    if (member == null || _selectedRoleCodes.isEmpty) return;

    final l10n = context.l10n;
    final invitation = await ref
        .read(membershipInvitationControllerProvider.notifier)
        .createPhoneInvitation(
          groupId: groupId,
          membershipId: member.membershipId,
          phone: _phoneController.text,
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
      return _InvitationSentScreen(
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
          onSelected: _selectMember,
        ),
        _InviteStep.enterPhone => ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.inviteMemberPhoneStepHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: UmojaSpacing.md),
              if ((_selectedMember?.phone ?? '').isNotEmpty) ...[
                Text(
                  l10n.inviteMemberPhonePrefilledHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: UmojaSpacing.sm),
              ],
              TextField(
                key: const Key('invitePhoneField'),
                controller: _phoneController,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.inviteMemberPhoneStepTitle,
                  hintText: l10n.authPhoneHint,
                  errorText: _showPhoneError
                      ? l10n.membershipInvitationInvalidPhoneError
                      : null,
                ),
                onChanged: (_) {
                  if (_showPhoneError) {
                    setState(() => _showPhoneError = false);
                  }
                },
                onSubmitted: (_) => _continueFromPhoneStep(),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              UmojaPrimaryButton(
                key: const Key('inviteMemberContinueFromPhoneAction'),
                label: l10n.continueToPhoneStepAction,
                onPressed: _continueFromPhoneStep,
              ),
            ],
          ),
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
                      Text(l10n.targetPhoneLabel, style: _labelStyle(context)),
                      Text(_phoneController.text),
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

/// Prompt 09G-B1-F2 §G: the redesigned success state — NO invitation
/// URL, NO raw token/secret, NO Copy Link/Share Link/Open Invitation
/// link action. "Invitation Sent" here means only that the invitation
/// record was created in Umoja — never implies an SMS was actually
/// delivered (no SMS provider exists yet).
class _InvitationSentScreen extends StatelessWidget {
  const _InvitationSentScreen({required this.invitation, required this.member});

  final MembershipPhoneInvitation invitation;
  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return UmojaPage(
      title: l10n.invitationCreatedTitle,
      backTo: AppRoutes.membersList,
      backLabel: l10n.membersTitle,
      body: ResponsiveCenter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.invitationSentForLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Text(member.displayName),
            const SizedBox(height: UmojaSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.targetPhoneLabel, style: _labelStyle(context)),
                    Text(invitation.targetPhoneE164),
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
                    Text(l10n.expiresOnLabel, style: _labelStyle(context)),
                    Text(invitation.expiresAt.toLocal().toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.invitationSentNextStepsMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: UmojaSpacing.xl),
            UmojaSecondaryButton(
              key: const Key('invitationSentViewInvitationsAction'),
              label: l10n.viewInvitationsAction,
              expand: true,
              onPressed: () => context.go(AppRoutes.membershipInvitationsList),
            ),
            const SizedBox(height: UmojaSpacing.sm),
            UmojaPrimaryButton(
              key: const Key('invitationSentDoneAction'),
              label: l10n.doneAction,
              expand: true,
              onPressed: () => context.go(AppRoutes.membersList),
            ),
          ],
        ),
      ),
    );
  }
}
