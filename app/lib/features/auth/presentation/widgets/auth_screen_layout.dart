import 'package:flutter/material.dart';

import '../../../../core/branding/umoja_brand_mark.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/theme/umoja_theme.dart';
import '../../../../core/widgets/umoja_language_selector.dart';

/// Shared layout for the phone-entry, OTP-verify, and PIN screens: a
/// consistent, prominent Umoja brand header — sized so the screen
/// reads as clearly branded, not a tiny icon above a generic form
/// (prompt 05B §2) — followed by screen-specific content, constrained
/// to a comfortable reading width on every platform (~440px, mobile
/// and desktop alike).
///
/// The header uses [UmojaBrandMark.combined] — the official supplied
/// vertical (symbol-above-wordmark) lockup artwork (prompt 05F) —
/// rather than manually composing symbol and wordmark.
///
/// Prompt 05E-A §7: content sits in a balanced upper-middle column —
/// a smaller gap above and a larger one below (roughly 2:3), inside a
/// scrollable so the keyboard opening on a PIN/OTP field never
/// overflows — rather than either pinned to the very top (leaves a
/// large dead zone below on a tall phone) or exactly centered in the
/// full viewport (looks awkward, and centers dangerously low once the
/// keyboard is open).
///
/// The gaps are sized as a fraction of the available viewport
/// (`LayoutBuilder`), clamped to sane min/max bounds, rather than
/// `Spacer`s inside an `IntrinsicHeight` — this app's `UmojaCodeInput`
/// (used by every screen built on this layout) has its own internal
/// `LayoutBuilder` for adaptive box sizing, and `IntrinsicHeight`
/// cannot coexist with a descendant `LayoutBuilder` ("LayoutBuilder
/// does not support returning intrinsic dimensions"). A plain
/// `mainAxisSize.min` `Column` of fixed-size children (the two gap
/// `SizedBox`es included) avoids that entirely: it never queries
/// intrinsic dimensions, and on a short viewport or with the keyboard
/// open it simply grows past the computed gaps and the
/// `SingleChildScrollView` scrolls, exactly as before.
///
/// Prompt 05E-A §8: forced to the light Umoja theme regardless of
/// system brightness — dark mode exists as a token-derived fallback
/// (see `UmojaTheme.dark`) but has not received the same manual
/// polish, so auth screens must never silently inherit it.
class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({
    super.key,
    required this.children,
    this.showLanguageSelector = true,
    this.onBack,
  });

  final List<Widget> children;

  /// Only the phone-entry screen needs this — the language choice is
  /// made before OTP verify is reached, and is otherwise available from
  /// More once signed in.
  final bool showLanguageSelector;

  /// When set, shows a visible top-left back arrow AND intercepts the
  /// Android system Back button/gesture to call the same callback
  /// (prompt 05C §18/§22 — "the system Back gesture/button should
  /// follow the same intended route" as the visible arrow) instead of
  /// the default pop, which could land on an unrelated/blank route
  /// depending on how this screen was reached (`context.go` replaces
  /// history, so a bare pop is not reliable here). `null` (the default)
  /// preserves the original behavior for screens that never had a back
  /// option (phone entry, OTP verify, first-time PIN setup/unlock).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;

    final scaffold = Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Roughly a 2:3 upper/lower balance, clamped so a very
                // short viewport (or the keyboard eating half the
                // screen) still reserves enough room below the
                // top-left back arrow/language selector overlay, and a
                // very tall one doesn't push content implausibly low.
                final topGap = (constraints.maxHeight * 0.09).clamp(
                  56.0,
                  110.0,
                );
                final bottomGap = (constraints.maxHeight * 0.14).clamp(
                  UmojaSpacing.xxxl,
                  160.0,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UmojaSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topGap),
                          const Center(
                            child: UmojaBrandMark.combined(wordmarkHeight: 100),
                          ),
                          const SizedBox(height: UmojaSpacing.xxl),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          ),
                          SizedBox(height: bottomGap),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (showLanguageSelector)
              Positioned(
                top: UmojaSpacing.sm,
                right: UmojaSpacing.lg,
                child: const UmojaLanguageSelector(compact: true),
              ),
            if (onBack != null)
              Positioned(
                top: UmojaSpacing.sm,
                left: UmojaSpacing.sm,
                child: IconButton(
                  key: const Key('authScreenBackButton'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              ),
          ],
        ),
      ),
    );

    final themed = Theme(data: UmojaTheme.light, child: scaffold);

    if (onBack == null) return themed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: themed,
    );
  }
}
