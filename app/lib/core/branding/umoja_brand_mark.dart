import 'package:flutter/material.dart';

import '../theme/umoja_spacing.dart';

/// Renders Umoja's official brand artwork — never recreated with the
/// Ubuntu UI font or redrawn. Both source images are pre-cleaned,
/// genuinely-transparent PNGs (see docs/product/design-system.md).
///
/// - [UmojaBrandMark.symbol] — the umbrella/people mark alone. Use for
///   compact contexts: the app launcher icon source, favicon source,
///   a collapsed `NavigationRail`, and any small brand touch-point.
/// - [UmojaBrandMark.wordmark] — the custom "UMOJA" wordmark alone.
/// - [UmojaBrandMark.lockup] — symbol beside wordmark, for wider
///   contexts (auth branding, the expanded desktop sidebar). This is
///   the app's one symbol+wordmark composition — there is no separate
///   official combined lockup asset file, so every place that needs
///   symbol-and-wordmark-together (including the sidebar) uses this
///   same layout rather than each reconstructing its own.
///
/// Renders the `_trim` derivative of each source file (prompt 05D
/// §16-17): `umoja_mark.png`/`umoja_wordmark.png` carry a large
/// transparent margin baked into their canvas (safe-area padding for
/// the app-icon/favicon use, irrelevant here) which, left in, made
/// [wordmark]/[lockup] read as oddly overspaced no matter how tight
/// the explicit layout spacing was set. The `_trim` files are the
/// identical artwork cropped to its own opaque bounding box (plus a
/// few native pixels of margin) — never stretched, never cutting into
/// actual glyph pixels — generated once from the authoritative
/// originals, which remain untouched and are still what
/// `flutter_launcher_icons` reads for the actual app icon.
class UmojaBrandMark extends StatelessWidget {
  const UmojaBrandMark.symbol({super.key, this.size = 40})
    : _layout = _UmojaBrandLayout.symbol,
      wordmarkHeight = null;

  const UmojaBrandMark.wordmark({super.key, this.wordmarkHeight = 32})
    : _layout = _UmojaBrandLayout.wordmark,
      size = null;

  const UmojaBrandMark.lockup({
    super.key,
    this.size = 32,
    this.wordmarkHeight = 26,
  }) : _layout = _UmojaBrandLayout.lockup;

  final _UmojaBrandLayout _layout;

  /// Symbol edge length (`symbol`/`lockup` layouts).
  final double? size;

  /// Wordmark render height (`wordmark`/`lockup` layouts) — width
  /// follows automatically from the artwork's own aspect ratio.
  final double? wordmarkHeight;

  static const _markAsset = 'assets/branding/umoja_mark_trim.png';
  static const _wordmarkAsset = 'assets/branding/umoja_wordmark_trim.png';

  /// The visual gap between symbol and wordmark in [lockup] — small
  /// now that both assets are trimmed to their own artwork bounds
  /// (prompt 05D §17 target: ~4-8 logical px).
  static const _lockupGap = UmojaSpacing.xs;

  @override
  Widget build(BuildContext context) {
    switch (_layout) {
      case _UmojaBrandLayout.symbol:
        return Image.asset(_markAsset, width: size, height: size);
      case _UmojaBrandLayout.wordmark:
        return Image.asset(_wordmarkAsset, height: wordmarkHeight);
      case _UmojaBrandLayout.lockup:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(_markAsset, width: size, height: size),
            const SizedBox(width: _lockupGap),
            Image.asset(_wordmarkAsset, height: wordmarkHeight),
          ],
        );
    }
  }
}

enum _UmojaBrandLayout { symbol, wordmark, lockup }
