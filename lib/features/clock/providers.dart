import 'dart:async';

import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The day the Clock tab is showing. Always local midnight. "Today" is the
/// shared clock's today, so tests that fake the clock get a fake today too.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => startOfDay(ref.read(clockProvider));

  void select(DateTime day) => state = startOfDay(day);
  void next() => state = nextDay(state);
  void previous() => state = previousDay(state);
  void today() => state = startOfDay(ref.read(clockProvider));
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

final dayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(ref.watch(selectedDateProvider));
});

/// The events of the day before the selected one, to know whether "Copy
/// yesterday" has anything to copy.
final previousDayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(previousDay(ref.watch(selectedDateProvider)));
});

/// The current time, updated once a minute. The one shared source for
/// everything on the Clock screen that depends on "now". Tests override it with
/// `clockProvider.overrideWith(() => FakeClock(...))`.
class ClockNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = DateTime.now();
    _schedule(now);
    ref.onDispose(() => _timer?.cancel());
    return now;
  }

  void _schedule(DateTime now) {
    _timer = Timer(untilNextMinute(now), () {
      final tick = DateTime.now();
      state = tick;
      _schedule(tick);
    });
  }
}

final clockProvider = NotifierProvider<ClockNotifier, DateTime>(
  ClockNotifier.new,
);

/// The tones planned on each day of the week that starts at the keyed Monday,
/// for the week strip's dots. Each page of the strip watches its own week.
final weekTonesProvider =
    StreamProvider.family<Map<DateTime, Set<Tone>>, DateTime>((ref, weekStart) {
      final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
      return ref.watch(eventRepositoryProvider).watchTonesByDay(weekStart, end);
    });

/// The saved day templates, newest first, for the template picker.
final templatesProvider = StreamProvider<List<DayTemplate>>((ref) {
  return ref.watch(reuseRepositoryProvider).watchTemplates();
});

/// How a series repeats, keyed by series id, for the detail sheet. Null when
/// the series no longer exists.
final seriesRuleProvider = FutureProvider.family<RecurrenceRule?, int>((
  ref,
  seriesId,
) {
  return ref.watch(seriesRepositoryProvider).ruleFor(seriesId);
});
