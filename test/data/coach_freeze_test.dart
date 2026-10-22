import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: the plan brief names `AppDatabase.testExecutor()`, which does not
// exist in this codebase. Every data test uses
// `AppDatabase.forTesting(NativeDatabase.memory())`; this file follows that
// established pattern.
void main() {
  late AppDatabase db;
  late DriftCoachRepository repo;

  // Monday 2026-10-19 09:00: ISO week 42 (Mon 12 – Sun 18 Oct) is finished,
  // so ensureWeek(2026, 42) is past the Sunday 18:00 gate and must generate.
  final now = DateTime(2026, 10, 19, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCoachRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  /// Ten ended inbox sessions starting at 17:00 over ten days in the 28-day
  /// window of week 42: seven abandoned, three completed. That is 70% of
  /// inbox abandoned after 16:00 over 10 ended sessions, so the late-abandon
  /// rule (min 10 ended, >= 30%) must fire.
  Future<void> seedLateAbandonWeek() async {
    for (var i = 0; i < 10; i++) {
      final date = DateTime(2026, 10, 1 + i);
      final eventId = await db.eventDao.insertEvent(
        EventsCompanion.insert(
          date: date,
          title: 'Inbox late',
          toneIndex: Tone.inbox.dbIndex,
          startMinute: 17 * 60,
          endMinute: 18 * 60,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.sessionDao.insertSession(
        SessionsCompanion.insert(
          eventId: eventId,
          startedAt: DateTime(date.year, date.month, date.day, 17),
          plannedSeconds: 3600,
          activeSeconds: const Value(1800),
          outcome: Value(
            (i < 7
                    ? SessionOutcome.abandoned
                    : SessionOutcome.completed)
                .dbIndex,
          ),
        ),
      );
    }
  }

  test('ensureWeek freezes then re-reads snapshot, never recomputes', () async {
    await seedLateAbandonWeek();

    await repo.ensureWeek(2026, 42);
    final first = await repo.watchWeekInsights(2026, 42).first;
    expect(first.map((row) => row.kind), contains('late-abandon'));
    expect(
      first.firstWhere((row) => row.kind == 'late-abandon').payloadJson,
      contains('70%'),
    );

    await repo.ensureWeek(2026, 42);
    final second = await repo.watchWeekInsights(2026, 42).first;
    expect(second.length, first.length);
    expect(
      second.map((row) => (row.kind, row.payloadJson)),
      first.map((row) => (row.kind, row.payloadJson)),
    );
  });

  test('current ISO week never generates before Sunday 18:00 local', () async {
    final midweek = DriftCoachRepository(
      db,
      now: () => DateTime(2026, 10, 15, 12),
    );
    await seedLateAbandonWeek();

    // Thursday of week 42: the gate (Sunday 18:00) has not passed.
    await midweek.ensureWeek(2026, 42);
    expect(await midweek.watchWeekInsights(2026, 42).first, isEmpty);
  });
}
