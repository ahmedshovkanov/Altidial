import 'package:drift/drift.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

export 'package:energy_clock/core/geometry/ring_layout.dart'
    show RingOverflowException;
export 'package:energy_clock/features/clock/model/calendar_event.dart';

abstract interface class EventRepository {
  Stream<List<CalendarEvent>> watchDay(DateTime day);
  Future<List<CalendarEvent>> eventsForDay(DateTime day);

  /// The tones planned on each day from [from] (inclusive) to [toExclusive],
  /// for the week strip's dots. Days with no events are absent from the map.
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  );

  /// Every flight in `[from, toExclusive)`, oldest first, as a stream.
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  );

  /// Throws [RingOverflowException] if the new event would need a fourth ring.
  /// When [isFlight] is true the tone is forced to Inbox and [fromCode] /
  /// [toCode] must be valid IATA codes (validated by the caller).
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
    int? projectId,
  });

  /// Throws [RingOverflowException] if the new position would need a fourth
  /// ring. The event's own current position is excluded from the check.
  Future<void> moveEvent({
    required int id,
    required DateTime day,
    required MinuteRange range,
  });

  Future<void> updateDetails({
    required int id,
    required String title,
    required Tone tone,
  });

  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
  });

  /// Links ([projectId]) or unlinks (null) one event to a project.
  Future<void> updateProject({required int id, required int? projectId});

  /// Bulk version of [updateProject] for the edit-all-future path: every
  /// event of [seriesId] on or after [fromDate].
  Future<void> updateProjectForSeries({
    required int seriesId,
    required DateTime fromDate,
    required int? projectId,
  });

  Future<void> deleteEvent(int id);
}

class DriftEventRepository implements EventRepository {
  /// [materialiser], when given, fills a day from its recurring series each
  /// time the day (or a range of days) is watched.
  DriftEventRepository(
    this._dao, {
    DateTime Function()? clock,
    this._materialiser,
  }) : _clock = clock ?? DateTime.now;

  final EventDao _dao;
  final DateTime Function() _clock;
  final SeriesMaterialiser? _materialiser;

  /// Expands the series that cover [from, toExclusive). If that fails, the days
  /// are shown as stored: a broken expansion must never lock the person out of
  /// their day.
  Future<void> _fill(DateTime from, DateTime toExclusive) async {
    final materialiser = _materialiser;
    if (materialiser == null) return;
    try {
      await materialiser.materialise(from, toExclusive);
    } on Object {
      // Fall through to what is stored.
    }
  }

  @override
  Stream<List<CalendarEvent>> watchDay(DateTime day) async* {
    final start = startOfDay(day);
    await _fill(start, nextDay(start));
    yield* _dao
        .watchDay(start)
        .map((rows) => rows.map(CalendarEvent.fromRow).toList());
  }

  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async {
    final rows = await _dao.eventsForDay(startOfDay(day));
    return rows.map(CalendarEvent.fromRow).toList();
  }

  @override
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    await _fill(start, end);
    yield* _dao.watchToneDays(start, end).map((rows) {
      final byDay = <DateTime, Set<Tone>>{};
      for (final row in rows) {
        byDay
            .putIfAbsent(startOfDay(row.date), () => <Tone>{})
            .add(Tone.fromDbIndex(row.toneIndex));
      }
      return byDay;
    });
  }

  @override
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    await _fill(start, end);
    yield* _dao.watchRange(start, end).map(
      (rows) => rows
          .where((row) => row.isFlight)
          .map(CalendarEvent.fromRow)
          .toList(),
    );
  }

  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
    int? projectId,
  }) async {
    final normalisedDay = startOfDay(day);
    await _guardRings(day: normalisedDay, range: range);

    final now = _clock();
    final flight = isFlight;
    return _dao.insertEvent(
      EventsCompanion.insert(
        date: normalisedDay,
        title: title,
        toneIndex: flight ? Tone.inbox.dbIndex : tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        createdAt: now,
        updatedAt: now,
        isFlight: Value(flight),
        flightNumber: Value(flight ? flightNumber : null),
        fromCode: Value(flight ? fromCode : null),
        toCode: Value(flight ? toCode : null),
        projectId: Value(projectId),
      ),
    );
  }

  @override
  Future<void> moveEvent({
    required int id,
    required DateTime day,
    required MinuteRange range,
  }) async {
    final normalisedDay = startOfDay(day);
    await _guardRings(day: normalisedDay, range: range, excludingId: id);

    await _dao.updateTimes(
      id: id,
      startMinute: range.start,
      endMinute: range.end,
      updatedAt: _clock(),
    );
  }

  @override
  Future<void> updateDetails({
    required int id,
    required String title,
    required Tone tone,
  }) {
    return _dao.updateDetails(
      id: id,
      title: title,
      toneIndex: tone.dbIndex,
      updatedAt: _clock(),
    );
  }

  @override
  Future<void> deleteEvent(int id) => _dao.deleteById(id, now: _clock());

  @override
  Future<void> updateProject({required int id, required int? projectId}) =>
      _dao.updateProject(id: id, projectId: projectId);

  @override
  Future<void> updateProjectForSeries({
    required int seriesId,
    required DateTime fromDate,
    required int? projectId,
  }) => _dao.updateProjectForSeries(
    seriesId: seriesId,
    fromDate: startOfDay(fromDate),
    projectId: projectId,
  );

  @override
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
  }) {
    return _dao.updateFlight(
      id: id,
      isFlight: isFlight,
      flightNumber: isFlight ? flightNumber : null,
      fromCode: isFlight ? fromCode : null,
      toCode: isFlight ? toCode : null,
      updatedAt: _clock(),
    );
  }

  Future<void> _guardRings({
    required DateTime day,
    required MinuteRange range,
    int? excludingId,
  }) async {
    final existing = await eventsForDay(day);
    final ranges = [
      for (final event in existing)
        if (event.id != excludingId) event.range,
    ];
    if (wouldOverflowRings(existing: ranges, candidate: range)) {
      throw const RingOverflowException();
    }
  }
}
