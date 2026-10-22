// The Stats tab at every window size the app supports, four text scales, a
// busy week, an empty week and a busy month: nothing overflows, everything
// scrolls into view, and no frame throws.
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

/// The window sizes every tab is tested at.
const sizes = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 17 Pro': Size(402, 874),
  'iPad mini portrait': Size(744, 1133),
  'iPad 11" portrait': Size(834, 1194),
  'iPad 11" landscape': Size(1194, 834),
  'iPad 13" portrait': Size(1032, 1376),
  'iPad 13" landscape': Size(1376, 1032),
  'narrow Split View': Size(320, 1000),
};

/// The tab bar's reserve on a phone with no home indicator.
const double shellInset = 84;

StatsSnapshot filled() => StatsSnapshot(
  toneByDay: [
    for (var day = 5; day <= 11; day++)
      for (final tone in Tone.values)
        (
          date: DateTime(2026, 10, day),
          tone: tone,
          minutes: 20 + ((day * (tone.dbIndex + 2)) % 120),
        ),
  ],
  plannedByTone: const [
    (tone: Tone.focus, plannedMinutes: 900, completedMinutes: 640),
    (tone: Tone.life, plannedMinutes: 420, completedMinutes: 380),
    (tone: Tone.inbox, plannedMinutes: 180, completedMinutes: 200),
  ],
  focus: const FocusDepth(
    minutes: 640,
    longestSeconds: 7200,
    averageSeconds: 3200,
    ended: 13,
    abandoned: 2,
  ),
  focusInstants: [
    for (var day = 5; day <= 11; day++)
      for (final hour in [8, 12, 19])
        (
          startedAt: DateTime(2026, 10, day, hour),
          activeSeconds: 1800 + ((day * hour) % 3600),
        ),
  ],
);

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  for (final entry in sizes.entries) {
    final size = entry.value;
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final (label, seed, month) in const [
        ('a busy week', true, false),
        ('an empty week', false, false),
        ('a busy month', true, true),
      ]) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, $label',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            if (seed) harness.stats.emit(filled());
            if (month) {
              harness.container.read(statsPeriodProvider.notifier).state =
                  StatsPeriod.month(DateTime(2026, 10, 15));
            } else {
              // Pin the week so the range label is deterministic.
              harness.container.read(statsPeriodProvider.notifier).state =
                  StatsPeriod.week(DateTime(2026, 10, 7));
            }

            await tester.pumpWidget(
              harness.app(
                TabBarInset(height: shellInset, child: const StatsScreen()),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            for (final title in [
              Strings.statsToneBalance,
              Strings.statsPlannedActual,
              Strings.statsFocusDepth,
              Strings.statsHeatmap,
            ]) {
              expect(find.text(title), findsOneWidget);
            }

            // Every card stays inside the window horizontally.
            for (final card in find.byType(AppCard).evaluate()) {
              final rect = tester.getRect(find.byWidget(card.widget));
              expect(rect.left, greaterThanOrEqualTo(-0.5));
              expect(rect.right, lessThanOrEqualTo(size.width + 0.5));
            }

            // The last section scrolls into view without throwing.
            await tester.drag(
              find.byType(SingleChildScrollView),
              const Offset(0, -3000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text(Strings.statsHeatmap), findsOneWidget);
          },
        );
      }
    }
  }
}
