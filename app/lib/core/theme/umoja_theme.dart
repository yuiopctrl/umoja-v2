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
/// Light mode is the polished target for this design system. Dark mode
/// is derived from the same tokens (via [ColorScheme.fromSeed] plus the
/// same component themes) so it stays usable and won't need a
/// structural rewrite later, but it has not received the same manual
/// scrutiny — see docs/product/design-system.md.
class UmojaTheme {
  const UmojaTheme._();

  static ThemeData get light => _build(_lightScheme, UmojaColors.background);

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: UmojaColors.primary,
      brightness: Brightness.dark,
    ),
    null,
  );

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
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
