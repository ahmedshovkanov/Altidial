import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftRoundupRepository repository;
  DateTime now = DateTime(2026, 10, 13, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 13, 8);
    repository = DriftRoundupRepository(db, now: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent({
    required DateTime date,
    Tone tone = Tone.focus,
    int start = 540,
    int end = 660,
  }) => db.eventDao.insertEvent(
    EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: tone.dbIndex,
      startMinute: start,
      endMinute: end,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> seedSession({
    required int eventId,
    int activeSeconds = 3600,
    DateTime? startedAt,
  }) => db.sessionDao.insertSession(
    SessionsCompanion.insert(
      eventId: eventId,
      startedAt: startedAt ?? DateTime(2026, 10, 5, 9),
      plannedSeconds: 3600,
      activeSeconds: Value(activeSeconds),
      outcome: Value(SessionOutcome.completed.dbIndex),
    ),
  );

  test('an empty database generates nothing', () async {
    await repository.ensureCurrent();
    expect(await repository.watchArchive().first, isEmpty);
  });

  test(
    'a finished week generates its payload, the current week never does',
    () async {
      // ISO week 41: 5–11 October 2026. Now is Tuesday the 13th (week 42).
      final id = await seedEvent(date: DateTime(2026, 10, 6));
      await seedSession(eventId: id, activeSeconds: 5400);

      await repository.ensureCurrent();

      final archive = await repository.watchArchive().first;
      expect(archive.map((row) => (row.isoYear, row.isoWeek)), [(2026, 41)]);

      final payload = await repository.payload(2026, 41);
      expect(payload, isNotNull);
      expect(payload!.weekStart, DateTime(2026, 10, 5));
      expect(payload.plannedMinutes, 120);
      expect(payload.completedMinutes, 90);
      expect(payload.focusMinutes, 90);
      expect(payload.lifeMinutes, 0);
      expect(payload.inboxMinutes, 0);
      expect(payload.adherencePercent, 75);
      expect(payload.bestFocusDay, DateTime(2026, 10, 6));
      expect(payload.bestFocusMinutes, 90);
      // Streaks freeze as of the week's Sunday: one Tuesday session is a
      // longest of 1 with nothing current by Sunday.
      expect(payload.currentStreak, 0);
      expect(payload.longestStreak, 1);
      // 90 focus minutes: 135 session XP, no badges, no previous week.
      expect(payload.xpEarned, 135);
      expect(payload.previousAdherencePercent, isNull);
    },
  );

  test('an empty week between data weeks archives as empty', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 9, 22)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.ensureCurrent();

    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => row.isoWeek), [41, 40, 39]);

    final empty = await repository.payload(2026, 40);
    expect(empty!.plannedMinutes, 0);
    expect(empty.adherencePercent, isNull);
    expect(empty.bestFocusDay, isNull);
  });

  test('the archive reads newest first', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 9, 29)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.ensureCurrent();

    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => row.isoWeek), [41, 40]);
  });

  test(
    'badges unlocked in the week are named, and the next week sees the last',
    () async {
      await seedSession(eventId: await seedEvent(date: DateTime(2026, 9, 29)));
      await db.progressDao.unlockBadges([
        'first_session',
      ], DateTime(2026, 9, 30, 12));
      await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
      await repository.ensureCurrent();

      final week40 = await repository.payload(2026, 40);
      expect(week40!.badgesUnlocked, ['first_session']);
      expect(week40.xpEarned, greaterThan(50));

      final week41 = await repository.payload(2026, 41);
      expect(week41!.badgesUnlocked, isEmpty);
      expect(week41.previousAdherencePercent, week40.adherencePercent);
    },
  );

  test('a corrupt row reads as null, not as a crash', () async {
    await db.roundupDao.insertRoundup(
      isoYear: 2026,
      isoWeek: 41,
      payloadJson: '{"isoWeek": "forty"}',
      generatedAt: now,
    );

    expect(await repository.payload(2026, 41), isNull);
    expect(await repository.watchArchive().first, hasLength(1));
  });

  test('watching the archive generates first', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 6));
    await seedSession(eventId: id);

    // No ensureCurrent call: the stream itself generates.
    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => row.isoWeek), [41]);
  });
}
