import 'package:umoja/features/security/providers/has_pin_credential_provider.dart';

/// Standard overrides for widget tests that need to reach past the PIN
/// gate to exercise operational screens — "PIN already configured
/// server-side" for every signed-in fixture, so existing
/// profile/group/member-screen tests don't need to know or care about
/// PIN credential state. Dedicated PIN-flow/login tests override this
/// provider themselves instead of using this helper.
///
/// No explicit return type: `Override` isn't part of riverpod 3.x's
/// public export surface, so this relies on type inference rather than
/// naming it.
// ignore: strict_top_level_inference
pinBypassOverrides() => [
  hasPinCredentialProvider.overrideWith((ref) async => true),
];
