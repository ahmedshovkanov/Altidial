import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftEventRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => DateTime(2026, 10, 14, 9, 0),
    );
  });

  tearDown(() async => db.close());

  test('watchFlights returns only flights, ordered by date then start',
      () async {
    final day = DateTime(2026, 10, 14);
    await repository.createEvent(
      day: day,
      title: 'Standup',
      tone: Tone.inbox,
      range: const MinuteRange(540, 600),
    );
    await repository.createEvent(
      day: day,
      title: 'LH715',
      tone: Tone.inbox,
      range: const MinuteRange(625, 850),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );
    final flights = await repository
        .watchFlights(DateTime(2026, 10, 1), DateTime(2026, 11, 1))
        .first;
    expect(flights.map((f) => f.title), ['LH715']);
    expect(flights.single.fromCode, 'SOF');
  });
}
