import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/session/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<int> addEvent() => harness.repository.createEvent(
    day: DateTime(2026, 10, 7),
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 660),
  );

  test('a launch with nothing running has nothing to recover', () async {
    expect(
      await harness.container.read(sessionRecoveryProvider.future),
      isNull,
    );
  });

  test('a session already running at launch is offered for recovery', () async {
    final eventId = await addEvent();
    harness.sessions.seedRunning(
      eventId: eventId,
      startedAt: DateTime(2026, 10, 7, 9, 0),
    );

    final id = await harness.container.read(sessionRecoveryProvider.future);

    expect(id, harness.sessions.running!.id);
  });

  test('a session started after launch is not a recovery', () async {
    await harness.container.read(sessionRecoveryProvider.future);
    await harness.sessions.start(eventId: await addEvent());

    expect(harness.container.read(sessionRecoveryProvider).value, isNull);
  });

  test('resolving clears the offer', () async {
    final eventId = await addEvent();
    harness.sessions.seedRunning(
      eventId: eventId,
      startedAt: DateTime(2026, 10, 7, 9, 0),
    );
    await harness.container.read(sessionRecoveryProvider.future);

    harness.container.read(sessionRecoveryProvider.notifier).resolve();

    expect(harness.container.read(sessionRecoveryProvider).value, isNull);
  });
}
