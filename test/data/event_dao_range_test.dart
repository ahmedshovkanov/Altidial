import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('watchRange emits only in-range rows, ordered by date then start',
      () async {
    final dao = db.eventDao;
    final now = DateTime(2026, 10, 14, 12);
    Future<int> insert(DateTime date, int start, {bool flight = false}) =>
        dao.insertEvent(
          EventsCompanion.insert(
            date: date,
            title: flight ? 'Flight' : 'Work',
            toneIndex: 2,
            startMinute: start,
            endMinute: start + 60,
            createdAt: now,
            updatedAt: now,
            isFlight: Value(flight),
          ),
        );
    await insert(DateTime(2026, 10, 10), 600, flight: true);
    await insert(DateTime(2026, 10, 14), 900, flight: true);
    await insert(DateTime(2026, 10, 14), 300, flight: true);
    await insert(DateTime(2026, 10, 20), 600);

    final rows = await dao
        .watchRange(DateTime(2026, 10, 12), DateTime(2026, 10, 18))
        .first;
    expect(rows.map((r) => r.startMinute), [300, 900]);
    expect(rows.every((r) => r.date == DateTime(2026, 10, 14)), isTrue);
  });
}
