import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../app/routing/app_routes.dart';
import '../../../core/config/env_config.dart';

/// The outcome of building a shareable invitation link (Prompt
/// 09G-B1-E4 §H). Never a bare `String?` — callers must explicitly
/// handle the unconfigured case rather than accidentally sharing a
/// `null`-derived/broken value.
class InvitationLinkResult {
  const InvitationLinkResult.url(this.url) : isConfigured = true;

  const InvitationLinkResult.unconfigured() : url = null, isConfigured = false;

  /// Non-null iff [isConfigured] is `true`.
  final String? url;

  final bool isConfigured;
}

/// The ONE invitation-link builder used by both Copy and Share (Prompt
/// 09G-B1-E4 §H) — no second place in this codebase builds this URL.
///
/// On web, [kIsWeb] makes `Uri.base` the browser's own trusted origin
/// — always safe/authoritative there. On every other platform there is
/// no equivalent, and no production public web domain is configured
/// for this project yet, so this deliberately returns "unconfigured"
/// rather than ever falling back to a relative path (which is not a
/// usable WhatsApp/SMS link) or an invented/localhost domain.
///
/// [isWebOverride]/[configuredPublicWebUrlOverride] exist ONLY so unit
/// tests can exercise both the web and native branches deterministically
/// from a VM test run (where [kIsWeb] is always `false` and no
/// `--dart-define` is set) — every real call site (Copy/Share in
/// `invite_member_screen.dart`) omits them and gets the real platform
/// value / [EnvConfig], so this remains the single real builder, never
/// a second one.
InvitationLinkResult buildInvitationLinkResult(
  String token, {
  bool? isWebOverride,
  String? configuredPublicWebUrlOverride,
}) {
  final path = AppRoutes.membershipInvitationAcceptPath(token);
  final isWeb = isWebOverride ?? kIsWeb;

  if (isWeb) {
    try {
      return InvitationLinkResult.url(Uri.base.resolve(path).toString());
    } catch (_) {
      return const InvitationLinkResult.unconfigured();
    }
  }

  final configuredUrl =
      configuredPublicWebUrlOverride ??
      (EnvConfig.isPublicWebUrlConfigured ? EnvConfig.publicWebUrl : null);
  if (configuredUrl == null) {
    return const InvitationLinkResult.unconfigured();
  }
  try {
    final base = Uri.parse(configuredUrl);
    return InvitationLinkResult.url(base.resolve(path).toString());
  } catch (_) {
    return const InvitationLinkResult.unconfigured();
  }
}
