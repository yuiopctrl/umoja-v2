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
import '../../auth/presentation/widgets/auth_screen_layout.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../controllers/pin_recovery_controller.dart';

const _otpLength = 6;

/// `/auth/pin-recover/verify` — the "Umesahau PIN?" recovery step
/// (prompt 05C §18-20). Re-verifies an OTP for the phone already on the
/// authenticated account (never re-entered, never a different number —
/// that's "Tumia namba nyingine" instead) so the existing Supabase
/// session is never touched here. A visible back arrow AND the Android
/// system Back both return to `/auth/pin-unlock` with no side effects
/// at all — the current PIN and session are completely untouched by
/// simply visiting or cancelling out of this screen.
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
  Timer? _cooldownTicker;
  bool _requested = false;

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
    // Auto-send once per screen visit — the phone is already known, so
    // there is no "enter phone number" step to trigger this from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requested) {
        _requested = true;
        ref.read(pinRecoveryControllerProvider.notifier).sendOtp();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _autoSubmit?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _back() => context.go(AppRoutes.pinUnlock);

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(pinRecoveryControllerProvider.notifier)
        .verifyOtp(_codeController.text);
    if (ok && mounted) {
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
    final phone = maskedPhone(ref.watch(currentSupabaseUserProvider)?.phone);
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
