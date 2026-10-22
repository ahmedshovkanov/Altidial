import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/model/session_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 7, 10, 0, 0);

  RunningSession session({
    int planned = 1500,
    int paused = 0,
    DateTime? pauseStartedAt,
  }) => RunningSession(
    session: SessionRecord(
      id: 1,
      eventId: 1,
      startedAt: start,
      endedAt: null,
      plannedSeconds: planned,
      pausedSeconds: paused,
      pauseStartedAt: pauseStartedAt,
      activeSeconds: 0,
      overtimeSeconds: 0,
      outcome: SessionOutcome.running,
    ),
    eventTitle: 'Deep work',
    eventTone: Tone.focus,
    eventDate: DateTime(2026, 10, 7),
    eventRange: const MinuteRange(600, 625),
  );

  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('while running', () {
    test('shows the time left and how much of the ring remains', () {
      final display = SessionDisplay.of(session(), at(375));

      expect(display.isPaused, isFalse);
      expect(display.isOvertime, isFalse);
      expect(display.remainingSeconds, 1125);
      expect(display.timeText, '18:45');
      expect(display.fractionRemaining, closeTo(0.75, 1e-9));
      expect(display.spokenTime, '18 minutes 45 seconds left');
      expect(display.plannedText, '25m');
    });

    test('starts with a full ring', () {
      final display = SessionDisplay.of(session(), at(0));
      expect(display.fractionRemaining, 1);
      expect(display.timeText, '25:00');
    });

    test('shows hours for a long session', () {
      final display = SessionDisplay.of(session(planned: 7200), at(0));
      expect(display.timeText, '2:00:00');
      expect(display.plannedText, '2h');
    });
  });

  group('in overtime', () {
    test('switches to a plus sign and counts up', () {
      final display = SessionDisplay.of(session(), at(1500 + 125));

      expect(display.isOvertime, isTrue);
      expect(display.remainingSeconds, 0);
      expect(display.overtimeSeconds, 125);
      expect(display.timeText, '+02:05');
      expect(display.fractionRemaining, 0);
      expect(display.spokenTime, '2 minutes 5 seconds over');
    });

    test('is already overtime, at +00:00, the moment the time is used up', () {
      final display = SessionDisplay.of(session(), at(1500));
      expect(display.isOvertime, isTrue);
      expect(display.timeText, '+00:00');
    });

    test('an extension takes it back out of overtime', () {
      final display = SessionDisplay.of(session(planned: 1800), at(1500));
      expect(display.isOvertime, isFalse);
      expect(display.timeText, '05:00');
    });
  });

  group('while paused', () {
    test('freezes the time', () {
      final paused = session(pauseStartedAt: at(300));
      expect(SessionDisplay.of(paused, at(300)).timeText, '20:00');
      expect(SessionDisplay.of(paused, at(900)).timeText, '20:00');
      expect(SessionDisplay.of(paused, at(900)).isPaused, isTrue);
    });
  });

  test('planned end follows pauses and extensions', () {
    final display = SessionDisplay.of(
      session(planned: 1800, paused: 120),
      at(10),
    );
    expect(display.plannedEnd, at(1920));
  });

  test('a clock moved back shows the full time, not a negative one', () {
    final display = SessionDisplay.of(session(), at(-3600));
    expect(display.timeText, '25:00');
    expect(display.fractionRemaining, 1);
  });
}
