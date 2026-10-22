import 'dart:math' as math;

import 'package:altidial/shared/layout/window_class.dart';
import 'package:flutter/painting.dart';

/// How the session screen is arranged for a window. Unlike the Clock page, the
/// session screen scrolls when it must, so these numbers only choose the ring
/// size and whether the buttons stack; a wrong guess can never overflow.
class SessionLayoutPlan {
  const SessionLayoutPlan({
    required this.wide,
    required this.stackedControls,
    required this.ringDiameter,
  });

  /// Text scale above which the buttons stack one to a row.
  static const double stackedControlsTextScale = 1.15;

  /// The smallest ring. Below this the screen scrolls instead of shrinking it.
  static const double minRing = 200;

  /// The largest ring on a phone or a medium window.
  static const double maxRing = 360;

  /// The largest ring on a wide window.
  static const double maxWideRing = 520;

  /// Two panes: the ring on the left, the details and buttons on the right.
  final bool wide;

  /// One button per row, for large text.
  final bool stackedControls;

  final double ringDiameter;

  /// Chooses the layout for a body of [size], with [inset] of its bottom
  /// covered by the floating tab bar. [bannerVisible] and [recovering] say
  /// whether the taller cards are showing.
  factory SessionLayoutPlan.forSize(
    Size size, {
    required double inset,
    required double textScale,
    required WindowClass windowClass,
    required bool bannerVisible,
    required bool recovering,
  }) {
    final stacked = textScale > stackedControlsTextScale;
    final available = size.height - inset;

    if (windowClass == WindowClass.wide) {
      const paneGap = 24.0;
      final paneWidth = (size.width * 0.36).clamp(340.0, 440.0);
      final left = size.width - paneWidth - 3 * paneGap;
      final ring = math.min(left, available - 2 * paneGap);
      return SessionLayoutPlan(
        wide: true,
        stackedControls: stacked,
        ringDiameter: ring.clamp(minRing, maxWideRing).toDouble(),
      );
    }

    // Generous estimates, at normal text size, of what sits around the ring.
    final header = 49 + 80 * textScale;
    final footer = 20 * textScale;
    final controls = recovering
        ? 260 + 40 * textScale
        : stacked
        ? 248.0
        : 120.0;
    final banner = bannerVisible ? 150 + 30 * textScale : 0;
    const gaps = 4 * 16.0;
    final room = available - header - footer - controls - banner - gaps;
    final widest = math.min(size.width - 48, maxRing);
    return SessionLayoutPlan(
      wide: false,
      stackedControls: stacked,
      ringDiameter: room.clamp(minRing, math.max(minRing, widest)).toDouble(),
    );
  }
}
