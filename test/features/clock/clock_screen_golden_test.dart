// Golden images of the whole Clock tab, with the floating tab bar, at the three
// window classes: an iPhone in light and dark mode, an iPad in portrait
// (medium, one column) and an iPad in landscape (wide, two panes). The clock is
// fixed at Wednesday 7 October 2026, 10:30, animations are off, and
// `test/flutter_test_config.dart` loads Nunito, so every image is
// deterministic and shows real text.
import 'package:altidial/app/navigation/tab_scaffold.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

const screenKey = ValueKey('clock-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> seed() async {
    for (final (title, tone, start, end) in [
      ('Deep work', Tone.focus, 540, 720),
      ('Walk', Tone.life, 600, 660),
      ('Lunch', Tone.life, 750, 795),
      ('Email and calls', Tone.inbox, 840, 900),
      ('Writing', Tone.focus, 960, 1080),
    ]) {
      await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );
    }
    // A planned tone on another day, so the week strip shows a dot there too.
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 8),
      title: 'Plan',
      tone: Tone.inbox,
      range: const MinuteRange(540, 600),
    );
  }

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed();

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
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone 17 Pro, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'clock_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'clock_iphone_dark.png',
    );
  });

  testWidgets('iPad 11" portrait (medium), light', (tester) async {
    await check(
      tester,
      size: const Size(834, 1194),
      theme: AppTheme.light,
      file: 'clock_ipad_portrait_light.png',
    );
  });

  testWidgets('iPad 11" landscape (wide, two panes), light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'clock_ipad_landscape_light.png',
    );
  });
}
