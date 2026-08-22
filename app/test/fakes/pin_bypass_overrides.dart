import 'package:umoja/features/security/providers/has_pin_configured_provider.dart';
import 'package:umoja/features/security/providers/lock_state_provider.dart';

/// Standard overrides for widget tests that need to reach past the PIN
/// gate to exercise operational screens — "PIN already configured and
/// unlocked" for every signed-in fixture, so existing
/// profile/group/member-screen tests don't need to know or care about
/// PIN state. Dedicated PIN-flow tests override these two providers
/// themselves instead of using this helper.
///
/// No explicit return type: `Override` isn't part of riverpod 3.x's
/// public export surface, so this relies on type inference rather than
/// naming it.
// ignore: strict_top_level_inference
pinBypassOverrides() => [
  hasPinConfiguredProvider.overrideWith((ref) async => true),
  lockStateProvider.overrideWith(_AlwaysUnlockedLockNotifier.new),
];

class _AlwaysUnlockedLockNotifier extends LockNotifier {
  @override
  LockState build() => LockState.unlocked;
}
