import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Note (Task 5 brief Step 1 deviation): test/data/session_repository_test.dart
// contains no shared `openTestDatabase` helper (it builds
// `AppDatabase.forTesting(NativeDatabase.memory())` inline in setUp), so this
// file defines a local `openTestDatabase()` instead of importing a helper
// that does not exist. No helper was added to session_repository_test.dart.
AppDatabase openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

Future<int> _makeEndedSession(AppDatabase db, {required String title, required int tone, required int hour}) async {
  final now = DateTime(2026, 10, 15, hour, 0);
  final eventId = await db.into(db.events).insert(
    EventsCompanion.insert(
      date: DateTime(2026, 10, 15),
      title: title,
      toneIndex: tone,
      startMinute: hour * 60,
      endMinute: hour * 60 + 60,
      createdAt: now,
      updatedAt: now,
    ),
  );
  final repo = DriftSessionRepository(db.sessionDao);
  final id = await repo.start(eventId: eventId);
  await repo.finish(id);
  return id;
}

/// Counts the statements that reach sqlite, so a test can prove the join does
/// not point-query once per session.
class _CountingExecutor implements QueryExecutor {
  _CountingExecutor(this._inner);

  final QueryExecutor _inner;
  final List<String> selects = <String>[];

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) {
    selects.add(statement);
    return _inner.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) => _inner.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) => _inner.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) => _inner.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) => _inner.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) => _inner.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  Future<void> close() => _inner.close();
}

void main() {
  test('the join reads every event in one query, not one per session', () async {
    final counting = _CountingExecutor(NativeDatabase.memory());
    final db = AppDatabase.forTesting(counting);
    addTearDown(db.close);
    for (var i = 0; i < 6; i++) {
      await _makeEndedSession(db, title: 'F$i', tone: 0, hour: 9 + i % 3);
    }
    counting.selects.clear();

    final rows = await DriftReflectionsRepository(db).loadTimeline();

    expect(rows.length, 6);
    final eventQueries = counting.selects.where((s) => s.contains('FROM "events"')).length;
    expect(eventQueries, 1);
  });

  test('timeline joins sessions with events newest first and decodes tags', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await _makeEndedSession(db, title: 'Deep work', tone: 0, hour: 9);
    await DriftSessionRepository(db.sessionDao).saveReflection(
      sessionId: id, energyRating: 4, focusRating: 5, tags: ['flow'], note: 'hi',
    );
    final repo = DriftReflectionsRepository(db);
    final rows = await repo.loadTimeline();
    expect(rows.length, 1);
    expect(rows.single.eventTitle, 'Deep work');
    expect(rows.single.session.tags, ['flow']);
    expect(rows.single.session.note, 'hi');
  });

  test('a corrupt tags csv is sanitised on the way out of the row', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await _makeEndedSession(db, title: 'Deep work', tone: 0, hour: 9);
    // Written straight to the table, as an older build or a bad migration
    // would have: an id nobody knows, an empty piece and a duplicate.
    await (db.update(db.sessions)..where((t) => t.id.equals(id))).write(
      const SessionsCompanion(tagsCsv: Value('flow,bogus,,flow,clear-goal')),
    );

    final rows = await DriftReflectionsRepository(db).loadTimeline();

    expect(rows.single.session.tags, ['flow', 'clear-goal']);
  });

  test('abandoned sessions appear in timeline but not in patterns', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final sessionRepo = DriftSessionRepository(db.sessionDao);
    for (var i = 0; i < 6; i++) {
      final id = await _makeEndedSession(db, title: 'F$i', tone: 0, hour: 9);
      await sessionRepo.saveReflection(sessionId: id, energyRating: 5, focusRating: 5, tags: ['clear-goal'], note: null);
    }
    final abandonedEvent = await db.into(db.events).insert(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 15), title: 'Ab', toneIndex: 0,
        startMinute: 600, endMinute: 660,
        createdAt: DateTime(2026, 10, 15), updatedAt: DateTime(2026, 10, 15),
      ),
    );
    final abId = await sessionRepo.start(eventId: abandonedEvent);
    await sessionRepo.abandon(abId);
    await sessionRepo.saveReflection(sessionId: abId, energyRating: 1, focusRating: 1, tags: const [], note: null);
    final repo = DriftReflectionsRepository(db);
    final timeline = await repo.loadTimeline();
    expect(timeline.length, 7);
    final cards = await repo.loadPatterns();
    expect(cards, isEmpty); // 6 done but split 6/0 -> withoutClear empty -> no clear-goal card
  });
}


