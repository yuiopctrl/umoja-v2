import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/auto_submit_on_length.dart';
import '../../../core/widgets/umoja_code_input.dart';
import '../../security/controllers/pin_recovery_controller.dart';
import '../controllers/phone_auth_controller.dart';
import '../controllers/pin_login_controller.dart';
import '../data/auth_failure.dart';
import 'widgets/auth_screen_layout.dart';

const _pinLength = 4;

enum _LastAction { none, login, firstTime, forgotPin }

/// `/auth/phone`: the normal returning-login screen (prompt 05E §11) —
/// phone number + 4-digit PIN, verified server-side, no OTP for this
/// case. Also the entry point for the two OTP sub-flows: "Mara ya
/// kwanza?" (first-time verification, -> `/auth/verify`) and "Umesahau
/// PIN?" (recovery, -> `/auth/pin-recover/verify`) — both reuse
/// whatever phone number is already typed here rather than asking for
/// it again.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  AutoSubmitOnLength? _autoSubmit;
  _LastAction _lastAction = _LastAction.none;

  @override
  void initState() {
    super.initState();
    _autoSubmit = AutoSubmitOnLength(
      controller: _pinController,
      length: _pinLength,
      onComplete: _submitLogin,
    );
  }

  @override
  void dispose() {
    _autoSubmit?.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _isBusy(WidgetRef ref) =>
      ref.read(pinLoginControllerProvider).isSubmitting ||
      ref.read(phoneAuthControllerProvider).isSubmitting ||
      ref.read(pinRecoveryControllerProvider).isSubmitting;

  Future<void> _submitLogin() async {
    if (_isBusy(ref)) return;
    FocusScope.of(context).unfocus();
    setState(() => _lastAction = _LastAction.login);
    final ok = await ref
        .read(pinLoginControllerProvider.notifier)
        .submit(rawPhone: _phoneController.text, pin: _pinController.text);
    if (!ok && mounted) {
      _pinController.clear();
    }
  }

  Future<void> _submitFirstTime() async {
    if (_isBusy(ref)) return;
    FocusScope.of(context).unfocus();
    setState(() => _lastAction = _LastAction.firstTime);
    final ok = await ref
        .read(phoneAuthControllerProvider.notifier)
        .submitPhone(_phoneController.text);
    if (ok && mounted) {
      context.go(AppRoutes.authVerify);
    }
  }

  Future<void> _forgotPin() async {
    if (_isBusy(ref)) return;
    FocusScope.of(context).unfocus();
    setState(() => _lastAction = _LastAction.forgotPin);
    final ok = await ref
        .read(pinRecoveryControllerProvider.notifier)
        .start(_phoneController.text);
    if (ok && mounted) {
      context.go(AppRoutes.pinForgotVerify);
    }
  }

  AuthFailureType? _currentError() {
    return switch (_lastAction) {
      _LastAction.none => null,
      _LastAction.login => ref.watch(pinLoginControllerProvider).errorType,
      _LastAction.firstTime => ref.watch(phoneAuthControllerProvider).errorType,
      _LastAction.forgotPin =>
        ref.watch(pinRecoveryControllerProvider).errorType,
    };
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(pinLoginControllerProvider);
    final firstTimeSubmitting = ref.watch(
      phoneAuthControllerProvider.select((s) => s.isSubmitting),
    );
    final forgotSubmitting = ref.watch(
      pinRecoveryControllerProvider.select((s) => s.isSubmitting),
    );
    final isBusy =
        loginState.isSubmitting || firstTimeSubmitting || forgotSubmitting;

    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final errorType = _currentError();

    return AuthScreenLayout(
      children: [
        Text(l10n.authWelcomeTitle, style: textTheme.headlineMedium),
        const SizedBox(height: UmojaSpacing.sm),
        Text(l10n.authLoginSubtitle, style: textTheme.bodyLarge),
        const SizedBox(height: UmojaSpacing.xxl),
        TextField(
          controller: _phoneController,
          autofocus: true,
          enabled: !isBusy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.authPhoneLabel,
            hintText: l10n.authPhoneHint,
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Text(l10n.authPinLabel, style: textTheme.labelLarge),
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCodeInput(
          controller: _pinController,
          length: _pinLength,
          enabled: !isBusy,
          hasError: errorType != null,
          onSubmitted: (_) => _submitLogin(),
        ),
        if (errorType != null) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            authFailureMessage(l10n, errorType),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isBusy ? null : _submitLogin,
            child: loginState.isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.loginButton),
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Center(
          child: TextButton(
            onPressed: isBusy ? null : _forgotPin,
            // Prompt 05E-E: neutral, matching "Karibu Umoja"'s color
            // (`onSurface`) rather than the global text-button theme's
            // primary red — deliberately scoped to just these two
            // secondary auth links, not a `textButtonTheme` change, so
            // OTP screens' Cancel/Resend (which should stay branded)
            // are unaffected.
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(l10n.pinForgot),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: isBusy ? null : _submitFirstTime,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(l10n.authFirstTimeLink),
          ),
        ),
      ],
    );
  }
}
