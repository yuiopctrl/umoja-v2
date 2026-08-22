import 'package:flutter/material.dart';

/// Centralized semantic color tokens for Umoja. Widgets should always
/// consume these (or the [ThemeData] built from them in
/// `umoja_theme.dart`) instead of writing literal hex values —
/// keeping the palette in one place is what lets it change without a
/// widget-by-widget hunt, and is what lets a widget (e.g.
/// `UmojaStatusBadge`) pick light- or dark-appropriate tokens by
/// checking `Theme.of(context).brightness` instead of hard-coding one
/// palette regardless of theme.
///
/// This is the light-mode palette, plus (prompt 05E-C) an explicit
/// dark-mode companion for every token that needs one — never derived
/// from an uncontrolled `ColorScheme.fromSeed`, which produces
/// washed-out/pale tones for a saturated seed like [primary]. See
/// `umoja_theme.dart` for how both are assembled into a [ThemeData],
/// and `docs/product/design-system.md` for the rationale behind each
/// choice.
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

  // ---------------------------------------------------------------
  // Dark-mode companions (prompt 05E-C, locked by 05E-D). [primary]
  // itself is the *same* canonical brand red in both themes — for
  // buttons, focused borders/PIN-box focus, and every branded
  // interactive text/link. There is deliberately no separate
  // brighter/"accessible" red variant for dark-mode text/border
  // contexts any more — that produced a visible two-reds
  // inconsistency (a pink accent next to the deep-red button) and is
  // a locked design-system rule against re-introducing (see
  // docs/product/design-system.md, "Dark mode"). Only [primarySoftDark]
  // exists as a *container/fill* companion — still unambiguously in
  // the primary family (a muted, dark tint of the same hue), paired
  // with white ([onPrimary]) for whatever sits on top of it, which is
  // what actually earns contrast there rather than a second red tone.
  // ---------------------------------------------------------------

  static const primarySoftDark = Color(0xFF3A1620);

  static const backgroundDark = Color(0xFF121317);
  static const surfaceDark = Color(0xFF1B1D22);
  static const surfaceSubtleDark = Color(0xFF24272E);

  /// Warm near-white, not pure white — softer for extended reading.
  static const textPrimaryDark = Color(0xFFF5F3F2);
  static const textSecondaryDark = Color(0xFFB8BCC6);
  static const textDisabledDark = Color(0xFF6C707A);

  static const borderDark = Color(0xFF34373F);
  static const borderStrongDark = Color(0xFF474B55);

  static const successDark = Color(0xFF4ADE80);
  static const successSoftDark = Color(0xFF12321F);

  static const warningDark = Color(0xFFFBBF6B);
  static const warningSoftDark = Color(0xFF3A2A12);

  static const dangerDark = Color(0xFFFF6B6B);
  static const dangerSoftDark = Color(0xFF3A1616);

  static const infoDark = Color(0xFF7DB3F5);
  static const infoSoftDark = Color(0xFF122234);
}
