import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/app_context_provider.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';

/// Bridges Riverpod state changes into go_router's `refreshListenable`,
/// so the router re-evaluates its redirect on every relevant state
/// change without introducing a second, duplicate auth listener —
/// [authStateChangesProvider] remains the single auth-state source.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref
      ..listen(authSessionStatusProvider, (_, _) => notifyListeners())
      ..listen(appContextProvider, (_, _) => notifyListeners())
      ..listen(selectedGroupProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
