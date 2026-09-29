/// Thrown by [parseInvitationToken] for any unparseable/malformed
/// input. Deliberately a single, contentless variant — the UI never
/// shows a raw `FormatException`/parser detail, only one generic
/// localized "invalid link" message (see `failure_messages.dart`).
/// Never carries the original input in a message, so it can never be
/// accidentally logged.
class InvalidInvitationLinkException implements Exception {
  const InvalidInvitationLinkException();
}

final _invitePathPattern = RegExp(r'^/invite/([^/]+)/?$');

/// Extracts the bearer token from a pasted invitation link or bare
/// path (Prompt 09G-B1-E4 §F) — the "Open Invitation" paste flow's
/// sole parsing logic.
///
/// Accepts:
///   - a full URL: `https://<any-host>/invite/<token>`
///   - an app-local path: `/invite/<token>`
///
/// The host of a full URL is deliberately NEVER inspected/validated —
/// only the path is used, and only to extract the token. This is safe
/// specifically because nothing about the host is ever trusted or
/// acted on: the token itself is the sole authority, validated
/// server-side (`rpc_accept_membership_invitation`/
/// `rpc_preview_membership_invitation`) via a 256-bit bearer token
/// that cannot be brute-forced. Pasting `https://evil.example/invite/X`
/// has the exact same effect as pasting the bare token `X` — the app
/// only ever navigates internally to `/invite/X`, and the backend
/// alone decides whether `X` resolves to anything.
///
/// Rejects (throwing [InvalidInvitationLinkException]):
///   - empty/whitespace-only input
///   - `/invite/` with no token segment
///   - any additional path segments after the token
///   - a non-http(s) URI scheme (`javascript:`, `data:`, ...) — this
///     is a defensive input-sanity check, not a host allowlist
///   - anything that isn't `/invite/<token>` shaped at all
///
/// Query parameters are never inspected — only `Uri.path` contributes
/// to the extracted token, so a trick like
/// `/invite/real?x=/invite/other` still yields `real`, never `other`.
String parseInvitationToken(String rawInput) {
  final trimmed = rawInput.trim();
  if (trimmed.isEmpty) throw const InvalidInvitationLinkException();

  final uri = Uri.tryParse(trimmed);
  if (uri == null) throw const InvalidInvitationLinkException();

  String path;
  if (uri.hasScheme) {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const InvalidInvitationLinkException();
    }
    path = uri.path;
  } else {
    // A bare path (no scheme/authority) — e.g. "/invite/<token>".
    path = uri.path.isNotEmpty ? uri.path : trimmed;
  }

  final match = _invitePathPattern.firstMatch(path);
  if (match == null) throw const InvalidInvitationLinkException();

  final token = match.group(1)!;
  if (token.isEmpty) throw const InvalidInvitationLinkException();

  return token;
}
