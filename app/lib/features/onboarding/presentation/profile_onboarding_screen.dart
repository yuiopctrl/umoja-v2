import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../controllers/profile_onboarding_controller.dart';

/// `/onboarding/profile`: first-time profile completion. Only
/// full_name is required — see docs/product/authentication.md. Phone
/// is shown read-only, derived from the authenticated identity, never
/// editable here (changing the authentication phone is a separate
/// future workflow).
class ProfileOnboardingScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  ConsumerState<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState
    extends ConsumerState<ProfileOnboardingScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // On success the router redirects onward automatically once the
    // refreshed context reports the profile as complete.
    await ref
        .read(profileOnboardingControllerProvider.notifier)
        .saveFullName(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileOnboardingControllerProvider);
    final authenticatedPhone = ref.watch(currentSupabaseUserProvider)?.phone;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete your profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !state.isSubmitting,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (authenticatedPhone != null) ...[
                const SizedBox(height: 16),
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: authenticatedPhone),
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
