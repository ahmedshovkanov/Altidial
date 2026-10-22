import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  final monday = DateTime(2026, 10, 5);
  final nextMonday = DateTime(2026, 10, 12);

  group('DriftEventRepository.watchTonesByDay', () {
    late AppDatabase db;
    late DriftEventRepository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftEventRepository(db.eventDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('groups the tones by local day and leaves empty days out', () async {
      await repository.createEvent(
        day: DateTime(2026, 10, 5),
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      await repository.createEvent(
        day: DateTime(2026, 10, 5),
        title: 'B',
        tone: Tone.life,
        range: const MinuteRange(180, 240),
      );
      await repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'C',
        tone: Tone.inbox,
        range: const MinuteRange(60, 120),
      );
      await repository.createEvent(
        day: nextMonday,
        title: 'Next week',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );

      final byDay = await repository.watchTonesByDay(monday, nextMonday).first;

      expect(byDay.keys.toSet(), {
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 7),
      });
      expect(byDay[DateTime(2026, 10, 5)], {Tone.focus, Tone.life});
      expect(byDay[DateTime(2026, 10, 7)], {Tone.inbox});
    });
  });

  group('weekTonesProvider', () {
    late FakeEventRepository repository;

    setUp(() {
      repository = FakeEventRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('covers Monday to Sunday of the keyed week', () async {
      await repository.createEvent(
        day: DateTime(2026, 10, 11), // Sunday, last day of the week
        title: 'Sunday',
        tone: Tone.life,
        range: const MinuteRange(60, 120),
      );
      await repository.createEvent(
        day: nextMonday, // belongs to the next week
        title: 'Monday',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      final container = ProviderContainer(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final byDay = await container.read(weekTonesProvider(monday).future);
      expect(byDay.keys.toSet(), {DateTime(2026, 10, 11)});
      expect(byDay[DateTime(2026, 10, 11)], {Tone.life});
    });

    test('different weeks are different providers', () async {
      await repository.createEvent(
        day: nextMonday,
        title: 'Monday',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      final container = ProviderContainer(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(await container.read(weekTonesProvider(monday).future), isEmpty);
      expect(
        (await container.read(weekTonesProvider(nextMonday).future)).keys,
        [nextMonday],
      );
    });
  });
}
