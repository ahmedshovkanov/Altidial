import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The week or month the Stats tab shows.
final statsPeriodProvider = NotifierProvider<StatsPeriodNotifier, StatsPeriod>(
  StatsPeriodNotifier.new,
);

/// The concrete window of the shown period. Weeks start on the first day of
/// the week (the setting, Monday by default).
final statsWindowProvider = Provider<StatsWindow>((ref) {
  final period = ref.watch(statsPeriodProvider);
  final firstWeekday =
      ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
  return switch (period.kind) {
    StatsPeriodKind.week => _weekWindow(period.anchor, firstWeekday),
    StatsPeriodKind.month => _monthWindow(period.anchor),
  };
});

StatsWindow _weekWindow(DateTime anchor, int firstWeekday) {
  final from = startOfWeek(anchor, firstWeekday: firstWeekday);
  return (
    from: from,
    toExclusive: DateTime(from.year, from.month, from.day + 7),
    dayCount: 7,
  );
}

StatsWindow _monthWindow(DateTime anchor) {
  final from = startOfMonth(anchor);
  return (
    from: from,
    toExclusive: addMonths(from, 1),
    dayCount: daysInMonth(anchor),
  );
}

/// The snapshot for the shown window. Watches the window, so a period or
/// first-day change re-queries.
final statsDataProvider = StreamProvider<StatsSnapshot>((ref) {
  final window = ref.watch(statsWindowProvider);
  return ref
      .watch(statsRepositoryProvider)
      .watchWindow(window.from, window.toExclusive);
});
