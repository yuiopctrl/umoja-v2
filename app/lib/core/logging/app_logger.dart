import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Centralized logging setup. Features should obtain a [Logger] via
/// `Logger('SomeName')` after [AppLogger.init] has been called once at
/// startup; do not configure logging output anywhere else.
class AppLogger {
  const AppLogger._();

  static bool _initialized = false;

  static void init({Level level = Level.INFO}) {
    if (_initialized) return;
    _initialized = true;

    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }
}
