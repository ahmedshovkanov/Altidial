import 'package:flutter/animation.dart';

/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// Corner radii.
abstract final class AppRadii {
  static const double chip = 12;
  static const double control = 16;
  static const double card = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Animation durations and curves. All durations drop to zero when the system
/// asks for reduced motion; callers check `MediaQuery.disableAnimationsOf`.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Standard ease for sweeps, fades and slides.
  static const Curve standard = Curves.easeOutCubic;

  /// Slight overshoot for pops and the dial resize.
  static const Curve pop = Curves.easeOutBack;
}
