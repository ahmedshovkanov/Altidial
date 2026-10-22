// Golden images of the session screen inside the real tab shell: the countdown
// running, in overtime, paused, a session found after a kill, and the wide
// iPad layout. The clock is fixed at Wednesday 7 October 2026, 10:30,
// animations are off, and `test/flutter_test_config.dart` loads Nunito, so
// every image is deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

const screenKey = ValueKey('session-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// Opens the shell, starts a session on a new event and moves the clock
  /// [secondsIn] seconds after the 10:30 start. [leftover] makes it a session
  /// found at launch instead.
  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
    String title = 'Deep work',
    Tone tone = Tone.focus,
    int begin = 600,
    int end = 690,
    int secondsIn = 0,
    bool pause = false,
    bool leftover = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: title,
      tone: tone,
      range: MinuteRange(begin, end),
    );
    if (leftover) {
      harness.sessions.seedRunning(
        eventId: eventId,
        startedAt: DateTime(2026, 10, 7, 10, 10),
        plannedSeconds: (end - begin) * 60,
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: RepaintBoundary(
          key: screenKey,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const TabScaffold(),
          ),
        ),
      ),
    );
    await pumpDial(tester);

    if (!leftover) {
      final sessionId = await harness.sessions.start(eventId: eventId);
      await pumpDial(tester);
      harness.clock.set(
        DateTime(2026, 10, 7, 10, 30).add(Duration(seconds: secondsIn)),
      );
      if (pause) {
        await harness.sessions.pause(sessionId);
      }
      await pumpDial(tester);
    }
    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone, running a Focus session, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'session_iphone_running_light.png',
      secondsIn: 23 * 60 + 17,
    );
  });

  testWidgets('iPhone, overtime, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'session_iphone_overtime_dark.png',
      title: 'Email and calls',
      tone: Tone.inbox,
      begin: 600,
      end: 645,
      secondsIn: 45 * 60 + 125,
    );
  });

  testWidgets('iPhone, paused Life session, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'session_iphone_paused_light.png',
      title: 'Lunch walk',
      tone: Tone.life,
      begin: 600,
      end: 645,
      secondsIn: 12 * 60,
      pause: true,
    );
  });

  testWidgets('iPhone, a session found after the app was killed, light', (
    tester,
  ) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'session_iphone_recovery_light.png',
      leftover: true,
    );
  });

  testWidgets('small iPhone, running, dark', (tester) async {
    await check(
      tester,
      size: const Size(375, 667),
      theme: AppTheme.dark,
      file: 'session_iphone_se_running_dark.png',
      secondsIn: 5 * 60,
    );
  });

  testWidgets('iPad 13" landscape (wide), running an Inbox session, dark', (
    tester,
  ) async {
    await check(
      tester,
      size: const Size(1376, 1032),
      theme: AppTheme.dark,
      file: 'session_ipad_landscape_dark.png',
      title: 'Email and calls',
      tone: Tone.inbox,
      begin: 600,
      end: 660,
      secondsIn: 8 * 60,
    );
  });

  testWidgets('iPad 11" portrait (medium), running, light', (tester) async {
    await check(
      tester,
      size: const Size(834, 1194),
      theme: AppTheme.light,
      file: 'session_ipad_portrait_light.png',
      secondsIn: 40 * 60,
    );
  });
}
