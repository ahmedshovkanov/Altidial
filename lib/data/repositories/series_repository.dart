import 'package:drift/drift.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/geometry/ring_layout.dart';
import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/daos/series_dao.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/models/series_row_rule.dart';

/// Writes recurring events (spec §7): making an event repeat, and editing or
/// deleting "this and all future" of a series. Deleting a single occurrence is
/// `EventRepository.deleteEvent`, which skips it.
///
/// Days are filled in by `SeriesMaterialiser`, not here: these methods change
/// the series and the one event the person is looking at, and the later days
/// follow the next time they are read.
abstract interface class SeriesRepository {
  /// The rule of the series, or null if it no longer exists.
  Future<RecurrenceRule?> ruleFor(int seriesId);

  /// Creates an event on [day] that repeats by [rule] (which must repeat), and
  /// its series, which starts on [day]. The event on [day] exists even when
  /// its weekday is not in the rule. Returns the event's id. Throws
  /// `RingOverflowException`, writing nothing, if [day] cannot take it.
  Future<int> createRecurring({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  });

  /// "This and all future". The event keeps its row and takes the new values.
  /// If it belongs to a series, that series ends the day before and its later
  /// days are removed; if [rule] repeats, a new series starts on the event's
  /// day, so a one-off event becomes a repeating one. A rule of "never" leaves
  /// the event as a one-off. Throws `RingOverflowException`, changing nothing,
  /// if the new times do not fit the event's own day. An event that no longer
  /// exists is ignored.
  Future<void> updateFromHere({
    required int eventId,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  });

  /// Deletes the event and, if it belongs to a series, every later day of it,
  /// and ends the series the day before (or removes the series, if this was its
  /// first day). An event that no longer exists is ignored.
  Future<void> deleteFromHere(int eventId);
}

class DriftSeriesRepository implements SeriesRepository {
  DriftSeriesRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SeriesDao _dao;
  final DateTime Function() _clock;

  @override
  Future<RecurrenceRule?> ruleFor(int seriesId) async =>
      (await _dao.seriesById(seriesId))?.rule;

  @override
  Future<int> createRecurring({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) {
    assert(rule.repeats, 'createRecurring needs a rule that repeats');
    final first = startOfDay(day);
    return _dao.inTransaction(() async {
      await _guardRings(day: first, range: range);
      final now = _clock();
      final seriesId = await _insertSeries(
        title: title,
        tone: tone,
        range: range,
        rule: rule,
        validFrom: first,
        now: now,
      );
      return _dao.insertEvent(
        EventsCompanion.insert(
          seriesId: Value(seriesId),
          date: first,
          title: title,
          toneIndex: tone.dbIndex,
          startMinute: range.start,
          endMinute: range.end,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<void> updateFromHere({
    required int eventId,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) {
    return _dao.inTransaction(() async {
      final event = await _dao.eventById(eventId);
      if (event == null) return;
      final day = event.date;
      await _guardRings(day: day, range: range, excludingId: eventId);

      final oldSeriesId = event.seriesId;
      if (oldSeriesId != null) {
        await _endBefore(oldSeriesId, day);
        await _dao.deleteOccurrencesFrom(oldSeriesId, nextDay(day));
      }

      final now = _clock();
      final newSeriesId = rule.repeats
          ? await _insertSeries(
              title: title,
              tone: tone,
              range: range,
              rule: rule,
              validFrom: day,
              now: now,
            )
          : null;
      await _dao.rewriteEvent(
        id: eventId,
        title: title,
        toneIndex: tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        seriesId: newSeriesId,
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> deleteFromHere(int eventId) {
    return _dao.inTransaction(() async {
      final event = await _dao.eventById(eventId);
      if (event == null) return;

      final seriesId = event.seriesId;
      if (seriesId == null) {
        await _dao.deleteEventAndSessions(eventId);
        return;
      }
      await _endBefore(seriesId, event.date);
      await _dao.deleteOccurrencesFrom(seriesId, event.date);
    });
  }

  /// Ends the series the day before [day]. A series that starts on [day] (or
  /// later) has no earlier days to keep, so it is removed.
  Future<void> _endBefore(int seriesId, DateTime day) async {
    final series = await _dao.seriesById(seriesId);
    if (series == null) return;
    if (!series.validFrom.isBefore(day)) {
      await _dao.deleteSeries(seriesId);
    } else {
      await _dao.setValidUntil(seriesId, previousDay(day));
    }
  }

  Future<int> _insertSeries({
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
    required DateTime validFrom,
    required DateTime now,
  }) {
    final until = rule.until;
    return _dao.insertSeries(
      EventSeriesCompanion.insert(
        title: title,
        toneIndex: tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        recurrenceKind: rule.kind.dbIndex,
        weekdayMask: Value(rule.weekdayMask),
        validFrom: validFrom,
        // An end day before the first day would make an empty series.
        validUntil: Value(
          until != null && until.isBefore(validFrom) ? validFrom : until,
        ),
        createdAt: now,
      ),
    );
  }

  Future<void> _guardRings({
    required DateTime day,
    required MinuteRange range,
    int? excludingId,
  }) async {
    final rows = await _dao.liveEventsBetween(day, nextDay(day));
    final existing = [
      for (final row in rows)
        if (row.id != excludingId) MinuteRange(row.startMinute, row.endMinute),
    ];
    if (wouldOverflowRings(existing: existing, candidate: range)) {
      throw const RingOverflowException();
    }
  }
}
