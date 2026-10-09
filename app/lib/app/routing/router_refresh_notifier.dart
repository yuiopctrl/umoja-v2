import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/app_context_provider.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/auth/providers/pending_invitation_token_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../../features/security/providers/has_pin_credential_provider.dart';
import 'last_route_provider.dart';

/// Bridges Riverpod state changes into go_router's `refreshListenable`,
/// so the router re-evaluates its redirect on every relevant state
/// change without introducing a second, duplicate auth listener —
/// [authStateChangesProvider] remains the single auth-state source.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref
      ..listen(authSessionStatusProvider, (_, _) => notifyListeners())
      ..listen(appContextProvider, (_, _) => notifyListeners())
      ..listen(selectedGroupProvider, (_, _) => notifyListeners())
      ..listen(hasPinCredentialProvider, (_, _) => notifyListeners())
      ..listen(pendingInvitationTokenProvider, (_, _) => notifyListeners())
      // Prompt 09G-B6-C.5 §I: `lastRouteProvider` loads asynchronously
      // from shared_preferences — this re-evaluates `redirect` once it
      // resolves, so a restored location is picked up on the very
      // next pass rather than only on a later unrelated state change.
      // Fires ONLY on that one initial null -> value resolution, never
      // on the ongoing `record()` calls `app_shell.dart` makes on every
      // subsequent settled navigation — those must never themselves
      // force an extra router rebuild, which would otherwise let a
      // screen's own just-recorded history entry leak into its own
      // back-arrow visibility check (see `navigation_history_provider`
      // on why that self-entry must never be visible to this build).
      ..listen(lastRouteProvider, (previous, next) {
        if (previous == null && next != null) notifyListeners();
      });
  }

  final Ref _ref;
}
