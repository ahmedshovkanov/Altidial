import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/model/day_load.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(int id, int start, int end, Tone tone) => CalendarEvent(
  id: id,
  seriesId: null,
  date: DateTime(2026, 10, 7),
  title: 'Event $id',
  tone: tone,
  range: MinuteRange(start, end),
  status: EventStatus.planned,
);

void main() {
  group('computeDayLoad', () {
    test('no events is empty', () {
      final load = computeDayLoad(const []);
      expect(load.isEmpty, isTrue);
      expect(load.totalMinutes, 0);
      expect(load.tones, isEmpty);
    });

    test('sums minutes per tone', () {
      final load = computeDayLoad([
        event(1, 540, 660, Tone.focus), // 120
        event(2, 780, 840, Tone.life), // 60
        event(3, 900, 1020, Tone.focus), // 120
      ]);
      expect(load.minutesFor(Tone.focus), 240);
      expect(load.minutesFor(Tone.life), 60);
      expect(load.minutesFor(Tone.inbox), 0);
      expect(load.totalMinutes, 300);
      expect(load.isEmpty, isFalse);
    });

    test('overlapping events count twice, because overlap is extra load', () {
      final load = computeDayLoad([
        event(1, 540, 600, Tone.focus),
        event(2, 540, 600, Tone.life),
      ]);
      expect(load.totalMinutes, 120);
    });

    test('lists only tones with time, in the fixed tone order', () {
      final load = computeDayLoad([
        event(1, 60, 120, Tone.inbox),
        event(2, 180, 240, Tone.focus),
      ]);
      expect(load.tones, [Tone.focus, Tone.inbox]);
    });
  });

  group('segmentWidths', () {
    test('widths are proportional to minutes and fill the space', () {
      final widths = segmentWidths([240, 120, 60], 420);
      expect(widths[0], closeTo(240, 1e-9));
      expect(widths[1], closeTo(120, 1e-9));
      expect(widths[2], closeTo(60, 1e-9));
      expect(widths.reduce((a, b) => a + b), closeTo(420, 1e-9));
    });

    test('a tone with no minutes gets no width', () {
      final widths = segmentWidths([100, 0, 100], 200);
      expect(widths, [100, 0, 100]);
    });

    test('a tiny segment is held at the minimum and the rest give way', () {
      final widths = segmentWidths([1000, 10], 300);
      expect(widths[1], 8);
      expect(widths[0], closeTo(292, 1e-9));
      expect(widths.reduce((a, b) => a + b), closeTo(300, 1e-9));
    });

    test('several tiny segments are all held at the minimum', () {
      final widths = segmentWidths([5000, 10, 12], 300);
      expect(widths[1], 8);
      expect(widths[2], 8);
      expect(widths[0], closeTo(284, 1e-9));
    });

    test('a single segment takes everything', () {
      expect(segmentWidths([0, 45, 0], 250), [0, 250, 0]);
    });

    test('nothing planned or no space gives zeros', () {
      expect(segmentWidths([0, 0, 0], 250), [0, 0, 0]);
      expect(segmentWidths([10, 20, 30], 0), [0, 0, 0]);
    });

    test(
      'a segment that only just clears the minimum is not shrunk below it',
      () {
        // 100 of 2000 minutes in 120 px is 6 px, so it is pinned at 8 and the
        // other segment takes the remaining 112 px.
        final widths = segmentWidths([1900, 100], 120);
        expect(widths[1], 8);
        expect(widths[0], closeTo(112, 1e-9));
      },
    );
  });
}
