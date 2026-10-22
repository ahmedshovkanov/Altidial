import 'package:drift/drift.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/daos/series_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/series_row_rule.dart';

/// Expands recurring series into ordinary `events` rows (spec §4.3), so that
/// nothing downstream contains recurrence logic.
///
/// It is idempotent. For every day a series covers, an event is created only
/// if the series has no row on that day yet; a skipped row counts as a row,
/// and an occurrence the person moved or renamed is never overwritten.
///
/// A series occurrence that would need a fourth overlapping ring is not
/// created on that day (the dial can draw three). It is tried again whenever
/// the day is next materialised, so it appears as soon as there is room.
class SeriesMaterialiser {
  SeriesMaterialiser(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SeriesDao _dao;
  final DateTime Function() _clock;

  Future<void> materialiseDay(DateTime day) =>
      materialise(day, nextDay(startOfDay(day)));

  /// Fills the days in [from, toExclusive) in one transaction.
  Future<void> materialise(DateTime from, DateTime toExclusive) {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    if (!start.isBefore(end)) return Future.value();

    return _dao.inTransaction(() async {
      final series = await _dao.seriesCovering(start, end);
      if (series.isEmpty) return;

      final existing = await _dao.occurrenceKeys(start, end);
      final rangesByDay = <DateTime, List<MinuteRange>>{};
      for (final row in await _dao.liveEventsBetween(start, end)) {
        rangesByDay
            .putIfAbsent(row.date, () => [])
            .add(MinuteRange(row.startMinute, row.endMinute));
      }

      final now = _clock();
      for (final row in series) {
        final range = MinuteRange(row.startMinute, row.endMinute);
        for (final date in occurrenceDates(
          rule: row.rule,
          validFrom: row.validFrom,
          from: start,
          toExclusive: end,
        )) {
          if (existing.contains((seriesId: row.id, date: date))) continue;

          final onDay = rangesByDay.putIfAbsent(date, () => []);
          if (wouldOverflowRings(existing: onDay, candidate: range)) continue;

          await _dao.insertEvent(
            EventsCompanion.insert(
              seriesId: Value(row.id),
              date: date,
              title: row.title,
              toneIndex: row.toneIndex,
              startMinute: row.startMinute,
              endMinute: row.endMinute,
              // Series carry no project: occurrences start unlinked and are
              // linked per-occurrence via EventDao.updateProject.
              projectId: const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
          onDay.add(range);
        }
      }
    });
  }
}
