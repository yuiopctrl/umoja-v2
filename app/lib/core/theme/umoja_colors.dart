import 'package:flutter/material.dart';

/// Centralized semantic color tokens for Umoja. Widgets should always
/// consume these (or the [ThemeData] built from them in
/// `umoja_theme.dart`) instead of writing literal hex values —
/// keeping the palette in one place is what lets it change without a
/// widget-by-widget hunt.
///
/// This is the light-mode palette. See `umoja_theme.dart` for how a
/// dark theme is derived from it, and `docs/product/design-system.md`
/// for the rationale behind each choice.
class UmojaColors {
  const UmojaColors._();

  static const primary = Color(0xFFA51C30);
  static const primaryDark = Color(0xFF741421);
  static const primarySoft = Color(0xFFFBEAEC);

  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF2F4F7);

  static const textPrimary = Color(0xFF171A21);
  static const textSecondary = Color(0xFF667085);
  static const textDisabled = Color(0xFF98A2B3);

  static const border = Color(0xFFE4E7EC);
  static const borderStrong = Color(0xFFD0D5DD);

  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFECFDF3);

  static const warning = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFFFAEB);

  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFEF3F2);

  static const info = Color(0xFF175CD3);
  static const infoSoft = Color(0xFFEFF8FF);

  static const onPrimary = Color(0xFFFFFFFF);
}
