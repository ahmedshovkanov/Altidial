// Golden images of the StatsHub (pushed from Profile), with an iPhone in
// light and dark with a busy week, and an iPhone with an empty week. The
// period is pinned to the week of 7 October 2026, animations are off, and
// `test/flutter_test_config.dart` loads Nunito, so every image is
// deterministic and shows real text.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:energy_clock/features/stats/stats_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import 'stats_layout_matrix_test.dart' show filled;

const screenKey = ValueKey('stats-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
    harness.container.read(statsPeriodProvider.notifier).state =
        StatsPeriod.week(DateTime(2026, 10, 7));
  });

  tearDown(() {
    harness.dispose();
  });

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
    if (seeded) harness.stats.emit(filled());

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
            home: const StatsHub(),
          ),
        ),
      ),
    );
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
      file: 'stats_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'stats_iphone_dark.png',
    );
  });

  testWidgets('iPhone 17 Pro, an empty week, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'stats_iphone_empty_light.png',
      seeded: false,
    );
  });
}
