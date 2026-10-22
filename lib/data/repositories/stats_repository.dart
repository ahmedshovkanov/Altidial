import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';

/// Completed minutes for one tone on one local day.
typedef ToneDayMinutes = ({DateTime date, Tone tone, int minutes});

/// Planned against completed minutes for one tone over a whole window.
typedef TonePlannedActual = ({
  Tone tone,
  int plannedMinutes,
  int completedMinutes,
});

/// One `countsAsDone` focus session: when it began, how long was worked.
typedef FocusInstant = ({DateTime startedAt, int activeSeconds});

/// Focus depth over a window (spec §8.3): totals over the `countsAsDone` pool,
/// the abandonment rate over every ended session.
class FocusDepth {
  const FocusDepth({
    required this.minutes,
    required this.longestSeconds,
    required this.averageSeconds,
    required this.ended,
    required this.abandoned,
  });

  const FocusDepth.zero()
    : this(
        minutes: 0,
        longestSeconds: 0,
        averageSeconds: 0,
        ended: 0,
        abandoned: 0,
      );

  final int minutes;
  final int longestSeconds;
  final int averageSeconds;
  final int ended;
  final int abandoned;

  /// Null when nothing ended: callers show `—`.
  double? get abandonmentRate => ended == 0 ? null : abandoned / ended;
}

/// Everything the Stats tab shows for one window.
class StatsSnapshot {
  const StatsSnapshot({
    required this.toneByDay,
    required this.plannedByTone,
    required this.focus,
    required this.focusInstants,
  });

  const StatsSnapshot.empty()
    : this(
        toneByDay: const [],
        plannedByTone: const [],
        focus: const FocusDepth.zero(),
        focusInstants: const [],
      );

  /// Completed minutes per (day, tone) cell, day then tone order.
  final List<ToneDayMinutes> toneByDay;

  /// One row per tone, even at zero.
  final List<TonePlannedActual> plannedByTone;
  final FocusDepth focus;
  final List<FocusInstant> focusInstants;

  int get plannedTotal =>
      plannedByTone.fold(0, (sum, row) => sum + row.plannedMinutes);
  int get completedTotal =>
      plannedByTone.fold(0, (sum, row) => sum + row.completedMinutes);

  /// Rounded percent, or null when nothing was planned.
  int? get adherencePercent =>
      plannedTotal == 0 ? null : (completedTotal * 100 / plannedTotal).round();

  bool get isEmpty =>
      plannedTotal == 0 && completedTotal == 0 && focus.ended == 0;
}

/// What the Stats tab reads: one snapshot per window.
abstract interface class StatsRepository {
  /// Materialises recurring events into `[from, toExclusive)` first, then
  /// emits the snapshot and emits again on every database change.
  Stream<StatsSnapshot> watchWindow(DateTime from, DateTime toExclusive);
}

class DriftStatsRepository implements StatsRepository {
  DriftStatsRepository(this._db, {this._materialiser});

  final AppDatabase _db;
  final SeriesMaterialiser? _materialiser;

  @override
  Stream<StatsSnapshot> watchWindow(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    final materialiser = _materialiser;
    if (materialiser != null) {
      try {
        await materialiser.materialise(from, toExclusive);
      } on Object {
        // Show the window as stored: a failed expansion must not blank Stats.
      }
    }
    yield await _load(from, toExclusive);
    await for (final _ in _db.tableUpdates()) {
      yield await _load(from, toExclusive);
    }
  }

  /// Seconds truncate to minutes once per (day, tone) cell; per-tone
  /// completed minutes are the sum of their day cells.
  Future<StatsSnapshot> _load(
    DateTime from,
    DateTime toExclusive,
  ) => _db.transaction(() async {
    final cells = await _db.statsDao.toneSecondsByDay(from, toExclusive);
    final planned = await _db.statsDao.plannedMinutesByTone(from, toExclusive);
    final instants = await _db.statsDao.focusInstants(
      from,
      toExclusive,
      Tone.focus.dbIndex,
    );
    final outcomes = await _db.statsDao.focusOutcomeCounts(
      from,
      toExclusive,
      Tone.focus.dbIndex,
    );

    final toneByDay =
        <ToneDayMinutes>[
          for (final cell in cells)
            (
              date: cell.date,
              tone: Tone.fromDbIndex(cell.toneIndex),
              minutes: cell.seconds ~/ 60,
            ),
        ]..sort((a, b) {
          final days = a.date.compareTo(b.date);
          return days != 0 ? days : a.tone.dbIndex.compareTo(b.tone.dbIndex);
        });

    final plannedByToneIndex = <int, int>{
      for (final row in planned) row.toneIndex: row.minutes,
    };
    final completedByTone = <Tone, int>{};
    for (final cell in toneByDay) {
      completedByTone[cell.tone] =
          (completedByTone[cell.tone] ?? 0) + cell.minutes;
    }
    final plannedByTone = <TonePlannedActual>[
      for (final tone in Tone.values)
        (
          tone: tone,
          plannedMinutes: plannedByToneIndex[tone.dbIndex] ?? 0,
          completedMinutes: completedByTone[tone] ?? 0,
        ),
    ];

    final focusSeconds = instants.fold(
      0,
      (sum, instant) => sum + instant.activeSeconds,
    );
    return StatsSnapshot(
      toneByDay: toneByDay,
      plannedByTone: plannedByTone,
      focus: FocusDepth(
        minutes: focusSeconds ~/ 60,
        longestSeconds: instants.fold(
          0,
          (longest, instant) =>
              instant.activeSeconds > longest ? instant.activeSeconds : longest,
        ),
        averageSeconds: instants.isEmpty ? 0 : focusSeconds ~/ instants.length,
        ended: outcomes.ended,
        abandoned: outcomes.abandoned,
      ),
      focusInstants: instants,
    );
  });
}
