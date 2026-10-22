import 'package:drift/native.dart';
import 'package:altidial/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 3);

  EventsCompanion entry(DateTime date, int toneIndex, int start) {
    return EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: toneIndex,
      startMinute: start,
      endMinute: start + 30,
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

  test(
    'returns each distinct date and tone once, inside the range only',
    () async {
      await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 0, 60));
      await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 0, 120));
      await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 2, 180));
      await db.eventDao.insertEvent(entry(DateTime(2026, 10, 6), 1, 60));
      await db.eventDao.insertEvent(entry(DateTime(2026, 10, 12), 1, 60));
      await db.eventDao.insertEvent(entry(DateTime(2026, 10, 4), 1, 60));

      final rows = await db.eventDao
          .watchToneDays(DateTime(2026, 10, 5), DateTime(2026, 10, 12))
          .first;

      final pairs = rows.map((r) => '${r.date.day}:${r.toneIndex}').toSet();
      expect(pairs, {'5:0', '5:2', '6:1'});
      expect(rows, hasLength(3));
    },
  );

  test('an empty range is an empty list', () async {
    final rows = await db.eventDao
        .watchToneDays(DateTime(2026, 10, 5), DateTime(2026, 10, 12))
        .first;
    expect(rows, isEmpty);
  });

  test('emits again when an event is added', () async {
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 0, 60));
    final counts = <int>[];
    final subscription = db.eventDao
        .watchToneDays(DateTime(2026, 10, 5), DateTime(2026, 10, 12))
        .listen((rows) => counts.add(rows.length));
    addTearDown(subscription.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 6), 1, 60));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(counts, [1, 2]);
  });
}
