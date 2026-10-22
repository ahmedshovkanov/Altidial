import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:flutter/material.dart';

/// Paints the outer progress ring: an arc from the top that fills on the
/// inhale and empties on the exhale. A [fraction] of 1 is a full circle.
class _OrbRingPainter extends CustomPainter {
  const _OrbRingPainter({
    required this.fraction,
    required this.thickness,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final double thickness;
  final Color color;
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
  bool shouldRepaint(_OrbRingPainter old) =>
      old.fraction != fraction ||
      old.thickness != thickness ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// The breathing guide: a scaling orb inside a progress ring. [fraction] is the
/// progress through the current phase, so the orb grows through an inhale and
/// shrinks through an exhale. When [inSync] is false the accent dims to signal
/// a gentle correction; under [reduceMotion] the scale tween and glow are
/// dropped while the ring still shows progress.
class BreathingOrb extends StatelessWidget {
  const BreathingOrb({
    required this.diameter,
    required this.phase,
    required this.fraction,
    required this.secondsLeft,
    required this.label,
    required this.inSync,
    required this.reduceMotion,
    super.key,
  });

  final double diameter;
  final BreathPhase phase;
  final double fraction;
  final int secondsLeft;
  final String label;
  final bool inSync;
  final bool reduceMotion;

  static const double _minScale = 0.55;
  static const double _maxScale = 1.0;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = context.toneColors.focus;

    final ringFraction = phase == BreathPhase.inhale
        ? fraction
        : 1 - fraction;
    final scale = reduceMotion
        ? (phase == BreathPhase.inhale ? _maxScale : _minScale)
        : (phase == BreathPhase.inhale
              ? _lerp(_minScale, _maxScale, fraction)
              : _lerp(_maxScale, _minScale, fraction));

    final accent = inSync ? tone.solid : colors.muted;
    final orbSize = diameter * 0.6 * scale;
    final glow = !reduceMotion && inSync
        ? <BoxShadow>[
            BoxShadow(
              color: tone.solid.withValues(alpha: 0.32 * scale),
              blurRadius: 40 * scale,
              spreadRadius: 4 * scale,
            ),
          ]
        : const <BoxShadow>[];

    return SizedBox.square(
      dimension: diameter,
      child: CustomPaint(
        painter: _OrbRingPainter(
          fraction: ringFraction,
          thickness: diameter * 0.045,
          color: accent,
          trackColor: colors.outline,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: inSync ? tone.soft : colors.page,
                  border: Border.all(color: accent, width: 3),
                  boxShadow: glow,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(color: colors.muted),
                  ),
                  Text(
                    '$secondsLeft',
                    style: AppTypography.sessionTime(diameter * 0.15)
                        .copyWith(color: accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
