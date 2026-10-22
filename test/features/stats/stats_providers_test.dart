import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/heatmap.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_settings_repository.dart';
import '../../support/fake_stats_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeStatsRepository stats;
  late ProviderContainer container;

  // Wednesday 7 October 2026.
  final wednesday = DateTime(2026, 10, 7);

  setUp(() {
    settings = FakeSettingsRepository();
    stats = FakeStatsRepository();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        statsRepositoryProvider.overrideWithValue(stats),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    stats.dispose();
  });

  void setWeek(DateTime anchor) {
    container.read(statsPeriodProvider.notifier).state = StatsPeriod.week(
      anchor,
    );
  }

  test('the initial period is the current week', () {
    final period = container.read(statsPeriodProvider);
    expect(period.kind, StatsPeriodKind.week);
    expect(
      period.anchor.isBefore(DateTime.now().add(const Duration(days: 1))),
      isTrue,
    );
  });

  test('switching kind keeps the anchor', () {
    setWeek(wednesday);
    container.read(statsPeriodProvider.notifier).setKind(StatsPeriodKind.month);
    final period = container.read(statsPeriodProvider);
    expect(period.kind, StatsPeriodKind.month);
    expect(period.anchor, wednesday);
  });

  test('previous moves a week and a month back', () {
    setWeek(wednesday);
    container.read(statsPeriodProvider.notifier).previous();
    expect(container.read(statsPeriodProvider).anchor, DateTime(2026, 9, 30));

    setWeek(wednesday);
    container.read(statsPeriodProvider.notifier).setKind(StatsPeriodKind.month);
    container.read(statsPeriodProvider.notifier).previous();
    expect(container.read(statsPeriodProvider).anchor, DateTime(2026, 9));
  });

  test('next never enters the future', () {
    setWeek(DateTime(2026, 9, 30));
    final notifier = container.read(statsPeriodProvider.notifier);
    notifier.next();
    final back = container.read(statsPeriodProvider).anchor;
    expect(back.isAfter(DateTime(2026, 9, 30)), isTrue);
    expect(back.isBefore(DateTime.now().add(const Duration(days: 8))), isTrue);

    // From the current week, next is a no-op.
    notifier.returnToNow();
    final current = container.read(statsPeriodProvider).anchor;
    notifier.next();
    expect(container.read(statsPeriodProvider).anchor, current);
  });

  test('a month window spans the calendar month', () {
    container.read(statsPeriodProvider.notifier).state = StatsPeriod.month(
      DateTime(2026, 10, 15),
    );
    expect(container.read(statsWindowProvider), (
      from: DateTime(2026, 10),
      toExclusive: DateTime(2026, 11),
      dayCount: 31,
    ));
  });

  test('a week window starts on the first day of the week', () async {
    setWeek(wednesday);
    expect(container.read(statsWindowProvider).from, DateTime(2026, 10, 5));

    settings.values['first_day_of_week'] = '7';
    container.invalidate(firstDayOfWeekProvider);
    await container.read(firstDayOfWeekProvider.future);
    expect(container.read(statsWindowProvider).from, DateTime(2026, 10, 4));
  });

  test('the heatmap buckets by local weekday and hour, rows rotated', () {
    final instants = [
      (startedAt: DateTime(2026, 10, 5, 9, 5), activeSeconds: 3600),
      (startedAt: DateTime(2026, 10, 5, 9, 40), activeSeconds: 1800),
      (startedAt: DateTime(2026, 10, 11, 22), activeSeconds: 600),
    ];
    final mondayFirst = buildHeatmap(instants);
    expect(mondayFirst, hasLength(7));
    expect(mondayFirst.every((row) => row.length == 24), isTrue);
    expect(mondayFirst[0][9], 90);
    expect(mondayFirst[6][22], 10);

    // Sunday-first: Monday's 09:00 cell moves to row 1, Sunday's to row 0.
    final sundayFirst = buildHeatmap(instants, firstWeekday: DateTime.sunday);
    expect(sundayFirst[1][9], 90);
    expect(sundayFirst[0][22], 10);
  });

  test('the heatmap truncates per cell after summing', () {
    final instants = [
      (startedAt: DateTime(2026, 10, 5, 9), activeSeconds: 30),
      (startedAt: DateTime(2026, 10, 5, 9, 30), activeSeconds: 30),
    ];
    expect(buildHeatmap(instants)[0][9], 1);
    expect(buildHeatmap(const [])[3][12], 0);
  });

  test(
    'the data provider serves the fake snapshot and records its window',
    () async {
      setWeek(wednesday);
      stats.emit(
        StatsSnapshot(
          toneByDay: [
            (date: DateTime(2026, 10, 6), tone: Tone.focus, minutes: 90),
          ],
          plannedByTone: const [
            (tone: Tone.focus, plannedMinutes: 100, completedMinutes: 90),
          ],
          focus: const FocusDepth.zero(),
          focusInstants: const [],
        ),
      );

      final snapshot = await container.read(statsDataProvider.future);
      expect(snapshot.completedTotal, 90);
      expect(stats.requests.single, (
        from: DateTime(2026, 10, 5),
        to: DateTime(2026, 10, 12),
      ));
    },
  );
}
