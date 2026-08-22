import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../members/providers/members_query_provider.dart';
import '../../security/providers/has_pin_credential_provider.dart';
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
/// Prompt 05E §13/§14: this is now a **real** Supabase sign-out, full
/// stop — there is no more separate local-only "lock" concept to
/// distinguish it from. "Toka" (More screen) calls this directly; the
/// next entry is always the phone + PIN login screen
/// (`/auth/phone`), never an automatic OTP.
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
      ..invalidate(hasPinCredentialProvider)
      ..invalidate(membersQueryProvider);
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
