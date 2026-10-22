import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 3);

  Future<int> add(
    DateTime date,
    int toneIndex,
    int start,
    int end, {
    int status = 0,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: date,
        title: 'Event',
        toneIndex: toneIndex,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<Map<String, int>> minutes(DateTime from, DateTime to) async {
    final rows = await db.eventDao.watchToneMinutes(from, to).first;
    return {
      for (final row in rows) '${row.date.day}:${row.toneIndex}': row.minutes,
    };
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('sums the minutes of each tone on each day', () async {
    await add(DateTime(2026, 10, 5), 0, 60, 120);
    await add(DateTime(2026, 10, 5), 0, 300, 390);
    await add(DateTime(2026, 10, 5), 2, 180, 195);
    await add(DateTime(2026, 10, 6), 1, 60, 105);

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '5:0': 150,
      '5:2': 15,
      '6:1': 45,
    });
  });

  test('overlapping events count twice', () async {
    await add(DateTime(2026, 10, 5), 0, 60, 120);
    await add(DateTime(2026, 10, 5), 0, 90, 150);

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '5:0': 120,
    });
  });

  test('leaves out days outside the range and the end day itself', () async {
    await add(DateTime(2026, 9, 30), 0, 60, 120);
    await add(DateTime(2026, 10, 1), 0, 60, 120);
    await add(DateTime(2026, 11, 1), 0, 60, 120);

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '1:0': 60,
    });
  });

  test('leaves out skipped events and keeps completed ones', () async {
    await add(
      DateTime(2026, 10, 5),
      0,
      60,
      120,
      status: EventStatus.skipped.dbIndex,
    );
    await add(
      DateTime(2026, 10, 6),
      1,
      60,
      120,
      status: EventStatus.completed.dbIndex,
    );

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '6:1': 60,
    });
  });

  test('an empty range is an empty list', () async {
    expect(
      await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)),
      isEmpty,
    );
  });

  test('emits again when an event is added', () async {
    final seen = <int>[];
    final subscription = db.eventDao
        .watchToneMinutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1))
        .listen((rows) => seen.add(rows.length));
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await add(DateTime(2026, 10, 5), 0, 60, 120);
    await pumpEventQueue();

    expect(seen.first, 0);
    expect(seen.last, 1);
  });
}
