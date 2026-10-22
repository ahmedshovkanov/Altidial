import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reflectionsTimelineProvider = StreamProvider<List<ReflectedSession>>((ref) {
  return ref.watch(reflectionsRepositoryProvider).watchTimeline();
});

/// The pattern cards for the timeline's completed, rated sessions.
///
/// Derived from [reflectionsTimelineProvider] rather than from a second
/// `watchTimeline()` subscription, so one database write costs one timeline
/// join instead of two. The create function re-runs on every timeline value,
/// which is the same idiom [statsDataProvider] uses to re-query on a watch
/// change.
final reflectionPatternsProvider = StreamProvider<List<PatternCard>>((ref) {
  final timeline = ref.watch(reflectionsTimelineProvider);
  return timeline.when(
    data: (rows) => Stream.value(_patternCards(rows)),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
    loading: () => _pending(),
  );
});

List<PatternCard> _patternCards(List<ReflectedSession> timeline) {
  final inputs = <PatternInput>[
    for (final row in timeline)
      if (row.session.outcome.countsAsDone &&
          row.session.energyRating != null &&
          row.session.focusRating != null)
        (
          tone: row.tone,
          energyRating: row.session.energyRating!,
          focusRating: row.session.focusRating!,
          tags: row.session.tags,
          startHour: row.startHour,
          isPostLife: row.isPostLife,
        ),
  ];
  return ReflectionPatterns.compute(inputs);
}

/// A stream that never emits and never completes, so the provider keeps its
/// loading state while the timeline it watches is still loading. An empty
/// stream would instead be reported as a failure by [StreamProvider].
Stream<T> _pending<T>() => Stream<T>.multi((_) {});