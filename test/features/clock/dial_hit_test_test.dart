import 'dart:math' as math;

import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_hit_test.dart';
import 'package:flutter_test/flutter_test.dart';

const geometry = DialGeometry(
  center: Offset(100, 100),
  faceRadius: 100,
  firstRingInset: 8,
  ringWidth: 20,
  ringGap: 4,
);

CalendarEvent event(int id, MinuteRange range) => CalendarEvent(
  id: id,
  seriesId: null,
  date: DateTime(2026, 8, 23),
  title: 'Event $id',
  tone: Tone.focus,
  range: range,
  status: EventStatus.planned,
);

/// A point on the centreline of [ring] at [minute].
Offset pointAt(int minute, int ring) {
  final angle = geometry.angleForMinute(minute.toDouble());
  final radius = geometry.ringCenterRadius(ring);
  return Offset(
    geometry.center.dx + radius * math.cos(angle),
    geometry.center.dy + radius * math.sin(angle),
  );
}

void main() {
  final events = [
    event(1, const MinuteRange(540, 720)),
    event(2, const MinuteRange(600, 660)),
  ];
  const rings = {1: 0, 2: 1};

  test('finds the event under a point on its ring', () {
    final hit = eventAtPoint(
      point: pointAt(600, 0),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit?.id, 1);
  });

  test('distinguishes rings at the same minute', () {
    final hit = eventAtPoint(
      point: pointAt(620, 1),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit?.id, 2);
  });

  test('returns null outside every event', () {
    final hit = eventAtPoint(
      point: pointAt(200, 0),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit, isNull);
  });

  test('returns null on the face itself', () {
    final hit = eventAtPoint(
      point: const Offset(100, 100),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit, isNull);
  });

  test('the exclusive end minute is not a hit', () {
    final hit = eventAtPoint(
      point: pointAt(720, 0),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit, isNull);
  });
}
