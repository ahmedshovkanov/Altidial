import 'package:altidial/app/onboarding/sample_day.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_event_repository.dart';

/// Refuses one event by title, as a failing write would.
class _FlakyRepository extends FakeEventRepository {
  _FlakyRepository(this.failingTitle);

  final String failingTitle;

  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
    int? projectId,
  }) {
    if (title == failingTitle) throw StateError('disk full');
    return super.createEvent(
      day: day,
      title: title,
      tone: tone,
      range: range,
      isFlight: isFlight,
      flightNumber: flightNumber,
      fromCode: fromCode,
      toCode: toCode,
      projectId: projectId,
    );
  }
}

void main() {
  final day = DateTime(2026, 10, 7);
  late FakeEventRepository repository;

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  test('the sample day is the four specified events', () {
    expect(
      [for (final e in sampleDay) (e.title, e.tone, e.range)],
      [
        ('Deep work', Tone.focus, const MinuteRange(540, 660)),
        ('Email and calls', Tone.inbox, const MinuteRange(660, 705)),
        ('Lunch walk', Tone.life, const MinuteRange(750, 795)),
        ('Writing', Tone.focus, const MinuteRange(840, 960)),
      ],
    );
  });

  test('creates every event on the given day', () async {
    final complete = await createSampleDay(repository, day: day);

    expect(complete, isTrue);
    final events = await repository.eventsForDay(day);
    expect(events.map((e) => e.title), [
      'Deep work',
      'Email and calls',
      'Lunch walk',
      'Writing',
    ]);
    expect(events.map((e) => e.tone), [
      Tone.focus,
      Tone.inbox,
      Tone.life,
      Tone.focus,
    ]);
  });

  test('does not touch other days', () async {
    await createSampleDay(repository, day: day);
    expect(await repository.eventsForDay(DateTime(2026, 10, 8)), isEmpty);
  });

  test(
    'skips an event that would need a fourth ring, and carries on',
    () async {
      // Three events overlapping 09:00-12:00 already fill every ring there.
      for (var i = 0; i < 3; i++) {
        await repository.createEvent(
          day: day,
          title: 'Busy $i',
          tone: Tone.life,
          range: const MinuteRange(540, 720),
        );
      }

      final complete = await createSampleDay(repository, day: day);

      expect(complete, isTrue, reason: 'a skipped event is not an error');
      final titles = (await repository.eventsForDay(day)).map((e) => e.title);
      expect(titles, isNot(contains('Deep work')));
      expect(titles, isNot(contains('Email and calls')));
      expect(titles, containsAll(['Lunch walk', 'Writing']));
    },
  );

  test(
    'an unexpected error is reported but the rest are still created',
    () async {
      final flaky = _FlakyRepository('Lunch walk');
      addTearDown(flaky.dispose);

      final complete = await createSampleDay(flaky, day: day);

      expect(complete, isFalse);
      final titles = (await flaky.eventsForDay(day)).map((e) => e.title);
      expect(titles, ['Deep work', 'Email and calls', 'Writing']);
    },
  );
}
