import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:energy_clock/features/session/session_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // The harness clock reads Wednesday 7 October 2026, 10:30:00.
  final now = DateTime(2026, 10, 7, 10, 30);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<RunningSession> startSession({int start = 630, int end = 690}) async {
    final id = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: 'Deep work',
      tone: Tone.focus,
      range: MinuteRange(start, end),
    );
    await harness.sessions.start(eventId: id);
    return harness.sessions.running!;
  }

  SessionAlertsNotifier alerts() =>
      harness.container.read(sessionAlertsProvider.notifier);

  group('scheduling', () {
    test('schedules the alert for the planned end', () async {
      final session = await startSession();

      await alerts().sync(session);

      final pending = harness.notifications.pending[sessionEndNotificationId]!;
      expect(pending.at, now.add(const Duration(hours: 1)));
      expect(pending.title, "Time's up");
      expect(pending.body, contains('Deep work'));
      expect(
        harness.container.read(sessionAlertsProvider),
        AlertsStatus.granted,
      );
    });

    test('does not ask for permission when it is already granted', () async {
      await alerts().sync(await startSession());
      expect(harness.notifications.requests, 0);
    });

    test('a pause removes the alert and a resume puts it back later', () async {
      final session = await startSession();
      await alerts().sync(session);

      harness.clock.set(now.add(const Duration(minutes: 10)));
      await harness.sessions.pause(session.id);
      await alerts().sync(harness.sessions.running);
      expect(harness.notifications.pending, isEmpty);

      harness.clock.set(now.add(const Duration(minutes: 25)));
      await harness.sessions.resume(session.id);
      await alerts().sync(harness.sessions.running);

      // Planned end moves later by the 15 minutes spent paused.
      expect(
        harness.notifications.pending[sessionEndNotificationId]!.at,
        now.add(const Duration(hours: 1, minutes: 15)),
      );
    });

    test('an extension moves the alert later', () async {
      final session = await startSession();
      await harness.sessions.extend(session.id, seconds: 900);

      await alerts().sync(harness.sessions.running);

      expect(
        harness.notifications.pending[sessionEndNotificationId]!.at,
        now.add(const Duration(hours: 1, minutes: 15)),
      );
    });

    test('a session that has ended removes the alert', () async {
      final session = await startSession();
      await alerts().sync(session);

      await alerts().sync(null);

      expect(harness.notifications.pending, isEmpty);
    });

    test('a session already in overtime schedules nothing', () async {
      final session = await startSession();
      harness.clock.set(now.add(const Duration(hours: 2)));

      await alerts().sync(session);

      expect(harness.notifications.pending, isEmpty);
      expect(harness.notifications.log, ['cancel $sessionEndNotificationId']);
    });

    test('a plugin failure never throws', () async {
      harness.notifications.failSchedule = true;
      await expectLater(alerts().sync(await startSession()), completes);
    });

    test('quick changes are carried out in order', () async {
      final session = await startSession();
      final first = alerts().sync(session);
      final second = alerts().sync(null);
      final third = alerts().sync(session);
      await Future.wait([first, second, third]);

      expect(harness.notifications.log, [
        'schedule $sessionEndNotificationId',
        'cancel $sessionEndNotificationId',
        'schedule $sessionEndNotificationId',
      ]);
      expect(harness.notifications.pending, isNotEmpty);
    });

    test('a switched-off session toggle cancels instead of scheduling', () async {
      harness.settings.values[notifySessionEndKey] = false;
      final session = await startSession();

      await alerts().sync(session);

      expect(harness.notifications.pending, isEmpty);
      expect(harness.notifications.requests, 0);
    });

    test('an unset session toggle schedules as before', () async {
      final session = await startSession();

      await alerts().sync(session);

      expect(
        harness.notifications.pending[sessionEndNotificationId],
        isNotNull,
      );
    });
  });

  group('permission', () {
    test('asks once, the first time an alert is needed', () async {
      harness.notifications.enabled = false;
      final session = await startSession();

      await alerts().sync(session);
      await alerts().sync(session);

      expect(harness.notifications.requests, 1);
      expect(harness.settings.values[notificationsPromptedKey], isTrue);
      expect(
        harness.notifications.pending.containsKey(sessionEndNotificationId),
        isTrue,
      );
    });

    test('a refusal leaves the session alone and records the denial', () async {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;

      await alerts().sync(await startSession());

      expect(harness.notifications.pending, isEmpty);
      expect(
        harness.container.read(sessionAlertsProvider),
        AlertsStatus.denied,
      );
    });

    test('never asks again after the prompt has been shown', () async {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;
      final session = await startSession();

      await alerts().sync(session);
      await alerts().sync(session);

      expect(harness.notifications.requests, 1);
    });

    test(
      'turning notifications on in Settings takes effect on the next sync',
      () async {
        harness.notifications.enabled = false;
        harness.notifications.grantsRequest = false;
        final session = await startSession();
        await alerts().sync(session);

        harness.notifications.enabled = true;
        await alerts().sync(session);

        expect(
          harness.container.read(sessionAlertsProvider),
          AlertsStatus.granted,
        );
        expect(harness.notifications.pending, isNotEmpty);
      },
    );
  });

  group('the banner', () {
    test('is hidden until permission has been refused', () async {
      expect(
        await harness.container.read(notificationBannerVisibleProvider.future),
        isFalse,
      );
    });

    test('shows after a refusal, and stays hidden once dismissed', () async {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;
      await alerts().sync(await startSession());

      expect(
        await harness.container.read(notificationBannerVisibleProvider.future),
        isTrue,
      );

      harness.settings.values[notificationBannerSeenKey] = true;
      harness.container.invalidate(notificationBannerVisibleProvider);

      expect(
        await harness.container.read(notificationBannerVisibleProvider.future),
        isFalse,
      );
    });
  });

  group('following the running session', () {
    test('schedules when a session starts and cancels when it ends', () async {
      harness.container.listen(sessionAlertsSyncProvider, (_, _) {});
      harness.container.listen(runningSessionProvider, (_, _) {});
      await pumpEventQueue();
      expect(harness.notifications.log, ['cancel $sessionEndNotificationId']);

      final session = await startSession();
      await pumpEventQueue();
      expect(
        harness.notifications.pending.containsKey(sessionEndNotificationId),
        isTrue,
      );

      await harness.sessions.finish(session.id);
      await pumpEventQueue();
      expect(harness.notifications.pending, isEmpty);
    });

    test('ignores re-emissions that change nothing', () async {
      harness.container.listen(sessionAlertsSyncProvider, (_, _) {});
      harness.container.listen(runningSessionProvider, (_, _) {});
      final session = await startSession();
      await pumpEventQueue();
      final calls = harness.notifications.log.length;

      // An unrelated event edit makes the running-session stream emit again.
      await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Email',
        tone: Tone.inbox,
        range: const MinuteRange(900, 930),
      );
      await pumpEventQueue();

      expect(harness.notifications.log.length, calls);
      expect(harness.sessions.running!.id, session.id);
    });
  });
}
