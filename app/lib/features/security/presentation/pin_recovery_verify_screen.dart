import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/auto_submit_on_length.dart';
import '../../../core/utils/masked_phone.dart';
import '../../../core/utils/otp_autofill.dart';
import '../../../core/widgets/umoja_code_input.dart';
import '../../auth/presentation/widgets/auth_screen_layout.dart';
import '../controllers/pin_recovery_controller.dart';

const _otpLength = 6;

/// `/auth/pin-recover/verify` — the "Umesahau PIN?" recovery step
/// (prompt 05E §17). The OTP for [PinRecoveryController.state.phone]
/// was already sent by the login screen's "Umesahau PIN?" tap (via
/// `PinRecoveryController.start`) before navigating here — this screen
/// never sends it itself, so arriving here never double-sends. A
/// visible back arrow AND the Android system Back both return to
/// `/auth/phone` and reset recovery state — no side effects on any
/// existing PIN credential or session, since nothing here mutates
/// either until a replacement PIN is actually confirmed on the next
/// screen.
class PinRecoveryVerifyScreen extends ConsumerStatefulWidget {
  const PinRecoveryVerifyScreen({super.key});

  @override
  ConsumerState<PinRecoveryVerifyScreen> createState() =>
      _PinRecoveryVerifyScreenState();
}

class _PinRecoveryVerifyScreenState
    extends ConsumerState<PinRecoveryVerifyScreen> {
  final _codeController = TextEditingController();
  AutoSubmitOnLength? _autoSubmit;
  late final OtpAutofill _otpAutofill;
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _autoSubmit = AutoSubmitOnLength(
      controller: _codeController,
      length: _otpLength,
      onComplete: _verify,
    );
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _otpAutofill = ref.read(otpAutofillProvider);
    _listenForSmsAutofill();
  }

  Future<void> _listenForSmsAutofill() async {
    final code = await _otpAutofill.listenForCode();
    // See OtpVerifyScreen._listenForSmsAutofill — same reasoning: this
    // just drives the existing manual-entry path, so auto-submit and
    // the controller's own isSubmitting guard already prevent a
    // duplicate/late verifyOtp call.
    if (!mounted || code == null || _codeController.text.isNotEmpty) return;
    _codeController.text = code;
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _autoSubmit?.dispose();
    _otpAutofill.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _back() {
    _otpAutofill.cancel();
    ref.read(pinRecoveryControllerProvider.notifier).reset();
    context.go(AppRoutes.authPhone);
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(pinRecoveryControllerProvider.notifier)
        .verifyOtp(_codeController.text);
    if (ok && mounted) {
      _otpAutofill.cancel();
      context.go(AppRoutes.pinForgotNewPin);
    } else if (mounted) {
      _codeController.clear();
    }
  }

  Future<void> _resend() async {
    await ref.read(pinRecoveryControllerProvider.notifier).resendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinRecoveryControllerProvider);
    final phone = maskedPhone(state.phone?.e164);
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    final resendAt = state.resendAvailableAt;
    final secondsRemaining = resendAt == null
        ? 0
        : resendAt.difference(DateTime.now()).inSeconds.clamp(0, 60);

    return AuthScreenLayout(
      showLanguageSelector: false,
      onBack: _back,
      children: [
        Text(l10n.pinRecoveryVerifyTitle, style: textTheme.headlineMedium),
        const SizedBox(height: UmojaSpacing.sm),
        Text(
          phone == null
              ? l10n.pinRecoveryVerifySubtitle
              : l10n.pinRecoveryVerifySubtitleWithPhone(phone),
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: UmojaSpacing.xl),
        Center(
          child: UmojaCodeInput(
            controller: _codeController,
            length: _otpLength,
            autofocus: true,
            enabled: !state.isSubmitting,
            hasError: state.errorType != null,
            isOneTimeCode: true,
            onSubmitted: (_) => _verify(),
          ),
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
                onPressed: state.isSubmitting ? null : _back,
                child: Text(l10n.cancelButton, overflow: TextOverflow.ellipsis),
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
