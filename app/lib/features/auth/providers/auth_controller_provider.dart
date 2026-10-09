import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/last_route_provider.dart';
import '../../../app/routing/navigation_history_provider.dart';
import '../../members/providers/members_query_provider.dart';
import '../../membership_invitations/controllers/membership_invitation_acceptance_controller.dart';
import '../../security/providers/has_pin_credential_provider.dart';
import '../controllers/phone_auth_controller.dart';
import 'app_context_provider.dart';
import 'auth_repository_provider.dart';
import 'pending_invitation_token_provider.dart';
import 'selected_group_provider.dart';

/// The single place sign-out happens. Beyond calling Supabase Auth's
/// `signOut()` (which owns clearing its own token storage), this
/// explicitly invalidates every user-scoped provider so User B can
/// never observe a stale fragment of User A's state (app context,
/// selected group, in-flight phone/OTP entry, a pending/just-accepted
/// invitation token) — see docs/product/authentication.md ("no
/// user-state leakage") and Prompt 09G-B1-E4-FINAL §B/§C: an
/// invitation token may survive the temporary auth prerequisites
/// needed to complete THAT SAME invitation, but must never survive an
/// explicit sign-out into a future, unrelated session — otherwise a
/// later ordinary login (by the same or a different person on the
/// same device) could be silently redirected to someone else's old
/// invitation, or have its own "just accepted" hold released early by
/// a stale flag belonging to a previous session.
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
      ..invalidate(membersQueryProvider)
      ..invalidate(pendingInvitationTokenProvider)
      ..invalidate(membershipInvitationAcceptanceControllerProvider);
    // Prompt 09G-B6-C.5 §K: a later, unrelated login must never inherit
    // this session's in-session navigation history or its persisted
    // last-open route — both are cleared explicitly, the same
    // "no user-state leakage" treatment as every provider above.
    _ref.read(navigationHistoryProvider.notifier).clear();
    await _ref.read(lastRouteProvider.notifier).clear();
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
