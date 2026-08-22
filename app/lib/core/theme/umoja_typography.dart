import 'package:flutter/material.dart';

/// Umoja's typography hierarchy, expressed as a Material [TextTheme] so
/// every widget can keep using `Theme.of(context).textTheme.*` rather
/// than reaching for a parallel style system.
///
/// The font family itself (Ubuntu) is applied once, at the
/// [ThemeData.fontFamily] level in `umoja_theme.dart` — these
/// [TextStyle]s deliberately don't set `fontFamily` themselves, so
/// every style here (and any ad-hoc [TextStyle] that doesn't override
/// it) resolves to Ubuntu automatically. Ubuntu is bundled as a static
/// font asset (Regular/Medium/Bold — see pubspec.yaml), not a Google
/// Fonts network dependency. The brand wordmark artwork is separate
/// from this typeface and is never recreated with it — see
/// `core/branding/umoja_brand_mark.dart`.
///
/// Mapping (see docs/product/design-system.md for the full rationale):
/// - display / large title  -> [TextTheme.headlineMedium]
/// - page title             -> [TextTheme.titleLarge]
/// - section title          -> [TextTheme.titleMedium]
/// - card title              -> [TextTheme.titleSmall]
/// - body                   -> [TextTheme.bodyLarge]
/// - secondary body         -> [TextTheme.bodyMedium]
/// - label                  -> [TextTheme.labelLarge]
/// - caption                -> [TextTheme.bodySmall]
class UmojaTypography {
  const UmojaTypography._();

  static TextTheme textTheme({
    required Color primaryText,
    required Color secondaryText,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.2,
      ),
      // display / large title.
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.25,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.25,
      ),
      // display / large title (primary greeting-scale usage).
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      // page title.
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.3,
      ),
      // section title.
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.35,
      ),
      // card title.
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.35,
      ),
      // body.
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 1.45,
      ),
      // secondary body.
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        // caption.
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.4,
      ),
      // label.
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        height: 1.3,
      ),
    );
  }
}
