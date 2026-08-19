import 'package:flutter/material.dart';

/// Centralized Material 3 theme configuration.
///
/// Branding is intentionally neutral for now — this is a foundation, not
/// final visual design. Widgets should pull styling from `Theme.of(context)`
/// rather than hardcoding colors or text styles.
class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Colors.teal;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}
