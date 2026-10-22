import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repository;
  late DateTime now;

  final day = DateTime(2026, 10, 7);

  /// Plain `test` bodies cannot use `pumpAndSettle`, so the clock is a variable
  /// the test moves by hand.
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  Future<int> addEvent({
    String title = 'Deep work',
    int tone = 0,
    int start = 600,
    int end = 660,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: day,
        title: title,
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<EventRow> eventRow(int id) async =>
      (await db.eventDao.eventsForDay(day)).firstWhere((row) => row.id == id);

  setUp(() {
    now = DateTime(2026, 10, 7, 10, 0, 0);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSessionRepository(db.sessionDao, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('starting', () {
    test('plans the length of the event and reports it as running', () async {
      final eventId = await addEvent(
        title: 'Lunch walk',
        tone: 1,
        start: 750,
        end: 795,
      );

      final id = await repository.start(eventId: eventId);
      final running = await repository.runningSession();

      expect(running, isNotNull);
      expect(running!.id, id);
      expect(running.eventId, eventId);
      expect(running.eventTitle, 'Lunch walk');
      expect(running.eventTone, Tone.life);
      expect(running.session.plannedSeconds, 45 * 60);
      expect(running.session.startedAt, now);
      expect(running.session.outcome, SessionOutcome.running);
      expect(running.session.endedAt, isNull);
      expect(running.timing.isPaused, isFalse);
    });

    test('is refused while another session is running', () async {
      final first = await addEvent();
      final second = await addEvent(title: 'Email', start: 700, end: 730);
      await repository.start(eventId: first);

      expect(
        () => repository.start(eventId: second),
        throwsA(isA<SessionAlreadyRunningException>()),
      );
    });

    test('is refused for an event that does not exist', () async {
      expect(
        () => repository.start(eventId: 999),
        throwsA(isA<SessionEventMissingException>()),
      );
    });

    test('is allowed again once the last session has ended', () async {
      final first = await addEvent();
      final second = await addEvent(title: 'Email', start: 700, end: 730);
      final id = await repository.start(eventId: first);
      await repository.abandon(id);

      await repository.start(eventId: second);
      expect((await repository.runningSession())!.eventId, second);
    });

    test('nothing runs on a fresh database', () async {
      expect(await repository.runningSession(), isNull);
    });
  });

  group('pausing', () {
    test(
      'pause records when it began and resume adds it to the total',
      () async {
        final id = await repository.start(eventId: await addEvent());
        advance(300);
        await repository.pause(id);
        expect((await repository.runningSession())!.timing.isPaused, isTrue);

        advance(120);
        await repository.resume(id);

        final session = (await repository.runningSession())!.session;
        expect(session.pausedSeconds, 120);
        expect(session.pauseStartedAt, isNull);
      },
    );

    test('pauses add up across several pauses', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.pause(id);
      advance(60);
      await repository.resume(id);
      advance(100);
      await repository.pause(id);
      advance(30);
      await repository.resume(id);

      expect((await repository.runningSession())!.session.pausedSeconds, 90);
    });

    test('pausing twice keeps the first pause start', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(10);
      await repository.pause(id);
      final first = (await repository.runningSession())!.session.pauseStartedAt;
      advance(50);
      await repository.pause(id);

      expect(
        (await repository.runningSession())!.session.pauseStartedAt,
        first,
      );
    });

    test('resuming a session that is not paused changes nothing', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(60);
      await repository.resume(id);

      expect((await repository.runningSession())!.session.pausedSeconds, 0);
    });
  });

  group('extending', () {
    test('adds to the planned length', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.extend(id, seconds: 300);
      await repository.extend(id, seconds: 900);

      expect(
        (await repository.runningSession())!.session.plannedSeconds,
        3600 + 300 + 900,
      );
    });

    test('does nothing to a session that has ended', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.abandon(id);
      await repository.extend(id, seconds: 300);

      expect(await repository.runningSession(), isNull);
    });
  });

  group('finishing', () {
    test(
      'before the planned end is finished early, for the time worked',
      () async {
        final eventId = await addEvent();
        final id = await repository.start(eventId: eventId);
        advance(1200);

        final done = await repository.finish(id);

        expect(done!.outcome, SessionOutcome.finishedEarly);
        expect(done.activeSeconds, 1200);
        expect(done.overtimeSeconds, 0);
        expect(done.endedAt, now);
        expect(await repository.runningSession(), isNull);
        expect((await eventRow(eventId)).status, EventStatus.completed.dbIndex);
      },
    );

    test('at the planned end is completed', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(3600);

      final done = await repository.finish(id);

      expect(done!.outcome, SessionOutcome.completed);
      expect(done.activeSeconds, 3600);
      expect(done.overtimeSeconds, 0);
    });

    test('past the planned end records the overtime', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(3600 + 450);

      final done = await repository.finish(id);

      expect(done!.outcome, SessionOutcome.completed);
      expect(done.activeSeconds, 4050);
      expect(done.overtimeSeconds, 450);
    });

    test('an extension moves the planned end', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.extend(id, seconds: 900);
      advance(3600 + 100);

      final done = await repository.finish(id);

      expect(done!.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 3700);
    });

    test('time spent paused is not counted as work', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(600);
      await repository.pause(id);
      advance(1000);
      await repository.resume(id);
      advance(600);

      final done = await repository.finish(id);

      expect(done!.activeSeconds, 1200);
      expect(done.pausedSeconds, 1000);
    });

    test('finishing while paused closes the pause', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(600);
      await repository.pause(id);
      advance(500);

      final done = await repository.finish(id);

      expect(done!.activeSeconds, 600);
      expect(done.pausedSeconds, 500);
      expect(done.pauseStartedAt, isNull);
    });

    test(
      'a clock moved back records zero rather than a negative time',
      () async {
        final eventId = await addEvent();
        final id = await repository.start(eventId: eventId);
        advance(-7200);

        final done = await repository.finish(id);

        expect(done!.activeSeconds, 0);
        expect(done.outcome, SessionOutcome.finishedEarly);
      },
    );

    test('a second finish does nothing', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(100);
      await repository.finish(id);
      advance(100);

      expect(await repository.finish(id), isNull);
    });
  });

  group('abandoning', () {
    test('is recorded as abandoned and leaves the event planned', () async {
      final eventId = await addEvent();
      final id = await repository.start(eventId: eventId);
      advance(400);

      await repository.abandon(id);

      final rows = await db.sessionDao.sessionsForEvent(eventId);
      expect(rows.single.outcome, SessionOutcome.abandoned.dbIndex);
      expect(rows.single.activeSeconds, 400);
      expect(rows.single.endedAt, now);
      expect(await repository.runningSession(), isNull);
      expect((await eventRow(eventId)).status, EventStatus.planned.dbIndex);
    });
  });

  group('closing out after the app was killed', () {
    test('caps the time at the planned length', () async {
      final eventId = await addEvent();
      final id = await repository.start(eventId: eventId);
      advance(3600 + 5 * 3600);

      final done = await repository.closeOut(id);

      expect(done!.outcome, SessionOutcome.completed);
      expect(done.activeSeconds, 3600);
      expect(done.overtimeSeconds, 0);
      expect((await eventRow(eventId)).status, EventStatus.completed.dbIndex);
    });

    test('before the planned end it is finished early, uncapped', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(900);

      final done = await repository.closeOut(id);

      expect(done!.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 900);
    });
  });

  group('watching', () {
    test('emits the session, then null when it ends', () async {
      final id = await repository.start(eventId: await addEvent());
      final emissions = <RunningSession?>[];
      final subscription = repository.watchRunning().listen(emissions.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      advance(60);
      await repository.finish(id);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions.first?.id, id);
      expect(emissions.last, isNull);
    });
  });

  group('deleting an event', () {
    test('also deletes its sessions', () async {
      final eventId = await addEvent();
      final other = await addEvent(title: 'Email', start: 700, end: 730);
      final first = await repository.start(eventId: eventId);
      advance(60);
      await repository.finish(first);
      final second = await repository.start(eventId: other);
      advance(60);
      await repository.finish(second);

      await db.eventDao.deleteById(eventId, now: now);

      expect(await db.sessionDao.sessionsForEvent(eventId), isEmpty);
      expect(await db.sessionDao.sessionsForEvent(other), hasLength(1));
    });

    test('also removes a running session, so none points at a ghost', () async {
      final eventId = await addEvent();
      await repository.start(eventId: eventId);

      await db.eventDao.deleteById(eventId, now: now);

      expect(await repository.runningSession(), isNull);
    });
  });
}
