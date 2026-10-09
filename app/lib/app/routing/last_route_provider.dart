import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'umoja.last_route';

/// Prompt 09G-B6-C.5 §I: persists only the LAST successfully-settled
/// authenticated location — a plain path string, never a secret,
/// never form field contents — so a normal app close/reopen can
/// restore it instead of always landing back on Home. Device/session-
/// local `shared_preferences`, the exact same mechanism and scoping
/// already used for the language preference (`language_provider.dart`)
/// — not account-scoped storage, which is exactly why sign-out still
/// clears it (§K, `auth_controller_provider.dart`): a stored path is
/// meaningless/unsafe to hand to a different future session.
class LastRouteNotifier extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = prefs.getString(_prefsKey);
    } catch (_) {
      // Best-effort only — e.g. no platform binding available (a pure
      // Dart test with no Flutter test binding initialized). Losing
      // cross-restart restoration in that case is never a crash.
    }
  }

  /// Fire-and-forget: called on every settled authenticated
  /// navigation (`app_shell.dart`), same as
  /// [NavigationHistoryNotifier.recordVisit].
  Future<void> record(String location) async {
    state = location;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, location);
    } catch (_) {
      // Best-effort only — see [_load].
    }
  }

  /// Prompt 09G-B6-C.5 §K: called from [AuthController.signOut] — a
  /// persisted path must never be available to restore into a later,
  /// unrelated session.
  Future<void> clear() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Best-effort only — see [_load].
    }
  }
}

final lastRouteProvider = NotifierProvider<LastRouteNotifier, String?>(
  LastRouteNotifier.new,
);
