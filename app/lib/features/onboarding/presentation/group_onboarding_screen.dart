import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../controllers/group_onboarding_controller.dart';

/// `/onboarding/group`: first-group creation for a signed-in,
/// profile-complete user with no eligible active group. Always goes
/// through `rpc_create_group()` — see [GroupOnboardingController].
class GroupOnboardingScreen extends ConsumerStatefulWidget {
  const GroupOnboardingScreen({super.key});

  @override
  ConsumerState<GroupOnboardingScreen> createState() =>
      _GroupOnboardingScreenState();
}

class _GroupOnboardingScreenState extends ConsumerState<GroupOnboardingScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // On success the router redirects to /home automatically once the
    // refreshed context resolves the new group as selected. On
    // failure, entered values remain in the (still-owned-by-this-widget)
    // text controllers, and the error shows below.
    await ref
        .read(groupOnboardingControllerProvider.notifier)
        .createGroup(
          name: _nameController.text,
          description: _descriptionController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupOnboardingControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.groupOnboardingTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.groupOnboardingSubtitle),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !state.isSubmitting,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.groupNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                enabled: !state.isSubmitting,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.groupDescriptionLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error == GroupOnboardingError.nameRequired
                      ? l10n.groupNameRequiredError
                      : l10n.groupSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.createGroupButton),
                ),
              ),
              const SizedBox(height: 16),
              const SignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}
