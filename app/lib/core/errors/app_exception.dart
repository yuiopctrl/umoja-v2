/// Base type for application-level exceptions that should be presented
/// to the user or handled explicitly, rather than crashing unpredictably.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when required runtime configuration (e.g. Supabase credentials)
/// is missing. Callers are expected to catch this during bootstrap and
/// render a clear "configuration missing" state instead of crashing.
class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}
