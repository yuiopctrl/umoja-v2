import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/auto_submit_on_length.dart';
import '../controllers/phone_auth_controller.dart';
import 'widgets/auth_screen_layout.dart';

/// Supabase phone/SMS OTP is always 6 digits — unlike email OTP, this
/// is not independently configurable in `supabase/config.toml`
/// ([auth.sms] has no `otp_length` key; only `[auth.email]` does).
const _otpLength = 6;

/// `/auth/verify`: enter the OTP sent to the phone number submitted on
/// `/auth/phone`. Auto-verifies once [_otpLength] digits are entered
/// (prompt 05B §13); the "Thibitisha" button remains as a manual
/// fallback, sharing the same `isSubmitting` guard so the two paths can
/// never both be in flight. Successful verification transitions the
/// app automatically (via the auth-state stream + router) — no manual
/// "Continue" step is needed.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  AutoSubmitOnLength? _autoSubmit;

  // Only drives the "Resend in Ns" countdown label; owned and disposed
  // by this widget so it never leaks past screen disposal. The actual
  // cooldown gate (PhoneAuthState.canResend) does not depend on this
  // timer at all.
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _autoSubmit = AutoSubmitOnLength(
      controller: _codeController,
      length: _otpLength,
      onComplete: _verify,
    );
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _autoSubmit?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(phoneAuthControllerProvider.notifier)
        .verifyOtp(_codeController.text);
    // On success the auth-state stream flips and the router redirects
    // away from here automatically; on failure the error shows below.
  }

  Future<void> _resend() async {
    await ref.read(phoneAuthControllerProvider.notifier).resendOtp();
  }

  void _changeNumber() {
    ref.read(phoneAuthControllerProvider.notifier).changeNumber();
    context.go(AppRoutes.authPhone);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final phone = state.phone;

    if (phone == null) {
      // Reached directly (e.g. deep link, hot restart) without a phone
      // number in flight — there is nothing to verify.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.authPhone);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final resendAt = state.resendAvailableAt;
    final secondsRemaining = resendAt == null
        ? 0
        : resendAt.difference(DateTime.now()).inSeconds.clamp(0, 60);
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return AuthScreenLayout(
      showLanguageSelector: false,
      children: [
        Text(l10n.otpTitle, style: textTheme.headlineMedium),
        const SizedBox(height: UmojaSpacing.sm),
        Text(l10n.otpSubtitle(phone.display), style: textTheme.bodyLarge),
        const SizedBox(height: UmojaSpacing.xxl),
        TextField(
          controller: _codeController,
          autofocus: true,
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: _otpLength,
          decoration: InputDecoration(
            labelText: l10n.otpCodeLabel,
            counterText: '',
          ),
          onSubmitted: (_) => _verify(),
        ),
        if (state.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            authFailureMessage(l10n, state.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: state.isSubmitting ? null : _verify,
            child: state.isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.otpVerifyButton),
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: TextButton(
                onPressed: state.isSubmitting ? null : _changeNumber,
                child: Text(
                  l10n.otpChangeNumber,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: (state.isSubmitting || !state.canResend)
                    ? null
                    : _resend,
                child: Text(
                  state.canResend
                      ? l10n.otpResend
                      : l10n.otpResendCountdown(secondsRemaining),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
