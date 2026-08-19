import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';
import '../errors/app_exception.dart';

final _log = Logger('SupabaseBootstrap');

/// Initializes the Supabase SDK exactly once, if configuration is present.
///
/// This is the only place in the app that should call
/// `Supabase.initialize`. Everything else must go through
/// [supabaseClientProvider].
///
/// Returns `true` if Supabase was initialized, `false` if configuration
/// was missing (in which case the app runs in a documented
/// "configuration missing" state instead of crashing).
Future<bool> initSupabase() async {
  if (!EnvConfig.isSupabaseConfigured) {
    _log.warning('Supabase configuration missing; skipping initialization.');
    return false;
  }

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );
  return true;
}

/// Exposes the app's single Supabase client instance to the rest of the
/// app. Features must consume this provider instead of calling
/// `Supabase.instance.client` directly, so the client stays centrally
/// owned and swappable (e.g. for testing).
///
/// Throws [ConfigurationException] if Supabase was never initialized —
/// callers should check [isSupabaseConfiguredProvider] first where a
/// missing configuration is a valid UI state rather than a bug.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  EnvConfig.requireSupabaseConfig();
  return Supabase.instance.client;
});

/// Whether Supabase configuration is available, without throwing.
/// Useful for rendering a "configuration missing" state in the UI.
final isSupabaseConfiguredProvider = Provider<bool>((ref) {
  return EnvConfig.isSupabaseConfigured;
});
