import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_session_provider.dart';

enum LockState { locked, unlocked }

/// Whether the app is currently locked behind the PIN, for the
/// currently-authenticated Supabase identity. Purely in-memory by
/// design (never persisted).
///
/// Rebuilds whenever the authenticated identity changes — signing out
/// (-> null), or a different/returning user signing in — so one user's
/// "unlocked" state can never carry over and silently skip another
/// user's PIN gate on a shared device. [authUserIdProvider] only
/// changes on a genuine identity change (not on every token refresh
/// for the same user), so this does not spuriously re-lock the app
/// during normal use.
///
/// On such a rebuild, the outcome depends on *why* the identity
/// changed (prompt 05D §10-11):
/// - A live, in-process [AuthChangeEvent.signedIn] — a phone OTP that
///   was just successfully verified, whether first-time sign-in or an
///   account switch — has already strongly authenticated this session,
///   so it unlocks immediately. The PIN is never asked for again right
///   after OTP, regardless of whether one is already configured for
///   this identity; PIN gating (via `hasPinConfigured`/[LockState] in
///   `route_guard.dart`) still runs `pin-setup` first if this identity
///   has no PIN on this device yet, but never `pin-unlock`.
/// - Anything else — most importantly a cold app-process start
///   restoring an already-valid session, reported as
///   [AuthChangeEvent.initialSession], not `signedIn` — starts
///   [LockState.locked] (prompt 05B §12: "if app process restarts
///   while session remains valid, PIN should be required").
///
/// `ref.read` (not `watch`) on [latestAuthChangeEventProvider] here is
/// deliberate: only the identity change itself (via [authUserIdProvider])
/// should trigger a rebuild — a plain read lets this rebuild inspect
/// *why* without also rebuilding on every later `tokenRefreshed` event
/// for the same user, which must never re-lock the app.
class LockNotifier extends Notifier<LockState> {
  @override
  LockState build() {
    final userId = ref.watch(authUserIdProvider);
    if (userId == null) return LockState.locked;

    final latestEvent = ref.read(latestAuthChangeEventProvider);
    return latestEvent == AuthChangeEvent.signedIn
        ? LockState.unlocked
        : LockState.locked;
  }

  /// "Funga programu" — does not touch the Supabase session.
  void lock() => state = LockState.locked;

  /// Called after a correct PIN entry, or immediately after first-time
  /// PIN setup (proving possession by having just entered it twice).
  void unlock() => state = LockState.unlocked;
}

final lockStateProvider = NotifierProvider<LockNotifier, LockState>(
  LockNotifier.new,
);
