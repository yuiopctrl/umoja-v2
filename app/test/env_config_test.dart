import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/config/env_config.dart';
import 'package:umoja/core/errors/app_exception.dart';

// EnvConfig reads compile-time constants via String.fromEnvironment, so
// their values are fixed for the whole test binary and cannot be
// swapped per-test — only by passing --dart-define(-from-file) to
// `flutter test` itself, e.g.:
//   flutter test --dart-define=SUPABASE_URL=http://x \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=y
// to exercise the "configured" branch. The default `flutter test` run
// (no dart-defines, as CI uses) exercises the "unconfigured" branch
// below, which is what these tests lock down.
void main() {
  test('SUPABASE_PUBLISHABLE_KEY is the config value EnvConfig exposes', () {
    // Compiles/type-checks against the new field name; a stale
    // `supabaseAnonKey` reference would fail to build.
    expect(EnvConfig.supabasePublishableKey, isA<String>());
  });

  test('with no dart-define supplied, Supabase is reported unconfigured', () {
    expect(EnvConfig.supabaseUrl, isEmpty);
    expect(EnvConfig.supabasePublishableKey, isEmpty);
    expect(EnvConfig.isSupabaseConfigured, isFalse);
  });

  test(
    'requireSupabaseConfig throws referencing the new name, not the legacy one',
    () {
      expect(
        EnvConfig.requireSupabaseConfig,
        throwsA(
          isA<ConfigurationException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('SUPABASE_URL'),
              contains('SUPABASE_PUBLISHABLE_KEY'),
              isNot(contains('SUPABASE_ANON_KEY')),
            ),
          ),
        ),
      );
    },
  );
}
