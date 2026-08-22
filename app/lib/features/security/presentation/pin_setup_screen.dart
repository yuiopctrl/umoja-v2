import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/auto_submit_on_length.dart';
import '../../../core/widgets/umoja_code_input.dart';
import '../../auth/presentation/widgets/auth_screen_layout.dart';
import '../controllers/pin_setup_controller.dart';

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
    // Drives the button's enabled/disabled state as digits are typed
    // (prompt 05E-A §9) — auto-submit alone only reacts at exactly 4
    // digits, so without this listener the button would stay in
    // whatever enabled state it had at the last full rebuild while the
    // user is still mid-entry.
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _autoSubmit?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(pinSetupControllerProvider.notifier);
    final step = ref.read(pinSetupControllerProvider).step;
    if (step == PinSetupStep.enterPin) {
      notifier.submitFirst(_controller.text);
      return;
    }

    final ok = await notifier.submitConfirm(_controller.text);
    // Plain first-time setup (`cancelRoute == null`) relies on the
    // router's redirect to leave `/auth/pin-setup` once
    // `hasPinCredentialProvider` refetches `true` — same pattern as
    // every other auth screen. The recovery reuse of this screen
    // (`cancelRoute` set) cannot rely on that: `route_guard.dart`
    // deliberately exempts `/auth/pin-recover/new-pin` from the
    // redirect unconditionally, in either direction, so a user mid
    // recovery is never bounced away before finishing it (see
    // `_pinRecoveryRoutes` doc). That same exemption would otherwise
    // strand a *successful* recovery here forever, so this reuse alone
    // navigates explicitly on success.
    if (ok && widget.cancelRoute != null && mounted) {
      context.go(AppRoutes.splash);
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
    final isComplete = _controller.text.length == _pinLength;
    // Deliberately does NOT also require `!state.isSubmitting` — a
    // request in flight must keep the button's *enabled* (deep
    // Umoja-red) visual with a loading indicator swapped in for the
    // label (prompt 05E-A §9), never fall back to the pale disabled
    // style. Double-submission is already prevented one layer down:
    // both `PinSetupController.submitFirst`/`submitConfirm` no-op while
    // `state.isSubmitting` is true, so a stray extra tap here is safe.
    final canSubmit = isComplete;

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
        Center(
          child: UmojaCodeInput(
            key: ValueKey(state.step),
            controller: _controller,
            length: _pinLength,
            autofocus: true,
            enabled: !state.isSubmitting,
            hasError: state.mismatch || state.saveError,
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (state.mismatch) ...[
          const SizedBox(height: UmojaSpacing.md),
          Text(
            l10n.pinMismatch,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.saveError) ...[
          const SizedBox(height: UmojaSpacing.md),
          Text(
            l10n.pinSetupSaveError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSubmit ? _submit : null,
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
