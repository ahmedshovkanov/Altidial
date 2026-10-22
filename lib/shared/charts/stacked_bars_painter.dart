import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// One day's column: completed minutes per tone.
typedef ToneStack = Map<Tone, int>;

/// Each tone's share of the day total; all zero when the day is empty.
Map<Tone, double> stackFractions(ToneStack day) {
  final total = day.values.fold(0, (sum, minutes) => sum + minutes);
  return {
    for (final tone in Tone.values)
      tone: total == 0 ? 0 : (day[tone] ?? 0) / total,
  };
}

/// The horizontal slot per bar and the bar width inside it (clamped to 28).
({double slot, double barWidth}) stackGeometry(Size size, int barCount) {
  final slot = size.width / barCount;
  return (slot: slot, barWidth: math.min(slot - 8, 28).toDouble());
}

/// One vertical bar per day, tones stacked from the bottom in [Tone.values]
/// order, heights relative to the fullest day. Empty days show the track.
class StackedBarsPainter extends CustomPainter {
  StackedBarsPainter({
    required this.days,
    required this.colors,
    required this.trackColor,
    this.barRadius = 3,
  });

  final List<ToneStack> days;
  final Map<Tone, Color> colors;
  final Color trackColor;
  final double barRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final geometry = stackGeometry(size, days.length);
    final maxTotal = days.fold(
      0,
      (max, day) => math.max(max, day.values.fold(0, (sum, m) => sum + m)),
    );
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < days.length; i++) {
      final x = geometry.slot * i + (geometry.slot - geometry.barWidth) / 2;
      final full = Rect.fromLTWH(x, 0, geometry.barWidth, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(full, Radius.circular(barRadius)),
        paint..color = trackColor,
      );
      final total = days[i].values.fold(0, (sum, m) => sum + m);
      if (total == 0 || maxTotal == 0) continue;
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(full, Radius.circular(barRadius)),
      );
      var y = size.height;
      for (final tone in Tone.values) {
        final minutes = days[i][tone] ?? 0;
        if (minutes == 0) continue;
        final height = minutes / maxTotal * size.height;
        y -= height;
        canvas.drawRect(
          Rect.fromLTWH(x, y, geometry.barWidth, height),
          paint..color = colors[tone] ?? trackColor,
        );
      }
      canvas.restore();
    }
  }

  bool _stacksEqual(List<ToneStack> a, List<ToneStack> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      for (final tone in Tone.values) {
        if ((a[i][tone] ?? 0) != (b[i][tone] ?? 0)) return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant StackedBarsPainter oldDelegate) =>
      !_stacksEqual(oldDelegate.days, days) ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.barRadius != barRadius;
}
