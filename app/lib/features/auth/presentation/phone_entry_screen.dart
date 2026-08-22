import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../controllers/phone_auth_controller.dart';
import 'widgets/auth_screen_layout.dart';

/// `/auth/phone`: the first authentication screen — enter a phone
/// number, request an OTP. No OTP/PIN/email/password alternative is
/// offered; phone OTP is the only authentication method (Prompt 03).
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(phoneAuthControllerProvider.notifier)
        .submitPhone(_phoneController.text);
    if (success && mounted) {
      context.go(AppRoutes.authVerify);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return AuthScreenLayout(
      children: [
        Text(l10n.authWelcomeTitle, style: textTheme.headlineMedium),
        const SizedBox(height: UmojaSpacing.sm),
        Text(l10n.authPhoneSubtitle, style: textTheme.bodyLarge),
        const SizedBox(height: UmojaSpacing.xxl),
        TextField(
          controller: _phoneController,
          autofocus: true,
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.authPhoneLabel,
            hintText: l10n.authPhoneHint,
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (state.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.md),
          Text(
            authFailureMessage(l10n, state.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
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
                : Text(l10n.continueButton),
          ),
        ),
      ],
    );
  }
}
