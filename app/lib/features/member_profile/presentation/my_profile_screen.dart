import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_initials_avatar.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../members/presentation/widgets/member_role_label.dart';
import '../../members/presentation/widgets/member_status_badge.dart';
import '../domain/my_member_profile.dart';
import '../providers/edit_member_profile_controller.dart';
import '../providers/my_member_profile_provider.dart';

/// `/me/profile`: the caller's OWN account + membership details for
/// the currently selected group (Prompt 09G-B2). Reads the selected
/// group from [selectedGroupProvider] (via [myMemberProfileProvider]),
/// never from a route parameter — switching group elsewhere in the app
/// naturally refetches the correct profile here. No financial data:
/// that is deferred to later B3-B6 authoritative read models.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profileAsync = ref.watch(myMemberProfileProvider);

    return UmojaPage(
      title: l10n.myProfileTitle,
      // UmojaLoadingState/UmojaErrorState both need a bounded height
      // (ListView/Center respectively) — the default scrollable body
      // gives unbounded height, matching every other screen that mixes
      // an async `.when()` with these widgets (see
      // members_list_screen.dart). The loaded data case scrolls itself.
      scrollable: false,
      body: profileAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.myProfileLoadFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(myMemberProfileProvider),
        ),
        data: (profile) =>
            SingleChildScrollView(child: _MyProfileContent(profile: profile)),
      ),
    );
  }
}

class _MyProfileContent extends ConsumerWidget {
  const _MyProfileContent({required this.profile});

  final MyMemberProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          key: const Key('myProfileHeaderCard'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  profile.accountAvatarUrl != null
                      ? CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(
                            profile.accountAvatarUrl!,
                          ),
                        )
                      : UmojaInitialsAvatar(
                          name: profile.displayFullName,
                          size: 56,
                        ),
                  const SizedBox(width: UmojaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayFullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (profile.accountPhone != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.accountPhone!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UmojaSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('myProfileEditAction'),
                  onPressed: () => _showEditProfileSheet(context, profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.myProfileEditAction),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaSection(
          title: l10n.myProfileMembershipSectionTitle,
          child: UmojaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.groupName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    MemberStatusBadge(status: profile.membershipStatus),
                  ],
                ),
                const SizedBox(height: UmojaSpacing.sm),
                if (profile.groupCode != null)
                  _ProfileFactRow(
                    label: l10n.myProfileGroupCodeLabel,
                    value: profile.groupCode!,
                  ),
                if (profile.memberNumber != null)
                  _ProfileFactRow(
                    label: l10n.myProfileMemberNumberLabel,
                    value: profile.memberNumber!,
                  ),
                if (profile.joinedAt != null)
                  _ProfileFactRow(
                    label: l10n.myProfileJoinedLabel,
                    value: profile.joinedAt!,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaSection(
          title: l10n.myProfileRoleSectionTitle,
          child: UmojaCard(
            child: Wrap(
              spacing: UmojaSpacing.sm,
              runSpacing: UmojaSpacing.sm,
              children: profile.roleCodes.isEmpty
                  ? [Text(l10n.rolesNone)]
                  : [
                      for (final code in profile.roleCodes)
                        Chip(label: Text(memberRoleLabel(l10n, code))),
                    ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditProfileSheet(BuildContext context, MyMemberProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditProfileSheet(profile: profile),
    );
  }
}

class _ProfileFactRow extends StatelessWidget {
  const _ProfileFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final MyMemberProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profile.accountFullName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final controller = ref.read(editMemberProfileControllerProvider.notifier);
    final success = await controller.saveFullName(_nameController.text);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.myProfileSaveSuccess)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(editMemberProfileControllerProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: UmojaSpacing.lg,
          right: UmojaSpacing.lg,
          top: UmojaSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + UmojaSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.myProfileEditAction,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: UmojaSpacing.md),
            TextField(
              key: const Key('myProfileFullNameField'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.myProfileFullNameLabel,
                errorText: state.error == EditMemberProfileError.nameRequired
                    ? l10n.fullNameRequiredError
                    : state.error == EditMemberProfileError.saveFailed
                    ? l10n.profileSaveError
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !state.isSubmitting,
            ),
            const SizedBox(height: UmojaSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('myProfileSaveAction'),
                onPressed: state.isSubmitting ? null : _save,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.myProfileSaveAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
