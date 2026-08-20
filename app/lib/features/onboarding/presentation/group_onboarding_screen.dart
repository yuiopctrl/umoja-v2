import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your group',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'You currently have no active group. Create one to continue.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !state.isSubmitting,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                enabled: !state.isSubmitting,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
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
                      : const Text('Create Group'),
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
