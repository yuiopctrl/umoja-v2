import 'package:flutter/material.dart';

import 'umoja_colors.dart';
import 'umoja_radius.dart';
import 'umoja_spacing.dart';
import 'umoja_typography.dart';

/// Builds Umoja's Material 3 [ThemeData] from the design tokens in this
/// directory. Widgets should style themselves from `Theme.of(context)`
/// (colors, text styles, component themes) rather than reading
/// [UmojaColors]/[UmojaTypography] directly — that keeps this file the
/// single place a visual adjustment has to be made.
///
/// Prompt 05E-C: dark mode is now built from the same explicit,
/// hand-picked tokens as light mode (see [UmojaColors]'s dark-mode
/// companions), not [ColorScheme.fromSeed] — a seeded dark scheme
/// derives washed-out/pale tones from a saturated seed like
/// [UmojaColors.primary], which is exactly what produced the faint,
/// low-contrast dark auth screen this prompt fixes. Every screen
/// (auth included — `AuthScreenLayout` no longer force-overrides the
/// theme) now follows whichever of these two the app is actually in.
///
/// **Prompt 05E-D — locked rule**: `scheme.primary` is
/// [UmojaColors.primary] (the one deep Umoja red, `#A51C30`) in *both*
/// themes, full stop. An earlier pass used a separate, brighter
/// "accessible" red for dark-mode text/border contexts (focused
/// inputs, PIN-box focus, "Umesahau PIN?"/OTP links) — that produced a
/// visible two-reds inconsistency (a pink accent next to the deep-red
/// button) and is deliberately not done any more. Where a dark
/// surface needs a *soft/container* fill (the language selector's
/// active segment, the nav bar's selected indicator), that fill is
/// [UmojaColors.primarySoftDark] — still unambiguously in the primary
/// family, just as `primarySoft` is for light — paired with
/// [UmojaColors.onPrimary] (white) for the text/icon on top of it,
/// which is what actually earns "strong contrast" there rather than a
/// second red tone.
class UmojaTheme {
  const UmojaTheme._();

  static ThemeData get light => _build(_lightScheme, UmojaColors.background);

  static ThemeData get dark => _build(_darkScheme, UmojaColors.backgroundDark);

  static ColorScheme get _lightScheme =>
      ColorScheme.fromSeed(
        seedColor: UmojaColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: UmojaColors.primary,
        onPrimary: UmojaColors.onPrimary,
        primaryContainer: UmojaColors.primarySoft,
        onPrimaryContainer: UmojaColors.primaryDark,
        secondary: UmojaColors.primaryDark,
        onSecondary: UmojaColors.onPrimary,
        error: UmojaColors.danger,
        onError: UmojaColors.onPrimary,
        errorContainer: UmojaColors.dangerSoft,
        onErrorContainer: UmojaColors.danger,
        surface: UmojaColors.surface,
        onSurface: UmojaColors.textPrimary,
        onSurfaceVariant: UmojaColors.textSecondary,
        surfaceContainerHighest: UmojaColors.surfaceSubtle,
        surfaceContainerHigh: UmojaColors.surfaceSubtle,
        surfaceContainer: UmojaColors.surfaceSubtle,
        surfaceContainerLow: UmojaColors.surface,
        surfaceContainerLowest: UmojaColors.surface,
        outline: UmojaColors.borderStrong,
        outlineVariant: UmojaColors.border,
      );

  /// `primary`/`onPrimary` are the exact same [UmojaColors.primary] /
  /// [UmojaColors.onPrimary] as light mode — one Umoja brand identity
  /// across both themes (prompt 05E-D). `primaryContainer` is the
  /// dark *soft* fill for container/indicator treatments (still
  /// clearly primary-family, just muted), paired with white
  /// (`onPrimary`) rather than a second red tone for its foreground.
  static ColorScheme get _darkScheme =>
      ColorScheme.fromSeed(
        seedColor: UmojaColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: UmojaColors.primary,
        onPrimary: UmojaColors.onPrimary,
        primaryContainer: UmojaColors.primarySoftDark,
        onPrimaryContainer: UmojaColors.onPrimary,
        secondary: UmojaColors.primary,
        onSecondary: UmojaColors.onPrimary,
        error: UmojaColors.dangerDark,
        onError: UmojaColors.backgroundDark,
        errorContainer: UmojaColors.dangerSoftDark,
        onErrorContainer: UmojaColors.dangerDark,
        surface: UmojaColors.surfaceDark,
        onSurface: UmojaColors.textPrimaryDark,
        onSurfaceVariant: UmojaColors.textSecondaryDark,
        surfaceContainerHighest: UmojaColors.surfaceSubtleDark,
        surfaceContainerHigh: UmojaColors.surfaceSubtleDark,
        surfaceContainer: UmojaColors.surfaceSubtleDark,
        surfaceContainerLow: UmojaColors.surfaceDark,
        surfaceContainerLowest: UmojaColors.backgroundDark,
        outline: UmojaColors.borderStrongDark,
        outlineVariant: UmojaColors.borderDark,
      );

  static ThemeData _build(ColorScheme scheme, Color? scaffoldBackground) {
    final textTheme = UmojaTypography.textTheme(
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground ?? scheme.surface,
      fontFamily: 'Ubuntu',
      textTheme: textTheme,
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scaffoldBackground ?? scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: UmojaRadius.cardAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: UmojaSpacing.lg,
          vertical: UmojaSpacing.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: UmojaRadius.controlAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: UmojaRadius.controlAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: UmojaRadius.controlAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: UmojaRadius.controlAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: UmojaRadius.controlAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: UmojaRadius.controlAll,
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        labelStyle: textTheme.bodyMedium,
        // Deliberately full-opacity: `onSurfaceVariant` is already the
        // dedicated "muted" token (prompt 05E-C — stacking an alpha
        // reduction on top of it is exactly what produced illegibly
        // faint hint/placeholder text).
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: UmojaRadius.controlAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.xl),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: UmojaRadius.controlAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: UmojaRadius.controlAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        shape: RoundedRectangleBorder(borderRadius: UmojaRadius.smallAll),
        padding: const EdgeInsets.symmetric(
          horizontal: UmojaSpacing.md,
          vertical: UmojaSpacing.xs,
        ),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: UmojaRadius.largeAll),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(UmojaRadius.large),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: UmojaRadius.mediumAll),
      ),
    );
  }
}
