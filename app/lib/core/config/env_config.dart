import '../errors/app_exception.dart';

/// Typed access to build-time environment configuration.
///
/// Values are supplied via `--dart-define` / `--dart-define-from-file` at
/// build or run time — never read from a bundled `.env` file, since that
/// would ship configuration inside the compiled app. See `app/.env.example`
/// and the root README for the exact commands.
///
/// Supabase's anon/publishable key is a public client key by design; it is
/// safe to embed via dart-define. The Supabase *service role* key must
/// never be referenced from this app.
class EnvConfig {
  const EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Whether the minimum configuration required to initialize Supabase
  /// is present.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Throws a [ConfigurationException] if required configuration is
  /// missing. Callers that need Supabase should call this explicitly
  /// rather than assuming the values are present.
  static void requireSupabaseConfig() {
    if (!isSupabaseConfigured) {
      throw const ConfigurationException(
        'Missing Supabase configuration. Provide SUPABASE_URL and '
        'SUPABASE_ANON_KEY via --dart-define-from-file (see app/.env.example '
        'and the root README).',
      );
    }
  }
}
