import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/security/providers/lock_state_provider.dart';

/// Prompt 05D §9-11: regression coverage for the OTP/PIN-setup cycle
/// root cause — [LockNotifier] used to reset to [LockState.locked] on
/// *any* identity change, including one caused by a live, in-process
/// OTP verify. These tests exercise [LockNotifier] against the real
/// [currentSupabaseUserProvider]/[latestAuthChangeEventProvider] chain
/// (only the two raw signal providers are overridden with controllable
/// fakes — [authUserIdProvider] and [LockNotifier] itself are the real
/// implementations under test).
User _fakeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class _FakeUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  void set(User? user) => state = user;
}

class _FakeEventNotifier extends Notifier<AuthChangeEvent?> {
  @override
  AuthChangeEvent? build() => null;
  void set(AuthChangeEvent? event) => state = event;
}

final _fakeUserProvider = NotifierProvider<_FakeUserNotifier, User?>(
  _FakeUserNotifier.new,
);
final _fakeEventProvider =
    NotifierProvider<_FakeEventNotifier, AuthChangeEvent?>(
      _FakeEventNotifier.new,
    );

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        currentSupabaseUserProvider.overrideWith(
          (ref) => ref.watch(_fakeUserProvider),
        ),
        latestAuthChangeEventProvider.overrideWith(
          (ref) => ref.watch(_fakeEventProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a live signedIn event unlocks immediately — never asks for the PIN '
      'right after a successful OTP, whether or not a PIN already exists', () {
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);

    expect(container.read(lockStateProvider), LockState.unlocked);
  });

  test('a cold-start initialSession restoring an already-valid session starts '
      'locked (prompt 05B §12 — app restart requires the PIN again)', () {
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container
        .read(_fakeEventProvider.notifier)
        .set(AuthChangeEvent.initialSession);

    expect(container.read(lockStateProvider), LockState.locked);
  });

  test('signing out (no user) is locked', () {
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
    expect(container.read(lockStateProvider), LockState.unlocked);

    container.read(_fakeUserProvider.notifier).set(null);
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedOut);
    expect(container.read(lockStateProvider), LockState.locked);
  });

  test(
    'account switch (A -> sign out -> fresh OTP for B) unlocks again for B, '
    'exactly like a first sign-in — no residual lock from A carries over',
    () {
      container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
      container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
      expect(container.read(lockStateProvider), LockState.unlocked);

      // "Toka" locks without touching identity.
      container.read(lockStateProvider.notifier).lock();
      expect(container.read(lockStateProvider), LockState.locked);
      // Correct PIN entry still unlocks explicitly, as before.
      container.read(lockStateProvider.notifier).unlock();
      expect(container.read(lockStateProvider), LockState.unlocked);

      // "Tumia namba nyingine": sign out, then a fresh OTP for a
      // different account.
      container.read(_fakeUserProvider.notifier).set(null);
      container
          .read(_fakeEventProvider.notifier)
          .set(AuthChangeEvent.signedOut);
      expect(container.read(lockStateProvider), LockState.locked);

      container.read(_fakeUserProvider.notifier).set(_fakeUser('userB'));
      container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
      expect(
        container.read(lockStateProvider),
        LockState.unlocked,
        reason:
            'a fresh OTP verify for the switched-to account must not '
            'require a second PIN screen — this is what previously cycled '
            'back through OTP/PIN setup on repeated switching',
      );
    },
  );

  test('switching back to a previously-used account (A) also unlocks '
      'immediately on its fresh OTP verify, not just first-time switches', () {
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
    container.read(_fakeUserProvider.notifier).set(null);
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedOut);
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userB'));
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
    container.read(_fakeUserProvider.notifier).set(null);
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedOut);

    // Switch back to A.
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);

    expect(container.read(lockStateProvider), LockState.unlocked);
  });

  test('a token refresh for the same user never re-locks the app', () {
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
    expect(container.read(lockStateProvider), LockState.unlocked);

    // Same user id, new User instance (as a real token refresh produces)
    // — authUserIdProvider's own String? equality must prevent
    // LockNotifier from rebuilding at all, so the (irrelevant, since
    // never read) tokenRefreshed event cannot re-lock the app.
    container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
    container
        .read(_fakeEventProvider.notifier)
        .set(AuthChangeEvent.tokenRefreshed);

    expect(container.read(lockStateProvider), LockState.unlocked);
  });
}
