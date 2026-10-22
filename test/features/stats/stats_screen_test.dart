import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:altidial/features/reflections/reflections_screen.dart';
import 'package:altidial/features/stats/stats_screen.dart';
import 'package:altidial/shared/charts/heatmap_painter.dart';
import 'package:altidial/shared/charts/paired_bars_painter.dart';
import 'package:altidial/shared/charts/stacked_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

class _ThrowingStatsRepository implements StatsRepository {
  @override
  Stream<StatsSnapshot> watchWindow(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    throw StateError('unreadable');
  }
}

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  StatsSnapshot filled() => StatsSnapshot(
    toneByDay: [
      (date: DateTime(2026, 10, 5), tone: Tone.focus, minutes: 150),
      (date: DateTime(2026, 10, 5), tone: Tone.life, minutes: 60),
      (date: DateTime(2026, 10, 6), tone: Tone.focus, minutes: 90),
      (date: DateTime(2026, 10, 6), tone: Tone.inbox, minutes: 30),
    ],
    plannedByTone: const [
      (tone: Tone.focus, plannedMinutes: 300, completedMinutes: 240),
      (tone: Tone.life, plannedMinutes: 60, completedMinutes: 60),
      (tone: Tone.inbox, plannedMinutes: 30, completedMinutes: 30),
    ],
    focus: const FocusDepth(
      minutes: 240,
      longestSeconds: 5400,
      averageSeconds: 3600,
      ended: 5,
      abandoned: 1,
    ),
    focusInstants: [
      (startedAt: DateTime(2026, 10, 5, 9), activeSeconds: 5400),
      (startedAt: DateTime(2026, 10, 5, 10), activeSeconds: 3600),
      (startedAt: DateTime(2026, 10, 6, 21), activeSeconds: 5400),
    ],
  );

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const StatsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the four sections with the current range', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    for (final title in [
      Strings.statsToneBalance,
      Strings.statsPlannedActual,
      Strings.statsFocusDepth,
      Strings.statsHeatmap,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text(Strings.statsPeriodWeek), findsOneWidget);
    expect(find.textContaining('–'), findsOneWidget);
  });

  testWidgets('the month toggle re-queries a month window', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    await tester.tap(find.text(Strings.statsPeriodMonth));
    await tester.pumpAndSettle();

    final first = harness.stats.requests.first;
    final last = harness.stats.requests.last;
    expect(first.to.difference(first.from).inDays, 7);
    expect(last.to.difference(last.from).inDays, greaterThanOrEqualTo(28));
  });

  testWidgets('chevrons move the window and back again', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('stats-previous')));
    await tester.pumpAndSettle();
    final back = harness.stats.requests.last;
    final start = harness.stats.requests.first;
    expect(
      back.from,
      DateTime(start.from.year, start.from.month, start.from.day - 7),
    );

    await tester.tap(find.byKey(const ValueKey('stats-next')));
    await tester.pumpAndSettle();
    expect(harness.stats.requests.last.from, start.from);
  });

  testWidgets('an empty snapshot shows all four empty states', (tester) async {
    await mount(tester);

    for (final message in [
      Strings.statsEmptyToneBalance,
      Strings.statsEmptyPlanned,
      Strings.statsEmptyFocus,
      Strings.statsEmptyHeatmap,
    ]) {
      expect(find.text(message), findsOneWidget);
    }
    // No chart paints when empty (IconButtons use framework CustomPaint, so
    // match only our painters).
    bool isStatsChart(Widget widget) =>
        widget is CustomPaint &&
        (widget.painter is StackedBarsPainter ||
            widget.painter is PairedBarsPainter ||
            widget.painter is HeatmapPainter);
    expect(find.byWidgetPredicate(isStatsChart), findsNothing);
  });

  testWidgets('the charts announce their numbers to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    harness.stats.emit(filled());
    await mount(tester);

    final tone = tester.getSemantics(
      find.byKey(const ValueKey('stats-tone-balance')),
    );
    expect(tone.label, contains('Focus'));
    final planned = tester.getSemantics(
      find.byKey(const ValueKey('stats-planned-actual')),
    );
    expect(planned.label, contains('adherence'));
    final depth = tester.getSemantics(
      find.byKey(const ValueKey('stats-focus-depth')),
    );
    expect(depth.label, contains('Total focus'));
    final heatmap = tester.getSemantics(
      find.byKey(const ValueKey('stats-heatmap')),
    );
    expect(heatmap.label, contains('Busiest'));
    handle.dispose();
  });

  testWidgets('the Journal button opens the Journal', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    await tester.tap(find.text(Strings.reflectionsTitle));
    await tester.pumpAndSettle();

    expect(find.byType(ReflectionsScreen), findsOneWidget);
  });

  testWidgets('a failed read explains itself', (tester) async {
    final broken = ClockHarness(
      overrides: [
        statsRepositoryProvider.overrideWithValue(_ThrowingStatsRepository()),
      ],
    );
    addTearDown(broken.dispose);
    await tester.pumpWidget(broken.app(const StatsScreen()));
    await tester.pumpAndSettle();

    expect(find.text(Strings.statsLoadError), findsOneWidget);
  });
}
