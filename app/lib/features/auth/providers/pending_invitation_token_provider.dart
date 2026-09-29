import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bearer token of an invitation the user tried to open while some
/// prerequisite (signed out, PIN not configured, profile incomplete)
/// was still blocking `/invite/:token` — set by the router's redirect
/// wrapper (Prompt 09G-B1-E3 §C) so the intended destination survives
/// the authentication/onboarding detour, and consulted by
/// [computeRedirect] to send the user back to it once every
/// prerequisite is satisfied.
///
/// Session-only, in-memory, never persisted (SharedPreferences, disk,
/// analytics, logs) — matches [selectedGroupProvider]'s own "session-
/// only" precedent. Holds only the bearer token itself (already
/// opaque, unguessable, and the sole credential a real invitation
/// link carries) — never a group/membership/user id derived from it.
class PendingInvitationTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Idempotent: setting the same token twice is a no-op state change
  /// (Riverpod already dedupes an unchanged `state =` assignment).
  void set(String token) => state = token;

  void clear() => state = null;
}

final pendingInvitationTokenProvider =
    NotifierProvider<PendingInvitationTokenNotifier, String?>(
      PendingInvitationTokenNotifier.new,
    );
