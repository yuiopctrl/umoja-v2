import 'package:flutter/material.dart';

/// Renders Umoja's official brand artwork — never recreated with the
/// Ubuntu UI font or redrawn, never manually reconstructed when an
/// official pre-combined asset already exists for the context (prompt
/// 05F — officially supplied `umoja_combined.png`/`umoja_sidebar.png`
/// replaced the earlier `Row(symbol, wordmark)` composition this
/// widget used to build itself).
///
/// - [UmojaBrandMark.symbol] — the umbrella/people mark alone. Use for
///   compact contexts: a collapsed `NavigationRail`, and any small
///   brand touch-point. (The app launcher icon / favicon are generated
///   separately by `flutter_launcher_icons` from `umoja_mark.png`
///   directly — see `pubspec.yaml` — not rendered through this
///   widget.)
/// - [UmojaBrandMark.wordmark] — the custom "UMOJA" wordmark alone.
/// - [UmojaBrandMark.combined] — the official vertical (symbol above
///   wordmark) lockup artwork. Use for auth/login branding.
/// - [UmojaBrandMark.sidebarLockup] — the official horizontal (symbol
///   beside wordmark) lockup artwork. Use for the expanded desktop
///   sidebar.
///
/// Renders the `_trim` derivative of each source file (prompt 05D
/// §16-17, extended in 05F to the newer combined/sidebar assets): the
/// supplied PNGs carry a transparent margin baked into their canvas,
/// which, left in, makes a layout read as oddly overspaced no matter
/// how tight the explicit spacing around it is set. The `_trim` files
/// are the identical artwork cropped to its own opaque bounding box
/// (plus a few native pixels of margin) — never stretched, never
/// cutting into actual glyph pixels — generated once from the
/// authoritative originals, which remain untouched in
/// `assets/branding/` for provenance (and, for `umoja_mark.png`
/// specifically, for app-icon generation).
class UmojaBrandMark extends StatelessWidget {
  const UmojaBrandMark.symbol({super.key, this.size = 40})
    : _layout = _UmojaBrandLayout.symbol,
      wordmarkHeight = null;

  const UmojaBrandMark.wordmark({super.key, this.wordmarkHeight = 32})
    : _layout = _UmojaBrandLayout.wordmark,
      size = null;

  const UmojaBrandMark.combined({super.key, this.wordmarkHeight = 96})
    : _layout = _UmojaBrandLayout.combined,
      size = null;

  const UmojaBrandMark.sidebarLockup({super.key, this.wordmarkHeight = 44})
    : _layout = _UmojaBrandLayout.sidebarLockup,
      size = null;

  final _UmojaBrandLayout _layout;

  /// Symbol edge length (`symbol` layout only).
  final double? size;

  /// Render height (`wordmark`/`combined`/`sidebarLockup` layouts) —
  /// width follows automatically from the artwork's own aspect ratio.
  final double? wordmarkHeight;

  static const _iconAsset = 'assets/branding/umoja_icon_trim.png';
  static const _wordmarkAsset = 'assets/branding/umoja_wordmark_trim.png';
  static const _combinedAsset = 'assets/branding/umoja_combined_trim.png';
  static const _sidebarAsset = 'assets/branding/umoja_sidebar_trim.png';

  @override
  Widget build(BuildContext context) {
    switch (_layout) {
      case _UmojaBrandLayout.symbol:
        return Image.asset(_iconAsset, width: size, height: size);
      case _UmojaBrandLayout.wordmark:
        return Image.asset(_wordmarkAsset, height: wordmarkHeight);
      case _UmojaBrandLayout.combined:
        return Image.asset(_combinedAsset, height: wordmarkHeight);
      case _UmojaBrandLayout.sidebarLockup:
        return Image.asset(_sidebarAsset, height: wordmarkHeight);
    }
  }
}

enum _UmojaBrandLayout { symbol, wordmark, combined, sidebarLockup }
