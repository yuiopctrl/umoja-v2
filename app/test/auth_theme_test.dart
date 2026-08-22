import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/theme/umoja_colors.dart';
import 'package:umoja/core/theme/umoja_radius.dart';
import 'package:umoja/core/theme/umoja_theme.dart';
import 'package:umoja/core/widgets/umoja_language_selector.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/pin_bypass_overrides.dart';

/// Prompt 05E-C: regression coverage for "auth follows the app theme,
/// with readable contrast, and a non-pill shared language switcher."
/// Deliberately not pixel-perfect — these check theme *tokens* and
/// *structure* (brightness, which color a widget resolved to, that a
/// radius isn't a stadium), never exact rendered pixels.
Future<void> _pumpLoginScreen(
  WidgetTester tester, {
  required Brightness platformBrightness,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(
          AuthSessionStatus.signedOut,
        ),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('1-2. dark platform theme produces a dark auth background — '
      'AuthScreenLayout no longer forces light', (tester) async {
    await _pumpLoginScreen(tester, platformBrightness: Brightness.dark);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));

    expect(theme.brightness, Brightness.dark);
    expect(
      scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
      UmojaColors.backgroundDark,
    );
  });

  testWidgets('3. light platform theme produces a light auth background', (
    tester,
  ) async {
    await _pumpLoginScreen(tester, platformBrightness: Brightness.light);

    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, UmojaColors.background);
  });

  testWidgets(
    '4. the primary auth title resolves to the theme\'s onSurface token '
    'in both themes — never a low-contrast/washed-out color',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        final titleWidget = tester.widget<Text>(find.text('Karibu Umoja'));
        final theme = Theme.of(tester.element(find.text('Karibu Umoja')));

        expect(
          titleWidget.style?.color,
          theme.colorScheme.onSurface,
          reason: 'brightness=$brightness',
        );
      }
    },
  );

  testWidgets(
    '5. helper/body text is not reduced to a rejected ultra-low opacity '
    '— it uses the dedicated muted token at full alpha',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        final helperWidget = tester.widget<Text>(
          find.text('Ingiza namba yako ya simu na PIN.'),
        );
        final color = helperWidget.style?.color;

        expect(color, isNotNull, reason: 'brightness=$brightness');
        expect(
          color!.a,
          1.0,
          reason:
              'brightness=$brightness — helper text must be fully opaque, '
              'not dimmed via alpha',
        );
      }
    },
  );

  testWidgets('6. the login screen\'s SW|EN switcher is the shared '
      'UmojaLanguageSelector widget', (tester) async {
    await _pumpLoginScreen(tester, platformBrightness: Brightness.light);
    expect(find.byType(UmojaLanguageSelector), findsOneWidget);
  });

  testWidgets('8. the language switcher\'s corner radius is UmojaRadius.small '
      '(8px) — never a pill/stadium shape', (tester) async {
    await _pumpLoginScreen(tester, platformBrightness: Brightness.light);

    // The selector's outer bordered wrapper is a Container with a
    // BoxDecoration; the thin 1px divider between segments is also
    // a Container, but with no `decoration` (just a flat `color`) —
    // filter for the one that actually carries the radius.
    final containers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(UmojaLanguageSelector),
            matching: find.byType(Container),
          ),
        )
        .where((c) => c.decoration is BoxDecoration);
    final decoration = containers.single.decoration as BoxDecoration;
    expect(decoration.borderRadius, UmojaRadius.smallAll);

    // Explicitly rule out a pill/stadium: a stadium border has no
    // fixed corner radius at all (it's `StadiumBorder`, not
    // `BorderRadius`), and any radius this small is nowhere near a
    // fully-rounded capsule for a control of this height.
    final radius = (decoration.borderRadius as BorderRadius).topLeft;
    expect(radius.x, lessThanOrEqualTo(8.0));
    expect(radius.x, greaterThanOrEqualTo(6.0));
  });

  testWidgets('9. switching language from the login screen works', (
    tester,
  ) async {
    await _pumpLoginScreen(tester, platformBrightness: Brightness.light);

    expect(find.text('Karibu Umoja'), findsOneWidget);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Umoja'), findsOneWidget);
  });

  testWidgets(
    'prompt 05E-D: the focused phone field border resolves to the exact '
    'same UmojaColors.primary as the Log In button, in both themes — '
    'never a separate pink/accent token',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        final theme = Theme.of(tester.element(find.byType(Scaffold).first));
        final focusedBorder =
            theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;

        expect(
          focusedBorder.borderSide.color,
          UmojaColors.primary,
          reason: 'brightness=$brightness',
        );
        expect(theme.colorScheme.primary, UmojaColors.primary);
      }
    },
  );

  testWidgets(
    'prompt 05E-D: the first (default-active) PIN box border resolves '
    'to UmojaColors.primary in both themes',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        // Box 0 is "active" by construction whenever the field is
        // empty (index == current length == 0) — no real focus
        // interaction needed to observe this state.
        final firstBox = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .first;
        final decoration = firstBox.decoration as BoxDecoration;
        final border = decoration.border as Border;

        expect(
          border.top.color,
          UmojaColors.primary,
          reason: 'brightness=$brightness',
        );
      }
    },
  );

  testWidgets(
    'prompt 05E-E: "Umesahau PIN?" and "Mara ya kwanza..." action links '
    'are neutral (onSurface, matching "Karibu Umoja") — a deliberate, '
    'narrowly-scoped exception to the textButtonTheme default, which '
    'stays primary-colored for other auth TextButtons (Cancel/Resend)',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        final theme = Theme.of(tester.element(find.byType(Scaffold).first));

        for (final label in [
          'Umesahau PIN?',
          'Mara ya kwanza? Thibitisha namba kwa OTP',
        ]) {
          final button = tester.widget<TextButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(TextButton),
            ),
          );
          final foreground = button.style?.foregroundColor?.resolve({});

          expect(
            foreground,
            theme.colorScheme.onSurface,
            reason: 'brightness=$brightness, label=$label',
          );
        }

        // The theme-wide TextButton default is unaffected — it's an
        // inline override on these two widgets only, not a
        // `textButtonTheme` change (still primary, for OTP screens'
        // Cancel/Resend etc.).
        expect(
          theme.textButtonTheme.style?.foregroundColor?.resolve({}),
          UmojaColors.primary,
          reason: 'brightness=$brightness',
        );
      }
    },
  );

  testWidgets('prompt 05E-D: the primary Log In button background is exactly '
      'UmojaColors.primary in both themes', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await _pumpLoginScreen(tester, platformBrightness: brightness);

      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      final buttonBackground = theme.filledButtonTheme.style?.backgroundColor
          ?.resolve({});

      expect(
        buttonBackground,
        UmojaColors.primary,
        reason: 'brightness=$brightness',
      );
    }
  });

  testWidgets(
    'prompt 05E-D: the unfocused/enabled input border stays a neutral '
    'outline token, never the brand primary color',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        final theme = Theme.of(tester.element(find.byType(Scaffold).first));
        final enabledBorder =
            theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;

        expect(
          enabledBorder.borderSide.color,
          theme.colorScheme.outlineVariant,
          reason: 'brightness=$brightness',
        );
        expect(
          enabledBorder.borderSide.color,
          isNot(UmojaColors.primary),
          reason: 'brightness=$brightness',
        );
      }
    },
  );

  testWidgets('prompt 05E-D: the error input border uses the semantic error '
      'token, never the brand primary color', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await _pumpLoginScreen(tester, platformBrightness: brightness);

      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      final errorBorder =
          theme.inputDecorationTheme.errorBorder as OutlineInputBorder;

      expect(errorBorder.borderSide.color, theme.colorScheme.error);
      expect(
        errorBorder.borderSide.color,
        isNot(UmojaColors.primary),
        reason: 'brightness=$brightness',
      );
    }
  });

  testWidgets(
    'prompt 05E-E: the language switcher never fills a segment with a '
    'background — its background always matches the page it sits on — '
    'and the selected language is indicated by primary-colored, bold '
    'text instead',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpLoginScreen(tester, platformBrightness: brightness);

        final theme = Theme.of(tester.element(find.byType(Scaffold).first));

        final materials = tester.widgetList<Material>(
          find.descendant(
            of: find.byType(UmojaLanguageSelector),
            matching: find.byType(Material),
          ),
        );
        for (final material in materials) {
          expect(
            material.color,
            Colors.transparent,
            reason: 'brightness=$brightness — no segment fill',
          );
        }

        // "SW" is selected by default (Swahili) — bold + primary red;
        // "EN" is unselected — regular weight + the neutral muted token.
        final swText = tester.widget<Text>(find.text('SW'));
        final enText = tester.widget<Text>(find.text('EN'));

        expect(swText.style?.color, theme.colorScheme.primary);
        expect(swText.style?.fontWeight, FontWeight.w700);
        expect(enText.style?.color, theme.colorScheme.onSurfaceVariant);
        expect(enText.style?.fontWeight, FontWeight.w500);
      }
    },
  );

  testWidgets(
    'prompt 05E-D: light and dark themes share one Umoja brand primary '
    'identity — UmojaTheme.light and UmojaTheme.dark resolve to the '
    'exact same colorScheme.primary',
    (tester) async {
      expect(UmojaTheme.light.colorScheme.primary, UmojaColors.primary);
      expect(UmojaTheme.dark.colorScheme.primary, UmojaColors.primary);
      expect(
        UmojaTheme.light.colorScheme.primary,
        UmojaTheme.dark.colorScheme.primary,
      );
    },
  );

  testWidgets(
    '11. login phone + PIN fields and buttons still render and accept '
    'input after the theme/switcher changes (auth functionality '
    'unchanged — see account_switch_pin_cycle_test.dart for the full '
    'pin-login regression suite)',
    (tester) async {
      await _pumpLoginScreen(tester, platformBrightness: Brightness.dark);

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Ingia'), findsOneWidget);
      expect(find.text('Umesahau PIN?'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '0712345678');
      await tester.pump();
      expect(find.text('0712345678'), findsWidgets);
    },
  );
}
