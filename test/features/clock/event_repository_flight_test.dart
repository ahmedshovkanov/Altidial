import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftEventRepository repository;
  final day = DateTime(2026, 10, 14);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => DateTime(2026, 10, 14, 9, 0),
    );
  });

  tearDown(() async => db.close());

  test('creating a flight forces Inbox tone and round-trips columns', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'Fly home',
      tone: Tone.focus, // flights always land on Inbox regardless
      range: const MinuteRange(625, 850),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );
    final events = await repository.eventsForDay(day);
    final flight = events.singleWhere((e) => e.id == id);
    expect(flight.tone, Tone.inbox);
    expect(flight.isFlight, isTrue);
    expect(flight.flightNumber, 'LH715');
    expect(flight.fromCode, 'SOF');
    expect(flight.toCode, 'BER');
  });

  test('updateFlight clears columns when toggled off', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'Fly home',
      tone: Tone.inbox,
      range: const MinuteRange(625, 850),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );
    await repository.updateFlight(
      id: id,
      isFlight: false,
      flightNumber: null,
      fromCode: null,
      toCode: null,
    );
    final events = await repository.eventsForDay(day);
    final event = events.singleWhere((e) => e.id == id);
    expect(event.isFlight, isFalse);
    expect(event.flightNumber, isNull);
    expect(event.fromCode, isNull);
    expect(event.toCode, isNull);
  });
}
