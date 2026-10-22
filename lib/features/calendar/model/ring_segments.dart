import 'dart:math' as math;

import 'package:altidial/core/tone.dart';

/// One tone's arc of a day ring. Angles are in radians, clockwise, measured
/// from the positive x axis as Flutter's canvas does, so a ring that starts at
/// the top starts at -pi/2.
class RingSegment {
  const RingSegment(this.tone, this.startAngle, this.sweepAngle);

  final Tone tone;
  final double startAngle;
  final double sweepAngle;

  @override
  bool operator ==(Object other) =>
      other is RingSegment &&
      other.tone == tone &&
      other.startAngle == startAngle &&
      other.sweepAngle == sweepAngle;

  @override
  int get hashCode => Object.hash(tone, startAngle, sweepAngle);

  @override
  String toString() => 'RingSegment($tone, $startAngle, $sweepAngle)';
}

/// Splits a full circle between the tones in proportion to [minutes], in the
/// fixed tone order, starting at the top. Tones with no minutes are left out,
/// and a day with none at all has no segments.
///
/// One tone alone is a full circle. Otherwise each arc is followed by a [gap]
/// (radians) so neighbours never touch, and an arc is never shorter than
/// [minSweep], so a sliver of one tone is still visible; the arcs are scaled
/// so that arcs and gaps together fill the circle exactly.
List<RingSegment> ringSegments(
  Map<Tone, int> minutes, {
  double gap = 0.2,
  double minSweep = 0.25,
}) {
  const full = 2 * math.pi;
  const top = -math.pi / 2;

  final present = [
    for (final tone in Tone.values)
      if ((minutes[tone] ?? 0) > 0) tone,
  ];
  if (present.isEmpty) return const [];
  if (present.length == 1) return [RingSegment(present.single, top, full)];

  final total = present.fold<int>(0, (sum, tone) => sum + minutes[tone]!);
  final room = full - present.length * gap;
  final raw = [
    for (final tone in present)
      math.max(minSweep, room * minutes[tone]! / total),
  ];
  final scale = room / raw.fold<double>(0, (sum, sweep) => sum + sweep);

  final segments = <RingSegment>[];
  var angle = top + gap / 2;
  for (var i = 0; i < present.length; i++) {
    final sweep = raw[i] * scale;
    segments.add(RingSegment(present[i], angle, sweep));
    angle += sweep + gap;
  }
  return segments;
}
