import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  final day = DateTime(2026, 8, 23);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => DateTime(2026, 8, 23, 9, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('creating an event returns it as a domain object', () async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );

    final events = await repository.eventsForDay(day);
    expect(events.single.title, 'Deep work');
    expect(events.single.tone, Tone.focus);
    expect(events.single.range, const MinuteRange(540, 720));
    expect(events.single.status, EventStatus.planned);
  });

  test('the day is normalised to local midnight', () async {
    await repository.createEvent(
      day: DateTime(2026, 8, 23, 17, 42),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    expect(await repository.eventsForDay(day), hasLength(1));
  });

  test('three overlapping events are allowed', () async {
    await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    await repository.createEvent(
      day: day,
      title: 'B',
      tone: Tone.life,
      range: const MinuteRange(600, 660),
    );
    await repository.createEvent(
      day: day,
      title: 'C',
      tone: Tone.inbox,
      range: const MinuteRange(610, 620),
    );
    expect(await repository.eventsForDay(day), hasLength(3));
  });

  test('a fourth overlapping event is refused', () async {
    for (final range in const [
      MinuteRange(540, 720),
      MinuteRange(600, 660),
      MinuteRange(610, 620),
    ]) {
      await repository.createEvent(
        day: day,
        title: 'Event',
        tone: Tone.focus,
        range: range,
      );
    }

    expect(
      () => repository.createEvent(
        day: day,
        title: 'Fourth',
        tone: Tone.focus,
        range: const MinuteRange(615, 618),
      ),
      throwsA(isA<RingOverflowException>()),
    );
  });

  test(
    'moving an event excludes its own position from the ring check',
    () async {
      // Three overlapping events fill all three rings.
      await repository.createEvent(
        day: day,
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      await repository.createEvent(
        day: day,
        title: 'B',
        tone: Tone.life,
        range: const MinuteRange(600, 660),
      );
      final movingId = await repository.createEvent(
        day: day,
        title: 'C',
        tone: Tone.inbox,
        range: const MinuteRange(610, 620),
      );

      // Nudging C keeps it overlapping A and B. This fits only because C's own
      // current position is excluded from the check; counting it would make the
      // candidate a fourth ring and throw.
      await repository.moveEvent(
        id: movingId,
        day: day,
        range: const MinuteRange(615, 625),
      );

      final moved = (await repository.eventsForDay(
        day,
      )).firstWhere((event) => event.id == movingId);
      expect(moved.range, const MinuteRange(615, 625));
    },
  );

  test('updateDetails changes title and tone', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await repository.updateDetails(id: id, title: 'Email', tone: Tone.inbox);

    final event = (await repository.eventsForDay(day)).single;
    expect(event.title, 'Email');
    expect(event.tone, Tone.inbox);
  });

  test('deleting removes the event', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await repository.deleteEvent(id);
    expect(await repository.eventsForDay(day), isEmpty);
  });
}
