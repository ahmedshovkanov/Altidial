import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/session/session_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 7, 10, 0, 0);

  SessionTiming timing({
    int planned = 1500,
    int paused = 0,
    DateTime? pauseStartedAt,
  }) => SessionTiming(
    startedAt: start,
    plannedSeconds: planned,
    pausedSeconds: paused,
    pauseStartedAt: pauseStartedAt,
  );

  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('while running', () {
    test('counts down from the planned length', () {
      final t = timing();
      expect(t.elapsedSecondsAt(at(0)), 0);
      expect(t.remainingSecondsAt(at(0)), 1500);
      expect(t.elapsedSecondsAt(at(90)), 90);
      expect(t.remainingSecondsAt(at(90)), 1410);
      expect(t.isOvertimeAt(at(90)), isFalse);
      expect(t.overtimeSecondsAt(at(90)), 0);
    });

    test('ignores the part of a second that has not finished', () {
      final t = timing();
      final almost = at(90).add(const Duration(milliseconds: 999));
      expect(t.elapsedSecondsAt(almost), 90);
    });

    test('goes into overtime exactly when the planned time is used up', () {
      final t = timing();
      expect(t.isOvertimeAt(at(1499)), isFalse);
      expect(t.isOvertimeAt(at(1500)), isTrue);
      expect(t.overtimeSecondsAt(at(1500)), 0);
      expect(t.remainingSecondsAt(at(1500)), 0);
    });

    test('keeps counting up in overtime', () {
      final t = timing();
      expect(t.overtimeSecondsAt(at(1500 + 205)), 205);
      expect(t.remainingSecondsAt(at(1500 + 205)), -205);
    });
  });

  group('pauses', () {
    test('time spent paused is not counted', () {
      final t = timing(paused: 120);
      expect(t.elapsedSecondsAt(at(600)), 480);
    });

    test('a pause in progress freezes the elapsed time', () {
      final t = timing(paused: 60, pauseStartedAt: at(300));
      expect(t.isPaused, isTrue);
      expect(t.elapsedSecondsAt(at(300)), 240);
      expect(t.elapsedSecondsAt(at(900)), 240);
    });

    test('the pause in progress is added to the paused total', () {
      final t = timing(paused: 60, pauseStartedAt: at(300));
      expect(t.currentPauseSecondsAt(at(450)), 150);
      expect(t.pausedSecondsTotalAt(at(450)), 210);
    });

    test('a running session has no pause in progress', () {
      final t = timing(paused: 60);
      expect(t.isPaused, isFalse);
      expect(t.currentPauseSecondsAt(at(450)), 0);
      expect(t.pausedSecondsTotalAt(at(450)), 60);
    });
  });

  group('the planned end', () {
    test('is the start plus the planned length', () {
      expect(timing().plannedEnd, at(1500));
    });

    test('moves later by the time spent paused', () {
      expect(timing(paused: 120).plannedEnd, at(1620));
    });

    test('moves later when the session is extended', () {
      expect(timing(planned: 1500 + 300).plannedEnd, at(1800));
    });
  });

  group('a clock moved backwards', () {
    test('never gives a negative elapsed time', () {
      final t = timing();
      expect(t.elapsedSecondsAt(at(-3600)), 0);
      expect(t.remainingSecondsAt(at(-3600)), 1500);
      expect(t.overtimeSecondsAt(at(-3600)), 0);
    });

    test('never gives a negative pause length', () {
      final t = timing(pauseStartedAt: at(300));
      expect(t.currentPauseSecondsAt(at(100)), 0);
    });

    test('paused time larger than the span still floors at zero', () {
      final t = timing(paused: 5000);
      expect(t.elapsedSecondsAt(at(100)), 0);
    });
  });

  group('across a daylight-saving change', () {
    test('uses absolute instants, so a 25-hour day adds no hour', () {
      // 2026-10-25 is the European fall-back day; the arithmetic works on
      // epoch seconds, so two instants 90 s apart are 90 s apart.
      final fallBack = DateTime.utc(2026, 10, 25, 0, 59, 30);
      final t = SessionTiming(
        startedAt: fallBack,
        plannedSeconds: 600,
        pausedSeconds: 0,
        pauseStartedAt: null,
      );
      expect(t.elapsedSecondsAt(fallBack.add(const Duration(seconds: 90))), 90);
    });
  });

  group('SessionOutcome', () {
    test('database indices are stable', () {
      expect(SessionOutcome.running.dbIndex, 0);
      expect(SessionOutcome.completed.dbIndex, 1);
      expect(SessionOutcome.finishedEarly.dbIndex, 2);
      expect(SessionOutcome.abandoned.dbIndex, 3);
    });

    test('fromDbIndex round-trips and rejects unknown values', () {
      for (final outcome in SessionOutcome.values) {
        expect(SessionOutcome.fromDbIndex(outcome.dbIndex), outcome);
      }
      expect(() => SessionOutcome.fromDbIndex(9), throwsArgumentError);
    });

    test('only completed and finished-early count as done', () {
      expect(SessionOutcome.completed.countsAsDone, isTrue);
      expect(SessionOutcome.finishedEarly.countsAsDone, isTrue);
      expect(SessionOutcome.abandoned.countsAsDone, isFalse);
      expect(SessionOutcome.running.countsAsDone, isFalse);
    });
  });
}
