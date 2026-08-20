import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/member_form_controller.dart';
import '../providers/member_detail_provider.dart';

/// `/members/new` and `/members/:membershipId/edit`: one form screen
/// for both creating and editing a member — only identity/contact
/// fields are editable here; status and roles are managed from member
/// detail via their own dedicated actions/RPCs.
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
  final _memberNumberController = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _memberNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(memberFormControllerProvider.notifier);

    final member = widget.isEditing
        ? await controller.updateMember(
            groupId: groupId,
            membershipId: widget.membershipId!,
            displayName: _nameController.text,
            phone: _phoneController.text,
            memberNumber: _memberNumberController.text,
          )
        : await controller.createMember(
            groupId: groupId,
            displayName: _nameController.text,
            phone: _phoneController.text,
            memberNumber: _memberNumberController.text,
          );

    if (member != null && mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.go(AppRoutes.memberDetailPath(member.membershipId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(memberFormControllerProvider);

    // Pre-fill fields once, from the existing member, in edit mode.
    if (widget.isEditing && !_prefilled) {
      final detailAsync = ref.watch(memberDetailProvider(widget.membershipId!));
      final member = detailAsync.value;
      if (member != null) {
        _nameController.text = member.displayName;
        _phoneController.text = member.phone ?? '';
        _memberNumberController.text = member.memberNumber ?? '';
        _prefilled = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Member' : 'Add Member'),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                enabled: !formState.isSubmitting,
                autofocus: !widget.isEditing,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                enabled: !formState.isSubmitting,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: '0712345678',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _memberNumberController,
                enabled: !formState.isSubmitting,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Member number (optional)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: groupId == null ? null : (_) => _submit(groupId),
              ),
              if (formState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  formState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (formState.isSubmitting || groupId == null)
                      ? null
                      : () => _submit(groupId),
                  child: formState.isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save / Hifadhi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
