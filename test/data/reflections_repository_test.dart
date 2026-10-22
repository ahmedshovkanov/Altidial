import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Note (Task 3 brief Step 1 deviation): test/data/session_repository_test.dart
// contains no shared `openTestDatabase` helper (it builds
// `AppDatabase.forTesting(NativeDatabase.memory())` inline in setUp), so this
// file defines a local `_openDb()` instead of importing a helper that does
// not exist. No helper was added to session_repository_test.dart.
AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  test('saveReflection persists energy focus tags note and edits overwrite', () async {
    final db = _openDb();
    addTearDown(db.close);
    final repo = DriftSessionRepository(db.sessionDao);
    final now = DateTime(2026, 10, 15, 10, 0);
    final eventId = await db.into(db.events).insert(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 15),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final sessionId = await repo.start(eventId: eventId);
    await repo.finish(sessionId);
    await repo.saveReflection(
      sessionId: sessionId,
      energyRating: 4,
      focusRating: 5,
      tags: ['flow', 'clear-goal'],
      note: 'Great hour',
    );
    var row = await db.sessionDao.sessionById(sessionId);
    expect(row!.energyRating, 4);
    expect(row.focusRating, 5);
    expect(row.tagsCsv, 'flow,clear-goal');
    expect(row.note, 'Great hour');
    await repo.saveReflection(
      sessionId: sessionId,
      energyRating: 2,
      focusRating: 2,
      tags: ['tired'],
      note: null,
    );
    row = await db.sessionDao.sessionById(sessionId);
    expect(row!.energyRating, 2);
    expect(row.tagsCsv, 'tired');
    expect(row.note, isNull);
  });

  test('saveReflection rejects out-of-range ratings and over-long notes', () async {
    final db = _openDb();
    addTearDown(db.close);
    final repo = DriftSessionRepository(db.sessionDao);
    final now = DateTime(2026, 10, 15, 10, 0);
    final eventId = await db.into(db.events).insert(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 15),
        title: 'Email',
        toneIndex: 2,
        startMinute: 600,
        endMinute: 660,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final sessionId = await repo.start(eventId: eventId);
    await repo.finish(sessionId);
    expect(
      () => repo.saveReflection(sessionId: sessionId, energyRating: 0, focusRating: 5, tags: const [], note: null),
      throwsArgumentError,
    );
    expect(
      () => repo.saveReflection(sessionId: sessionId, energyRating: 3, focusRating: 6, tags: const [], note: null),
      throwsArgumentError,
    );
    expect(
      () => repo.saveReflection(sessionId: sessionId, energyRating: 3, focusRating: 3, tags: const [], note: 'a' * 141),
      throwsArgumentError,
    );
  });
}
