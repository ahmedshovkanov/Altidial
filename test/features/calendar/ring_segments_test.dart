import 'dart:math' as math;

import 'package:altidial/core/tone.dart';
import 'package:altidial/features/calendar/model/ring_segments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = 2 * math.pi;
  const top = -math.pi / 2;

  test('a day with no minutes has no segments', () {
    expect(ringSegments(const {}), isEmpty);
    expect(ringSegments({Tone.focus: 0, Tone.life: 0}), isEmpty);
  });

  test('one tone alone is a full circle from the top, with no gap', () {
    final segments = ringSegments({Tone.life: 90});

    expect(segments, hasLength(1));
    expect(segments.single.tone, Tone.life);
    expect(segments.single.startAngle, top);
    expect(segments.single.sweepAngle, full);
  });

  test('a tone with no minutes is left out', () {
    final segments = ringSegments({
      Tone.focus: 60,
      Tone.life: 0,
      Tone.inbox: 60,
    });
    expect(segments.map((segment) => segment.tone), [Tone.focus, Tone.inbox]);
  });

  test('segments follow the fixed tone order, whatever the map order', () {
    final segments = ringSegments({
      Tone.inbox: 30,
      Tone.life: 30,
      Tone.focus: 30,
    });
    expect(segments.map((segment) => segment.tone), Tone.values);
  });

  test('sweeps are proportional to the minutes', () {
    final segments = ringSegments({Tone.focus: 120, Tone.life: 60}, gap: 0.2);

    // 120 and 60 minutes share the circle minus two gaps, two to one.
    expect(segments[0].sweepAngle / segments[1].sweepAngle, closeTo(2, 1e-9));
  });

  test('segments and gaps together fill the circle exactly', () {
    for (final minutes in [
      {Tone.focus: 100, Tone.life: 50},
      {Tone.focus: 100, Tone.life: 50, Tone.inbox: 25},
      {Tone.focus: 1000, Tone.life: 1, Tone.inbox: 1},
    ]) {
      final segments = ringSegments(minutes, gap: 0.3);
      final swept = segments.fold<double>(0, (sum, s) => sum + s.sweepAngle);
      expect(swept + segments.length * 0.3, closeTo(full, 1e-9));
    }
  });

  test('the first segment starts half a gap past the top', () {
    final segments = ringSegments({Tone.focus: 60, Tone.life: 60}, gap: 0.4);
    expect(segments.first.startAngle, closeTo(top + 0.2, 1e-9));
  });

  test('each segment starts one gap after the previous one ends', () {
    final segments = ringSegments({
      Tone.focus: 60,
      Tone.life: 30,
      Tone.inbox: 30,
    }, gap: 0.25);

    for (var i = 1; i < segments.length; i++) {
      final previousEnd =
          segments[i - 1].startAngle + segments[i - 1].sweepAngle;
      expect(segments[i].startAngle, closeTo(previousEnd + 0.25, 1e-9));
    }
  });

  test('a sliver of the day still gets a visible arc', () {
    final segments = ringSegments({Tone.focus: 1000, Tone.inbox: 1});

    expect(segments.last.tone, Tone.inbox);
    expect(segments.last.sweepAngle, greaterThan(0.2));
  });

  test('segments compare by value', () {
    expect(
      const RingSegment(Tone.focus, 0, 1),
      const RingSegment(Tone.focus, 0, 1),
    );
    expect(
      const RingSegment(Tone.focus, 0, 1),
      isNot(const RingSegment(Tone.life, 0, 1)),
    );
    expect(
      const RingSegment(Tone.focus, 0, 1).hashCode,
      const RingSegment(Tone.focus, 0, 1).hashCode,
    );
  });
}
