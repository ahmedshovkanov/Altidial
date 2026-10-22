import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/core/coach/planner.dart';
import 'package:altidial/core/coach/reflection_summary.dart';
import 'package:altidial/core/roundup/iso_week.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/reflections/providers.dart';
import 'package:altidial/features/stats/model/heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final todayIntentProvider = StreamProvider(
  (ref) => ref
      .watch(coachRepositoryProvider)
      .watchIntent(ref.watch(selectedDateProvider)),
);

final todayReviewProvider = StreamProvider(
  (ref) => ref
      .watch(coachRepositoryProvider)
      .watchReview(ref.watch(selectedDateProvider)),
);

/// The 28-day focus window ending on the selected day: the history the
/// suggestions read the person's peak hours from.
final coachWindowProvider = StreamProvider<StatsSnapshot>((ref) {
  final day = ref.watch(selectedDateProvider);
  final from = startOfDay(day.subtract(const Duration(days: 27)));
  final toExclusive = nextDay(day);
  return ref.watch(statsRepositoryProvider).watchWindow(from, toExclusive);
});

/// The two hours with the most focus minutes in [snapshot], busiest first.
/// Empty when nothing was focused: with no history there is no peak to
/// suggest, so callers show the empty state instead of guessing.
List<int> topPeakHours(StatsSnapshot snapshot) {
  final matrix = buildHeatmap(snapshot.focusInstants);
  final totals = List.filled(24, 0);
  for (final row in matrix) {
    for (var hour = 0; hour < 24; hour++) {
      totals[hour] += row[hour];
    }
  }
  final ranked = [for (var hour = 0; hour < 24; hour++) hour]
    ..sort((a, b) {
      final byMinutes = totals[b].compareTo(totals[a]);
      return byMinutes != 0 ? byMinutes : a.compareTo(b);
    });
  return ranked.where((hour) => totals[hour] > 0).take(2).toList();
}

/// Today's swap suggestions: the day's events against the top-2 peak hours
/// of the 28-day focus window. Suggests only, never moves anything.
final suggestionsProvider = Provider<AsyncValue<List<SwapSuggestion>>>((ref) {
  final events = ref.watch(dayEventsProvider);
  final window = ref.watch(coachWindowProvider);
  final focusTarget =
      ref.watch(focusTargetProvider).valueOrNull ??
      defaultDailyFocusTargetMinutes;
  return events.when(
    data: (list) => window.when(
      data: (snapshot) => AsyncValue.data(
        suggestSwaps(
          today: list,
          peakHours: topPeakHours(snapshot),
          focusTargetMinutes: focusTarget,
        ),
      ),
      error: (error, stackTrace) =>
          AsyncValue<List<SwapSuggestion>>.error(error, stackTrace),
      loading: () => const AsyncValue<List<SwapSuggestion>>.loading(),
    ),
    error: (error, stackTrace) =>
        AsyncValue<List<SwapSuggestion>>.error(error, stackTrace),
    loading: () => const AsyncValue<List<SwapSuggestion>>.loading(),
  );
});

/// Today's reflection aggregates for the Coach review block, derived from
/// the live reflections timeline filtered to the selected day. Read-only:
/// never writes sessions or reviews.
final todayReflectionSummaryProvider =
    Provider<AsyncValue<ReflectionSummary>>((ref) {
      final timeline = ref.watch(reflectionsTimelineProvider);
      final day = ref.watch(selectedDateProvider);
      return timeline.when(
        data: (rows) {
          final dayStart = startOfDay(day);
          final today = rows
              .where((r) => startOfDay(r.eventDate) == dayStart)
              .toList();
          return AsyncValue.data(
            summarizeReflections([
              for (final r in today)
                (
                  energy: r.session.energyRating,
                  focus: r.session.focusRating,
                  tags: r.session.tags,
                ),
            ]),
          );
        },
        error: (e, st) => AsyncValue.error(e, st),
        loading: () => const AsyncValue.loading(),
      );
    });

/// This week's frozen insight cards. The first watch of the week generates
/// any missing cards via `ensureWeek` (the same ensure-on-watch pattern as
/// `RoundupRepository.watchArchive`); later watches re-read the frozen rows.
/// The repository guards the gate: the current ISO week never generates
/// before Sunday 18:00 local.
final weekInsightsProvider = StreamProvider<List<CoachInsightRow>>((
  ref,
) async* {
  final week = isoWeekOf(ref.watch(selectedDateProvider));
  final repository = ref.watch(coachRepositoryProvider);
  await repository.ensureWeek(week.year, week.week);
  yield* repository.watchWeekInsights(week.year, week.week);
});
