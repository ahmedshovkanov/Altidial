import 'dart:math' as math;

import 'package:altidial/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// A ring that empties clockwise as time runs out. It starts full at the top.
/// A [fraction] of 1 is a full circle and 0 is nothing but the track.
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({
    required this.fraction,
    required this.thickness,
    required this.color,
    required this.trackColor,
  });

  /// How much of the ring is filled, 0 to 1.
  final double fraction;

  final double thickness;

  /// The filled part.
  final Color color;

  /// The empty part.
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = trackColor,
    );

    final filled = fraction.clamp(0.0, 1.0);
    if (filled <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (filled >= 1) {
      canvas.drawCircle(center, radius, paint);
    } else {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * filled, false, paint);
    }
  }

  @override
  bool shouldRepaint(CountdownRingPainter old) =>
      old.fraction != fraction ||
      old.thickness != thickness ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// The session's countdown: a raised round face like the dial's, the ring
/// around its edge, and [child] in the middle.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.diameter,
    required this.fraction,
    required this.color,
    required this.child,
    this.semanticsLabel,
    super.key,
  });

  final double diameter;
  final double fraction;

  /// The filled part: the event's tone, or the danger colour in overtime.
  final Color color;

  final Widget child;
  final String? semanticsLabel;

  /// The ring's thickness for a face of [diameter].
  static double thicknessFor(double diameter) => diameter * 0.065;

  /// The width available for [child] inside the ring.
  static double innerWidthFor(double diameter) =>
      diameter - 2 * thicknessFor(diameter) - diameter * 0.12;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final thickness = thicknessFor(diameter);

    final ring = SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          boxShadow: colors.faceShadow,
          border: colors.isDark ? Border.all(color: colors.outline) : null,
        ),
        child: CustomPaint(
          painter: CountdownRingPainter(
            fraction: fraction,
            thickness: thickness,
            color: color,
            trackColor: colors.outline,
          ),
          child: Center(
            child: SizedBox(width: innerWidthFor(diameter), child: child),
          ),
        ),
      ),
    );

    if (semanticsLabel == null) return ring;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: ring,
    );
  }
}
