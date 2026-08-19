import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../core/logging/app_logger.dart';
import '../core/supabase/supabase_client_provider.dart';
import 'app.dart';

final _log = Logger('Bootstrap');

/// Performs one-time startup work (logging, Supabase) and runs the app.
///
/// Supabase initialization is best-effort: if configuration is missing,
/// the app still starts and the foundation screen reports the missing
/// configuration instead of crashing. See [EnvConfig].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();

  final supabaseInitialized = await initSupabase();
  _log.info(
    supabaseInitialized
        ? 'Supabase initialized.'
        : 'Starting without Supabase (configuration missing).',
  );

  runApp(const ProviderScope(child: UmojaApp()));
}
