import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../members/providers/members_query_provider.dart';
import '../../security/providers/has_pin_configured_provider.dart';
import '../../security/providers/lock_state_provider.dart';
import '../controllers/phone_auth_controller.dart';
import 'app_context_provider.dart';
import 'auth_repository_provider.dart';
import 'selected_group_provider.dart';

/// The single place sign-out happens. Beyond calling Supabase Auth's
/// `signOut()` (which owns clearing its own token storage), this
/// explicitly invalidates every user-scoped provider so User B can
/// never observe a stale fragment of User A's state (app context,
/// selected group, in-flight phone/OTP entry) — see
/// docs/product/authentication.md ("no user-state leakage").
///
/// This is "Toka kabisa" (full sign out, currently only reachable via
/// "Tumia namba nyingine") — distinct from "Funga programu" (lock),
/// which never reaches this class at all (see [LockNotifier.lock]).
///
/// Prompt 05D §12: this deliberately does **not** clear the outgoing
/// identity's stored PIN. PIN storage is already keyed per
/// `auth.user.id` (`PinRepository`/`SecurePinRepository`), so leaving
/// it in place costs nothing and lets a device switch away from an
/// account and later return to it without recreating a PIN every
/// time — clearing it here was the earlier (prompt 05B/05C) behavior
/// and was the root cause of an OTP/PIN-setup cycle on repeated
/// account switching (see `lock_state_provider.dart` for the matching
/// fix on the unlock side).
///
/// Reactive invalidation (via [appContextProvider] watching
/// `authUserIdProvider`) already handles this on the next auth-state
/// event; the explicit invalidation here makes it immediate and
/// deterministic rather than depending on event-propagation timing.
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
    _ref
      ..invalidate(appContextProvider)
      ..invalidate(selectedGroupProvider)
      ..invalidate(phoneAuthControllerProvider)
      ..invalidate(hasPinConfiguredProvider)
      ..invalidate(membersQueryProvider);
    _ref.read(lockStateProvider.notifier).lock();
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
