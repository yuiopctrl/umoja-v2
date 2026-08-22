import 'package:flutter/material.dart';

import '../../../../core/branding/umoja_brand_mark.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/widgets/umoja_language_selector.dart';

/// Shared layout for the phone-entry and OTP-verify screens: a
/// consistent, prominent Umoja brand header (symbol + wordmark) —
/// sized so the screen reads as clearly branded, not a tiny icon above
/// a generic form (prompt 05B §2) — followed by screen-specific
/// content, constrained to a comfortable reading width on every
/// platform (~440px, mobile and desktop alike).
///
/// Deliberately top-aligned with generous fixed spacing rather than
/// `Center`-ing in the full viewport — an exactly-centered form looks
/// awkward on a very tall phone screen.
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
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.xxl),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: UmojaSpacing.massive,
                      bottom: UmojaSpacing.xxxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: UmojaBrandMark.symbol(size: 84)),
                        // Prompt 05D §17: both `UmojaBrandMark` assets
                        // are now trimmed to their own artwork bounds,
                        // so this explicit gap is close to the actual
                        // visual gap (~4-8 logical px target) rather
                        // than stacking on top of a large baked-in
                        // transparent PNG margin.
                        const SizedBox(height: UmojaSpacing.xs),
                        Center(
                          child: UmojaBrandMark.wordmark(wordmarkHeight: 46),
                        ),
                        const SizedBox(height: UmojaSpacing.xxxl),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
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

    if (onBack == null) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: scaffold,
    );
  }
}
