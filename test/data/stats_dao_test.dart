import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftStatsRepository repository;

  // October 2026: the 5th is a Monday.
  final monday = DateTime(2026, 10, 5);
  final nextMonday = DateTime(2026, 10, 12);
  final now = DateTime(2026, 10, 7, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftStatsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent({
    required DateTime date,
    Tone tone = Tone.focus,
    int start = 540,
    int end = 600,
    int status = 0,
  }) => db.eventDao.insertEvent(
    EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: tone.dbIndex,
      startMinute: start,
      endMinute: end,
      status: Value(status),
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> seedSession({
    required int eventId,
    SessionOutcome outcome = SessionOutcome.completed,
    int activeSeconds = 3600,
    DateTime? startedAt,
  }) => db.sessionDao.insertSession(
    SessionsCompanion.insert(
      eventId: eventId,
      startedAt: startedAt ?? DateTime(2026, 10, 6, 9),
      plannedSeconds: 3600,
      activeSeconds: Value(activeSeconds),
      outcome: Value(outcome.dbIndex),
    ),
  );

  Future<StatsSnapshot> snapshot() =>
      repository.watchWindow(monday, nextMonday).first;

  test(
    'countsAsDone minutes group per day and tone, on the event date',
    () async {
      final focus = await seedEvent(date: DateTime(2026, 10, 6));
      final life = await seedEvent(
        date: DateTime(2026, 10, 6),
        tone: Tone.life,
        start: 660,
        end: 720,
      );
      await seedSession(eventId: focus, activeSeconds: 5400);
      await seedSession(
        eventId: focus,
        outcome: SessionOutcome.finishedEarly,
        activeSeconds: 1800,
      );
      await seedSession(eventId: life, activeSeconds: 3600);

      final stats = await snapshot();
      expect(stats.toneByDay, [
        (date: DateTime(2026, 10, 6), tone: Tone.focus, minutes: 120),
        (date: DateTime(2026, 10, 6), tone: Tone.life, minutes: 60),
      ]);
    },
  );

  test('abandoned, running and deleted sessions contribute nothing', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    final deleted = await seedEvent(date: DateTime(2026, 10, 6), status: 2);
    await seedSession(
      eventId: focus,
      outcome: SessionOutcome.abandoned,
      activeSeconds: 1800,
    );
    await seedSession(
      eventId: focus,
      outcome: SessionOutcome.running,
      activeSeconds: 600,
    );
    await seedSession(eventId: deleted, activeSeconds: 3600);

    final stats = await snapshot();
    expect(stats.toneByDay, isEmpty);
    expect(stats.completedTotal, 0);
    expect(stats.focus.ended, 1);
  });

  test('seconds truncate after grouping, not per session', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    await seedSession(eventId: focus, activeSeconds: 50);
    await seedSession(eventId: focus, activeSeconds: 50);

    final stats = await snapshot();
    // 100 seconds in one cell is a minute; truncated per session it would be 0.
    expect(stats.toneByDay.single.minutes, 1);
  });

  test('planned counts every stored event, completed folds the pool', () async {
    final focus = await seedEvent(
      date: DateTime(2026, 10, 6),
      start: 540,
      end: 660,
    );
    final life = await seedEvent(
      date: DateTime(2026, 10, 6),
      tone: Tone.life,
      start: 660,
      end: 720,
    );
    await seedSession(eventId: focus, activeSeconds: 5400);
    await seedSession(eventId: life, activeSeconds: 3600);

    final stats = await snapshot();
    expect(stats.plannedTotal, 180);
    expect(stats.completedTotal, 150);
    expect(stats.adherencePercent, 83);
    expect(stats.plannedByTone, [
      (tone: Tone.focus, plannedMinutes: 120, completedMinutes: 90),
      (tone: Tone.life, plannedMinutes: 60, completedMinutes: 60),
      (tone: Tone.inbox, plannedMinutes: 0, completedMinutes: 0),
    ]);
  });

  test('focus depth totals the pool but rates every ended session', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    final life = await seedEvent(date: DateTime(2026, 10, 6), tone: Tone.life);
    await seedSession(eventId: focus, activeSeconds: 900);
    await seedSession(eventId: focus, activeSeconds: 300);
    await seedSession(
      eventId: focus,
      outcome: SessionOutcome.abandoned,
      activeSeconds: 1200,
    );
    await seedSession(eventId: life, activeSeconds: 3600);

    final stats = await snapshot();
    expect(stats.focus.minutes, 20);
    expect(stats.focus.longestSeconds, 900);
    expect(stats.focus.averageSeconds, 600);
    expect(stats.focus.ended, 3);
    expect(stats.focus.abandoned, 1);
  });

  test(
    'focus instants are ordered, focus-only and countsAsDone-only',
    () async {
      final focus = await seedEvent(date: DateTime(2026, 10, 6));
      final life = await seedEvent(
        date: DateTime(2026, 10, 6),
        tone: Tone.life,
      );
      await seedSession(
        eventId: focus,
        startedAt: DateTime(2026, 10, 6, 14),
        activeSeconds: 1800,
      );
      await seedSession(
        eventId: focus,
        startedAt: DateTime(2026, 10, 6, 9),
        activeSeconds: 900,
      );
      await seedSession(
        eventId: focus,
        outcome: SessionOutcome.abandoned,
        startedAt: DateTime(2026, 10, 6, 8),
      );
      await seedSession(eventId: life, startedAt: DateTime(2026, 10, 6, 7));

      final stats = await snapshot();
      expect(stats.focusInstants, [
        (startedAt: DateTime(2026, 10, 6, 9), activeSeconds: 900),
        (startedAt: DateTime(2026, 10, 6, 14), activeSeconds: 1800),
      ]);
    },
  );

  test('days outside the window are excluded either side', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 4)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 5)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 11)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 12)));

    final stats = await snapshot();
    expect(stats.toneByDay.map((cell) => cell.date), [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 11),
    ]);
  });

  test('an empty window reads empty, with no adherence and no rate', () async {
    final stats = await snapshot();
    expect(stats.isEmpty, isTrue);
    expect(stats.adherencePercent, isNull);
    expect(stats.focus.abandonmentRate, isNull);
  });

  test('the stream emits again when a session is added', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 6));
    final emissions = repository
        .watchWindow(monday, nextMonday)
        .take(2)
        .toList();
    await Future<void>.delayed(Duration.zero);
    await seedSession(eventId: id, activeSeconds: 3600);

    final snapshots = await emissions;
    expect(snapshots, hasLength(2));
    expect(snapshots.first.completedTotal, 0);
    expect(snapshots.last.completedTotal, 60);
  });
}
