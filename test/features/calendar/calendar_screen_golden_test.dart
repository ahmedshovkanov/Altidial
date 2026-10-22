// Golden images of the Calendar tab, with the floating tab bar: an iPhone in
// light and dark with a month of mixed plans, an iPhone with an empty month,
// and an iPad in landscape. The clock is fixed at Wednesday 7 October 2026,
// 10:30, animations are off, and `test/flutter_test_config.dart` loads Nunito,
// so every image is deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const screenKey = ValueKey('calendar-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// October 2026: a mix of one, two and three tones, a day of almost only
  /// one tone, and nothing at all on some days.
  Future<void> seedOctober() async {
    Future<void> plan(int day, List<(Tone, int)> blocks) async {
      var start = 360;
      for (final (tone, minutes) in blocks) {
        await harness.repository.createEvent(
          day: DateTime(2026, 10, day),
          title: 'Event',
          tone: tone,
          range: MinuteRange(start, start + minutes),
        );
        start += 240;
      }
    }

    await plan(1, [(Tone.focus, 180), (Tone.life, 60)]);
    await plan(2, [(Tone.inbox, 90)]);
    await plan(3, [(Tone.life, 120)]);
    await plan(5, [(Tone.focus, 240), (Tone.life, 90), (Tone.inbox, 60)]);
    await plan(6, [(Tone.focus, 120)]);
    await plan(7, [(Tone.focus, 180), (Tone.life, 60), (Tone.inbox, 90)]);
    await plan(8, [(Tone.inbox, 45), (Tone.life, 45)]);
    await plan(9, [(Tone.focus, 235), (Tone.life, 5)]);
    await plan(12, [(Tone.life, 60)]);
    await plan(13, [(Tone.focus, 120), (Tone.inbox, 60)]);
    await plan(14, [(Tone.focus, 60), (Tone.life, 60), (Tone.inbox, 60)]);
    await plan(15, [(Tone.focus, 200)]);
    await plan(19, [(Tone.inbox, 30), (Tone.life, 90)]);
    await plan(20, [(Tone.focus, 150), (Tone.inbox, 30)]);
    await plan(21, [(Tone.life, 45)]);
    await plan(26, [(Tone.focus, 90), (Tone.life, 30)]);
    await plan(28, [(Tone.inbox, 60)]);
    await plan(30, [(Tone.focus, 120), (Tone.life, 120), (Tone.inbox, 120)]);
  }

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
    bool seeded = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (seeded) await seedOctober();

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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpAndSettle();

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
      file: 'calendar_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'calendar_iphone_dark.png',
    );
  });

  testWidgets('iPhone 17 Pro, an empty month, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'calendar_iphone_empty_light.png',
      seeded: false,
    );
  });

  testWidgets('iPad 11" landscape, light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'calendar_ipad_landscape_light.png',
    );
  });
}
