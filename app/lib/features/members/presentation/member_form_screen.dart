import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_form_section.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/member_form_controller.dart';
import '../providers/member_detail_provider.dart';

/// `/members/new` and `/members/:membershipId/edit`: one form screen
/// for both creating and editing a member — only identity/contact
/// fields are editable here; status and roles are managed from member
/// detail via their own dedicated actions/RPCs. The member number is
/// server-generated and never entered here (prompt 05B §36) — shown
/// read-only in edit mode, since once assigned it is a stable
/// identifier (§28).
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.membershipId});

  /// `null` for create mode; set for edit mode.
  final String? membershipId;

  bool get isEditing => membershipId != null;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _existingMemberNumber;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(memberFormControllerProvider.notifier);

    if (widget.isEditing) {
      final success = await controller.updateMember(
        groupId: groupId,
        membershipId: widget.membershipId!,
        displayName: _nameController.text,
        phone: _phoneController.text,
      );
      if (success && mounted) context.pop();
      return;
    }

    final member = await controller.createMember(
      groupId: groupId,
      displayName: _nameController.text,
      phone: _phoneController.text,
    );
    if (member != null && mounted) {
      context.go(AppRoutes.memberDetailPath(member.membershipId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(memberFormControllerProvider);
    final l10n = context.l10n;

    // Pre-fill fields once, from the existing member, in edit mode.
    if (widget.isEditing && !_prefilled) {
      final detailAsync = ref.watch(memberDetailProvider(widget.membershipId!));
      final member = detailAsync.value;
      if (member != null) {
        _nameController.text = member.displayName;
        _phoneController.text = member.phone ?? '';
        _existingMemberNumber = member.memberNumber;
        _prefilled = true;
      }
    }

    return UmojaPage(
      title: widget.isEditing ? l10n.editMemberTitle : l10n.addMemberAction,
      maxWidth: 640,
      backTo: widget.isEditing
          ? AppRoutes.memberDetailPath(widget.membershipId!)
          : AppRoutes.membersList,
      backLabel: widget.isEditing ? l10n.memberDetailTitle : l10n.membersTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.sectionIdentity,
            fields: [
              TextField(
                controller: _nameController,
                enabled: !formState.isSubmitting,
                autofocus: !widget.isEditing,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.formFullNameLabel),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  enabled: false,
                  controller: TextEditingController(
                    text: _existingMemberNumber ?? '—',
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.memberNumberLabel,
                  ),
                ),
              ],
            ],
          ),
          UmojaFormSection(
            title: l10n.formSectionContact,
            fields: [
              TextField(
                controller: _phoneController,
                enabled: !formState.isSubmitting,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.phoneOptionalLabel,
                  hintText: l10n.authPhoneHint,
                ),
                onSubmitted: groupId == null ? null : (_) => _submit(groupId),
              ),
            ],
          ),
          if (!widget.isEditing) ...[
            const SizedBox(height: UmojaSpacing.xs),
            Text(
              l10n.memberNumberAutoNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (formState.errorType != null) ...[
            Text(
              memberFailureMessage(l10n, formState.errorType!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          UmojaPrimaryButton(
            label: l10n.saveButton,
            expand: true,
            isLoading: formState.isSubmitting,
            onPressed: groupId == null ? null : () => _submit(groupId),
          ),
        ],
      ),
    );
  }
}
