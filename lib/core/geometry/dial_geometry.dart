import 'dart:math' as math;
import 'dart:ui';

import 'package:altidial/core/time/day_time.dart';

/// Pure polar math for the 24-hour dial. Deliberately free of any rendering
/// dependency beyond [Offset] so it can be unit-tested directly — testing
/// math is trivial where testing a painter is not.
class DialGeometry {
  const DialGeometry({
    required this.center,
    required this.faceRadius,
    required this.firstRingInset,
    required this.ringWidth,
    required this.ringGap,
    this.ringCount = maxRings,
    this.hitSlop = 0,
  });

  /// Overlapping events beyond this many rings are refused.
  static const int maxRings = 3;

  /// How far a touch may miss a ring or the creation band and still count, in
  /// logical pixels. [fitted] uses this; hand-built geometries default to 0.
  static const double defaultHitSlop = 12;

  static const double _quarterTurn = math.pi / 2;
  static const double _fullTurn = math.pi * 2;

  final Offset center;

  /// Radius of the clock face itself.
  final double faceRadius;

  /// Gap between the face edge and the inner edge of ring 0.
  final double firstRingInset;

  /// Thickness of each event ring.
  final double ringWidth;

  /// Gap between adjacent rings.
  final double ringGap;

  /// How many rings this geometry has room for, 1 to [maxRings]. [fitted]
  /// sizes the face to leave exactly this many.
  final int ringCount;

  /// Extra reach on each side of every ring and of the creation band when hit
  /// testing. Where two rings' reach overlaps, the ring with the nearer centre
  /// wins.
  final double hitSlop;

  /// Radians for a minute of day, with minute 0 at the top and the day
  /// running clockwise.
  double angleForMinute(double minute) =>
      minute / minutesPerDay * _fullTurn - _quarterTurn;

  /// Inverse of [angleForMinute], normalised into 0–1439.
  int minuteForAngle(double angle) {
    final normalised = (angle + _quarterTurn) % _fullTurn;
    final positive = normalised < 0 ? normalised + _fullTurn : normalised;
    final minute = (positive / _fullTurn * minutesPerDay).round();
    return minute % minutesPerDay;
  }

  /// The minute of day the dial points at for [point], 0–1439.
  int minuteAtPoint(Offset point) {
    final delta = point - center;
    return minuteForAngle(math.atan2(delta.dy, delta.dx));
  }

  double radiusAtPoint(Offset point) => (point - center).distance;

  /// Inner edge of ring 0.
  double get orbitInnerRadius => faceRadius + firstRingInset;

  /// Outer edge of the outermost ring. For a geometry built by [fitted] this
  /// is the dial's outer radius, whatever the ring count.
  double get orbitOuterRadius =>
      ringCenterRadius(ringCount - 1) + ringWidth / 2;

  /// Centreline radius of ring [index], counting outward from 0.
  double ringCenterRadius(int index) =>
      orbitInnerRadius + ringWidth / 2 + index * (ringWidth + ringGap);

  /// The ring nearest [point], or null when the point is further than half a
  /// ring width plus [hitSlop] from every ring's centreline.
  int? ringAtPoint(Offset point) {
    final radius = radiusAtPoint(point);
    int? best;
    var bestDistance = double.infinity;
    for (var index = 0; index < ringCount; index++) {
      final distance = (radius - ringCenterRadius(index)).abs();
      if (distance <= ringWidth / 2 + hitSlop && distance < bestDistance) {
        best = index;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// True anywhere in the orbit band, gaps and slop included. This is the area
  /// that accepts a drag-to-create gesture.
  bool isInOrbitBand(Offset point) {
    final radius = radiusAtPoint(point);
    return radius >= orbitInnerRadius - hitSlop &&
        radius <= orbitOuterRadius + hitSlop;
  }

  /// The point at [radius] and [angle] from [center].
  Offset pointOnCircle(double radius, double angle) => Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );

  /// True when a label centred at [angle] would render upside-down if drawn
  /// with the outward-facing orientation used on the top half of the dial.
  ///
  /// Text following the outside of a circle inverts once it passes the
  /// horizontal, so labels below the centre are drawn flipped instead.
  ///
  /// The 1e-9 tolerance matches this file's other closeTo comparisons: at
  /// exactly 1080 minutes (due west), angleForMinute lands on math.pi, whose
  /// double representation is not exactly π, so math.sin of it is a small
  /// positive epsilon (~1.2e-16) rather than the mathematically-true zero. A
  /// bare `> 0` would misclassify that exact boundary as inverted.
  bool isLabelInverted(double angle) => math.sin(angle) > 1e-9;

  /// Ring thickness as a fraction of the outer radius, by ring count. Fewer
  /// rings mean thicker arcs and a bigger face; three rings reproduces the
  /// original Phase 1 proportions.
  static const Map<int, double> _ringWidthFactor = {1: 0.15, 2: 0.13, 3: 0.11};

  /// Derives every radius from the available box so the dial scales across
  /// screens from one source of truth. [ringCount] is how many rings are in
  /// use: the face takes whatever room the other rings leave. [maxRadius]
  /// caps the dial on very large windows; the dial stays centred in [size].
  static DialGeometry fitted(
    Size size, {
    int ringCount = maxRings,
    double? maxRadius,
    double hitSlop = defaultHitSlop,
  }) {
    assert(
      ringCount >= 1 && ringCount <= maxRings,
      'ringCount must be between 1 and $maxRings',
    );
    final available = size.shortestSide / 2 - 8;
    final outerRadius = maxRadius == null
        ? available
        : math.min(available, maxRadius);
    final ringWidth = outerRadius * _ringWidthFactor[ringCount]!;
    final ringGap = outerRadius * 0.018;
    final firstRingInset = outerRadius * 0.045;
    final faceRadius =
        outerRadius -
        firstRingInset -
        ringCount * ringWidth -
        (ringCount - 1) * ringGap;

    return DialGeometry(
      center: Offset(size.width / 2, size.height / 2),
      faceRadius: faceRadius,
      firstRingInset: firstRingInset,
      ringWidth: ringWidth,
      ringGap: ringGap,
      ringCount: ringCount,
      hitSlop: hitSlop,
    );
  }

  /// Blends two geometries for the resize animation. The result keeps [b]'s
  /// ring count, because hit testing always uses the target geometry.
  static DialGeometry lerp(DialGeometry a, DialGeometry b, double t) {
    return DialGeometry(
      center: Offset.lerp(a.center, b.center, t)!,
      faceRadius: lerpDouble(a.faceRadius, b.faceRadius, t)!,
      firstRingInset: lerpDouble(a.firstRingInset, b.firstRingInset, t)!,
      ringWidth: lerpDouble(a.ringWidth, b.ringWidth, t)!,
      ringGap: lerpDouble(a.ringGap, b.ringGap, t)!,
      ringCount: b.ringCount,
      hitSlop: lerpDouble(a.hitSlop, b.hitSlop, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DialGeometry &&
      other.center == center &&
      other.faceRadius == faceRadius &&
      other.firstRingInset == firstRingInset &&
      other.ringWidth == ringWidth &&
      other.ringGap == ringGap &&
      other.ringCount == ringCount &&
      other.hitSlop == hitSlop;

  @override
  int get hashCode => Object.hash(
    center,
    faceRadius,
    firstRingInset,
    ringWidth,
    ringGap,
    ringCount,
    hitSlop,
  );
}
