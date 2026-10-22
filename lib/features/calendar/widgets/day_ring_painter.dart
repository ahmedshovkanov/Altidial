import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/model/ring_segments.dart';
import 'package:flutter/rendering.dart';

/// Paints one day's tone ring: a thin rounded arc per tone in its colour, or a
/// faint full circle in [emptyColor] when the day has no events.
class DayRingPainter extends CustomPainter {
  const DayRingPainter({
    required this.segments,
    required this.colors,
    required this.emptyColor,
    required this.strokeWidth,
  });

  final List<RingSegment> segments;

  /// The colour of each tone's arc.
  final Map<Tone, Color> colors;
  final Color emptyColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = size.center(Offset.zero);

    if (segments.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, strokeWidth / 2)
          ..color = emptyColor,
      );
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final segment in segments) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = colors[segment.tone]!;
      canvas.drawArc(
        rect,
        segment.startAngle,
        segment.sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DayRingPainter oldDelegate) =>
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.segments.length != segments.length ||
      !_sameSegments(oldDelegate.segments) ||
      !_sameColors(oldDelegate.colors);

  bool _sameSegments(List<RingSegment> other) {
    for (var i = 0; i < segments.length; i++) {
      if (other[i] != segments[i]) return false;
    }
    return true;
  }

  bool _sameColors(Map<Tone, Color> other) {
    for (final tone in Tone.values) {
      if (other[tone] != colors[tone]) return false;
    }
    return true;
  }
}
