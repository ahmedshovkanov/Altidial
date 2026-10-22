import 'package:drift/native.dart';
import 'package:altidial/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  final day = DateTime(2026, 8, 23);
  final otherDay = DateTime(2026, 8, 24);
  final now = DateTime(2026, 8, 23, 9, 0);

  EventsCompanion entry({
    required DateTime date,
    required String title,
    required int startMinute,
    required int endMinute,
    int toneIndex = 0,
  }) {
    return EventsCompanion.insert(
      date: date,
      title: title,
      toneIndex: toneIndex,
      startMinute: startMinute,
      endMinute: endMinute,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('inserted events come back for their own day only', () async {
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.insertEvent(
      entry(date: otherDay, title: 'Gym', startMinute: 400, endMinute: 460),
    );

    final result = await db.eventDao.eventsForDay(day);
    expect(result, hasLength(1));
    expect(result.single.title, 'Deep work');
  });

  test('events for a day are ordered by start minute', () async {
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Lunch', startMinute: 780, endMinute: 840),
    );
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );

    final result = await db.eventDao.eventsForDay(day);
    expect(result.map((row) => row.title), ['Deep work', 'Lunch']);
  });

  test('status defaults to planned', () async {
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    final result = await db.eventDao.eventsForDay(day);
    expect(result.single.status, 0);
  });

  test('updateTimes moves an event', () async {
    final id = await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.updateTimes(
      id: id,
      startMinute: 600,
      endMinute: 780,
      updatedAt: DateTime(2026, 8, 23, 10, 0),
    );

    final row = (await db.eventDao.eventsForDay(day)).single;
    expect(row.startMinute, 600);
    expect(row.endMinute, 780);
  });

  test('updateDetails changes title and tone', () async {
    final id = await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.updateDetails(
      id: id,
      title: 'Email',
      toneIndex: 2,
      updatedAt: DateTime(2026, 8, 23, 10, 0),
    );

    final row = (await db.eventDao.eventsForDay(day)).single;
    expect(row.title, 'Email');
    expect(row.toneIndex, 2);
  });

  test('deleteById removes the event', () async {
    final id = await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.deleteById(id, now: DateTime(2026, 10, 7, 9));
    expect(await db.eventDao.eventsForDay(day), isEmpty);
  });

  test('watchDay emits again when the day changes', () async {
    // Prime the connection: on a freshly-created, not-yet-opened database,
    // starting watch() and insertEvent() concurrently races drift's
    // QueryStream against the async open/migration, which can cancel the
    // pre-insert emission before it is delivered. Running one query first
    // ensures the database is already open when the watch begins.
    await db.eventDao.eventsForDay(day);

    final emissions = db.eventDao.watchDay(day);
    final future = emissions.take(2).toList();

    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );

    final batches = await future;
    expect(batches.first, isEmpty);
    expect(batches.last, hasLength(1));
  });
}
