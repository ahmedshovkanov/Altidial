import 'package:altidial/app/navigation/clock_tab.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/session/widgets/countdown_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  // The harness clock reads Wednesday 7 October 2026, 10:30:00.
  final start = DateTime(2026, 10, 7, 10, 30);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// A 30-minute event, with a session started on it at 10:30.
  Future<int> beginSession({
    String title = 'Deep work',
    Tone tone = Tone.focus,
    int begin = 600,
    int end = 630,
  }) async {
    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: title,
      tone: tone,
      range: MinuteRange(begin, end),
    );
    await harness.sessions.start(eventId: eventId);
    return eventId;
  }

  /// Moves every clock to [seconds] after the start and lets the screen
  /// redraw.
  Future<void> tickTo(WidgetTester tester, int seconds) async {
    harness.clock.set(start.add(Duration(seconds: seconds)));
    await tester.pump();
  }

  Future<void> show(
    WidgetTester tester, {
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      harness.app(
        const ClockTab(),
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    );
    await pumpDial(tester);
  }

  /// Opens the app on the Clock tab, then starts a session, as a person would.
  /// (A session that is already running when the app opens is a leftover.)
  Future<int> startAndShow(WidgetTester tester, {double textScale = 1}) async {
    await show(tester, textScale: textScale);
    final eventId = await beginSession();
    await pumpDial(tester);
    return eventId;
  }

  String timeText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('session-time'))).data!;

  String stateText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('session-state'))).data!;

  Finder button(String key) => find.byKey(ValueKey(key));

  group('what it shows', () {
    testWidgets('the title, tone, slot and the full time', (tester) async {
      await startAndShow(tester);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('10:00 – 10:30'), findsOneWidget);
      expect(timeText(tester), '30:00');
      expect(stateText(tester), Strings.sessionRemaining);
      expect(find.text('Planned 30m · ends 11:00'), findsOneWidget);
    });

    testWidgets('replaces the day while the session runs', (tester) async {
      await show(tester);
      expect(find.byType(ClockScreen), findsOneWidget);

      await beginSession();
      await pumpDial(tester);
      expect(find.byType(ClockScreen), findsNothing);
      expect(timeText(tester), '30:00');
    });

    testWidgets('counts down as the clock moves', (tester) async {
      await startAndShow(tester);

      await tickTo(tester, 90);
      expect(timeText(tester), '28:30');

      await tickTo(tester, 91);
      expect(timeText(tester), '28:29');
    });

    testWidgets('the ring empties as time passes', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 450);

      final ring = tester.widget<CountdownRing>(
        find.byKey(const ValueKey('session-ring')),
      );
      expect(ring.fraction, closeTo(0.75, 1e-9));
    });

    testWidgets('the ring is read as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await startAndShow(tester);

      expect(
        find.bySemanticsLabel('Deep work, Focus, 30 minutes left'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('pausing', () {
    testWidgets('freezes the time and offers resume', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 90);

      await tester.tap(button('session-pause'));
      await tester.pump();
      expect(harness.sessions.calls, ['start', 'pause']);
      expect(stateText(tester), Strings.sessionPaused);
      expect(find.text(Strings.sessionResume), findsOneWidget);

      await tickTo(tester, 400);
      expect(timeText(tester), '28:30');
    });

    testWidgets('resume carries on from where it stopped', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 90);
      await tester.tap(button('session-pause'));
      await tickTo(tester, 400);

      await tester.tap(button('session-pause'));
      await tester.pump();
      expect(harness.sessions.calls, ['start', 'pause', 'resume']);
      expect(stateText(tester), Strings.sessionRemaining);

      await tickTo(tester, 460);
      // Paused from 90 s to 400 s, so 150 s of the 460 have been worked.
      expect(timeText(tester), '27:30');
    });
  });

  group('adding time', () {
    testWidgets('+5m and +15m lengthen the session', (tester) async {
      await startAndShow(tester);

      await tester.tap(button('session-add-5'));
      await tester.pump();
      expect(timeText(tester), '35:00');

      await tester.tap(button('session-add-15'));
      await tester.pump();
      expect(timeText(tester), '50:00');
      expect(harness.sessions.calls, ['start', 'extend 300', 'extend 900']);
    });

    testWidgets('the buttons are spoken in full', (tester) async {
      final handle = tester.ensureSemantics();
      await startAndShow(tester);

      expect(find.bySemanticsLabel('Add 5 minutes'), findsOneWidget);
      expect(find.bySemanticsLabel('Add 15 minutes'), findsOneWidget);
      handle.dispose();
    });
  });

  group('overtime', () {
    testWidgets('turns red and counts up', (tester) async {
      await startAndShow(tester);

      await tickTo(tester, 1800 + 10);

      expect(timeText(tester), '+00:10');
      expect(stateText(tester), Strings.sessionOvertime);
      final ring = tester.widget<CountdownRing>(
        find.byKey(const ValueKey('session-ring')),
      );
      expect(ring.color, AppColors.light.danger);
      expect(ring.fraction, 1);
      expect(find.text('Planned 30m · was due 11:00'), findsOneWidget);
    });

    testWidgets('pausing in overtime keeps the was-due footer', (tester) async {
      await startAndShow(tester);

      await tickTo(tester, 1800 + 10);
      await tester.tap(button('session-pause'));
      await tester.pump();

      expect(stateText(tester), Strings.sessionPaused);
      expect(find.text('Planned 30m · was due 11:00'), findsOneWidget);
    });

    testWidgets('Finish takes over from Finish early', (tester) async {
      await startAndShow(tester);
      expect(find.text(Strings.sessionFinishEarly), findsOneWidget);

      await tickTo(tester, 1800 + 10);

      expect(find.text(Strings.sessionFinishEarly), findsNothing);
      expect(find.text(Strings.sessionFinish), findsOneWidget);
    });

    testWidgets('adding time takes it back out of overtime', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 1800 + 10);

      await tester.tap(button('session-add-15'));
      await tester.pump();

      expect(timeText(tester), '14:50');
      expect(stateText(tester), Strings.sessionRemaining);
    });

    testWidgets('one firm tap when the time runs out, none before', (
      tester,
    ) async {
      final haptics = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await startAndShow(tester);

      await tickTo(tester, 1799);
      expect(haptics, isEmpty);

      await tickTo(tester, 1800);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);

      await tickTo(tester, 1801);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);
    });
  });

  group('finishing', () {
    testWidgets('early records the time worked and completes the event', (
      tester,
    ) async {
      final eventId = await startAndShow(tester);
      await tickTo(tester, 12 * 60);

      await tester.tap(button('session-finish'));
      await pumpDial(tester);

      final done = harness.sessions.ended.single;
      expect(done.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 12 * 60);
      expect(
        harness.repository.eventById(eventId)!.status,
        EventStatus.completed,
      );
      expect(find.text('Logged 12m on Deep work.'), findsOneWidget);
      expect(find.byType(ClockScreen), findsOneWidget);
    });

    testWidgets('after the planned end counts as completed', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 1800 + 60);

      await tester.tap(button('session-finish'));
      await pumpDial(tester);

      final done = harness.sessions.ended.single;
      expect(done.outcome, SessionOutcome.completed);
      expect(done.overtimeSeconds, 60);
    });

    testWidgets('a very short session still logs 1m, never 0m', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 10);

      await tester.tap(button('session-finish'));
      await pumpDial(tester);

      expect(find.text('Logged 1m on Deep work.'), findsOneWidget);
      expect(find.text('Logged 0m on Deep work.'), findsNothing);
    });
  });

  group('abandoning', () {
    testWidgets('asks first, and keep going changes nothing', (tester) async {
      await startAndShow(tester);

      await tester.tap(button('session-abandon'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text(Strings.sessionAbandonTitle), findsOneWidget);

      await tester.tap(find.text(Strings.sessionKeepGoing));
      await pumpDial(tester);

      expect(harness.sessions.ended, isEmpty);
      expect(timeText(tester), '30:00');
    });

    testWidgets('confirming records it as abandoned', (tester) async {
      final eventId = await startAndShow(tester);
      await tickTo(tester, 300);

      await tester.tap(button('session-abandon'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, Strings.sessionAbandon),
        ),
      );
      await pumpDial(tester);

      expect(harness.sessions.ended.single.outcome, SessionOutcome.abandoned);
      expect(
        harness.repository.eventById(eventId)!.status,
        EventStatus.planned,
      );
      expect(find.text(Strings.sessionAbandoned), findsOneWidget);
      expect(find.byType(ClockScreen), findsOneWidget);
    });

    testWidgets('the debrief sheet shows the time actually spent, not 0m', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 300);

      await tester.tap(button('session-abandon'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, Strings.sessionAbandon),
        ),
      );
      await pumpDial(tester);

      expect(find.text('Deep work · 5m'), findsOneWidget);
      expect(find.text('Deep work · 0m'), findsNothing);
    });
  });

  group('a session left running by a killed app', () {
    Future<int> seedLeftover(WidgetTester tester) async {
      final eventId = await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
      );
      // Started at 10:10, so at 10:30 it has run 20 minutes of 60.
      harness.sessions.seedRunning(
        eventId: eventId,
        startedAt: DateTime(2026, 10, 7, 10, 10),
        plannedSeconds: 3600,
      );
      return eventId;
    }

    testWidgets('offers to resume or close out, instead of the controls', (
      tester,
    ) async {
      await seedLeftover(tester);
      await show(tester);

      expect(find.text(Strings.recoveryTitle), findsOneWidget);
      expect(find.textContaining('Deep work has been going for 20m'), findsOne);
      expect(button('session-pause'), findsNothing);
      expect(timeText(tester), '40:00');
    });

    testWidgets('says "under a minute" rather than 0m for a fresh one', (
      tester,
    ) async {
      final id = await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
      );
      harness.sessions.seedRunning(
        eventId: id,
        startedAt: DateTime(2026, 10, 7, 10, 29, 30),
      );
      await show(tester);

      expect(
        find.textContaining('Deep work has been going for under a minute'),
        findsOneWidget,
      );
    });

    testWidgets('resume carries on and brings the controls back', (
      tester,
    ) async {
      await seedLeftover(tester);
      await show(tester);

      await tester.tap(button('recovery-resume'));
      await pumpDial(tester);

      expect(find.text(Strings.recoveryTitle), findsNothing);
      expect(button('session-pause'), findsOneWidget);
      expect(harness.sessions.calls, isEmpty);
    });

    testWidgets('close out ends it and returns to the day', (tester) async {
      await seedLeftover(tester);
      await show(tester);

      await tester.tap(button('recovery-close-out'));
      await pumpDial(tester);

      expect(harness.sessions.calls, ['closeOut']);
      final done = harness.sessions.ended.single;
      expect(done.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 20 * 60);
      expect(find.byType(ClockScreen), findsOneWidget);
      expect(find.text('Logged 20m on Deep work.'), findsOneWidget);
    });

    testWidgets('a session started this launch is never offered', (
      tester,
    ) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      expect(find.text(Strings.recoveryTitle), findsNothing);
      expect(button('session-pause'), findsOneWidget);
    });
  });

  group('when notifications are off', () {
    setUp(() {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;
    });

    testWidgets('a one-time banner explains it', (tester) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      expect(find.text(Strings.alertsOffTitle), findsOneWidget);
      expect(timeText(tester), '30:00');
    });

    testWidgets('dismissing it hides it for good', (tester) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      await tester.tap(button('alerts-dismiss'));
      await pumpDial(tester);

      expect(find.text(Strings.alertsOffTitle), findsNothing);
      expect(harness.settings.values['notification_banner_seen'], isTrue);
    });

    testWidgets('Open Settings opens the settings and hides the banner', (
      tester,
    ) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      await tester.tap(button('alerts-open-settings'));
      await pumpDial(tester);

      expect(harness.notifications.settingsOpened, 1);
      expect(find.text(Strings.alertsOffTitle), findsNothing);
    });
  });

  testWidgets('starting a session schedules the alert for its end', (
    tester,
  ) async {
    await show(tester);
    await beginSession();
    await pumpDial(tester);

    final pending = harness.notifications.pending.values.single;
    expect(pending.at, DateTime(2026, 10, 7, 11, 0));
  });
}
