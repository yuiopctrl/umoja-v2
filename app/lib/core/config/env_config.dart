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

  /// Whether the minimum configuration required to initialize Supabase
  /// is present.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

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
