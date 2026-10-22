import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The one typeface and the text styles built on it (spec §4.2). Colour is
/// applied by the theme or by the caller.
abstract final class AppTypography {
  static const String fontFamily = 'Nunito';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    FontWeight weight, {
    double? height,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      fontFeatures: features,
    );
  }

  /// The time in the dial centre. Scales with the dial, between 22 and 44.
  static TextStyle displayTime(double faceRadius) => _style(
    (0.22 * faceRadius).clamp(22.0, 44.0),
    FontWeight.w800,
    height: 1.1,
    features: _tabular,
  );

  /// The big countdown inside the session ring. [size] comes from the ring's
  /// diameter. Tabular figures, so the digits never jitter as they change.
  static TextStyle sessionTime(double size) =>
      _style(size, FontWeight.w800, height: 1.05, features: _tabular);

  /// Hour numerals around the dial.
  static TextStyle dialNumeral(double faceRadius) => _style(
    math.max(11.0, 0.13 * faceRadius),
    FontWeight.w800,
    height: 1,
    features: _tabular,
  );

  /// The curved title on an event arc.
  static TextStyle arcLabel(double ringWidth) =>
      _style(math.max(10.0, 0.5 * ringWidth), FontWeight.w800, height: 1);

  /// The Material text theme, mapped from the spec's styles:
  /// `titleLarge` 28/800, `titleMedium` 20/700, `titleSmall` 16/700 (strong
  /// body), `bodyMedium` 16/400, `bodySmall` 12/600 (caption), `labelLarge`
  /// 14/700.
  static TextTheme textTheme({required Color ink, required Color muted}) {
    TextStyle style(
      double size,
      FontWeight weight,
      Color color, {
      double? height,
    }) => _style(size, weight, height: height).copyWith(color: color);

    return TextTheme(
      displaySmall: style(34, FontWeight.w800, ink, height: 1.1),
      headlineSmall: style(28, FontWeight.w800, ink, height: 1.15),
      titleLarge: style(28, FontWeight.w800, ink, height: 1.15),
      titleMedium: style(20, FontWeight.w700, ink, height: 1.2),
      titleSmall: style(16, FontWeight.w700, ink, height: 1.25),
      bodyLarge: style(16, FontWeight.w400, ink, height: 1.3),
      bodyMedium: style(16, FontWeight.w400, ink, height: 1.3),
      bodySmall: style(12, FontWeight.w600, muted, height: 1.25),
      labelLarge: style(14, FontWeight.w700, ink, height: 1.2),
      labelMedium: style(12, FontWeight.w600, muted, height: 1.2),
      labelSmall: style(11, FontWeight.w600, muted, height: 1.2),
    );
  }
}
