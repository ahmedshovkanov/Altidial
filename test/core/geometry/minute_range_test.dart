import 'package:altidial/core/geometry/minute_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinuteRange', () {
    test('duration is end minus start', () {
      expect(const MinuteRange(540, 720).durationMinutes, 180);
    });

    test('touching ranges do not overlap because end is exclusive', () {
      expect(
        const MinuteRange(540, 600).overlaps(const MinuteRange(600, 660)),
        isFalse,
      );
    });

    test('ranges sharing any interior minute overlap', () {
      expect(
        const MinuteRange(540, 720).overlaps(const MinuteRange(600, 660)),
        isTrue,
      );
    });

    test('equal ranges compare equal', () {
      expect(const MinuteRange(540, 720), const MinuteRange(540, 720));
    });
  });

  group('snapMinute', () {
    test('rounds to the nearest five minutes', () {
      expect(snapMinute(542), 540);
      expect(snapMinute(543), 545);
    });

    test('clamps to the day', () {
      expect(snapMinute(-10), 0);
      expect(snapMinute(1500), 1440);
    });
  });

  group('unwrapMinute', () {
    test('keeps a nearby sample untouched', () {
      expect(unwrapMinute(540, 545), 545);
    });

    test('lifts a sample that wrapped past midnight', () {
      expect(unwrapMinute(1430, 10), 1450);
    });

    test('drops a sample that wrapped backwards past midnight', () {
      expect(unwrapMinute(10, 1430), -10);
    });
  });

  group('rangeFromDrag', () {
    test('snaps both ends to five minutes', () {
      expect(
        rangeFromDrag(anchorMinute: 541, currentMinute: 722),
        const MinuteRange(540, 720),
      );
    });

    test('handles a backwards drag by ordering the ends', () {
      expect(
        rangeFromDrag(anchorMinute: 720, currentMinute: 600),
        const MinuteRange(600, 720),
      );
    });

    test('enforces the fifteen minute minimum', () {
      expect(
        rangeFromDrag(anchorMinute: 540, currentMinute: 543),
        const MinuteRange(540, 555),
      );
    });

    test('clamps at end of day and backs the start off to fit', () {
      expect(
        rangeFromDrag(anchorMinute: 1430, currentMinute: 1500),
        const MinuteRange(1425, 1440),
      );
    });

    test('a drag wrapping past midnight clamps rather than inverting', () {
      expect(
        rangeFromDrag(anchorMinute: 1380, currentMinute: 1450),
        const MinuteRange(1380, 1440),
      );
    });
  });

  group('rangeFromTap', () {
    test('starts at the snapped tap minute with an hour by default', () {
      expect(rangeFromTap(minute: 903), const MinuteRange(905, 965));
    });

    test('does not fall back to the 09:00 slot', () {
      expect(rangeFromTap(minute: 720), isNot(const MinuteRange(540, 600)));
    });

    test('slides back to fit inside the end of the day', () {
      expect(rangeFromTap(minute: 1410), const MinuteRange(1380, 1440));
    });
  });

  group('grabKindFor', () {
    const range = MinuteRange(540, 720);

    test('near the start edge resizes the start', () {
      expect(
        grabKindFor(range: range, touchMinute: 545),
        ArcGrabKind.resizeStart,
      );
    });

    test('near the end edge resizes the end', () {
      expect(
        grabKindFor(range: range, touchMinute: 715),
        ArcGrabKind.resizeEnd,
      );
    });

    test('in the middle moves the whole event', () {
      expect(grabKindFor(range: range, touchMinute: 620), ArcGrabKind.move);
    });

    test('a short event always moves rather than resizes', () {
      expect(
        grabKindFor(range: const MinuteRange(540, 555), touchMinute: 541),
        ArcGrabKind.move,
      );
    });
  });

  group('moveRange', () {
    test('translates and preserves duration', () {
      expect(
        moveRange(const MinuteRange(540, 720), 60),
        const MinuteRange(600, 780),
      );
    });

    test('clamps at the start of the day without shrinking', () {
      expect(
        moveRange(const MinuteRange(30, 90), -60),
        const MinuteRange(0, 60),
      );
    });

    test('clamps at the end of the day without shrinking', () {
      expect(
        moveRange(const MinuteRange(1350, 1410), 120),
        const MinuteRange(1380, 1440),
      );
    });
  });

  group('resizeRange', () {
    test('resizing the start moves only the start', () {
      expect(
        resizeRangeStart(const MinuteRange(540, 720), 600),
        const MinuteRange(600, 720),
      );
    });

    test('the start cannot cross the minimum duration', () {
      expect(
        resizeRangeStart(const MinuteRange(540, 720), 719),
        const MinuteRange(705, 720),
      );
    });

    test('the end cannot cross the minimum duration', () {
      expect(
        resizeRangeEnd(const MinuteRange(540, 720), 541),
        const MinuteRange(540, 555),
      );
    });

    test('the end clamps at the end of the day', () {
      expect(
        resizeRangeEnd(const MinuteRange(1380, 1410), 1500),
        const MinuteRange(1380, 1440),
      );
    });
  });
}
