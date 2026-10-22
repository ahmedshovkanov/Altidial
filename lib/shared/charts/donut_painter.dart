import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// Completed minutes for one tone.
typedef DonutSegment = ({Tone tone, int minutes});

/// Each segment's share of the whole circle; empty when there is nothing.
List<double> donutSweeps(List<DonutSegment> segments) {
  final total = segments.fold(0, (sum, segment) => sum + segment.minutes);
  if (total == 0) return const [];
  return [
    for (final segment in segments)
      if (segment.minutes > 0) segment.minutes / total,
  ];
}

/// A ring split into tone shares, starting at the top. An empty period shows
/// the track all the way round.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.segments,
    required this.colors,
    required this.trackColor,
    this.strokeWidth = 14,
  });

  final List<DonutSegment> segments;
  final Map<Tone, Color> colors;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
    final sweeps = donutSweeps(segments);
    var start = -math.pi / 2;
    var i = 0;
    for (final segment in segments) {
      if (segment.minutes == 0) continue;
      final sweep = sweeps[i];
      i++;
      canvas.drawArc(
        rect,
        start,
        sweep * math.pi * 2,
        false,
        paint..color = colors[segment.tone] ?? trackColor,
      );
      start += sweep * math.pi * 2;
    }
  }

  bool _segmentsEqual(List<DonutSegment> a, List<DonutSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tone != b[i].tone || a[i].minutes != b[i].minutes) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      !_segmentsEqual(oldDelegate.segments, segments) ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
