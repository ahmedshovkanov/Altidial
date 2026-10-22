import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Draws a ring made of arcs, one per colour, with rounded ends and a gap
/// between them. Used for the Clock tab icon, the onboarding illustration, and
/// the generated app icon and launch logo.
class RingMarkPainter extends CustomPainter {
  const RingMarkPainter({
    required this.colors,
    this.progress = 1,
    this.strokeFraction = 0.2,
    this.gapRadians = 0.9,
  });

  /// One arc per colour, clockwise from the top.
  final List<Color> colors;

  /// 0 to 1: how much of each arc is drawn, for a sweep-in animation.
  final double progress;

  /// Stroke width as a fraction of the diameter.
  final double strokeFraction;

  /// Gap between neighbouring arcs, measured between their centrelines. Round
  /// caps eat into it, so keep it well above `strokeFraction * 2.5`.
  final double gapRadians;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final stroke = size.shortestSide * strokeFraction;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    final arc = (2 * math.pi - colors.length * gapRadians) / colors.length;
    for (var i = 0; i < colors.length; i++) {
      final start = -math.pi / 2 + i * (arc + gapRadians) + gapRadians / 2;
      canvas.drawArc(
        rect,
        start,
        arc * progress,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(RingMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeFraction != strokeFraction ||
      oldDelegate.gapRadians != gapRadians ||
      !_sameColors(oldDelegate.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A square [RingMarkPainter]. Decorative, so hidden from screen readers.
class RingMark extends StatelessWidget {
  const RingMark({
    required this.colors,
    required this.size,
    this.progress = 1,
    this.strokeFraction = 0.2,
    super.key,
  });

  final List<Color> colors;
  final double size;
  final double progress;
  final double strokeFraction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: RingMarkPainter(
          colors: colors,
          progress: progress,
          strokeFraction: strokeFraction,
        ),
      ),
    );
  }
}
