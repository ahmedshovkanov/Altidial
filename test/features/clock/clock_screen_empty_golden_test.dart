// Golden image of the Clock tab on an empty editable day: the invitation to
// drag out a first event, and the Copy yesterday and Apply template buttons
// beneath it. Animations are off and the clock is fixed at Wednesday 7 October
// 2026, 10:30, so the image is deterministic.
import 'package:altidial/app/navigation/tab_scaffold.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

const screenKey = ValueKey('clock-empty-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Yesterday has events, so Copy yesterday is offered.
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 6),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 660),
    );

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

  testWidgets('iPhone 17 Pro, empty day, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'clock_iphone_empty_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, empty day, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'clock_iphone_empty_dark.png',
    );
  });

  testWidgets('iPad 11" landscape, empty day, light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'clock_ipad_landscape_empty_light.png',
    );
  });
}
