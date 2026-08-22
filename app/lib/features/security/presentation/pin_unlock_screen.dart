import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/auto_submit_on_length.dart';
import '../../../core/utils/masked_phone.dart';
import '../../../core/widgets/umoja_confirmation_sheet.dart';
import '../../auth/presentation/widgets/auth_screen_layout.dart';
import '../../auth/providers/auth_controller_provider.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../controllers/pin_unlock_controller.dart';

const _pinLength = 4;

/// `/auth/pin-unlock`: the normal daily re-entry screen once a PIN is
/// configured and the app is locked (fresh process start, or after
/// "Toka" on the More screen — prompt 05C §2). Auto-verifies at 4
/// digits (§14). Never calls Supabase itself:
/// - "Umesahau PIN?" navigates straight to the recovery flow
///   (`/auth/pin-recover/verify`) with no side effects at all (prompt
///   05C §18-19) — it does NOT sign out or touch the stored PIN;
///   the recovery screens themselves preserve the session and old PIN
///   until a new one is successfully set.
/// - "Tumia namba nyingine" is the one action here that still calls
///   full sign-out (a genuinely different, deliberate account switch)
///   behind its own confirmation.
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  final _controller = TextEditingController();
  AutoSubmitOnLength? _autoSubmit;
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _autoSubmit = AutoSubmitOnLength(
      controller: _controller,
      length: _pinLength,
      onComplete: _submit,
    );
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _autoSubmit?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(pinUnlockControllerProvider.notifier)
        .verify(_controller.text);
    if (!ok && mounted) {
      _controller.clear();
    }
  }

  /// Prompt 05C §18-19: initiating recovery must NOT itself invalidate
  /// anything — no signOut, no PIN clear, no confirmation dialog gating
  /// it (there is nothing destructive to confirm). The recovery screen
  /// itself provides a safe, side-effect-free Back to this screen.
  void _forgotPin() => context.go(AppRoutes.pinForgotVerify);

  /// "Tumia namba nyingine" — the deliberate account-switch/session-
  /// removal escape hatch (prompt 05C §3). Signs out and returns to
  /// phone entry, but — since prompt 05D §12 — does **not** clear this
  /// device's stored PIN for the outgoing identity: PIN storage is
  /// keyed per `auth.user.id`, so switching away and later switching
  /// back to the same account recognizes its existing PIN instead of
  /// forcing setup again. Deliberately not placed in normal operational
  /// navigation (More) — it only exists here, on the PIN login screen,
  /// so it can never be the easiest accidental exit.
  Future<void> _switchAccount() async {
    final l10n = context.l10n;
    final confirmed = await showUmojaConfirmationSheet(
      context,
      title: l10n.switchAccountConfirmTitle,
      message: l10n.switchAccountConfirmMessage,
      confirmLabel: l10n.switchAccountConfirmButton,
      cancelLabel: l10n.cancelButton,
    );
    if (confirmed) {
      await ref.read(authControllerProvider).signOut();
      if (mounted) context.go(AppRoutes.authPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinUnlockControllerProvider);
    final phone = maskedPhone(ref.watch(currentSupabaseUserProvider)?.phone);
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    final secondsRemaining = state.cooldownUntil == null
        ? 0
        : state.cooldownUntil!
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 60);
    final rateLimited = state.isRateLimited;

    return AuthScreenLayout(
      showLanguageSelector: false,
      children: [
        Text(l10n.pinUnlockTitle, style: textTheme.headlineMedium),
        const SizedBox(height: UmojaSpacing.sm),
        Text(l10n.pinUnlockSubtitle, style: textTheme.bodyLarge),
        if (phone != null) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            phone,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        TextField(
          controller: _controller,
          autofocus: true,
          enabled: !state.isSubmitting && !rateLimited,
          obscureText: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _pinLength,
          style: textTheme.headlineSmall,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (_) => _submit(),
        ),
        if (rateLimited) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            '${l10n.pinTooManyAttempts} (${secondsRemaining}s)',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ] else if (state.invalid) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            l10n.pinInvalid,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (state.isSubmitting || rateLimited) ? null : _submit,
            child: state.isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.pinUnlockButton),
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Center(
          child: TextButton(
            onPressed: state.isSubmitting ? null : _forgotPin,
            child: Text(l10n.pinForgot),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: state.isSubmitting ? null : _switchAccount,
            child: Text(l10n.switchAccountAction),
          ),
        ),
      ],
    );
  }
}
