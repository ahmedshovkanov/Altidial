import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-overlapping events all sit on the innermost ring', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 600)),
      RingCandidate(2, MinuteRange(600, 660)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 0});
    expect(result.overflowEventIds, isEmpty);
  });

  test('each overlap pushes one ring outward', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
      RingCandidate(3, MinuteRange(610, 620)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 1, 3: 2});
    expect(result.overflowEventIds, isEmpty);
  });

  test('a fourth simultaneous event overflows', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
      RingCandidate(3, MinuteRange(610, 620)),
      RingCandidate(4, MinuteRange(615, 618)),
    ]);
    expect(result.ringByEventId[4], isNull);
    expect(result.overflowEventIds, [4]);
  });

  test('a freed ring is reused by a later event', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
      RingCandidate(3, MinuteRange(660, 700)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 1, 3: 1});
  });

  test('input order does not affect the result', () {
    final result = assignRings(const [
      RingCandidate(3, MinuteRange(610, 620)),
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 1, 3: 2});
  });

  test('wouldOverflowRings refuses a fourth overlapping event', () {
    expect(
      wouldOverflowRings(
        existing: const [
          MinuteRange(540, 720),
          MinuteRange(600, 660),
          MinuteRange(610, 620),
        ],
        candidate: const MinuteRange(615, 618),
      ),
      isTrue,
    );
  });

  test('wouldOverflowRings allows a third overlapping event', () {
    expect(
      wouldOverflowRings(
        existing: const [MinuteRange(540, 720), MinuteRange(600, 660)],
        candidate: const MinuteRange(610, 620),
      ),
      isFalse,
    );
  });
}
