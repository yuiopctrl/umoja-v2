import '../errors/app_exception.dart';

/// Typed access to build-time environment configuration.
///
/// Values are supplied via `--dart-define` / `--dart-define-from-file` at
/// build or run time — never read from a bundled `.env` file, since that
/// would ship configuration inside the compiled app. See `app/.env.example`
/// and the root README for the exact commands.
///
/// Supabase's publishable key is a public client key by design; it is
/// safe to embed via dart-define. The Supabase *secret*/*service role*
/// key must never be referenced from this app.
class EnvConfig {
  const EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// The canonical public web URL this app is deployed at (e.g.
  /// `https://app.example.org`), used ONLY to build an absolute,
  /// shareable invitation link on non-web platforms (Prompt
  /// 09G-B1-E4 §H) — web builds use the browser's own trusted
  /// `Uri.base` origin instead and never read this value.
  ///
  /// No production domain exists yet for this project, so this is
  /// empty by default; [isPublicWebUrlConfigured] is false until a
  /// real value is supplied via `--dart-define-from-file`. Callers
  /// must treat "not configured" as a normal, expected state on
  /// native builds today — never invent/hardcode a domain, and never
  /// fall back to `localhost`.
  static const String publicWebUrl = String.fromEnvironment(
    'APP_PUBLIC_WEB_URL',
  );

  /// Whether the minimum configuration required to initialize Supabase
  /// is present.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Whether [publicWebUrl] is present and a well-formed absolute
  /// `http`/`https` URL with a non-empty host. Deliberately permissive
  /// beyond that (does not special-case `localhost`) — this only
  /// guards against silently building a broken link from garbage
  /// configuration, not against an operator's deliberate choice of
  /// value.
  static bool get isPublicWebUrlConfigured {
    if (publicWebUrl.isEmpty) return false;
    final uri = Uri.tryParse(publicWebUrl);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Throws a [ConfigurationException] if required configuration is
  /// missing. Callers that need Supabase should call this explicitly
  /// rather than assuming the values are present.
  static void requireSupabaseConfig() {
    if (!isSupabaseConfigured) {
      throw const ConfigurationException(
        'Missing Supabase configuration. Provide SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY via --dart-define-from-file (see '
        'app/.env.example and the root README).',
      );
    }
  }
}
