import 'package:flutter/widgets.dart';

/// Scales typography and spacing up on tablets so an iPad reads as a
/// bigger interface rather than the phone layout stretched thin.
abstract final class Responsive {
  /// Shortest-side width at or above which we treat the device as a tablet.
  static const double tabletBreakpoint = 600;

  /// Multiplier applied to the type scale on tablets.
  static const double tabletScale = 1.25;

  static double scaleForShortestSide(double shortestSide) {
    return shortestSide >= tabletBreakpoint ? tabletScale : 1.0;
  }

  static double scaleOf(BuildContext context) {
    return scaleForShortestSide(MediaQuery.sizeOf(context).shortestSide);
  }

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
}
