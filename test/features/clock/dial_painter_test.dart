import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/geometry/dial_geometry.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/widgets/dial_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const size = Size(390, 390);

CalendarEvent event(int id, MinuteRange range, Tone tone, {String title = ''}) {
  return CalendarEvent(
    id: id,
    seriesId: null,
    date: DateTime(2026, 8, 23),
    title: title,
    tone: tone,
    range: range,
    status: EventStatus.planned,
  );
}

DialStyle lightStyle({bool showNightTint = true}) =>
    DialStyle.fromColors(AppColors.light, showNightTint: showNightTint);

DialPainter buildPainter({
  int ringCount = 1,
  int? nowMinute,
  Tone? markerTone,
  List<CalendarEvent> events = const [],
  Map<int, int> rings = const {},
  Map<int, double> arcProgress = const {},
  bool popStyle = false,
  MinuteRange? ghostRange,
  Tone? ghostTone,
  double ghostOpacity = 0.55,
  DialStyle? style,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return DialPainter(
    geometry: DialGeometry.fitted(size, ringCount: ringCount),
    events: events,
    ringByEventId: rings,
    toneColors: ToneColors.light,
    style: style ?? lightStyle(),
    nowMinute: nowMinute,
    markerTone: markerTone,
    arcProgress: arcProgress,
    popStyle: popStyle,
    ghostRange: ghostRange,
    ghostTone: ghostTone,
    ghostOpacity: ghostOpacity,
    textScaler: textScaler,
  );
}

void paint(DialPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

/// Renders the painter to raw RGBA so a test can read individual pixels.
Future<ByteData> render(DialPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  picture.dispose();
  image.dispose();
  return data;
}

Color pixel(ByteData data, Offset point) {
  final index = (point.dy.round() * size.width.toInt() + point.dx.round()) * 4;
  return Color.fromARGB(
    data.getUint8(index + 3),
    data.getUint8(index),
    data.getUint8(index + 1),
    data.getUint8(index + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final geometry = DialGeometry.fitted(size, ringCount: 1);
  // A point near the outer edge of ring 0, clear of the curved label.
  Offset onArc(int minute) => geometry.pointOnCircle(
    geometry.ringCenterRadius(0) + geometry.ringWidth * 0.38,
    geometry.angleForMinute(minute.toDouble()),
  );

  group('painting does not throw', () {
    test('an empty dial', () {
      expect(() => paint(buildPainter()), returnsNormally);
    });

    test('events across all three rings', () {
      final events = [
        event(1, const MinuteRange(540, 720), Tone.focus, title: 'Deep work'),
        event(2, const MinuteRange(600, 660), Tone.life, title: 'Lunch'),
        event(3, const MinuteRange(610, 620), Tone.inbox, title: 'Email'),
      ];
      expect(
        () => paint(
          buildPainter(
            ringCount: 3,
            events: events,
            rings: const {1: 0, 2: 1, 3: 2},
          ),
        ),
        returnsNormally,
      );
    });

    test('an event that has no ring assigned is skipped', () {
      final events = [
        event(1, const MinuteRange(540, 720), Tone.focus, title: 'Deep work'),
        event(2, const MinuteRange(600, 660), Tone.life, title: 'Overflowed'),
      ];
      expect(
        () => paint(buildPainter(events: events, rings: const {1: 0})),
        returnsNormally,
      );
    });

    test('a very short arc with no room for its label', () {
      final events = [
        event(
          1,
          const MinuteRange(540, 555),
          Tone.focus,
          title: 'A very long event title that cannot possibly fit',
        ),
      ];
      expect(
        () => paint(buildPainter(events: events, rings: const {1: 0})),
        returnsNormally,
      );
    });

    test('the ghost arc during a drag', () {
      expect(
        () => paint(
          buildPainter(
            ghostRange: const MinuteRange(540, 720),
            ghostTone: Tone.focus,
          ),
        ),
        returnsNormally,
      );
    });

    test('the rim marker, with and without a tone', () {
      expect(() => paint(buildPainter(nowMinute: 630)), returnsNormally);
      expect(
        () => paint(buildPainter(nowMinute: 630, markerTone: Tone.life)),
        returnsNormally,
      );
    });

    test('a half-swept arc, in pop style and in dark mode', () {
      final events = [event(1, const MinuteRange(540, 720), Tone.focus)];
      expect(
        () => paint(
          buildPainter(
            events: events,
            rings: const {1: 0},
            arcProgress: const {1: 0.5},
            popStyle: true,
          ),
        ),
        returnsNormally,
      );
      expect(
        () => paint(buildPainter(style: DialStyle.fromColors(AppColors.dark))),
        returnsNormally,
      );
    });

    test('with the night tint off and with enlarged text', () {
      expect(
        () => paint(buildPainter(style: lightStyle(showNightTint: false))),
        returnsNormally,
      );
      expect(
        () => paint(buildPainter(textScaler: const TextScaler.linear(1.2))),
        returnsNormally,
      );
    });
  });

  group('what is drawn', () {
    test('an arc is painted in its tone colour', () async {
      final data = await render(
        buildPainter(
          events: [event(1, const MinuteRange(540, 720), Tone.focus)],
          rings: const {1: 0},
        ),
      );
      expect(pixel(data, onArc(630)), ToneColors.light.fillFor(Tone.focus));
    });

    test('an arc stops where its progress says', () async {
      final data = await render(
        buildPainter(
          events: [event(1, const MinuteRange(540, 720), Tone.focus)],
          rings: const {1: 0},
          arcProgress: const {1: 0.5},
        ),
      );
      // A quarter of the way along the range is drawn; three quarters is not.
      expect(pixel(data, onArc(585)), ToneColors.light.fillFor(Tone.focus));
      expect(pixel(data, onArc(675)).a, 0);
    });

    test('an arc with zero progress is not drawn at all', () async {
      final data = await render(
        buildPainter(
          events: [event(1, const MinuteRange(540, 720), Tone.focus)],
          rings: const {1: 0},
          arcProgress: const {1: 0},
        ),
      );
      expect(pixel(data, onArc(585)).a, 0);
    });

    test('the ghost is drawn at the requested opacity on ring 0', () async {
      final data = await render(
        buildPainter(
          ghostRange: const MinuteRange(540, 720),
          ghostTone: Tone.life,
          ghostOpacity: 1,
        ),
      );
      expect(pixel(data, onArc(630)), ToneColors.light.fillFor(Tone.life));
    });

    test('the marker rides the rim in the tone colour, else in ink', () async {
      final face = buildPainter(nowMinute: 360, markerTone: Tone.life);
      final spot = geometry.pointOnCircle(
        geometry.faceRadius * 0.88,
        geometry.angleForMinute(360),
      );
      expect(
        pixel(await render(face), spot),
        ToneColors.light.fillFor(Tone.life),
      );
      expect(
        pixel(await render(buildPainter(nowMinute: 360)), spot),
        AppColors.light.ink,
      );
    });

    test('no marker is drawn when there is no now minute', () async {
      final spot = geometry.pointOnCircle(
        geometry.faceRadius * 0.88,
        geometry.angleForMinute(360),
      );
      final colour = pixel(await render(buildPainter()), spot);
      expect(colour, isNot(AppColors.light.ink));
      expect(colour, isNot(ToneColors.light.fillFor(Tone.life)));
    });

    test('night hours are tinted and day hours are not', () async {
      final centre = geometry.center;
      final night = centre + Offset(0, -geometry.faceRadius * 0.40); // 00:00
      final day = centre + Offset(0, geometry.faceRadius * 0.40); // 12:00
      final tinted = await render(buildPainter());
      expect(pixel(tinted, night), isNot(AppColors.light.surface));
      expect(pixel(tinted, day), AppColors.light.surface);

      final plain = await render(
        buildPainter(style: lightStyle(showNightTint: false)),
      );
      expect(pixel(plain, night), AppColors.light.surface);
    });
  });

  group('room for a label next to a neighbour', () {
    // The next arc painted on a ring covers the end of the one before it: its
    // round cap and its outline reach back past its own start. The label slides
    // back along the arc, into the arc's own rounded start, by up to a third of
    // the ring width to make room.
    final radius = geometry.ringCenterRadius(0);
    final reach = (geometry.ringWidth / 2 + 2) / radius;
    final slideBack = geometry.ringWidth / 3 / radius;

    double sweepOf(MinuteRange range) =>
        geometry.angleForMinute(range.end.toDouble()) -
        geometry.angleForMinute(range.start.toDouble());

    DialPainter pair(
      MinuteRange first,
      MinuteRange second, {
      int secondRing = 0,
    }) => buildPainter(
      ringCount: secondRing + 1,
      events: [
        event(1, first, Tone.focus, title: 'Deep work'),
        event(2, second, Tone.inbox, title: 'Email'),
      ],
      rings: {1: 0, 2: secondRing},
    );

    const first = MinuteRange(540, 660);

    test('an arc on its own has its whole range to itself', () {
      final painter = buildPainter(
        events: [event(1, first, Tone.focus, title: 'Deep work')],
        rings: const {1: 0},
      );
      final room = painter.labelRoom(painter.events.single);
      expect(room.offset, 0);
      expect(room.sweep, closeTo(sweepOf(first), 1e-9));
    });

    test('an arc that starts where this one ends covers its end', () {
      final painter = pair(first, const MinuteRange(660, 705));
      final room = painter.labelRoom(painter.events.first);
      // Sliding wins some of it back; the rest of the cover is lost.
      expect(room.offset, closeTo(-slideBack, 1e-9));
      expect(room.sweep, closeTo(sweepOf(first) - reach + slideBack, 1e-9));
    });

    test('a small overlap is made up for entirely by sliding back', () {
      final painter = pair(first, const MinuteRange(675, 720));
      final covered = reach - sweepOf(const MinuteRange(660, 675));
      expect(covered, inExclusiveRange(0, slideBack)); // the case under test
      final room = painter.labelRoom(painter.events.first);
      expect(room.offset, closeTo(-covered, 1e-9));
      expect(room.sweep, closeTo(sweepOf(first), 1e-9));
    });

    test('a gap wider than the cap leaves the arc alone', () {
      final painter = pair(first, const MinuteRange(720, 780));
      final room = painter.labelRoom(painter.events.first);
      expect(room.offset, 0);
      expect(room.sweep, closeTo(sweepOf(first), 1e-9));
    });

    test('an arc on another ring does not cover it', () {
      final painter = pair(first, const MinuteRange(660, 705), secondRing: 1);
      final room = painter.labelRoom(painter.events.first);
      expect(room.offset, 0);
      expect(room.sweep, closeTo(sweepOf(first), 1e-9));
    });

    test('the arc painted second is not covered by the one before it', () {
      final painter = pair(first, const MinuteRange(660, 705));
      final room = painter.labelRoom(painter.events.last);
      expect(room.offset, 0);
      expect(room.sweep, closeTo(sweepOf(const MinuteRange(660, 705)), 1e-9));
    });
  });

  group('shouldRepaint', () {
    test('repaints when the now minute changes', () {
      expect(
        buildPainter(
          nowMinute: 600,
        ).shouldRepaint(buildPainter(nowMinute: 601)),
        isTrue,
      );
    });

    test('does not repaint when nothing changed', () {
      expect(
        buildPainter(
          nowMinute: 600,
        ).shouldRepaint(buildPainter(nowMinute: 600)),
        isFalse,
      );
    });

    test('repaints when the style changes', () {
      expect(
        buildPainter().shouldRepaint(
          buildPainter(style: DialStyle.fromColors(AppColors.dark)),
        ),
        isTrue,
      );
    });

    test('repaints when the sweep progress, marker tone or ghost changes', () {
      final base = buildPainter(
        events: [event(1, const MinuteRange(540, 720), Tone.focus)],
        rings: const {1: 0},
      );
      expect(
        base.shouldRepaint(
          buildPainter(
            events: [event(1, const MinuteRange(540, 720), Tone.focus)],
            rings: const {1: 0},
            arcProgress: const {1: 0.4},
          ),
        ),
        isTrue,
      );
      expect(
        buildPainter(
          markerTone: Tone.life,
          nowMinute: 5,
        ).shouldRepaint(buildPainter(markerTone: Tone.focus, nowMinute: 5)),
        isTrue,
      );
      expect(
        buildPainter(
          ghostOpacity: 0.3,
        ).shouldRepaint(buildPainter(ghostOpacity: 0.4)),
        isTrue,
      );
    });

    test('does not repaint for an equal but non-identical event list', () {
      final one = [event(1, const MinuteRange(540, 720), Tone.focus)];
      final two = [event(1, const MinuteRange(540, 720), Tone.focus)];
      final a = buildPainter(events: one, rings: {1: 0});
      final b = buildPainter(events: two, rings: {1: 0});
      expect(a.shouldRepaint(b), isFalse);
    });
  });
}
