// test/features/projects/project_progress_test.dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/model/project_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target mode divides actual by target', () {
    expect(ProjectProgress.compute(plannedMinutes: 100, actualMinutes: 50, targetMinutes: 200), 0.25);
  });
  test('planned mode divides actual by planned', () {
    expect(ProjectProgress.compute(plannedMinutes: 100, actualMinutes: 50, targetMinutes: null), 0.5);
  });
  test('empty plan is zero', () {
    expect(ProjectProgress.compute(plannedMinutes: 0, actualMinutes: 0, targetMinutes: null), 0.0);
  });
  test('overflow exceeds 1.0', () {
    expect(
      ProjectProgress.compute(plannedMinutes: 60, actualMinutes: 90, targetMinutes: null),
      1.5,
    );
  });
  test('isReadyToComplete true at and above 1.0', () {
    expect(ProjectProgress.isReadyToComplete(1.0), isTrue);
    expect(ProjectProgress.isReadyToComplete(1.5), isTrue);
  });
  test('isReadyToComplete false below 1.0', () {
    expect(ProjectProgress.isReadyToComplete(0.99), isFalse);
  });
  test('isOverdue null is false', () {
    expect(ProjectProgress.isOverdue(null, DateTime(2026, 10, 14)), isFalse);
  });
  test('isOverdue past is true, today is false', () {
    expect(
      ProjectProgress.isOverdue(DateTime(2026, 10, 10), DateTime(2026, 10, 14)),
      isTrue,
    );
    expect(
      ProjectProgress.isOverdue(DateTime(2026, 10, 14), DateTime(2026, 10, 14)),
      isFalse,
    );
  });
  test('overdue label', () {
    expect(deadlineLabel(DateTime(2026, 10, 10), DateTime(2026, 10, 14)), 'Overdue 4d');
  });
  test('deadlineLabel due today, due in, weekday, null', () {
    final now = DateTime(2026, 10, 14); // Wednesday
    expect(deadlineLabel(DateTime(2026, 10, 14), now), 'Due today');
    expect(deadlineLabel(DateTime(2026, 10, 17), now), 'Due in 3d');
    expect(deadlineLabel(DateTime(2026, 10, 30), now), startsWith('Due '));
    expect(deadlineLabel(null, now), isEmpty);
  });
  test('validateProjectTitle empty, overlong, valid', () {
    expect(validateProjectTitle('   '), isNotNull);
    expect(validateProjectTitle('a' * 81), isNotNull);
    expect(validateProjectTitle('Portfolio'), isNull);
  });
  test('validateTargetMinutes bounds', () {
    expect(validateTargetMinutes(null), isNull);
    expect(validateTargetMinutes(14), isNotNull);
    expect(validateTargetMinutes(600001), isNotNull);
    expect(validateTargetMinutes(600), isNull);
  });

  group('velocityLast7Days', () {
    SessionRow doneSession(
      int id, {
      required DateTime day,
      required int minutes,
    }) {
      final start = DateTime(day.year, day.month, day.day, 10);
      return SessionRow(
        id: id,
        eventId: 7,
        startedAt: start,
        endedAt: start.add(Duration(minutes: minutes)),
        plannedSeconds: minutes * 60,
        pausedSeconds: 0,
        activeSeconds: minutes * 60,
        overtimeSeconds: 0,
        outcome: 1,
      );
    }

    test('maps done minutes to last 7 days, older days excluded', () {
      final sessions = [
        doneSession(1, day: DateTime(2026, 10, 15), minutes: 45),
        doneSession(2, day: DateTime(2026, 10, 17), minutes: 30),
        // A week old: outside the window, must not leak into any bucket.
        doneSession(3, day: DateTime(2026, 10, 10), minutes: 60),
      ];
      final v = velocityLast7Days(
        doneSessions: sessions,
        now: DateTime(2026, 10, 17),
      );
      expect(v.length, 7);
      expect(v.last, 30); // today (Oct 17)
      expect(v[4], 45); // two days ago (Oct 15; buckets run Oct 11-17)
      expect(v.reduce((a, b) => a + b), 75);
    });

    test('empty input is seven zeros', () {
      expect(
        velocityLast7Days(doneSessions: const [], now: DateTime(2026, 10, 17)),
        List.filled(7, 0),
      );
    });

    test('sums seconds per day then truncates', () {
      // Two 90s sessions on the same day: 180s -> 3 minutes, not 1 + 1.
      final at = DateTime(2026, 10, 17, 10);
      SessionRow secs(int id, int seconds) => SessionRow(
        id: id,
        eventId: 7,
        startedAt: at,
        endedAt: at,
        plannedSeconds: seconds,
        pausedSeconds: 0,
        activeSeconds: seconds,
        overtimeSeconds: 0,
        outcome: 1,
      );
      final v = velocityLast7Days(
        doneSessions: [secs(1, 90), secs(2, 90)],
        now: DateTime(2026, 10, 17),
      );
      expect(v.last, 3);
      expect(v.sublist(0, 6), everyElement(0));
    });

    test('buckets by endedAt day, falls back to startedAt', () {
      final ended = SessionRow(
        id: 1,
        eventId: 7,
        startedAt: DateTime(2026, 10, 15, 23, 50),
        endedAt: DateTime(2026, 10, 16, 0, 10),
        plannedSeconds: 1200,
        pausedSeconds: 0,
        activeSeconds: 1200,
        overtimeSeconds: 0,
        outcome: 2,
      );
      final running = SessionRow(
        id: 2,
        eventId: 7,
        startedAt: DateTime(2026, 10, 17, 9),
        endedAt: null,
        plannedSeconds: 600,
        pausedSeconds: 0,
        activeSeconds: 600,
        overtimeSeconds: 0,
        outcome: 0,
      );
      final v = velocityLast7Days(
        doneSessions: [ended, running],
        now: DateTime(2026, 10, 17),
      );
      expect(v[5], 20); // ended Oct 16
      expect(v.last, 10); // started today, no end yet
    });
  });

  group('velocityBarHeight', () {
    test('scales minutes against the week max', () {
      expect(
        velocityBarHeight(minutes: 30, maxMinutes: 60),
        closeTo(34, 0.001), // 4 + (30 / 60) * (64 - 4)
      );
      expect(
        velocityBarHeight(minutes: 60, maxMinutes: 60),
        closeTo(64, 0.001),
      );
    });

    test('all-zero week stays finite at the minimum height', () {
      final height = velocityBarHeight(minutes: 0, maxMinutes: 0);
      expect(height.isFinite, isTrue);
      expect(height, closeTo(4, 0.001));
    });
  });

  group('sort comparators', () {
    ProjectRow project(
      int id, {
      String title = 'Project',
      DateTime? deadline,
    }) => ProjectRow(
      id: id,
      title: title,
      createdAt: DateTime(2026, 10, 1),
      deadline: deadline,
      status: 0,
      priority: 0,
    );

    test('compareByDeadline: nulls last, earliest first, title tiebreak', () {
      final noDeadline = project(1, title: 'Beta');
      final withDeadline = project(
        2,
        title: 'Alpha',
        deadline: DateTime(2026, 11, 1),
      );
      expect(compareByDeadline(noDeadline, withDeadline), greaterThan(0));
      expect(compareByDeadline(withDeadline, noDeadline), lessThan(0));

      final early = project(3, deadline: DateTime(2026, 10, 20));
      final late = project(4, deadline: DateTime(2026, 10, 25));
      expect(compareByDeadline(early, late), lessThan(0));

      final sameA = project(5, title: 'b', deadline: DateTime(2026, 10, 20));
      final sameB = project(6, title: 'a', deadline: DateTime(2026, 10, 20));
      expect(compareByDeadline(sameA, sameB), greaterThan(0));
      expect(
        compareByDeadline(project(7, title: 'x'), project(8, title: 'y')),
        lessThan(0),
      );
    });

    test('compareByTitle is case-insensitive with id tiebreak', () {
      expect(
        compareByTitle(project(1, title: 'beta'), project(2, title: 'Alpha')),
        greaterThan(0),
      );
      expect(
        compareByTitle(project(1, title: 'Same'), project(2, title: 'same')),
        lessThan(0),
      );
    });

    test('compareByProgress orders highest first, nulls n/a', () {
      final a = project(1, title: 'b');
      final b = project(2, title: 'a');
      expect(compareByProgress(a, b, 0.5, 1.0), greaterThan(0));
      expect(compareByProgress(a, b, 1.5, 1.5), greaterThan(0)); // title
    });

    test('compareByRecent: nulls last, most recent first', () {
      final a = project(1, title: 'b');
      final b = project(2, title: 'a');
      expect(
        compareByRecent(a, b, null, DateTime(2026, 10, 16)),
        greaterThan(0),
      );
      expect(
        compareByRecent(a, b, DateTime(2026, 10, 16), DateTime(2026, 10, 14)),
        lessThan(0),
      );
      expect(
        compareByRecent(a, b, DateTime(2026, 10, 16), DateTime(2026, 10, 16)),
        greaterThan(0), // title tiebreak
      );
      expect(compareByRecent(a, b, null, null), greaterThan(0)); // title
    });
  });

  group('notes and priority validation', () {
    test('validateNotes rejects over 500', () {
      expect(validateNotes('x' * 501), isNotNull);
      expect(validateNotes('x' * 500), isNull);
      expect(validateNotes('ok'), isNull);
      expect(validateNotes(''), isNull);
    });

    test('validatePriority allows null and 0-3 only', () {
      expect(validatePriority(null), isNull);
      expect(validatePriority(0), isNull);
      expect(validatePriority(3), isNull);
      expect(validatePriority(-1), isNotNull);
      expect(validatePriority(4), isNotNull);
    });
  });
}
