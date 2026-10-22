import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which shape of past the Stats tab shows.
enum StatsPeriodKind { week, month }

/// One week or one month, pinned by a local midnight inside it.
class StatsPeriod {
  const StatsPeriod.week(this.anchor) : kind = StatsPeriodKind.week;
  const StatsPeriod.month(this.anchor) : kind = StatsPeriodKind.month;

  final StatsPeriodKind kind;
  final DateTime anchor;
}

/// The concrete window a period maps to. `toExclusive` is a local midnight.
typedef StatsWindow = ({DateTime from, DateTime toExclusive, int dayCount});

/// The shown period. Starts on the current week; the chevrons never move past
/// it. Uses the wall clock directly: no feature may import the Clock's
/// providers, and the tests pin the state explicitly.
class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.week(startOfDay(DateTime.now()));

  void setKind(StatsPeriodKind kind) {
    if (state.kind == kind) return;
    state = kind == StatsPeriodKind.week
        ? StatsPeriod.week(state.anchor)
        : StatsPeriod.month(state.anchor);
  }

  void previous() {
    final anchor = state.anchor;
    state = switch (state.kind) {
      StatsPeriodKind.week => StatsPeriod.week(
        DateTime(anchor.year, anchor.month, anchor.day - 7),
      ),
      StatsPeriodKind.month => StatsPeriod.month(addMonths(anchor, -1)),
    };
  }

  void next() {
    final anchor = state.anchor;
    final candidate = switch (state.kind) {
      StatsPeriodKind.week => StatsPeriod.week(
        DateTime(anchor.year, anchor.month, anchor.day + 7),
      ),
      StatsPeriodKind.month => StatsPeriod.month(addMonths(anchor, 1)),
    };
    if (_startsAfterNow(candidate)) return;
    state = candidate;
  }

  void returnToNow() {
    final today = startOfDay(DateTime.now());
    state = state.kind == StatsPeriodKind.week
        ? StatsPeriod.week(today)
        : StatsPeriod.month(today);
  }

  bool _startsAfterNow(StatsPeriod candidate) {
    final now = startOfDay(DateTime.now());
    return switch (candidate.kind) {
      StatsPeriodKind.week => startOfWeek(
        candidate.anchor,
      ).isAfter(startOfWeek(now)),
      StatsPeriodKind.month => startOfMonth(
        candidate.anchor,
      ).isAfter(startOfMonth(now)),
    };
  }
}
