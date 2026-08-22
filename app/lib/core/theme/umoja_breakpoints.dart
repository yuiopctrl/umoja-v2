import 'umoja_spacing.dart';

/// Centralized responsive breakpoints, matching the app shell's
/// navigation behavior:
/// - narrow (< [mobile]): bottom navigation bar
/// - medium ([mobile]–[desktop)): [NavigationRail]
/// - wide (>= [desktop]): extended [NavigationRail]
class UmojaBreakpoints {
  const UmojaBreakpoints._();

  static const mobile = 700.0;
  static const desktop = 1200.0;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;

  /// Standard page horizontal padding for the given viewport width.
  static double horizontalPadding(double width) {
    return isMobile(width) ? UmojaSpacing.lg : UmojaSpacing.xxl;
  }
}
