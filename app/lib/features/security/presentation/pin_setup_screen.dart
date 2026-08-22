import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/auto_submit_on_length.dart';
import '../../auth/presentation/widgets/auth_screen_layout.dart';
import '../controllers/pin_setup_controller.dart';
import 'widgets/pin_dots.dart';

const _pinLength = 4;

/// `/auth/pin-setup`: shown once, right after a fresh OTP sign-in, when
/// no PIN is configured yet for this identity on this device (prompt
/// 05B §6/§11). Two steps — enter, then confirm — each auto-submitting
/// at 4 digits (§14); a mismatch on confirm restarts from the first
/// step rather than asking for a partial retry.
///
/// Reused as-is at `/auth/pin-recover/new-pin` for the "set new PIN"
/// step of PIN recovery (prompt 05C §18-21) — the underlying save
/// behavior is identical either way (`PinSetupController.submitConfirm`
/// only calls `setPin`, so it always overwrites atomically; there is no
/// separate "clear" step, so the old PIN is only ever replaced by a
/// *successful* new one). [cancelRoute], when set, shows a back arrow
/// and intercepts system Back (see `AuthScreenLayout.onBack`) so
/// backing out of an in-progress recovery routes to a safe, still-
/// locked PIN-entry state (§21) rather than leaving the app implicitly
/// unlocked or exposing operational screens without a PIN.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.cancelRoute});

  /// Route to return to if the user backs out before completing setup.
  /// `null` (the default, used for first-time setup) means no back
  /// option is offered — there is nothing safe to cancel back to at
  /// that point in the flow.
  final String? cancelRoute;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _controller = TextEditingController();
  AutoSubmitOnLength? _autoSubmit;
  PinSetupStep? _lastStep;

  @override
  void initState() {
    super.initState();
    _autoSubmit = AutoSubmitOnLength(
      controller: _controller,
      length: _pinLength,
      onComplete: _submit,
    );
  }

  @override
  void dispose() {
    _autoSubmit?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(pinSetupControllerProvider.notifier);
    final step = ref.read(pinSetupControllerProvider).step;
    if (step == PinSetupStep.enterPin) {
      notifier.submitFirst(_controller.text);
    } else {
      await notifier.submitConfirm(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinSetupControllerProvider);
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    // The controller moved to a new step (or restarted after a
    // mismatch) — clear the field so the dots/obscured text reflect
    // the new entry, not the previous one, and re-arm auto-submit:
    // confirming correctly means retyping the *same* PIN, which must
    // still auto-submit rather than being treated as an unchanged
    // no-op (see AutoSubmitOnLength.reset doc).
    if (_lastStep != state.step ||
        (state.mismatch && _controller.text.isNotEmpty)) {
      _lastStep = state.step;
      _autoSubmit?.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.clear();
      });
    }

    final isConfirm = state.step == PinSetupStep.confirmPin;

    return AuthScreenLayout(
      showLanguageSelector: false,
      onBack: widget.cancelRoute == null
          ? null
          : () => context.go(widget.cancelRoute!),
      children: [
        Text(
          isConfirm ? l10n.pinConfirmTitle : l10n.pinSetupTitle,
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        Text(
          isConfirm ? l10n.pinConfirmSubtitle : l10n.pinSetupSubtitle,
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) =>
              PinDots(filled: value.text.length, length: _pinLength),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        TextField(
          key: ValueKey(state.step),
          controller: _controller,
          autofocus: true,
          enabled: !state.isSubmitting,
          obscureText: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _pinLength,
          style: textTheme.headlineSmall,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (_) => _submit(),
        ),
        if (state.mismatch) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            l10n.pinMismatch,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.saveError) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            l10n.pinSetupSaveError,
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
