import 'package:flutter/widgets.dart';

/// Centralized, restrained corner radii. Umoja avoids pill-shaped
/// surfaces everywhere — radius communicates a surface's role
/// (control vs. card vs. sheet), not decoration.
class UmojaRadius {
  const UmojaRadius._();

  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;

  /// Buttons and input fields.
  static const control = 12.0;

  /// Cards and content surfaces.
  static const card = 14.0;

  static const smallAll = BorderRadius.all(Radius.circular(small));
  static const mediumAll = BorderRadius.all(Radius.circular(medium));
  static const largeAll = BorderRadius.all(Radius.circular(large));
  static const controlAll = BorderRadius.all(Radius.circular(control));
  static const cardAll = BorderRadius.all(Radius.circular(card));
}
