import 'dart:async' show Timer;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations_x.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../routing/navigation_history_provider.dart';

/// Prompt 09G-B6-C.5 §L/§M/§N/§O: the single global system-Back
/// handler, wrapping [AppShell] from inside the `ShellRoute`'s own
/// `builder` (`app_router.dart`) — every authenticated route's own
/// page/`ModalRoute` is exactly where a `PopScope` must live to
/// actually intercept the system Back button/gesture at all; one
/// placed above the Router's `Navigator` entirely (the original,
/// incorrect placement via `MaterialApp.router`'s own `builder` in
/// `app.dart`) never sees it, on a real device any more than in a
/// test using `WidgetTester.binding.handlePopRoute()`. Shares
/// [performAppBack] with `UmojaFeatureScaffold`'s own visible back
/// arrow, so hardware/gesture Back and the header button are always
/// coherent — a feature root with meaningful history is backed out of
/// exactly the same way regardless of which one triggered it.
///
/// Only when [performAppBack] reports there was truly nowhere to go
/// (the real terminal condition — no history, nothing to pop, no
/// fallback) does this apply Android's double-press-to-exit policy:
/// the first Back is consumed with a brief Snackbar
/// ("Press back again to exit" / its Swahili equivalent); a second
/// Back within [_confirmWindow] actually exits; otherwise the pending
/// state silently expires.
///
/// §O: this entire policy applies on Android only. Web/desktop keep
/// their platform's own native behavior (browser Back, window-close) —
/// [PopScope.canPop] stays `true` there, so this widget does nothing
/// beyond passing `child` through unchanged.
///
/// Also a pass-through — no [PopScope] installed at all — whenever
/// there is no signed-in session: the pre-auth flow (phone entry, OTP,
/// PIN setup/recovery) already has its own screen-specific `PopScope`s
/// with their own deliberate semantics (e.g. "system Back during PIN
/// recovery returns to login, never signs out"), and this guard's
/// authenticated-route double-back-exit policy must never shadow or
/// double up with those — consistent with never applying authenticated
/// route/session behavior before auth is actually established.
class AppExitGuard extends ConsumerStatefulWidget {
  const AppExitGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppExitGuard> createState() => _AppExitGuardState();
}

/// The actual platform exit call made on a confirmed second Back
/// press. Defaults to [SystemNavigator.pop] — the standard Flutter
/// idiom for a genuine Android app-close from a `PopScope` handler
/// (NOT `Navigator.pop`, which only pops an entry already on some
/// `Navigator`'s stack and is a no-op here, since reaching this
/// handler at all already means there was nothing left to pop).
/// Overridden only by tests (`ProviderContainer` override, the same
/// pattern every other test fake in this app uses) so a test can
/// assert the exit boundary was reached without the test process
/// itself being torn down — the minimum platform seam Prompt
/// 09G-B6-C.5 §Q requires, never a change to what happens on a real
/// device.
final appExitActionProvider = Provider<Future<void> Function()>(
  (ref) => SystemNavigator.pop,
);

class _AppExitGuardState extends ConsumerState<AppExitGuard> {
  static const _confirmWindow = Duration(seconds: 2);

  /// Whether a first Back press is currently awaiting its confirming
  /// second one. The [_expiryTimer] below is the sole, authoritative
  /// source of when this expires — deliberately not a `DateTime`
  /// wall-clock comparison, which a virtual/fake test clock
  /// (`tester.pump(duration)`) never advances: the timer firing IS
  /// the window elapsing, on a real device exactly as in a test.
  bool _isExitPending = false;

  /// The pending timeout that will expire the current confirmation —
  /// a real, cancelable [Timer] rather than a bare `Future.delayed`,
  /// so a second Back press or a settled navigation can cancel the
  /// one still outstanding from the first press instead of leaking
  /// it.
  Timer? _expiryTimer;

  bool get _usesDoubleBackExit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Prompt 09G-B6-C.5 §N: reset whenever the user clearly continues
  /// using the app — a settled navigation (observed below via
  /// [navigationHistoryProvider], the same signal `app_shell.dart`
  /// writes to on every route change) or the confirmation window
  /// simply elapsing on its own.
  void _resetPendingExit() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (!mounted) return;
    setState(() => _isExitPending = false);
  }

  void _handleTerminalBack(BuildContext context) {
    if (_isExitPending) {
      _expiryTimer?.cancel();
      _expiryTimer = null;
      _isExitPending = false;
      ref.read(appExitActionProvider)();
      return;
    }
    _expiryTimer?.cancel();
    setState(() => _isExitPending = true);
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.pressBackAgainToExitMessage),
          duration: _confirmWindow,
        ),
      );
    // The pending state also expires on timeout even without a
    // further Back press, so a stray later Back (after the window) is
    // correctly treated as a fresh "first" press rather than silently
    // exiting. Always cancelled and rescheduled together with
    // [_firstBackAt] (see every call site above/below), so by the time
    // this callback runs it unambiguously means THIS window elapsed —
    // no redundant re-check of elapsed wall-clock time needed (and, on
    // a virtual/fake test clock, actively wrong: the scheduled time
    // having elapsed is the authoritative signal, not a separate
    // `DateTime.now()` comparison that a fake clock never advances).
    _expiryTimer = Timer(_confirmWindow, () {
      _expiryTimer = null;
      _resetPendingExit();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesDoubleBackExit) return widget.child;
    if (ref.watch(authSessionStatusProvider) != AuthSessionStatus.signedIn) {
      return widget.child;
    }

    // Any settled navigation resets a pending exit confirmation.
    ref.listen(navigationHistoryProvider, (_, _) => _resetPendingExit());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigated = performAppBack(context, ref);
        if (navigated) {
          _resetPendingExit();
          return;
        }
        _handleTerminalBack(context);
      },
      child: widget.child,
    );
  }
}
